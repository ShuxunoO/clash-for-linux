#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$PROJECT_DIR/runtime"
CONFIG_DIR="$PROJECT_DIR/config"
LOG_DIR="$PROJECT_DIR/logs"

RUNTIME_CONFIG="$RUNTIME_DIR/config.yaml"
STATE_FILE="$RUNTIME_DIR/state.env"

TMP_DOWNLOAD="$RUNTIME_DIR/subscription.raw.yaml"
TMP_NORMALIZED="$RUNTIME_DIR/subscription.normalized.yaml"
TMP_PROXY_FRAGMENT="$RUNTIME_DIR/proxy.fragment.yaml"
TMP_CONFIG="$RUNTIME_DIR/config.yaml.tmp"

mkdir -p "$RUNTIME_DIR" "$CONFIG_DIR" "$LOG_DIR"

if [ -f "$PROJECT_DIR/.env" ]; then
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env"
fi

# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/get_cpu_arch.sh"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/resolve_clash.sh"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/config_utils.sh"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/port_utils.sh"

CLASH_HTTP_PORT="${CLASH_HTTP_PORT:-7890}"
CLASH_SOCKS_PORT="${CLASH_SOCKS_PORT:-7891}"
CLASH_REDIR_PORT="${CLASH_REDIR_PORT:-7892}"
CLASH_LISTEN_IP="${CLASH_LISTEN_IP:-0.0.0.0}"
CLASH_ALLOW_LAN="${CLASH_ALLOW_LAN:-false}"
EXTERNAL_CONTROLLER_ENABLED="${EXTERNAL_CONTROLLER_ENABLED:-true}"
EXTERNAL_CONTROLLER="${EXTERNAL_CONTROLLER:-127.0.0.1:9090}"
ALLOW_INSECURE_TLS="${ALLOW_INSECURE_TLS:-false}"
CLASH_AUTO_UPDATE="${CLASH_AUTO_UPDATE:-true}"
CLASH_URL="${CLASH_URL:-}"

CLASH_HTTP_PORT="$(resolve_port_value "HTTP" "$CLASH_HTTP_PORT")"
CLASH_SOCKS_PORT="$(resolve_port_value "SOCKS" "$CLASH_SOCKS_PORT")"
CLASH_REDIR_PORT="$(resolve_port_value "REDIR" "$CLASH_REDIR_PORT")"
EXTERNAL_CONTROLLER="$(resolve_host_port "External Controller" "$EXTERNAL_CONTROLLER" "127.0.0.1")"

write_state() {
  local status="$1"
  local reason="$2"
  local source="${3:-unknown}"

  cat > "$STATE_FILE" <<EOF
LAST_GENERATE_STATUS=$status
LAST_GENERATE_REASON=$reason
LAST_CONFIG_SOURCE=$source
LAST_GENERATE_AT=$(date -Iseconds)
EOF
}

