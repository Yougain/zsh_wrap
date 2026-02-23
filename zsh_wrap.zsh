# ~/.zshrc などに置く
zrb_filter_on() {
  emulate -L zsh
  setopt local_options no_monitor

  [[ -n "$ZRB_FILTER_PID" ]] && return 0

  exec {ZRB_ORIG_IN}<&0 {ZRB_ORIG_OUT}>&1 {ZRB_ORIG_ERR}>&2

  ZRB_INFO_FILE="$(mktemp)"

  TTY_IN_FD="$ZRB_ORIG_IN" TTY_OUT_FD="$ZRB_ORIG_OUT" ZSHPID=$$ zsh_wrap "$ZRB_INFO_FILE" &

  local info=""
  for _ in {1..200}; do
    [[ -s "$ZRB_INFO_FILE" ]] && { info="$(<"$ZRB_INFO_FILE")"; break; }
    sleep 0.01
  done
  [[ -z "$info" ]] && { echo "failed to get pty path" >&2; return 1; }

    local pts_path="${info#* }"
    ZRB_FILTER_PID="${info%% *}"

  exec <"$pts_path" >"$pts_path" 2>&1
}

zrb_filter_off() {
  [[ -z "$ZRB_FILTER_PID" ]] && return 0
  exec <&$ZRB_ORIG_IN >&$ZRB_ORIG_OUT 2>&$ZRB_ORIG_ERR
  kill "$ZRB_FILTER_PID" 2>/dev/null
  wait "$ZRB_FILTER_PID" 2>/dev/null
  exec {ZRB_ORIG_IN}<&- {ZRB_ORIG_OUT}>&- {ZRB_ORIG_ERR}>&-
  rm -f -- "$ZRB_INFO_FILE"
  unset ZRB_FILTER_PID ZRB_ORIG_IN ZRB_ORIG_OUT ZRB_ORIG_ERR ZRB_INFO_FILE
}

