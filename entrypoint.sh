#!/usr/bin/env sh
# Railway entrypoint for insto.
#
# Modes (set via $INSTO_MODE):
#   daemon   (default) - runs `insto watch-daemon` in the foreground.
#                         This is the long-running process that polls
#                         everything registered with `insto watch <target>`
#                         and is what a Railway "Service" expects: a process
#                         that keeps running.
#   oneshot             - runs a single `insto @user -c <cmd> ...` call and
#                         exits. Set $INSTO_ONESHOT_ARGS to the arguments,
#                         e.g. "@nasa -c info --json /data/output/info.json".
#                         Intended for a Railway Cron Job / scheduled service.
#                         IMPORTANT: the last word in $INSTO_ONESHOT_ARGS must
#                         be a real file path (not "-") for the file to exist
#                         on disk / be sent to Telegram below.
#   shell               - drops into `sh` for debugging (exec into the
#                         container from the Railway dashboard).
#
# Optional Telegram delivery (oneshot mode only): if both
# $TELEGRAM_BOT_TOKEN and $TELEGRAM_CHAT_ID are set, the file produced by
# the oneshot command (the last word of $INSTO_ONESHOT_ARGS) is uploaded to
# that chat as a document once the command finishes.
set -eu

MODE="${INSTO_MODE:-daemon}"

# The mounted Volume may be empty on first run, so (re)create the output
# dir every start rather than relying on the one baked into the image.
mkdir -p "${INSTO_HOME:-/data}/output"

send_to_telegram() {
    file_path="$1"
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
        return 0
    fi
    if [ "$file_path" = "-" ] || [ -z "$file_path" ]; then
        echo "[entrypoint] last arg of INSTO_ONESHOT_ARGS is not a file path ('$file_path')," \
             "skipping Telegram send. Point --json/--csv/--maltego at a real path" \
             "(e.g. /data/output/result.csv) to enable this." >&2
        return 0
    fi
    if [ ! -f "$file_path" ]; then
        echo "[entrypoint] expected output file '$file_path' was not created, skipping Telegram send." >&2
        return 0
    fi
    echo "[entrypoint] sending $file_path to Telegram chat $TELEGRAM_CHAT_ID"
    http_code=$(curl -sS -o /tmp/telegram_response.json -w "%{http_code}" \
        -F chat_id="${TELEGRAM_CHAT_ID}" \
        -F document=@"${file_path}" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument") || http_code="curl_error"
    if [ "$http_code" = "200" ]; then
        echo "[entrypoint] sent to Telegram successfully."
    else
        echo "[entrypoint] Telegram send failed (http_code=$http_code):" >&2
        cat /tmp/telegram_response.json >&2 2>/dev/null || true
    fi
}

case "$MODE" in
  daemon)
    echo "[entrypoint] starting insto watch-daemon (INSTO_HOME=${INSTO_HOME:-unset})"
    exec insto watch-daemon
    ;;
  oneshot)
    if [ -z "${INSTO_ONESHOT_ARGS:-}" ]; then
      echo "[entrypoint] INSTO_MODE=oneshot but INSTO_ONESHOT_ARGS is empty." >&2
      echo "[entrypoint] example: INSTO_ONESHOT_ARGS='@nasa -c info --json -'" >&2
      exit 1
    fi
    echo "[entrypoint] running: insto ${INSTO_ONESHOT_ARGS}"
    # Not `exec` here: we need to run to completion, then optionally send
    # the resulting file to Telegram, then exit with insto's own status.
    set +e
    # shellcheck disable=SC2086
    insto ${INSTO_ONESHOT_ARGS}
    status=$?
    set -e
    if [ $status -ne 0 ]; then
        echo "[entrypoint] insto exited with status $status" >&2
    fi
    # shellcheck disable=SC2086
    last_word=$(printf '%s\n' "${INSTO_ONESHOT_ARGS}" | awk '{print $NF}')
    send_to_telegram "$last_word"
    exit $status
    ;;
  shell)
    exec sh
    ;;
  *)
    echo "[entrypoint] unknown INSTO_MODE '${MODE}' (expected daemon|oneshot|shell)" >&2
    exit 1
    ;;
esac
