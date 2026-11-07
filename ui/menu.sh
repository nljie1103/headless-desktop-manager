#!/usr/bin/env bash
hdm_menu_has_children() { awk -F '|' -v wanted="$1" '$1==wanted {found=1; exit}END{exit !found}' "$HDM_ROOT/ui/menus.tsv"; }
hdm_menu_label() { awk -F '|' -v wanted="$1" '$4==wanted {print $3; exit}' "$HDM_ROOT/ui/menus.tsv"; }
hdm_menu_tree() { sed '/^#/d' "$HDM_ROOT/ui/menus.tsv" | awk -F '|' '{print $4 " " $3}'; }
hdm_menu() {
  local path=${1:-root} selection match code label ident shown
  while :; do
    if [[ -t 1 && -t 0 && ${TERM:-dumb} != dumb && ${HDM_NO_CLEAR:-0} != 1 ]]; then
      printf '\033[H\033[2J'
    fi
    printf '\n  HDM v%s  |  %s  |  %s\n' "$HDM_VERSION" "$(hdm_os)" "$(hdm_arch)"
    if [[ $path == root ]]; then
      printf '  GNOME: %s  |  GDM3: %s  |  RustDesk: %s\n'         "$(hdm_installed gnome-shell && echo 已安装 || echo 未安装)"         "$(hdm_service_state gdm3)" "$(hdm_pkg_version rustdesk)"
      hdm_env_summary
      printf '  快速入口：9 检测后安装    7 连接配置    10 故障诊断\n'
    else
      printf '  当前位置：%s\n' "$(hdm_menu_label "$path")"
      if [[ $path == 7.1 ]]; then
        printf '  配置方式：先分别填写 1/2/3，再用 6 预览、7 保存；8 只查设备 ID。\n'
      fi
    fi
    printf '  ────────────────────────────────────────────────\n'
    while IFS='|' read -r match code label ident; do
      [[ $match == "$path" ]] || continue
      shown=$label
      if hdm_gnome_wayland_only; then
        [[ $ident == 1.1 ]] && shown='安装 Xorg Dummy [仅用于 X11，非 GNOME Wayland 虚拟屏]'
        [[ $ident == 3.1.5 ]] && shown='配置 GNOME X11 [当前系统不支持，禁止强制切换]'
        [[ $ident == 9 ]] && shown='按本机状态一键安装 — GNOME Wayland + RustDesk [实验]'
      fi
      printf '  %-3s %s\n' "$code" "$shown"
    done < "$HDM_ROOT/ui/menus.tsv"
    printf '  ────────────────────────────────────────────────\n'
    printf '  0 返回/退出    q 退出    详细日志：菜单 10.8\n'
    if ! hdm_prompt '  请选择：' selection; then return 0; fi
    case "$selection" in q|Q) return 99;; 0) return 0;; esac
    ident=''
    while IFS='|' read -r match code label val; do
      if [[ $match == "$path" && $code == "$selection" ]]; then ident=$val; break; fi
    done < "$HDM_ROOT/ui/menus.tsv"
    if [[ -z $ident ]]; then hdm_warn '选项不存在，请重新输入。'; hdm_pause; continue; fi
    if hdm_menu_has_children "$ident"; then
      hdm_menu "$ident" || { local ret=$?; [[ $ret != 99 ]] || return 99; }
    else
      hdm_show "$ident $(hdm_menu_label "$ident")"
      if ! hdm_dispatch "$ident"; then hdm_warn '该操作未完成；检查以上原因，或到 10.8 查看完整日志。'; fi
      hdm_pause
    fi
  done
}
