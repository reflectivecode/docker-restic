#!/usr/bin/env sh
set -o errexit
set -o pipefail
set -o nounset

base_dir=${1}       # argument 1, required
directory_name=${2} # argument 2, required
init_only=${3}      # argument 2, required

echo "[i] [${directory_name}] processing directory"

directory_path="${base_dir}/${directory_name}"
exclude_file="${base_dir}/exclude_${directory_name}"

repository_var="RESTIC_REPOSITORY_${directory_name}"
repository=$(eval "echo \"\${${repository_var}:-}\"")

password_var="RESTIC_PASSWORD_${directory_name}"
password=$(eval "echo \"\${${password_var}:-}\"")

exclude_var="RESTIC_EXCLUDE_${directory_name}"
exclude=$(eval "echo \"\${${exclude_var}:-}\"")

keep_within_var="RESTIC_KEEP_WITHIN_${directory_name}"
keep_within=$(eval "echo \"\${${keep_within_var}:-\${RESTIC_KEEP_WITHIN}}\"")

keep_within_hourly_var="RESTIC_KEEP_WITHIN_HOURLY_${directory_name}"
keep_within_hourly=$(eval "echo \"\${${keep_within_hourly_var}:-\${RESTIC_KEEP_WITHIN_HOURLY}}\"")

keep_within_daily_var="RESTIC_KEEP_WITHIN_DAILY_${directory_name}"
keep_within_daily=$(eval "echo \"\${${keep_within_daily_var}:-\${RESTIC_KEEP_WITHIN_DAILY}}\"")

# verify environment variables
if [ -z "${repository:-}" ]; then
  echo "[e] [${directory_name}] missing environment variable ${repository_var}"
  exit 1
fi

if [ -z "${password:-}" ]; then
  echo "[e] [${directory_name}] missing environment variable ${password_var}"
  exit 1
fi

if [ "${init_only}" -eq "1" ]; then
  # prepare exclude files
  echo "${RESTIC_EXCLUDE:-}" > "${exclude_file}"
  echo "${exclude:-}" > "${exclude_file}"
  chown root:root "${exclude_file}"
  chmod 600 "${exclude_file}"
  exit 0
fi

export RESTIC_REPOSITORY="${repository}"
export RESTIC_PASSWORD="${password}"

cd "${directory_path}"

echo "[i] [${directory_name}] remove stale locks"
EXITCODE=0
restic unlock --quiet || EXITCODE=$?
if [ "${EXITCODE}" -eq "0" ]; then
  echo "[i] [${directory_name}] existing repo found"
else
  echo "[i] [${directory_name}] existing repo NOT found"
  echo "[i] [${directory_name}] creating repo"
  restic init --cleanup-cache
  echo "[i] [${directory_name}] repo created"
  touch "${IDEMPOTENCE_FLAG}"
  chown root:root "${IDEMPOTENCE_FLAG}"
  chmod 600 "${IDEMPOTENCE_FLAG}"
  printf "%s" "${RESTIC_REPOSITORY}" > "${IDEMPOTENCE_FLAG}"
fi

echo "[i] [${directory_name}] check for existing snapshots"
snapshot_count=$(restic snapshots --group-by '' --json latest | jq length)

if [ "${snapshot_count}" -eq "0" ]; then
  echo "[i] [${directory_name}] no snapshots, skipping restore"
  touch "${IDEMPOTENCE_FLAG}"
  chown root:root "${IDEMPOTENCE_FLAG}"
  chmod 600 "${IDEMPOTENCE_FLAG}"
  printf "%s" "${RESTIC_REPOSITORY}" > "${IDEMPOTENCE_FLAG}"
else
  echo "[i] [${directory_name}] snapshots found"
fi

if [ ! -f ${IDEMPOTENCE_FLAG} ]; then
  echo "[i] [${directory_name}] delete local data before restore"
  rm -rf *
  find . -type f -maxdepth 1 -name '.*' -exec rm -f {} +
  echo "[i] [${directory_name}] delete complete"

  echo "[i] [${directory_name}] restore latest snapshot and verify"
  restic restore latest --verify --target .
  echo "[i] [${directory_name}] restore success"
  touch "${IDEMPOTENCE_FLAG}"
  chown root:root "${IDEMPOTENCE_FLAG}"
  chmod 600 "${IDEMPOTENCE_FLAG}"
  printf "%s" "${RESTIC_REPOSITORY}" > "${IDEMPOTENCE_FLAG}"
fi

echo "[i] [${directory_name}] verifying repo matches local directory"
local_repo=$(cat "${IDEMPOTENCE_FLAG}")
if [ "${local_repo}" != "${RESTIC_REPOSITORY}" ]; then
  echo "[i] [${directory_name}] remote repo ${RESTIC_REPOSITORY}"
  echo "[i] [${directory_name}] local  repo ${local_repo}"
  echo "[e] [${directory_name}] Repository mismatch. Exiting."
  exit 99
fi

echo "[i] [${directory_name}] backing up"
restic backup --quiet --group-by '' --exclude "${IDEMPOTENCE_FLAG}" --exclude-file "${exclude_file}" --exclude-caches .

echo "[i] [${directory_name}] remove old backups"
restic forget --quiet --group-by '' --keep-within "${keep_within}" --keep-within-hourly "${keep_within_hourly}" --keep-within-daily "${keep_within_daily}"

echo "[i] [${directory_name}] prune"
restic prune --quiet --repack-small --cleanup-cache
