#!/usr/bin/env bash
hdm_menu_has_children() { awk -F '|' -v wanted="$1" '$1==wanted {found=1; exit}END{exit !found}' "$HDM_ROOT/ui/menus.tsv"; }
hdm_menu_label() { awk -F '|' -v wanted="$1" '$4==wanted {print $3; exit}' "$HDM_ROOT/ui/menus.tsv"; }
hdm_menu_tree() { sed '/^#/d' "$HDM_ROOT/ui/menus.tsv" | awk -F '|' '{print $4 " " $3}'; }
hdm_menu() {
  local path=${1:-root} selection match code label ident
  while :; do
    printf '\n==============================================================\n'
    printf ' Headless Desktop Manager v%s\n' "$HDM_VERSION"
    printf ' 系统：%s / %s\n' "$(hdm_os)" "$(hdm_arch)"
    if [[ $path == root ]]; then
      printf ' GNOME：%s | Dummy：%s | RustDesk：%s\n' "$(hdm_pkg_version gnome-shell)" "$(hdm_pkg_version xserver-xorg-video-dummy)" "$(hdm_pkg_version rustdesk)"
    else
      printf ' 当前菜单：%s\n' "$(hdm_menu_label "$path")"
    fi
    printf '%s\n' '--------------------------------------------------------------'
    while IFS='|' read -r match code label ident; do
      [[ $match == "$path" ]] || continue
      printf ' %3s. %s\n' "$code" "$label"
    done < "$HDM_ROOT/ui/menus.tsv"
    printf '   0. %s     q. 退出\n' "$([[ $path == root ]] && printf '退出' || printf '返回上一级')"
    printf '==============================================================\n'
    if ! hdm_prompt '请选择数字/字母：' selection; then return 0; fi
    case "$selection" in
      q|Q) return 99;;
      0) return 0;;
    esac
    ident=''
    while IFS='|' read -r match code label val; do
      if [[ $match == "$path" && $code == "$selection" ]]; then ident=$val; break; fi
    done < "$HDM_ROOT/ui/menus.tsv"
    if [[ -z $ident ]]; then hdm_warn '选项不存在，请重新输入。'; continue; fi
    if hdm_menu_has_children "$ident"; then
      hdm_menu "$ident" || { local ret=$?; if [[ $ret -eq 99 ]]; then return 99; fi; }
    else
      hdm_show "$ident $(hdm_menu_label "$ident")"
      if ! hdm_dispatch "$ident"; then hdm_warn "该项未成功完成；可通过菜单 10 查看诊断信息，或使用 0 返回。"; fi
      hdm_pause
    fi
  done
}
