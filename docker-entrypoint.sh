#!/bin/sh
set -eu

CONFIG_DIR="${CONFIG_DIR:-/app/config}"
CONFIG_FILE="${CONFIG_FILE:-${CONFIG_DIR}/config.json}"
CREDENTIALS_FILE="${CREDENTIALS_FILE:-${CONFIG_DIR}/credentials.json}"
DEFAULT_CONFIG_FILE="${DEFAULT_CONFIG_FILE:-/app/default-config.json}"

mkdir -p "${CONFIG_DIR}"
mkdir -p "$(dirname "${CREDENTIALS_FILE}")"

generate_api_key() {
  if [ -r /proc/sys/kernel/random/uuid ]; then
    tr -d '-' < /proc/sys/kernel/random/uuid | sed 's/^/sk-kiro-rs-/'
  else
    date +%s%N | sed 's/^/sk-kiro-rs-/'
  fi
}

if [ "${KIRO_CONFIG_OVERWRITE:-false}" = "true" ] || [ ! -f "${CONFIG_FILE}" ]; then
  if [ -f "${DEFAULT_CONFIG_FILE}" ]; then
    cp "${DEFAULT_CONFIG_FILE}" "${CONFIG_FILE}"
  else
    jq -n '{}' > "${CONFIG_FILE}"
  fi
fi

CONFIG_API_KEY="$(jq -r '.apiKey // ""' "${CONFIG_FILE}")"
if [ -n "${API_KEY:-}" ]; then
  CONFIG_API_KEY="${API_KEY}"
elif [ -z "${CONFIG_API_KEY}" ]; then
  CONFIG_API_KEY="$(generate_api_key)"
  echo "Generated apiKey for ${CONFIG_FILE}: ${CONFIG_API_KEY}"
fi

PORT_VALUE="${PORT:-8990}"
CREDENTIAL_RPM_VALUE="${CREDENTIAL_RPM:-0}"
TMP_CONFIG_FILE="${CONFIG_FILE}.tmp"

jq \
  --arg apiKey         "${CONFIG_API_KEY}" \
  --arg adminApiKey    "${ADMIN_API_KEY:-}" \
  --arg host           "${HOST:-0.0.0.0}" \
  --argjson port       "${PORT_VALUE}" \
  --arg region         "${REGION:-us-east-1}" \
  --arg tlsBackend     "${TLS_BACKEND:-rustls}" \
  --arg proxyUrl       "${PROXY_URL:-}" \
  --arg proxyUsername  "${PROXY_USERNAME:-}" \
  --arg proxyPassword  "${PROXY_PASSWORD:-}" \
  --argjson credentialRpm "${CREDENTIAL_RPM_VALUE}" \
  '. + {
     host:       (.host // $host),
     port:       (.port // $port),
     apiKey:     $apiKey,
     region:     (.region // $region),
     tlsBackend: (.tlsBackend // $tlsBackend)
   }
   + (if $adminApiKey    != "" then {adminApiKey:    $adminApiKey}    else {} end)
   + (if $proxyUrl       != "" then {proxyUrl:       $proxyUrl}       else {} end)
   + (if $proxyUsername  != "" then {proxyUsername:  $proxyUsername}  else {} end)
   + (if $proxyPassword  != "" then {proxyPassword:  $proxyPassword}  else {} end)
   + (if $credentialRpm  > 0   then {credentialRpm:  $credentialRpm}  else {} end)' \
  "${CONFIG_FILE}" > "${TMP_CONFIG_FILE}"
mv "${TMP_CONFIG_FILE}" "${CONFIG_FILE}"

if [ ! -f "${CREDENTIALS_FILE}" ]; then
  echo "[]" > "${CREDENTIALS_FILE}"
fi

exec /app/kiro-rs --config "${CONFIG_FILE}" --credentials "${CREDENTIALS_FILE}"
