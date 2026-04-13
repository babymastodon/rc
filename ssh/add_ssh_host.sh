#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

CONFIG_FILE="${SSH_CONFIG_FILE:-$HOME/.ssh/config}"
SSH_DIR="$(dirname "$CONFIG_FILE")"
INITIAL_ALIAS="${1:-}"

install_hint() {
  local tool="$1"
  case "$tool" in
    aws)
      printf 'Install the AWS CLI and rerun this script.\n' >&2
      printf 'macOS: brew install awscli\n' >&2
      printf 'Linux: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html\n' >&2
      ;;
    aws-session-manager-plugin)
      printf 'Install the AWS Session Manager plugin and rerun this script.\n' >&2
      printf 'macOS: brew install --cask session-manager-plugin\n' >&2
      printf 'Linux: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html\n' >&2
      ;;
    gcloud)
      printf 'Install the Google Cloud CLI and rerun this script.\n' >&2
      printf 'macOS: brew install --cask google-cloud-sdk\n' >&2
      printf 'Linux: https://cloud.google.com/sdk/docs/install\n' >&2
      ;;
  esac
}

default_key_path() {
  if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    printf '%s\n' "$HOME/.ssh/id_ed25519"
  elif [[ -f "$HOME/.ssh/id_rsa" ]]; then
    printf '%s\n' "$HOME/.ssh/id_rsa"
  else
    printf '%s\n' "$HOME/.ssh/id_ed25519"
  fi
}

prompt_with_default() {
  local prompt="$1" default="$2" value
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " value
    printf '%s\n' "${value:-$default}"
  else
    read -r -p "$prompt: " value
    printf '%s\n' "$value"
  fi
}

prompt_yes_no() {
  local prompt="$1" default="$2" value normalized prompt_suffix
  case "$default" in
    yes) prompt_suffix="[Y/n]" ;;
    no) prompt_suffix="[y/N]" ;;
    *) err "prompt_yes_no default must be yes or no."; exit 1 ;;
  esac
  while true; do
    read -r -p "$prompt $prompt_suffix: " value
    normalized="${value:-$default}"
    normalized="$(printf '%s' "$normalized" | tr '[:upper:]' '[:lower:]')"
    case "$normalized" in
      y|yes) printf 'yes\n'; return 0 ;;
      n|no) printf 'no\n'; return 0 ;;
    esac
    warn "Please answer yes or no."
  done
}

require_non_empty() {
  local label="$1" value="$2"
  if [[ -z "${value// }" ]]; then
    err "$label cannot be empty."
    exit 1
  fi
}

require_aws_instance_id() {
  local value="$1"
  if [[ ! "$value" =~ ^i-[0-9a-f]+$ ]]; then
    return 1
  fi
  return 0
}

prompt_aws_instance_id() {
  local value
  while true; do
    value="$(prompt_with_default "EC2 instance ID" "")"
    if [[ -z "${value// }" ]]; then
      warn "EC2 instance ID cannot be empty."
      continue
    fi
    if require_aws_instance_id "$value"; then
      printf '%s\n' "$value"
      return 0
    fi
    warn "EC2 instance ID must look like i-0123456789abcdef0."
  done
}

prompt_gcp_instance_name() {
  local value
  while true; do
    value="$(prompt_with_default "GCE instance name" "")"
    if [[ -z "${value// }" ]]; then
      warn "GCE instance name cannot be empty."
      continue
    fi
    printf '%s\n' "$value"
    return 0
  done
}

