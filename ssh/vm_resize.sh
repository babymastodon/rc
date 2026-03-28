#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

usage() {
  cat <<'EOF' >&2
Usage: vm_resize.sh <ssh-alias>

Resizes the AWS or GCP VM behind an SSH alias from ~/.ssh/config.
EOF
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
fi

alias_name="$1"

resolved="$(ssh -G "$alias_name" 2>/dev/null)" || {
  err "Failed to resolve SSH alias: $alias_name"
  exit 1
}

get_ssh_value() {
  local key="$1"
  printf '%s\n' "$resolved" | awk -v wanted="$key" '$1 == wanted { $1=""; sub(/^ /, ""); print; exit }'
}

extract_flag_value() {
  local text="$1" flag="$2"
  printf '%s\n' "$text" | sed -nE "s/.*${flag}[= ]([^[:space:]\"']+).*/\1/p" | head -n1
}

prompt_with_default() {
  local prompt="$1" default="$2" value
  read -r -p "$prompt [$default]: " value
  printf '%s\n' "${value:-$default}"
}

prompt_yes_no() {
  local prompt="$1" default="$2" value normalized
  local suffix
  case "$default" in
    yes) suffix="[Y/n]" ;;
    no) suffix="[N/y]" ;;
    *) suffix="[$default]" ;;
  esac
  while true; do
    read -r -p "$prompt? $suffix " value
    normalized="${value:-$default}"
    normalized="$(printf '%s' "$normalized" | tr '[:upper:]' '[:lower:]')"
    case "$normalized" in
      y|yes) printf 'yes\n'; return 0 ;;
      n|no) printf 'no\n'; return 0 ;;
    esac
    warn "Please answer yes or no."
  done
}

aws_instance_stopped() {
  [[ "$(aws ec2 describe-instances --region "$region" --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)" == "stopped" ]]
}

gcp_instance_terminated() {
  [[ "$(gcloud compute instances describe "$instance_name" --project "$project" --zone "$zone" --format='value(status)' 2>/dev/null)" == "TERMINATED" ]]
}

wait_until() {
  local message="$1"
  local check_fn="$2"

  printf '%s\n' "$message"
  while ! "$check_fn" >/dev/null 2>&1; do
    sleep 2
  done
}

hostname_value="$(get_ssh_value hostname)"
proxycommand_value="$(get_ssh_value proxycommand)"

if [[ -z "$hostname_value" ]]; then
  err "SSH alias $alias_name does not define HostName."
  exit 1
fi

if [[ -z "$proxycommand_value" ]]; then
  if [[ "$hostname_value" == "$alias_name" ]]; then
    err "SSH alias $alias_name was not found in ~/.ssh/config."
  else
    err "SSH alias $alias_name does not define ProxyCommand, so cloud/provider cannot be inferred."
  fi
  exit 1
fi

ensure_aws_ready() {
  if ! command -v aws >/dev/null 2>&1; then
    err "aws CLI is required for AWS-backed aliases."
    exit 1
  fi
  if aws sts get-caller-identity >/dev/null 2>&1; then
    return 0
  fi
  warn "AWS credentials are not active. Running aws sso login."
  aws sso login
  aws sts get-caller-identity >/dev/null
}

ensure_gcloud_ready() {
  if ! command -v gcloud >/dev/null 2>&1; then
    err "gcloud CLI is required for GCP-backed aliases."
    exit 1
  fi
  local active_account
  active_account="$(gcloud auth list --filter="status:ACTIVE" --format="value(account)")"
  if [[ -n "$active_account" ]]; then
    return 0
  fi
  warn "No active gcloud account. Running gcloud auth login."
  gcloud auth login
}

aws_family() {
  printf '%s\n' "${1%%.*}"
}

gcp_family() {
  local base="${1##*/}"
  while [[ "$base" =~ -[0-9]+$ ]]; do
    base="${base%-*}"
  done
  printf '%s\n' "$base"
}

list_aws_family_types() {
  local family="$1"
  aws ec2 describe-instance-types \
    --filters "Name=instance-type,Values=${family}.*" \
    --query 'sort_by(InstanceTypes,&MemoryInfo.SizeInMiB)[].[InstanceType,MemoryInfo.SizeInMiB]' \
    --output text 2>/dev/null | sort -k2,2nr | awk '{printf "%-20s %6.1f GiB\n", $1, $2/1024}'
}

list_gcp_family_types() {
  local family="$1" zone="$2"
  gcloud compute machine-types list \
    --zones="$zone" \
    --filter="name ~ ^${family}-" \
    --format='value(name,memoryMb)' 2>/dev/null | sort -k2,2nr | awk '{printf "%-20s %6.1f GiB\n", $1, $2/1024}'
}

print_eligible_types() {
  local title="$1"
  shift
  printf 'Eligible %s:\n' "$title"
  printf '%s\n' "$@"
  printf '\n'
}

