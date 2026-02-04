#!/usr/bin/env sh
set -o errexit
set -o pipefail
set -o nounset

base_dir="${PWD}"

# reset health info
rm -f "${HEALTH_FLAG}"
rm -rf "${HEALTH_ERRORS}"
mkdir -p "${HEALTH_ERRORS}"

echo "[i] verify environment variables and prepare exclude files"
for directory_name in */ ; do
  directory_name="${directory_name%/}" # trim trailing slash
  backup.sh "${base_dir}" "${directory_name}" 1
done

# backup loop
while true
do
  echo "[i] beginning backups/restores"
  start_loop=$(date +%s)

  cd "${base_dir}"
  for directory_name in */ ; do
    directory_name="${directory_name%/}" # trim trailing slash

    start_backup=$(date +%s)
    EXITCODE=0
    backup.sh "${base_dir}" "${directory_name}" 0 || EXITCODE=$?
    end_backup=$(date +%s)
    backup_seconds=$((end_backup-start_backup))

    if [ "${EXITCODE}" -eq "0" ]; then
      echo "[i] [${directory_name}] complete, time elapsed: ${backup_seconds}s"
      rm -f "${base_dir}/${HEALTH_ERRORS}/${directory_name}"
    else
      echo "[i] [${directory_name}] failed with exit code ${EXITCODE}, time elapsed: ${backup_seconds}s"
      touch "${base_dir}/${HEALTH_ERRORS}/${directory_name}"
    fi
  done

  end_loop=$(date +%s)
  loop_seconds=$((end_loop-start_loop))
  echo "[i] processed all repos after ${loop_seconds}s"

  cd ${base_dir}
  touch ${HEALTH_FLAG}

  if [[ "${PUSH_URL:-}" ]]; then
    loop_ms=$((1000*(end_loop-start_loop)))
    url="${PUSH_URL}&time=${loop_ms}"
    echo "[i] pinging push URL with interval ${loop_ms}"
    curl --silent --show-error --location "${url}" || true
    echo ""
  fi

  if [ "${INTERVAL}" = "-1" ]; then exit 0; fi
  echo "[i] sleeping ${INTERVAL}s"
  sleep ${INTERVAL}
done