aws_default_region() {
  local region=""
  if [[ -n "${AWS_REGION:-}" ]]; then
    region="$AWS_REGION"
  elif [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
    region="$AWS_DEFAULT_REGION"
  elif command -v aws >/dev/null 2>&1; then
    region="$(aws configure get region 2>/dev/null || true)"
  fi
  printf '%s\n' "${region:-us-east-1}"
}

gcp_default_project() {
  local project=""
  if command -v gcloud >/dev/null 2>&1; then
    project="$(gcloud config get-value project 2>/dev/null || true)"
  fi
  printf '%s\n' "${project:-my-project}"
}

gcp_default_zone() {
  local zone=""
  if command -v gcloud >/dev/null 2>&1; then
    zone="$(gcloud config get-value compute/zone 2>/dev/null || true)"
  fi
  printf '%s\n' "${zone:-us-central1-a}"
}

ensure_aws_ready() {
  if ! command -v aws >/dev/null 2>&1; then
    err "aws CLI is required for AWS hosts."
    install_hint aws
    exit 1
  fi

  if ! command -v session-manager-plugin >/dev/null 2>&1; then
    err "AWS Session Manager plugin is required for AWS hosts."
    install_hint aws-session-manager-plugin
    exit 1
  fi

  if aws sts get-caller-identity >/dev/null 2>&1; then
    return 0
  fi

  warn "AWS CLI is installed, but you are not logged in."
  printf 'Run this command to log in:\n  aws sso login\n' >&2
  if [[ "$(prompt_yes_no "Run aws sso login now" "yes")" != "yes" ]]; then
    err "AWS login required before adding an AWS host."
    exit 1
  fi

  aws sso login
  aws sts get-caller-identity >/dev/null 2>&1 || {
    err "AWS login did not succeed."
    exit 1
  }
}

ensure_gcloud_ready() {
  if ! command -v gcloud >/dev/null 2>&1; then
    err "gcloud CLI is required for GCP hosts."
    install_hint gcloud
    exit 1
  fi

  local active_account
  active_account="$(gcloud auth list --filter="status:ACTIVE" --format="value(account)")"
  if [[ -n "$active_account" ]]; then
    return 0
  fi

  warn "gcloud CLI is installed, but no active account is configured."
  printf 'Run this command to log in:\n  gcloud auth login\n' >&2
  if [[ "$(prompt_yes_no "Run gcloud auth login now" "yes")" != "yes" ]]; then
    err "GCP login required before adding a GCP host."
    exit 1
  fi

  gcloud auth login
  active_account="$(gcloud auth list --filter="status:ACTIVE" --format="value(account)")"
  if [[ -z "$active_account" ]]; then
    err "gcloud login did not succeed."
    exit 1
  fi
}

alias_exists() {
  local alias_name="$1"
  [[ -f "$CONFIG_FILE" ]] || return 1
  awk -v alias_name="$alias_name" '
    $1 == "Host" {
      for (i = 2; i <= NF; i++) {
        if ($i == alias_name) {
          found = 1
        }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$CONFIG_FILE"
}

prompt_alias_name() {
  local value="${INITIAL_ALIAS:-}"
  while true; do
    if [[ -n "${value:-}" ]]; then
      log "Using SSH alias: $value"
    else
      value="$(prompt_with_default "SSH alias" "devserver")"
    fi
    if [[ -z "${value// }" ]]; then
      warn "SSH alias cannot be empty."
      value=""
      continue
    fi
    if alias_exists "$value"; then
      warn "SSH alias '$value' already exists in $CONFIG_FILE."
      value=""
      continue
    fi
    printf '%s\n' "$value"
    return 0
  done
}

validate_aws_instance() {
  local output
  if output="$(aws ec2 describe-instances \
    --region "$region" \
    --instance-ids "$host_name" \
    --query 'Reservations[0].Instances[0].[InstanceId,State.Name,Placement.AvailabilityZone]' \
    --output text 2>&1)"; then
    log "AWS validation succeeded."
    printf 'Validation: %s\n' "$output"
    return 0
  else
    warn "AWS validation failed."
    printf 'Validation error: %s\n' "$output"
    return 1
  fi
}

validate_gcp_instance() {
  local output
  if output="$(gcloud compute instances describe "$host_name" \
    --project "$project" \
    --zone "$zone" \
    --format='value(name,status,zone)' 2>&1)"; then
    log "GCP validation succeeded."
    printf 'Validation: %s\n' "$output"
    return 0
  else
    warn "GCP validation failed."
    printf 'Validation error: %s\n' "$output"
    return 1
  fi
}

provider="$(prompt_with_default "Cloud provider (aws/gcp)" "aws")"
provider="$(printf '%s' "$provider" | tr '[:upper:]' '[:lower:]')"
case "$provider" in
  aws|gcp) ;;
  *)
    err "Provider must be aws or gcp."
    exit 1
    ;;
esac

case "$provider" in
  aws) ensure_aws_ready ;;
  gcp) ensure_gcloud_ready ;;
