#!/usr/bin/env bash
hdm_menu_has_children() { awk -F '|' -v wanted="$1" '$1==wanted {found=1; exit}END{exit !found}' "$HDM_ROOT/ui/menus.tsv"; }
hdm_menu_label() { awk -F '|' -v wanted="$1" '$4==wanted {print $3; exit}' "$HDM_ROOT/ui/menus.tsv"; }
hdm_menu_tree() { sed '/^#/d' "$HDM_ROOT/ui/menus.tsv" | awk -F '|' '{print $4 " " $3}'; }
# Calculate cell width without depending on terminal-specific padding of CJK text.
hdm_menu_cell_width() {
  local LC_CTYPE=C.UTF-8 text=$1 char number width=0 i
  for ((i=0;i<${#text};i++)); do
    char=${text:i:1}
    printf -v number '%d' "'$char" 2>/dev/null || number=63
    if ((number>127)); then ((width+=2)); else ((width+=1)); fi
  done
  printf '%d' "$width"
}
hdm_menu_pad() {
  local value=$1 desired=$2 current difference spaces
  current=$(hdm_menu_cell_width "$value")
  difference=$((desired-current))
  ((difference<1)) && difference=1
  printf '%s' "$value"
  printf -v spaces '%*s' "$difference" ''
  printf '%s' "$spaces"
}
hdm_menu_terminal_cols() {
  local cols=${COLUMNS:-}
  if [[ ! $cols =~ ^[0-9]+$ || $cols -lt 20 ]]; then
    cols=$(tput cols 2>/dev/null) || cols=80
  fi
  [[ $cols =~ ^[0-9]+$ ]] || cols=80
  printf '%s' "$cols"
}
hdm_menu_header() {
  local path=$1 desktop output session
  printf '\n  HDM %s  ·  %s %s\n' "$HDM_VERSION" "$(hdm_os)" "$(hdm_arch)"
  if [[ $path == root ]]; then
    desktop=$(hdm_env_desktop_kind)
    output=$(hdm_env_drm_state)
    session=$(hdm_env_active_session)
    printf '  桌面 %s  ·  显示 %s  ·  会话 %s  ·  RustDesk %s\n' \
      "$desktop" "$(hdm_env_drm_short "$output")" "$session" "$(hdm_pkg_version rustdesk)"
  else
    printf '  %s\n' "$(hdm_menu_label "$path")"
  fi
}
hdm_menu_main() {
  local -a left=(1 2 3 4 5) right=(6 7 8 9 10)
  local cols i l r
  cols=$(hdm_menu_terminal_cols)
  if ((cols>=68)); then
    for ((i=0;i<5;i++)); do
      l="${left[i]}  $(hdm_menu_label "${left[i]}")"
      r="${right[i]}  $(hdm_menu_label "${right[i]}")"
      printf '  '
      hdm_menu_pad "$l" 30
      printf '%s\n' "$r"
    done
  else
    for i in {1..10}; do printf '  %-2s %s\n' "$i" "$(hdm_menu_label "$i")"; done
  fi
}
hdm_menu_children() {
  local path=$1 parent code label ident shown
  while IFS='|' read -r parent code label ident; do
    [[ $parent == "$path" ]] || continue
    shown=$label
    # No installation-risk promises in labels: the handler checks support.
    printf '  %-3s %s\n' "$code" "$shown"
  done < "$HDM_ROOT/ui/menus.tsv"
}
hdm_menu() {
  local path=${1:-root} selection match code label ident val
  while :; do
    if [[ -t 1 && -t 0 && ${TERM:-dumb} != dumb && ${HDM_NO_CLEAR:-0} != 1 ]]; then
      printf '\033[H\033[2J'
    fi
    hdm_menu_header "$path"
    printf '\n'
    if [[ $path == root ]]; then hdm_menu_main; else hdm_menu_children "$path"; fi
    printf '\n  0 返回    q 退出\n'
    if ! hdm_prompt '  请选择：' selection; then return 0; fi
    case "$selection" in q|Q) return 99;; 0) return 0;; esac
    ident=''
    while IFS='|' read -r match code label val; do
      if [[ $match == "$path" && $code == "$selection" ]]; then ident=$val; break; fi
    done < "$HDM_ROOT/ui/menus.tsv"
    if [[ -z $ident ]]; then hdm_warn '无效选项'; hdm_pause; continue; fi
    if hdm_menu_has_children "$ident"; then
      hdm_menu "$ident" || { local ret=$?; [[ $ret != 99 ]] || return 99; }
    else
      hdm_show "$ident $(hdm_menu_label "$ident")"
      if ! hdm_dispatch "$ident"; then hdm_warn '操作未完成，可在菜单 10 查看日志。'; fi
      hdm_pause
    fi
  done
}
