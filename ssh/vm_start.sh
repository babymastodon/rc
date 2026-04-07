#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

POLL_INTERVAL_SEC="${POLL_INTERVAL_SEC:-5}"
TIMEOUT_SEC="${TIMEOUT_SEC:-300}"
SSH_RETRY_INTERVAL_SEC="${SSH_RETRY_INTERVAL_SEC:-5}"
SSH_RETRY_TIMEOUT_SEC="${SSH_RETRY_TIMEOUT_SEC:-120}"

usage() {
  cat <<'EOF' >&2
Usage: vm_start.sh [-t] <ssh-alias> [port...]

Starts the VM behind an SSH alias defined in ~/.ssh/config, waits for it to
become reachable, then SSHes into it.

Optional arguments:
- -t to sync the current local TERM terminfo to the remote before connecting
- Each port can be either:
- PORT to forward the same local and remote port
- LOCAL:REMOTE to forward different local and remote ports

Examples:
  vm_start.sh devserver 8080 3000
is equivalent to:
  ssh -L 8080:localhost:8080 -L 3000:localhost:3000 devserver

  vm_start.sh devserver 8000:443
is equivalent to:
  ssh -L 8000:localhost:443 devserver

  vm_start.sh -t devserver 8080
syncs the current TERM terminfo to the remote, then runs:
  ssh -L 8080:localhost:8080 devserver
EOF
  exit 1
}

sync_term_requested=0

while getopts ":t" opt; do
  case "$opt" in
    t)
      sync_term_requested=1
      ;;
    :)
      usage
      ;;
    \?)
      usage
      ;;
  esac
done

shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
  usage
fi

alias_name="$1"
shift
forwarded_port_specs=("$@")

if ! command -v ssh >/dev/null 2>&1; then
  err "ssh is required."
  exit 1
fi

resolved="$(ssh -G "$alias_name" 2>/dev/null)" || {
  err "Failed to resolve SSH alias: $alias_name"
  exit 1
}

get_ssh_value() {
  local key="$1"
  printf '%s\n' "$resolved" | awk -v wanted="$key" '$1 == wanted { $1=""; sub(/^ /, ""); print; exit }'
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  (( port >= 1 && port <= 65535 ))
}

build_forward_spec() {
  local spec="$1" local_port remote_port

  if [[ "$spec" == *:* ]]; then
    IFS=':' read -r local_port remote_port <<<"$spec"
  else
    local_port="$spec"
    remote_port="$spec"
  fi

  if ! validate_port "$local_port" || ! validate_port "$remote_port"; then
    return 1
  fi

  printf '%s:localhost:%s\n' "$local_port" "$remote_port"
}

forwarded_ports=()
for spec in "${forwarded_port_specs[@]}"; do
  forward_spec="$(build_forward_spec "$spec" || true)"
  if [[ -z "$forward_spec" ]]; then
    err "Invalid port forward: $spec. Use PORT or LOCAL:REMOTE with integers between 1 and 65535."
    exit 1
  fi
  forwarded_ports+=("$forward_spec")
done

hostname_value="$(get_ssh_value hostname)"
proxycommand_value="$(get_ssh_value proxycommand)"
user_value="$(get_ssh_value user)"

if [[ -z "$hostname_value" ]]; then
  err "SSH alias $alias_name does not define HostName."
  exit 1
fi

if [[ -z "$proxycommand_value" ]]; then
  if [[ "$hostname_value" == "$alias_name" ]]; then
    err "SSH alias $alias_name was not found in ~/.ssh/config."
    exit 1
  else
    cloud="direct"
  fi
else
  cloud=""
  case "$proxycommand_value" in
    *"aws ssm start-session"*)
      cloud="aws"
      ;;
    *"gcloud compute start-iap-tunnel"*)
      cloud="gcp"
      ;;
    *)
      err "Unsupported ProxyCommand for $alias_name: $proxycommand_value"
      exit 1
      ;;
  esac
fi

extract_flag_value() {
  local text="$1" flag="$2"
  printf '%s\n' "$text" | sed -nE "s/.*${flag}[= ]([^[:space:]\"']+).*/\1/p" | head -n1
}

ensure_aws_auth() {
  if ! command -v aws >/dev/null 2>&1; then
    err "aws CLI is required for AWS-backed aliases."
    exit 1
  fi

  if aws sts get-caller-identity >/dev/null 2>&1; then
    return 0
  fi

  local profile_arg=()
  if [[ -n "${AWS_PROFILE:-}" ]]; then
    profile_arg=(--profile "$AWS_PROFILE")
  fi

  warn "AWS credentials are not active. Running aws sso login."
  aws sso login "${profile_arg[@]}"
  aws sts get-caller-identity >/dev/null
}