esac

alias_name="$(prompt_alias_name)"
ssh_user="$(prompt_with_default "Linux username" "${USER:-devuser}")"
identity_file="$(prompt_with_default "Private key path" "$(default_key_path)")"

case "$provider" in
  aws)
    host_name="$(prompt_aws_instance_id)"
    region="$(prompt_with_default "AWS region" "$(aws_default_region)")"
    ;;
  gcp)
    host_name="$(prompt_gcp_instance_name)"
    project="$(prompt_with_default "GCP project ID" "$(gcp_default_project)")"
    zone="$(prompt_with_default "GCP zone" "$(gcp_default_zone)")"
    ;;
esac

require_non_empty "SSH alias" "$alias_name"
require_non_empty "Linux username" "$ssh_user"
require_non_empty "Private key path" "$identity_file"
require_non_empty "HostName" "$host_name"

config_block="$(cat <<EOF
Host $alias_name
    HostName $host_name
    User $ssh_user
    IdentityFile $identity_file
    ForwardAgent yes
    IdentityAgent \$SSH_AUTH_SOCK
EOF
)"

case "$provider" in
  aws)
    require_non_empty "AWS region" "$region"
    printf -v aws_proxy_command '    ProxyCommand sh -c "aws ssm start-session --target %%h --region %s --document-name AWS-StartSSHSession --parameters \\"portNumber=%%p\\""' "$region"
    config_block+=$'\n'"$aws_proxy_command"
    ;;
  gcp)
    require_non_empty "GCP project ID" "$project"
    require_non_empty "GCP zone" "$zone"
    config_block+=$'\n'"    IdentitiesOnly yes"
    config_block+=$'\n'"    ProxyCommand gcloud compute start-iap-tunnel %h 22 --project=$project --zone $zone --listen-on-stdin"
    ;;
esac

printf '\nProposed SSH config entry:\n\n'
printf '%s\n' "$config_block"
printf '\n'

validation_ok=no
case "$provider" in
  aws)
    if validate_aws_instance; then
      validation_ok=yes
    fi
    ;;
  gcp)
    if validate_gcp_instance; then
      validation_ok=yes
    fi
    ;;
esac
printf '\n'

confirm_default=no
if [[ "$validation_ok" == "yes" ]]; then
  confirm_default=yes
fi

confirm_write="$(prompt_yes_no "Prepend this entry to $CONFIG_FILE" "$confirm_default")"
if [[ "$confirm_write" != "yes" ]]; then
  log "Aborted without writing."
  exit 0
fi

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR" || true
touch "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE" || true

tmp_config="$(mktemp)"
if [[ -s "$CONFIG_FILE" ]]; then
  {
    printf '%s\n\n' "$config_block"
    cat "$CONFIG_FILE"
  } > "$tmp_config"
else
  printf '%s\n' "$config_block" > "$tmp_config"
fi
mv "$tmp_config" "$CONFIG_FILE"

log "Prepended Host $alias_name to $CONFIG_FILE"
printf 'Next step: launch and SSH in with:\n\n  vm %s\n\nTo mount the filesystem, run:\n\n  vmfs %s\n' "$alias_name" "$alias_name"
