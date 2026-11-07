#!/usr/bin/env bash
hdm_quick_plan() {
  cat <<'INFO'
推荐组合：Ubuntu 24.04 x86_64 + Xorg Dummy + 完整 GNOME + GDM3/X11 + RustDesk。
安装优先级：已配置可信 APT → 可信 Ubuntu 官方镜像（仅网络故障） → 对已发布/校验的 RustDesk GitHub 备用包。
不禁用 SSH，不关闭防火墙，不启用自动登录，不自动重启服务器。
未实机验证：GNOME Shell 软件渲染、GDM 登录画面捕获、断电重启后 RustDesk 远程控制。
INFO
  hdm_diag_full
}
hdm_quick_install() {
  hdm_root && hdm_guard_platform || return 1
  hdm_quick_plan
  hdm_danger '开始安装 GNOME + Dummy + RustDesk？可能下载数 GB 软件包，须保留 SSH/云控制台。' || return 2
  if ! hdm_installed xserver-xorg-video-dummy; then hdm_pkg_install xserver-xorg-video-dummy xserver-xorg-core || return 1; fi
  if ! hdm_installed ubuntu-desktop; then hdm_desktop_install_gnome full || return 1; fi
  if ! hdm_has rustdesk; then hdm_rustdesk_install_online latest || { hdm_warn 'RustDesk 安装失败。已装系统组件保留，可从菜单 5 单独重试。'; return 1; }; fi
  # Only after slow package installations do we arm the seven-minute rollback timer.
  if [[ ! -f /etc/X11/xorg.conf.d/20-hdm-dummy.conf ]]; then hdm_display_dummy_config || return 1; fi
  if ! grep -Eq '^[[:space:]]*WaylandEnable=false' /etc/gdm3/custom.conf 2>/dev/null; then hdm_gdm_x11 || return 1; fi
  hdm_diag_full
  hdm_warn '软件已安装但实际远程桌面尚未验证。请按计划测试 GDM/GNOME 和 RustDesk，并用 sudo hdm --confirm-display 保留配置。'
}
