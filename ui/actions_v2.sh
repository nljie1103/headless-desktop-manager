#!/usr/bin/env bash
# Task-first menu handlers. Legacy action functions remain available internally.
hdm_v2_display_manager_info() {
  local dm pkg
  dm=$(hdm_v2_default_dm)
  printf '当前默认登录管理器：%s\n' "$dm"
  for pkg in lightdm gdm3; do
    if hdm_installed "$pkg"; then
      printf '  %-8s 已安装 / 运行: %-9s / 自启: ' "$pkg" "$(hdm_service_state "$pkg")"
      systemctl is-enabled "$pkg" 2>/dev/null || :
    else
      printf '  %-8s 未安装\n' "$pkg"
    fi
  done
  if hdm_installed xfce4-session; then
    printf '  XFCE 会话：已安装（请在登录界面实际验证）\n'
  elif hdm_installed gnome-session-bin; then
    printf '  GNOME 会话：已安装（请在登录界面实际验证）\n'
  elif hdm_installed mate-session-manager; then
    printf '  MATE 会话：已安装（请在登录界面实际验证）\n'
  else
    printf '  桌面会话：未检测到 XFCE / GNOME / MATE；请先安装一个桌面环境。\n'
  fi
  printf '安装、服务运行与图形会话是不同状态。\n'
}
hdm_v2_display_manager_install_lightdm() {
  hdm_warn 'LightDM 是登录管理器，不是虚拟显示器。安装软件包可能触发系统登录管理器选择。'
  hdm_warn '请保留 SSH / 云控制台。HDM 不会自动重启图形会话，也不会自动卸载 GDM3。'
  hdm_pkg_install lightdm lightdm-gtk-greeter
}
hdm_v2_display_manager_install_gdm3() {
  hdm_warn 'GDM3 和 LightDM 同属登录管理器，仅需一个默认运行。安装 GDM3 不会自动卸载 LightDM。'
  hdm_pkg_install gdm3
}
hdm_v2_display_manager_upgrade() {
  local pkg=$1
  case "$pkg" in gdm3|lightdm) ;; *) return 2;; esac
  hdm_root && hdm_guard_platform || return 1
  if ! hdm_installed "$pkg"; then
    hdm_warn "$pkg 尚未安装。请先通过安装菜单安装。"
    return 2
  fi
  hdm_warn "升级 $pkg 可能影响远程登录界面；请保留 SSH/云平台控制台。"
  hdm_pkg_upgrade "$pkg"
}
hdm_v2_rustdesk_install() {
  # The explicit menu choice authorizes the install, including package
  # dependency checks. Existing RustDesk config and device ID are retained.
  local HDM_QUICK_APPROVED=1
  hdm_rustdesk_install_online latest
}
hdm_v2_update_release() {
  # Choosing this one menu item is explicit intent. The updater still checks
  # Release metadata, SHA256, archive safety and the version before switching.
  local HDM_QUICK_APPROVED=1
  hdm_update_install latest
}
hdm_v2_display_manager_upgrade_current() {
  local selected
  selected=$(hdm_v2_default_dm)
  if [[ $selected == unknown ]]; then
    if [[ $(hdm_service_state lightdm) == active ]]; then selected=lightdm
    elif [[ $(hdm_service_state gdm3) == active ]]; then selected=gdm3
    fi
  fi
  case "$selected" in
    lightdm|gdm3) hdm_v2_display_manager_upgrade "$selected" ;;
    *) hdm_warn '未检测到正在使用的登录管理器，请先安装 GDM3 或 LightDM。'; return 2;;
  esac
}
# Only display managers are directly managed here. Xorg and XFCE do not
# have independent always-on systemd services to toggle.
hdm_v2_dm_service() {
  local action=$1 selected
  case "$action" in start|stop|restart|enable|disable) ;; *) return 2 ;; esac
  hdm_root && hdm_guard_platform || return 1
  if ! hdm_has systemctl; then hdm_warn '当前系统不支持 systemd 服务管理。'; return 2; fi
  selected=$(hdm_v2_default_dm)
  case "$selected" in
    lightdm|gdm3) ;;
    *) hdm_warn '未识别默认登录管理器。请从菜单 3 → 11 选择 LightDM 或 GDM3。'; return 2 ;;
  esac
  if ! hdm_installed "$selected"; then
    hdm_warn "$selected 尚未安装，请先安装登录管理器。"
    return 2
  fi
  if [[ $(hdm_service_state lightdm) == active && $(hdm_service_state gdm3) == active ]]; then
    hdm_warn '检测到两个登录管理器均在运行，拒绝自动操作。请先人工处理冲突。'
    return 2
  fi
  if [[ $action == start || $action == restart ]]; then
    local other=lightdm
    [[ $selected == lightdm ]] && other=gdm3
    if [[ $(hdm_service_state "$other") == active ]]; then
      hdm_warn "另一个登录管理器 $other 正在运行，拒绝并发启动 $selected。"
      return 2
    fi
  fi
  printf '默认登录管理器：%s；操作：%s\n' "$selected" "$action"
  if [[ $action == start && $selected == lightdm ]] && ! hdm_installed xfce4-session && ! hdm_installed mate-session-manager; then
    hdm_warn '没有检测到 XFCE/MATE 桌面会话：LightDM 即使启动，仍可能没有可登录的桌面。建议先安装 XFCE。'
  fi
  case "$action" in
    stop|restart|disable)
      hdm_warn '警告：操作登录管理器可能中断当前图形会话和 RustDesk。请确保 SSH / 云控制台可用。'
      hdm_confirm "确认对 $selected 执行 $action？" || { hdm_warn '已取消，未修改服务状态。'; return 2; }
      ;;
  esac
  if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then
    printf '[DRY RUN] systemctl %s %s\n' "$action" "$selected"
    return 0
  fi
  if ! systemctl "$action" "$selected"; then
    hdm_warn "操作失败：请查看 systemctl status $selected 和 journalctl -b -u $selected。"
    systemctl status "$selected" --no-pager -l 2>&1 | tail -n 18 || :
    return 1
  fi
  printf '完成操作。运行状态：%s；开机自启：' "$(hdm_service_state "$selected")"
  systemctl is-enabled "$selected" 2>/dev/null || :
  if [[ $action == enable ]]; then printf '注意：启用开机自启不会立即启动服务。请另选“启动当前登录管理器”。\n'; fi
  if [[ $action == start || $action == restart ]]; then
    printf '注意：服务启动不等于桌面会话可用，也不等于 RustDesk 已能控制登录界面。\n'
  fi
}

