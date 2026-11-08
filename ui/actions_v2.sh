#!/usr/bin/env bash
# New eight-stage UI handlers. All non-prefixed targets continue to use the
# verified v4.2 legacy dispatch in ui/actions.sh.
hdm_v2_display_manager_info() {
  hdm_show '登录管理器状态'
  hdm_desktop_login_manager_guide
  hdm_action_pkg_detail gdm3
  hdm_action_pkg_detail lightdm
}
hdm_v2_display_manager_install_lightdm() {
  hdm_warn 'LightDM 是登录管理器，不是虚拟显示器。安装软件包可能触发系统登录管理器选择。'
  hdm_warn '请保留 SSH / 云控制台。HDM 不会自动重启图形会话，也不会自动卸载 GDM3。'
  hdm_pkg_install lightdm lightdm-gtk-greeter xorg
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
hdm_v2_protocol_info() {
  printf 'X11 是图形显示协议，Xorg 是常用 X11 服务器实现；Wayland 是另一套显示协议。\n'
  printf 'GDM3/LightDM 负责登录认证与桌面会话启动，不是虚拟显示器。\n'
  printf '已登录桌面、锁屏、注销后的登录界面，以及 RustDesk 是否可远控，须分别验证。\n'
  printf '查看完整链路：sudo hdm --chain；显示方案与虚拟输出：主菜单 1。\n'
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
      hdm_warn '真实卸载入口已提供，但会检查替代登录管理器是否已启动、当前活动桌面及 APT 删除依赖。先切换并实测 LightDM/XFCE，再卸载 GDM3；必须保留 SSH 与云控制台。' ;;
    dm-versions) hdm_v2_display_manager_info ;;
    dm-upgrade-gdm) hdm_v2_display_manager_upgrade gdm3 ;;
    dm-upgrade-lightdm) hdm_v2_display_manager_upgrade lightdm ;;
    protocol-guide) hdm_v2_protocol_info ;;
    script-uninstall-preview) hdm_v2_uninstall_preview ;;
    script-uninstall) hdm_v2_uninstall ;;
    *) hdm_warn "未识别的新版菜单动作：$1"; return 2 ;;
  esac
}