generate_secret() {
  if [ -n "${CLASH_SECRET:-}" ]; then
    echo "$CLASH_SECRET"
    return 0
  fi

  if [ -s "$RUNTIME_CONFIG" ]; then
    local old_secret
    old_secret="$(sed -nE 's/^[[:space:]]*secret:[[:space:]]*"?([^"#]+)"?.*$/\1/p' "$RUNTIME_CONFIG" | head -n 1)"
    if [ -n "${old_secret:-}" ]; then
      echo "$old_secret"
      return 0
    fi
  fi

  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

SECRET="$(generate_secret)"

upsert_yaml_kv_local() {
  local file="$1"
  local key="$2"
  local value="$3"

  [ -f "$file" ] || touch "$file"

  if grep -qE "^[[:space:]]*${key}:" "$file"; then
    sed -i -E "s|^[[:space:]]*${key}:.*$|${key}: ${value}|g" "$file"
  else
    printf "%s: %s\n" "$key" "$value" >> "$file"
  fi
}

apply_secret_to_config() {
  local file="$1"
  upsert_yaml_kv_local "$file" "secret" "$SECRET"
}

apply_controller_to_config() {
  local file="$1"
  local ui_dir="$RUNTIME_DIR/ui"

  if [ "$EXTERNAL_CONTROLLER_ENABLED" = "true" ]; then
    upsert_yaml_kv_local "$file" "external-controller" "$EXTERNAL_CONTROLLER"

    rm -rf "$ui_dir"
    mkdir -p "$ui_dir"

    if [ -d "$PROJECT_DIR/dashboard/public" ]; then
      cp -a "$PROJECT_DIR/dashboard/public/." "$ui_dir/"
      upsert_yaml_kv_local "$file" "external-ui" "$ui_dir"
    else
      remove_yaml_key_local "$file" "external-ui"
    fi
  else
    remove_yaml_key_local "$file" "external-controller"
    remove_yaml_key_local "$file" "external-ui"
  fi
}

download_subscription() {
  [ -n "$CLASH_URL" ] || return 1

  local curl_cmd=(curl -fL -S --retry 2 --connect-timeout 10 -m 30 -o "$TMP_DOWNLOAD")
  [ "$ALLOW_INSECURE_TLS" = "true" ] && curl_cmd+=(-k)
  curl_cmd+=("$CLASH_URL")

  "${curl_cmd[@]}"
}

is_complete_clash_config() {
  local file="$1"
  grep -qE '^[[:space:]]*(proxies:|proxy-providers:|mixed-port:|port:)' "$file"
}

cleanup_tmp_files() {
  rm -f "$TMP_PROXY_FRAGMENT" "$TMP_CONFIG"
}

build_fragment_config() {
  local template_file="$1"
  local target_file="$2"

  sed -n '/^proxies:/,$p' "$TMP_NORMALIZED" > "$TMP_PROXY_FRAGMENT"

  cat "$template_file" > "$target_file"
  cat "$TMP_PROXY_FRAGMENT" >> "$target_file"

  sed -i "s/CLASH_HTTP_PORT_PLACEHOLDER/${CLASH_HTTP_PORT}/g" "$target_file"
  sed -i "s/CLASH_SOCKS_PORT_PLACEHOLDER/${CLASH_SOCKS_PORT}/g" "$target_file"
  sed -i "s/CLASH_REDIR_PORT_PLACEHOLDER/${CLASH_REDIR_PORT}/g" "$target_file"
  sed -i "s/CLASH_LISTEN_IP_PLACEHOLDER/${CLASH_LISTEN_IP}/g" "$target_file"
  sed -i "s/CLASH_ALLOW_LAN_PLACEHOLDER/${CLASH_ALLOW_LAN}/g" "$target_file"
}

finalize_config() {
  local file="$1"
  mv -f "$file" "$RUNTIME_CONFIG"
}

remove_yaml_key_local() {
  local file="$1"
  local key="$2"

  [ -f "$file" ] || return 0
  sed -i -E "/^[[:space:]]*${key}:/d" "$file"
}

main() {
  local template_file="$CONFIG_DIR/template.yaml"

  if [ "$CLASH_AUTO_UPDATE" != "true" ]; then
    if [ -s "$RUNTIME_CONFIG" ]; then
      write_state "success" "auto_update_disabled_keep_runtime" "runtime_existing"
      exit 0
    fi

    echo "[ERROR] auto update disabled and runtime config missing: $RUNTIME_CONFIG" >&2
    write_state "failed" "runtime_missing" "none"
    exit 1
  fi

  if ! download_subscription; then
    if [ -s "$RUNTIME_CONFIG" ]; then
      write_state "success" "download_failed_keep_runtime" "runtime_existing"
      exit 0
    fi

    echo "[ERROR] failed to download subscription and runtime config missing" >&2
    write_state "failed" "download_failed" "none"
    exit 1
  fi

  cp -f "$TMP_DOWNLOAD" "$TMP_NORMALIZED"

  if is_complete_clash_config "$TMP_NORMALIZED"; then
    cp -f "$TMP_NORMALIZED" "$TMP_CONFIG"
    apply_controller_to_config "$TMP_CONFIG"
    apply_secret_to_config "$TMP_CONFIG"
    finalize_config "$TMP_CONFIG"
    write_state "success" "subscription_full" "subscription_full"
    cleanup_tmp_files
    exit 0
  fi

  if [ ! -s "$template_file" ]; then
    echo "[ERROR] missing template config file: $template_file" >&2
    write_state "failed" "missing_template" "none"
    cleanup_tmp_files
    exit 1
  fi

  build_fragment_config "$template_file" "$TMP_CONFIG"
  apply_controller_to_config "$TMP_CONFIG"
  apply_secret_to_config "$TMP_CONFIG"

  finalize_config "$TMP_CONFIG"
  write_state "success" "subscription_fragment_merged" "subscription_fragment"
  cleanup_tmp_files
}

trap cleanup_tmp_files EXIT
main "$@"