# RustDesk is a systemd service; the graphical session itself is managed
# by a display manager rather than by a fictitious "XFCE service".
hdm_v2_rustdesk_service() {
  local action=$1
  case "$action" in start|stop|restart|enable|disable) ;; *) return 2 ;; esac
  hdm_root && hdm_guard_platform || return 1
  hdm_has systemctl || { hdm_warn '当前系统没有 systemctl，无法管理 RustDesk 服务。'; return 2; }
  hdm_installed rustdesk || { hdm_warn 'RustDesk 尚未安装，请先选择安装。'; return 2; }
  case "$action" in
    stop|restart|disable)
      hdm_warn '此操作可能中断 RustDesk 远控，务必保留 SSH / 云控制台。'
      hdm_confirm "确认对 RustDesk 执行 $action？" || { hdm_warn '已取消，没有修改服务。'; return 2; }
      ;;
  esac
  if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then
    printf '[DRY RUN] systemctl %s rustdesk\n' "$action"
    return 0
  fi
  if ! systemctl "$action" rustdesk; then
    hdm_warn 'RustDesk 操作失败：'
    systemctl status rustdesk --no-pager -l 2>&1 | tail -n 18 || :
    return 1
  fi
  printf 'RustDesk 当前：%s；开机自启：' "$(hdm_service_state rustdesk)"
  systemctl is-enabled rustdesk 2>/dev/null || :
  if [[ $action == enable ]]; then
    printf '启用自启不等于立即启动，请另选“启动 RustDesk”。\n'
  fi
  printf '服务运行不等于远端能捕获图形会话，请从另一设备测试。\n'
}