prompt_aws_type() {
  local current_type="$1" current_family="$2" candidate family output
  while true; do
    candidate="$(prompt_with_default "New AWS instance type" "$current_type")"
    if output="$(aws ec2 describe-instance-types --instance-types "$candidate" --query 'InstanceTypes[0].InstanceType' --output text 2>&1)"; then
      family="$(aws_family "$candidate")"
      if [[ "$family" != "$current_family" ]]; then
        warn "AWS instance type $candidate is family $family, expected $current_family."
        continue
      fi
      printf '%s\n' "$candidate"
      return 0
    fi
    warn "Could not validate AWS instance type $candidate: $output"
  done
}

prompt_gcp_type() {
  local current_type="$1" current_family="$2" zone="$3" candidate family output
  while true; do
    candidate="$(prompt_with_default "New GCP machine type" "$current_type")"
    if output="$(gcloud compute machine-types describe "$candidate" --zone "$zone" --format='value(name)' 2>&1)"; then
      family="$(gcp_family "$candidate")"
      if [[ "$family" != "$current_family" ]]; then
        warn "GCP machine type $candidate is family $family, expected $current_family."
        continue
      fi
      printf '%s\n' "$candidate"
      return 0
    fi
    warn "Could not validate GCP machine type $candidate: $output"
  done
}

cloud=""
case "$proxycommand_value" in
  *"aws ssm start-session"*) cloud="aws" ;;
  *"gcloud compute start-iap-tunnel"*) cloud="gcp" ;;
  *)
    err "Unsupported ProxyCommand for $alias_name: $proxycommand_value"
    exit 1
    ;;
esac

case "$cloud" in
  aws)
    ensure_aws_ready
    instance_id="$hostname_value"
    region="$(extract_flag_value "$proxycommand_value" '--region')"
    if [[ -z "$region" ]]; then
      err "AWS alias $alias_name must include --region in ProxyCommand."
      exit 1
    fi
    current_type="$(aws ec2 describe-instances --region "$region" --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].InstanceType' --output text)"
    current_state="$(aws ec2 describe-instances --region "$region" --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].State.Name' --output text)"
    current_family="$(aws_family "$current_type")"
    printf 'Current AWS instance type: %s\n' "$current_type"
    mapfile -t aws_types < <(list_aws_family_types "$current_family")
    if [[ ${#aws_types[@]} -gt 0 ]]; then
      print_eligible_types "AWS $current_family sizes" "${aws_types[@]}"
    fi
    new_type="$(prompt_aws_type "$current_type" "$current_family")"

    if [[ "$current_state" == "running" ]]; then
      if [[ "$(prompt_yes_no "Instance is running. Stop it now" "no")" != "yes" ]]; then
        err "AWS instance must be stopped before resizing."
        exit 1
      fi
      aws ec2 stop-instances --region "$region" --instance-ids "$instance_id" >/dev/null
      wait_until "Stopping AWS instance $instance_id and waiting for it to stop..." aws_instance_stopped
    elif [[ "$current_state" != "stopped" ]]; then
      err "AWS instance is in state $current_state. Resize requires running or stopped."
      exit 1
    fi

    aws ec2 modify-instance-attribute --region "$region" --instance-id "$instance_id" --instance-type "{\"Value\":\"$new_type\"}"
    log "Resized AWS instance $instance_id from $current_type to $new_type."
    ;;
  gcp)
    ensure_gcloud_ready
    instance_name="$hostname_value"
    project="$(extract_flag_value "$proxycommand_value" '--project')"
    zone="$(extract_flag_value "$proxycommand_value" '--zone')"
    if [[ -z "$project" || -z "$zone" ]]; then
      err "GCP alias $alias_name must include --project and --zone in ProxyCommand."
      exit 1
    fi
    current_type_path="$(gcloud compute instances describe "$instance_name" --project "$project" --zone "$zone" --format='value(machineType)')"
    current_type="${current_type_path##*/}"
    current_state="$(gcloud compute instances describe "$instance_name" --project "$project" --zone "$zone" --format='value(status)')"
    current_family="$(gcp_family "$current_type")"
    printf 'Current GCP machine type: %s\n' "$current_type"
    mapfile -t gcp_types < <(list_gcp_family_types "$current_family" "$zone")
    if [[ ${#gcp_types[@]} -gt 0 ]]; then
      print_eligible_types "GCP $current_family sizes in $zone" "${gcp_types[@]}"
    fi
    new_type="$(prompt_gcp_type "$current_type" "$current_family" "$zone")"

    if [[ "$current_state" == "RUNNING" ]]; then
      if [[ "$(prompt_yes_no "Instance is running. Stop it now" "no")" != "yes" ]]; then
        err "GCP instance must be stopped before resizing."
        exit 1
      fi
      gcloud compute instances stop "$instance_name" --project "$project" --zone "$zone" --quiet
      wait_until "Stopping GCP instance $instance_name and waiting for it to stop..." gcp_instance_terminated
    elif [[ "$current_state" != "TERMINATED" ]]; then
      err "GCP instance is in state $current_state. Resize requires RUNNING or TERMINATED."
      exit 1
    fi

    gcloud compute instances set-machine-type "$instance_name" --project "$project" --zone "$zone" --machine-type "$new_type" --quiet
    log "Resized GCP instance $instance_name from $current_type to $new_type."
    ;;
esac

printf 'Run the following command to start it:\n    vm %s\n' "$alias_name"