ensure_gcloud_auth() {
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

start_aws_vm() {
  local instance_id region start_ts now status
  instance_id="$hostname_value"
  region="$(extract_flag_value "$proxycommand_value" '--region')"
  start_ts="$(date +%s)"

  ensure_aws_auth

  get_status() {
    local args=()
    if [[ -n "$region" ]]; then
      args+=(--region "$region")
    fi
    aws ec2 describe-instances \
      "${args[@]}" \
      --instance-ids "$instance_id" \
      --query 'Reservations[0].Instances[0].State.Name' \
      --output text
  }

  status="$(get_status)"
  case "$status" in
    running)
      log "AWS instance $instance_id is running."
      return 0
      ;;
    stopped)
      log "Starting AWS instance $instance_id${region:+ in $region}..."
      if [[ -n "$region" ]]; then
        aws ec2 start-instances --region "$region" --instance-ids "$instance_id" >/dev/null
      else
        aws ec2 start-instances --instance-ids "$instance_id" >/dev/null
      fi
      ;;
    pending)
      log "AWS instance $instance_id is already pending."
      ;;
    stopping|shutting-down|terminated)
      err "AWS instance $instance_id is in state $status."
      exit 1
      ;;
    *)
      err "Unknown AWS instance state for $instance_id: $status"
      exit 1
      ;;
  esac

  while true; do
    status="$(get_status)"
    if [[ "$status" == "running" ]]; then
      log "AWS instance $instance_id is running."
      return 0
    fi
    now="$(date +%s)"
    if (( now - start_ts > TIMEOUT_SEC )); then
      err "Timed out waiting for AWS instance $instance_id to reach running."
      exit 1
    fi
    sleep "$POLL_INTERVAL_SEC"
  done
}

start_gcp_vm() {
  local instance_name project zone start_ts now status
  instance_name="$hostname_value"
  project="$(extract_flag_value "$proxycommand_value" '--project')"
  zone="$(extract_flag_value "$proxycommand_value" '--zone')"
  start_ts="$(date +%s)"

  if [[ -z "$project" || -z "$zone" ]]; then
    err "GCP alias $alias_name must include --project and --zone in ProxyCommand."
    exit 1
  fi

  ensure_gcloud_auth

  get_status() {
    gcloud compute instances describe "$instance_name" \
      --project "$project" \
      --zone "$zone" \
      --format='value(status)'
  }

  status="$(get_status)"
  if [[ "$status" != "RUNNING" ]]; then
    log "Starting GCP instance $instance_name in $project/$zone..."
    gcloud compute instances start "$instance_name" \
      --project "$project" \
      --zone "$zone" >/dev/null
  else
    log "GCP instance $instance_name is already RUNNING."
  fi

  while true; do
    status="$(get_status)"
    if [[ "$status" == "RUNNING" ]]; then
      log "GCP instance $instance_name is RUNNING."
      return 0
    fi
    now="$(date +%s)"
    if (( now - start_ts > TIMEOUT_SEC )); then
      err "Timed out waiting for GCP instance $instance_name to reach RUNNING."
      exit 1
    fi
    sleep "$POLL_INTERVAL_SEC"
  done
}

sync_terminfo() {
  local term remote_cmd
  (( sync_term_requested )) || return 0
  term="${TERM:-}"

  [[ -n "$term" ]] || return 0
  command -v infocmp >/dev/null 2>&1 || return 0
  infocmp -x "$term" >/dev/null 2>&1 || return 0

  remote_cmd='
    if ! command -v tic >/dev/null 2>&1; then
      exit 0
    fi
    mkdir -p "$HOME/.terminfo"
    cat | tic -x -
  '

  log "Syncing local terminfo for $term to $alias_name when needed."
  ssh -o BatchMode=yes -o ConnectTimeout=5 -T "$alias_name" "$remote_cmd" \
    < <(infocmp -x "$term") >/dev/null 2>&1 || true
}

retry_ssh() {
  local ssh_start_ts now ssh_args=() ssh_probe_args=()
  ssh_start_ts="$(date +%s)"

  log "Attempting to connect to the SSH server..."

  for port in "${forwarded_ports[@]}"; do
    ssh_args+=(-L "$port")
  done

  ssh_probe_args+=(
    -o BatchMode=yes
    -o ConnectTimeout=5
    -o RequestTTY=no
    "$alias_name"
    true
  )
  ssh_args+=("$alias_name")

  while true; do
    if ssh "${ssh_probe_args[@]}" >/dev/null 2>&1; then
      break
    fi
    now="$(date +%s)"
    if (( now - ssh_start_ts > SSH_RETRY_TIMEOUT_SEC )); then
      err "Timed out waiting for SSH on $alias_name."
      exit 1
    fi
    sleep "$SSH_RETRY_INTERVAL_SEC"
  done

  sync_terminfo
  exec ssh "${ssh_args[@]}"
}

direct_ssh() {
  local ssh_args=()

  for port in "${forwarded_ports[@]}"; do
    ssh_args+=(-L "$port")
  done

  sync_terminfo
  log "Connecting directly to SSH host $hostname_value${user_value:+ as $user_value}."
  exec ssh "${ssh_args[@]}" "$alias_name"
}

if [[ "$cloud" == "direct" ]]; then
  log "Resolved $alias_name to direct SSH host $hostname_value${user_value:+ as $user_value}."
else
  log "Resolved $alias_name to $cloud host $hostname_value${user_value:+ as $user_value}."
fi

if [[ ${#forwarded_ports[@]} -gt 0 ]]; then
  log "Forwarding local ports: ${forwarded_ports[*]}"
fi

case "$cloud" in
  aws) start_aws_vm ;;
  gcp) start_gcp_vm ;;
  direct) direct_ssh ;;
esac

retry_ssh
