#!/usr/bin/env bash
# Loads Flutter dart-defines from the repo-root .env file (placeholders until you fill them in).
# Usage: ./scripts/flutter_run.sh [extra flutter run args...]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${repo_root}/.env"

if [[ ! -f "${env_file}" ]]; then
  echo "Missing .env file. Copy .env.example to .env and fill in your values." >&2
  exit 1
fi

flutter_keys=(
  APP_ENV
  SUPABASE_URL
  SUPABASE_ANON_KEY
  RAZORPAY_KEY_ID
  DEV_CUSTOMER_EMAIL
  DEV_CUSTOMER_PASSWORD
  DEV_OWNER_EMAIL
  DEV_OWNER_PASSWORD
  DEV_ADMIN_EMAIL
  DEV_ADMIN_PASSWORD
)

contains_key() {
  local needle="$1"
  for key in "${flutter_keys[@]}"; do
    if [[ "${key}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}

defines=()
while IFS= read -r line || [[ -n "${line}" ]]; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "${line}" || "${line}" == \#* ]] && continue

  key="${line%%=*}"
  value="${line#*=}"
  key="${key%"${key##*[![:space:]]}"}"
  value="${value#"${value%%[![:space:]]*}"}"

  if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi

  if contains_key "${key}" && [[ -n "${value}" ]]; then
    defines+=(--dart-define="${key}=${value}")
  fi
done < "${env_file}"

cd "${repo_root}"
if ((${#defines[@]} > 0)); then
  exec flutter run "${defines[@]}" "$@"
else
  exec flutter run "$@"
fi
