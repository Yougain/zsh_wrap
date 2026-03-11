# ~/.zshrc などに置く

ZRB_FILTER_DIR="$(temp_path zrb_filter_dir)"
ZRB_CMD_DIR="$(temp_path zrb_cmd_dir)"
mkdir -p "$ZRB_FILTER_DIR"
mkdir -p "$ZRB_CMD_DIR"

zrb_filter_on() {
  emulate -L zsh
  setopt local_options no_monitor

  [[ -n "$ZRB_FILTER_PID" ]] && return 0

  ZRB_ORIG_TTY="$(readlink /proc/$$/fd/0 2>/dev/null)"
  [[ -n "$ZRB_ORIG_TTY" && -c "$ZRB_ORIG_TTY" ]] || unset ZRB_ORIG_TTY

  exec {ZRB_ORIG_IN}<&0 {ZRB_ORIG_OUT}>&1 {ZRB_ORIG_ERR}>&2

  ZRB_INFO_FILE="$(temp_path zrb_info)"

  TTY_IN_FD="$ZRB_ORIG_IN" TTY_OUT_FD="$ZRB_ORIG_OUT" ZSHPID=$$ zsh_wrap "$ZRB_INFO_FILE" "$ZRB_FILTER_DIR" "$ZRB_CMD_DIR" &

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
  if [[ -n "$ZRB_ORIG_TTY" && -c "$ZRB_ORIG_TTY" ]]; then
    exec 0<>"$ZRB_ORIG_TTY" 1>&0 2>&1
  else
    exec <&$ZRB_ORIG_IN >&$ZRB_ORIG_OUT 2>&$ZRB_ORIG_ERR
  fi
  kill "$ZRB_FILTER_PID" 2>/dev/null
  wait "$ZRB_FILTER_PID" 2>/dev/null
  exec {ZRB_ORIG_IN}<&- {ZRB_ORIG_OUT}>&- {ZRB_ORIG_ERR}>&-
  rm -f "$ZRB_INFO_FILE"
  unset ZRB_FILTER_PID ZRB_ORIG_IN ZRB_ORIG_OUT ZRB_ORIG_ERR ZRB_INFO_FILE ZRB_ORIG_TTY
}

term_on(){
  [[ -z "$ZRB_FILTER_PID" ]] && return 0
  echo on > $ZRB_CMD_DIR/cmd
  kill USR2 $ZRB_FILTER_PID 2>/dev/null
}

term_off(){
  [[ -z "$ZRB_FILTER_PID" ]] && return 0
  echo off > $ZRB_CMD_DIR/cmd
  kill USR2 $ZRB_FILTER_PID 2>/dev/null
}

#zrb_filter_on
