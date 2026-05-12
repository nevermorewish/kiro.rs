#!/bin/sh
set -eu

CONFIG_DIR="${CONFIG_DIR:-/app/config}"
CONFIG_FILE="${CONFIG_FILE:-${CONFIG_DIR}/config.json}"
CREDENTIALS_FILE="${CREDENTIALS_FILE:-${CONFIG_DIR}/credentials.json}"

mkdir -p "${CONFIG_DIR}"

if [ "${KIRO_CONFIG_OVERWRITE:-false}" = "true" ] || [ ! -f "${CONFIG_FILE}" ]; then
  if [ -z "${API_KEY:-}" ]; then
    echo "ERROR: API_KEY is required when initializing ${CONFIG_FILE}" >&2
    exit 1
  fi

  PORT_VALUE="${PORT:-8990}"
  CREDENTIAL_RPM_VALUE="${CREDENTIAL_RPM:-0}"

  jq -n \
    --arg apiKey         "${API_KEY}" \
    --arg adminApiKey    "${ADMIN_API_KEY:-}" \
    --arg host           "${HOST:-0.0.0.0}" \
    --argjson port       "${PORT_VALUE}" \
    --arg region         "${REGION:-us-east-1}" \
    --arg tlsBackend     "${TLS_BACKEND:-rustls}" \
    --arg proxyUrl       "${PROXY_URL:-}" \
    --arg proxyUsername  "${PROXY_USERNAME:-}" \
    --arg proxyPassword  "${PROXY_PASSWORD:-}" \
    --argjson credentialRpm "${CREDENTIAL_RPM_VALUE}" \
    '{
       host:         $host,
       port:         $port,
       apiKey:       $apiKey,
       region:       $region,
       tlsBackend:   $tlsBackend
     }
     + (if $adminApiKey    != "" then {adminApiKey:    $adminApiKey}    else {} end)
     + (if $proxyUrl       != "" then {proxyUrl:       $proxyUrl}       else {} end)
     + (if $proxyUsername  != "" then {proxyUsername:  $proxyUsername}  else {} end)
     + (if $proxyPassword  != "" then {proxyPassword:  $proxyPassword}  else {} end)
     + (if $credentialRpm  > 0   then {credentialRpm:  $credentialRpm}  else {} end)' \
    > "${CONFIG_FILE}"
else
  echo "Using existing config file: ${CONFIG_FILE}"
fi

if [ ! -f "${CREDENTIALS_FILE}" ]; then
  echo "[]" > "${CREDENTIALS_FILE}"
fi

exec /app/kiro-rs --config "${CONFIG_FILE}" --credentials "${CREDENTIALS_FILE}"