hdm_v2_protocol_info() {
  printf 'X11 是图形显示协议，Xorg 是常用 X11 服务器实现；Wayland 是另一套显示协议。\n'
  printf 'GDM3/LightDM 负责登录认证与桌面会话启动，不是虚拟显示器。\n'
  printf '已登录桌面、锁屏、注销后的登录界面，以及 RustDesk 是否可远控，须分别验证。\n'
  printf '查看完整链路：sudo hdm --chain；显示方案与虚拟输出：主菜单 5。\n'
}

# The uninstall removes only the HDM command entry and current-version pointer.
# Keep versioned releases, configuration, rollback data, and all desktops intact.
# Test paths are confined to /tmp and require HDM_TEST_MODE=1.
hdm_v2_install_paths() {
  HDM_V2_INSTALL_BASE=/opt/hdm
  HDM_V2_COMMAND_PATH=/usr/local/bin/hdm
  if [[ ${HDM_TEST_MODE:-0} == 1 ]]; then
    local base=${HDM_UNINSTALL_TEST_BASE:-} cmd=${HDM_UNINSTALL_TEST_COMMAND:-}
    if [[ $base == /tmp/* && $cmd == /tmp/* && $base != *'..'* && $cmd != *'..'* ]]; then
      HDM_V2_INSTALL_BASE=$base
      HDM_V2_COMMAND_PATH=$cmd
    else
      hdm_warn '测试模式卸载路径无效，拒绝执行。'
      return 2
    fi
  fi
}
hdm_v2_uninstall_preview() {
  hdm_v2_install_paths || return $?
  local base=$HDM_V2_INSTALL_BASE cmd=$HDM_V2_COMMAND_PATH current
  current=$base/current
  local expected installed
  printf 'HDM 管理器卸载预览（仅清理入口，保留安装文件及数据）\n'
  printf '  程序入口：%s\n' "$cmd"
  printf '  当前版本指针：%s\n' "$current"
  if [[ ! -L $current ]]; then
    hdm_warn '未发现 HDM 当前版本符号链接，不执行卸载。'
    return 2
  fi
  installed=$(readlink -f -- "$current" 2>/dev/null) || return 2
  case "$installed" in
    "$base"/releases/v*) ;;
    *) hdm_warn '当前版本不是 HDM 管理的版本目录，拒绝卸载。'; return 2;;
  esac
  [[ -f $installed/hdm.sh && -f $installed/VERSION ]] || {
    hdm_warn 'HDM 当前版本文件不完整，拒绝卸载。'; return 2;
  }
  if [[ -e $cmd || -L $cmd ]]; then
    [[ -L $cmd ]] || { hdm_warn '现有 hdm 命令不是符号链接，拒绝覆盖或删除。'; return 2; }
    expected=$(readlink -f -- "$cmd" 2>/dev/null) || return 2
    [[ $expected == "$installed/hdm.sh" ]] || {
      hdm_warn 'hdm 命令链接到其他程序，拒绝删除。'; return 2;
    }
  fi
  printf '  当前版本：%s\n' "$(cat "$installed/VERSION")"
  printf '  将移除：HDM 命令入口与 current 版本链接。\n'
  printf '  保留：%s/releases/ 中的历史版本。\n' "$base"
  printf '  保留：/etc/hdm、/var/lib/hdm、/var/cache/hdm、/var/log/hdm。\n'
  printf '  不处理：Xorg、GNOME、XFCE、MATE、GDM3、LightDM、RustDesk 及其服务。\n'
  printf '  安装目录保留用于恢复；之后可再次运行 install.sh 恢复管理器。\n'
}
hdm_v2_uninstall() {
  hdm_root && hdm_guard_platform || return 1
  hdm_v2_uninstall_preview || return $?
  hdm_confirm '确认移除 HDM 菜单启动入口？安装版本、配置和日志仍会保留。' || {
    hdm_warn '已取消 HDM 管理器卸载。'
    return 2
  }
  # Revalidate paths after the confirmation to prevent stale/symlink targets.
  hdm_v2_uninstall_preview >/dev/null || return $?
  local base=$HDM_V2_INSTALL_BASE cmd=$HDM_V2_COMMAND_PATH
  if [[ -L $cmd ]]; then rm -- "$cmd" || return 1; fi
  [[ -L $base/current ]] && rm -- "$base/current"
  HDM_UNINSTALLED=1
  printf 'HDM 菜单入口已卸载。历史版本、配置、日志和所有桌面软件保持不变。\n'
  printf '重新安装可从已下载源码目录执行 sudo bash install.sh --local。\n'
}

hdm_v2_dispatch() {
  case "$1" in
    display-status) hdm_display_status ;;
    quick-install) hdm_quick_install ;;
    quick-plan) hdm_quick_plan ;;
    readiness) hdm_readiness_report ;;
    doctor) hdm_diag_doctor ;;
    dm-install-gdm3) hdm_v2_display_manager_install_gdm3 ;;
    rustdesk-start) hdm_v2_rustdesk_service start ;;
    rustdesk-stop) hdm_v2_rustdesk_service stop ;;
    rustdesk-restart) hdm_v2_rustdesk_service restart ;;
    rustdesk-autostart-on) hdm_v2_rustdesk_service enable ;;
    rustdesk-autostart-off) hdm_v2_rustdesk_service disable ;;
    rustdesk-server) hdm_rustdesk_server_wizard ;;
    rustdesk-password) hdm_rustdesk_password ;;
    rustdesk-status) hdm_rustdesk_status ;;
    dm-install-lightdm) hdm_v2_display_manager_install_lightdm ;;
    dm-uninstall-preview-gdm) hdm_action_remove_preview gdm3 ;;
    dm-remove-gdm3) hdm_v2_remove_real gdm3 ;;
    dm-remove-lightdm) hdm_v2_remove_real lightdm ;;
    dm-select-lightdm) hdm_v2_choose_dm lightdm ;;
    dm-select-gdm3) hdm_v2_choose_dm gdm3 ;;
    desktop-remove-gnome) hdm_v2_remove_real gnome ;;
    desktop-remove-xfce) hdm_v2_remove_real xfce ;;
    desktop-remove-mate) hdm_v2_remove_real mate ;;
    dm-uninstall-preview-lightdm) hdm_action_remove_preview lightdm ;;
    dm-uninstall-guide)
      hdm_warn '支持先卸载旧桌面再安装新桌面。APT 自动检查依赖，执行前确认一次；卸载当前图形登录组件可能立即中断 RustDesk，请使用 SSH/云控制台。' ;;
    dm-versions) hdm_v2_display_manager_info ;;
    dm-upgrade-current) hdm_v2_display_manager_upgrade_current ;;
    dm-upgrade-gdm) hdm_v2_display_manager_upgrade gdm3 ;;
    desktop-install-gnome) hdm_desktop_install_gnome_only ;;
    desktop-install-xfce) hdm_desktop_install_light xfce standard ;;
    desktop-install-mate) hdm_desktop_install_light mate standard ;;
    desktop-update) hdm_desktop_update ;;
    dm-upgrade-lightdm) hdm_v2_display_manager_upgrade lightdm ;;
    dm-start) hdm_v2_dm_service start ;;
    dm-stop) hdm_v2_dm_service stop ;;
    dm-restart) hdm_v2_dm_service restart ;;
    dm-autostart-on) hdm_v2_dm_service enable ;;
    dm-autostart-off) hdm_v2_dm_service disable ;;
    session-list) hdm_session_list_graphical ;;
    session-detail) hdm_session_show_detail ;;
    session-logs) hdm_session_greeter_logs ;;
    session-terminate) hdm_session_terminate_graphical ;;
    session-prepare) hdm_session_prepare_login ;;
    session-select) hdm_session_select_default ;;
    protocol-status) hdm_session_protocol_report ;;
    protocol-guide) hdm_v2_protocol_info ;;
    rustdesk-install) hdm_v2_rustdesk_install ;;
    rustdesk-update) hdm_v2_rustdesk_install ;;
    rustdesk-remove) hdm_rustdesk_uninstall ;;
    script-update) hdm_v2_update_release ;;
    script-uninstall-preview) hdm_v2_uninstall_preview ;;
    script-uninstall) hdm_v2_uninstall ;;
    *) hdm_warn "未识别的新版菜单动作：$1"; return 2 ;;
  esac
}
