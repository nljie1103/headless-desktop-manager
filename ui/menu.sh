#!/usr/bin/env bash
hdm_menu_has_children() { awk -F '|' -v wanted="$1" '($1 "")==(wanted "") {found=1; exit}END{exit !found}' "$HDM_ROOT/ui/menus.tsv"; }
hdm_menu_label() { awk -F '|' -v wanted="$1" '($4 "")==(wanted "") {print $3; exit}' "$HDM_ROOT/ui/menus.tsv"; }
hdm_legacy_menu_label() { awk -F '|' -v wanted="$1" '($4 "")==(wanted "") {print $3; exit}' "$HDM_ROOT/ui/legacy-menus.tsv"; }
hdm_menu_action_target() { awk -F '|' -v wanted="$1" '($1 "")==(wanted "") {print $2; exit}' "$HDM_ROOT/ui/menu-targets.tsv"; }
hdm_menu_execute() {
  local id=$1 target
  target=$(hdm_menu_action_target "$id")
  if [[ -z $target ]]; then
    hdm_warn "菜单 $id 未绑定执行目标，请检查菜单配置。"
    return 2
  fi
  case "$target" in
    new:*) hdm_v2_dispatch "${target#new:}" ;;
    *) hdm_dispatch "$target" ;;
  esac
}
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
hdm_menu_rule() {
  local path=${1:-root} cols count line
  cols=$(hdm_menu_terminal_cols)
  count=$((cols - 4))
  if [[ $path == root ]]; then
    ((count > 140)) && count=140
  else
    ((count > 74)) && count=74
  fi
  ((count < 18)) && count=18
  printf -v line '%*s' "$count" ''
  printf '  %s\n' "${line// /─}"
}
hdm_menu_header() {
  local path=$1 dm desktop rustdesk_state
  hdm_menu_rule "$path"
  printf '  HDM v%s  ·  %s / %s\n' "$HDM_VERSION" "$(hdm_os)" "$(hdm_arch)"
  if [[ $path == root ]]; then
    dm=$(hdm_v2_default_dm)
    case "$dm" in
      lightdm|gdm3) dm="$dm / $(hdm_service_state "$dm")" ;;
      *) dm="未选择" ;;
    esac
    if hdm_installed xfce4-session; then desktop=XFCE
    elif hdm_installed gnome-shell; then desktop=GNOME
    elif hdm_installed mate-session-manager; then desktop=MATE
    else desktop=未安装; fi
    rustdesk_state=$(hdm_service_state rustdesk)
    printf '  桌面：%s  |  登录界面：%s  |  RustDesk：%s\n' "$desktop" "$dm" "$rustdesk_state"
    printf '\n  ── 七节点桌面依赖线轴（本机状态 / 缺失组件）──\n'
    # Share the same snapshot for the seven-stage chain and package inventory.
    # A failing read-only diagnostic must never prevent reaching the menu.
    if ! timeout 18 python3 -B "$HDM_ROOT/modules/diagnostics/desktop_chain.py" \
        --home --width "$(hdm_menu_terminal_cols)"; then
      printf '  [待检查] 线轴暂不可用，请使用 hdm --chain 检查。\n'
    fi
    printf '\n  ▲ 软件已装不代表服务已运行；RustDesk 远端画面还需实测。\n'
  else
    printf '  %s\n' "$(hdm_menu_label "$path")"
  fi
  hdm_menu_rule "$path"
}
hdm_menu_main() {
  local -a left=(1 2 3) right=(4 5 6)
  local cols i l r
  cols=$(hdm_menu_terminal_cols)
  if ((cols>=78)); then
    for ((i=0;i<3;i++)); do
      l="${left[i]}. $(hdm_menu_label "${left[i]}")"
      r="${right[i]}. $(hdm_menu_label "${right[i]}")"
      printf '  '
      hdm_menu_pad "$l" 39
      printf '%s\n' "$r"
    done
  else
    for i in {1..6}; do printf '  %-3s %s\n' "${i}." "$(hdm_menu_label "$i")"; done
  fi
}
hdm_menu_children() {
  local path=$1 parent code label ident
  while IFS='|' read -r parent code label ident; do
    [[ $parent == "$path" ]] || continue
    printf '  '
    hdm_menu_pad "${code}." 5
    printf '%s\n' "$label"
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
    hdm_menu_rule "$path"
    if [[ $path == root ]]; then printf '  0/q 退出\n'; else printf '  0/q 返回    Q 退出\n'; fi
    if ! hdm_prompt '  请选择 > ' selection; then return 0; fi
    case "$selection" in 0|q) return 0;; Q) return 99;; esac
    ident=''
    while IFS='|' read -r match code label val; do
      if [[ $match == "$path" && $code == "$selection" ]]; then ident=$val; break; fi
    done < "$HDM_ROOT/ui/menus.tsv"
    if [[ -z $ident ]]; then hdm_warn '无效选项'; hdm_pause; continue; fi
    if hdm_menu_has_children "$ident"; then
      hdm_menu "$ident" || { local ret=$?; [[ $ret != 99 ]] || return 99; }
    else
      hdm_show "$ident $(hdm_menu_label "$ident")"
      local operation_rc=0
      hdm_menu_execute "$ident" || operation_rc=$?
      if [[ $EUID -eq 0 && -n ${HDM_LOG_DIR:-} && -d $HDM_LOG_DIR ]]; then
        printf '%s | HDM %s | menu %s | %s | exit=%s\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HDM_VERSION" "$ident" "$(hdm_menu_label "$ident")" "$operation_rc" \
          >> "$HDM_LOG_DIR/steps.log"
      fi
      ((operation_rc == 0)) || hdm_warn "操作未完成（退出码 $operation_rc），可从菜单 6 查看日志及导出诊断包。"
      [[ ${HDM_UNINSTALLED:-0} == 1 ]] && return 99
      # The parent menus have sourced old code. After an atomic HDM upgrade or
      # rollback, replace this entire process so Enter never returns to old UI.
      local active_base=${HDM_UPDATE_BASE:-/opt/hdm} active_root
      active_root=$(readlink -f -- "$active_base/current" 2>/dev/null) || active_root=''
      if [[ -n $active_root && $active_root != "$HDM_ROOT" && -f $active_root/hdm.sh ]]; then
        printf '\nHDM 已切换至 %s，进入新菜单...\n' "$(cat "$active_root/VERSION")"
        exec bash "$active_root/hdm.sh"
      fi
      hdm_pause
    fi
  done
}
