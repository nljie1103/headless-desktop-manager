#!/usr/bin/env bash
hdm_desktop_status() {
  hdm_show '桌面环境状态'
  for pkg in ubuntu-desktop ubuntu-desktop-minimal gnome-shell gdm3 xfce4 mate-desktop-environment lightdm; do
    printf '%-28s %s\n' "$pkg" "$(hdm_pkg_version "$pkg")"
  done
  printf 'GDM3：%s / LightDM：%s\n' "$(hdm_service_state gdm3)" "$(hdm_service_state lightdm)"
  printf '图形会话（登录用户、显示类型）：\n'
  loginctl list-sessions --no-legend 2>/dev/null || :
  if hdm_has pgrep; then pgrep -a -f 'gnome-shell|gnome-session' 2>/dev/null | head -12 || :; fi
  printf '仅服务进程存在不能证明完整 GNOME 图形会话可用。\n'
}
hdm_gdm_x11() {
  hdm_root && hdm_guard_platform || return 1
  local file=/etc/gdm3/custom.conf tmp
  [[ -d /etc/gdm3 ]] || { hdm_error 'GDM3 尚未安装'; return 1; }
  if [[ ${HDM_QUICK_APPROVED:-0} != 1 ]]; then
    hdm_danger '配置 GDM3 使用 Xorg（WaylandEnable=false）；可能影响远程登录显示。' || return 2
  fi
  if [[ ! -f $HDM_STATE/pending-rollback ]]; then
    hdm_snapshot_create "$file" /etc/X11/xorg.conf.d/20-hdm-dummy.conf || return 1
    hdm_recovery_arm "$HDM_LAST_SNAPSHOT" || return 1
  fi
  tmp=$(mktemp /etc/gdm3/.hdm.XXXXXX) || return 1
  if [[ -f $file ]]; then
    awk 'BEGIN{in_daemon=0;set=0;found=0} /^\[daemon\]/{in_daemon=1;found=1;print;next} /^\[/{if(in_daemon && !set){print "WaylandEnable=false";set=1};in_daemon=0;print;next} in_daemon && /^[[:space:]#]*WaylandEnable[[:space:]]*=/{if(!set){print "WaylandEnable=false";set=1};next} {print} END{if(in_daemon && !set)print "WaylandEnable=false";if(!found){print "\n[daemon]";print "WaylandEnable=false"}}' "$file" > "$tmp"
  else printf '[daemon]\nWaylandEnable=false\n' > "$tmp"; fi
  chmod 644 "$tmp"; mv -f "$tmp" "$file"
  hdm_info 'GDM3 X11 配置已保存。请在确认图形显示后执行 sudo hdm --confirm-display。'
  hdm_info '配置通常需要重启 GDM3/系统才能生效；HDM 不自动断开会话。'
}
hdm_desktop_install_gnome() {
  local variant=${1:-full} pkgs=(gdm3 xorg)
  case "$variant" in full) pkgs+=(ubuntu-desktop);; minimal) pkgs+=(ubuntu-desktop-minimal);; repair) pkgs+=(gnome-shell gnome-session gdm3);; *) return 1;; esac
  hdm_info 'GNOME 为 HDM 优先支持的桌面环境，不会自动改用轻量桌面。'
  if [[ ! -f /etc/X11/xorg.conf.d/20-hdm-dummy.conf ]]; then hdm_warn '尚未创建 Dummy 配置。可以先安装 GNOME，稍后再完成虚拟显示。'; fi
  hdm_pkg_install "${pkgs[@]}"
}
hdm_desktop_install_light() {
  local desktop=$1 variant=$2 pkgs=()
  case "$desktop:$variant" in
    xfce:standard) pkgs=(xfce4 xfce4-goodies lightdm);;
    xfce:minimal) pkgs=(xfce4 lightdm);;
    mate:standard) pkgs=(mate-desktop-environment mate-desktop-environment-extras lightdm);;
    mate:minimal) pkgs=(mate-desktop-environment-core lightdm);;
    *) return 1;;
  esac
  hdm_warn "$desktop 为可选桌面，尚未通过所有云服务器组合的真实图形验证。"
  hdm_pkg_install "${pkgs[@]}"
}
hdm_desktop_update() {
  local choice
  if hdm_installed ubuntu-desktop; then choice=ubuntu-desktop; elif hdm_installed ubuntu-desktop-minimal; then choice=ubuntu-desktop-minimal; elif hdm_installed xfce4; then choice=xfce4; elif hdm_installed mate-desktop-environment; then choice=mate-desktop-environment; else hdm_error '未检测到受支持的桌面环境'; return 1; fi
  hdm_pkg_upgrade "$choice"
}
hdm_desktop_switch() {
  local desktop=$1
  hdm_root && hdm_guard_platform || return 1
  case "$desktop" in
    gnome) hdm_installed gnome-shell || { hdm_error '请先安装 GNOME'; return 1; }; hdm_gdm_x11; hdm_info '已配置 GNOME X11 支持；实际切换会话需要在登录管理器选择 GNOME on Xorg。';;
    xfce|mate) hdm_warn '切换显示管理器和用户会话可能中断远控；本版本不自动切换为 LightDM。请在本地/云控制台验证后人工选择已安装的会话。';;
    *) return 1;;
  esac
}
hdm_desktop_repair() {
  if hdm_installed gnome-shell; then hdm_desktop_install_gnome repair; else hdm_warn 'GNOME 未安装。请先从菜单 3 选择安装。'; fi
}
hdm_desktop_compare() {
  cat <<'END_COMPARE'
GNOME：完整功能，HDM 默认支持目标；建议更高内存，无 GPU 时软件渲染需验证。
XFCE：轻量 X11，供低资源设备选择；GNOME 不是自动替代对象。
MATE：轻量传统桌面，会话管理器适配需进一步验证。
兼容性主路径：Ubuntu 24.04 x86_64 + GNOME + Xorg Dummy + RustDesk。
Xvfb/VKMS + GNOME/RustDesk 仍属于实验性组合。
END_COMPARE
}
