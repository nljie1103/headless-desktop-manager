#!/usr/bin/env bash
hdm_desktop_status() {
  hdm_show '桌面软件与会话状态'
  for pkg in ubuntu-desktop gnome-shell gdm3 xfce4 mate-desktop-environment lightdm; do
    if hdm_installed "$pkg"; then printf '%-28s %s\n' "$pkg" "$(hdm_pkg_version "$pkg")"; fi
  done
  printf 'GDM3：%s / LightDM：%s\n' "$(hdm_service_state gdm3)" "$(hdm_service_state lightdm)"
  hdm_session_report
}

hdm_gdm_x11() {
  hdm_root && hdm_guard_platform || return 1
  if hdm_gnome_wayland_only; then
    hdm_warn '当前 GNOME 不再支持 Xorg 会话。已跳过 WaylandEnable=false，避免 GDM3 登录循环。'
    hdm_warn '继续测试 GNOME Wayland、PipeWire、RustDesk；Xorg Dummy 可在菜单 1 中独立安装，但不能替代 GNOME Wayland 显示。'
    return 2
  fi
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
  local variant=${1:-full} pkgs=(gdm3)
  if hdm_gnome_wayland_only; then
    hdm_warn '检测到 GNOME Wayland-only：不添加 Xorg 强制配置；完整 GNOME 仍可通过软件源安装。'
  else
    pkgs+=(xorg)
  fi
  case "$variant" in full) pkgs+=(ubuntu-desktop);; minimal) pkgs+=(ubuntu-desktop-minimal);; repair) pkgs+=(gnome-shell gnome-session gdm3);; *) return 1;; esac
  hdm_info '本操作仅安装 GNOME；桌面方案由用户选择，已有桌面不会自动删除。'
  if ! hdm_gnome_wayland_only && [[ ! -f /etc/X11/xorg.conf.d/20-hdm-dummy.conf ]]; then hdm_warn '尚未创建 Dummy 配置。可以先安装 GNOME，稍后再完成虚拟显示。'; fi
  hdm_pkg_install "${pkgs[@]}"
}
# Desktop packages are deliberately independent of the login manager and X server.
# A user may already have LightDM and Xorg. "Quick setup" separately fills a
# compatible stack, while this menu only installs the selected desktop.
hdm_desktop_install_light() {
  local desktop=$1 variant=$2 pkgs=()
  case "$desktop:$variant" in
    xfce:standard) pkgs=(xfce4 xfce4-session xfce4-goodies);;
    xfce:minimal) pkgs=(xfce4 xfce4-session);;
    mate:standard) pkgs=(mate-desktop-environment mate-session-manager mate-desktop-environment-extras);;
    mate:minimal) pkgs=(mate-desktop-environment-core mate-session-manager);;
    *) return 1;;
  esac
  hdm_warn "只安装 $desktop 桌面环境；不会重新安装或切换 LightDM/GDM3，也不会安装 Dummy 显示。"
  hdm_pkg_install "${pkgs[@]}" || return $?
  if ! hdm_has Xorg && ! hdm_installed xserver-xorg-core; then
    hdm_warn '未检测到 Xorg；如需 X11 请另行补装图形服务器。'
  fi
  if [[ $(hdm_service_state lightdm) != active && $(hdm_service_state gdm3) != active ]]; then
    hdm_warn '登录管理器当前没有运行：安装桌面不等于自动启动图形登录界面。'
  fi
}

hdm_desktop_install_gnome_only() {
  hdm_warn '只安装 GNOME 桌面会话，不主动选择 GDM3 或切换 Wayland/X11。'
  hdm_pkg_install gnome-shell gnome-session gnome-control-center
}

hdm_desktop_update() {
  local choice
  if hdm_installed ubuntu-desktop; then choice=ubuntu-desktop; elif hdm_installed ubuntu-desktop-minimal; then choice=ubuntu-desktop-minimal; elif hdm_installed xfce4; then choice=xfce4; elif hdm_installed mate-desktop-environment; then choice=mate-desktop-environment; else hdm_error '未检测到受支持的桌面环境'; return 1; fi
  hdm_pkg_upgrade "$choice"
}
# Read-only guidance: package installation and the selected login greeter are
# separate; changing the default display manager may disconnect remote access.
hdm_desktop_login_manager_guide() {
  hdm_show 'X11 登录管理器'
  local current='未知'
  if [[ -r /etc/X11/default-display-manager ]]; then
    IFS= read -r current < /etc/X11/default-display-manager || :
  fi
  printf '默认登录管理器：%s\n' "$current"
  printf 'GDM3：%s；LightDM：%s\n' "$(hdm_service_state gdm3)" "$(hdm_service_state lightdm)"
  if hdm_installed lightdm && hdm_installed xfce4-session; then
    printf 'XFCE 与 LightDM 已安装，可从登录界面选择 XFCE Session。\n'
    printf '若要在 Ubuntu/Debian 上切换默认登录管理器，先备份 /etc/X11/default-display-manager，\n'
    printf '保留 SSH/控制台，再在可交互的终端执行 sudo dpkg-reconfigure lightdm。\n'
    printf 'HDM 不会代替用户切换显示管理器或立即重启现有图形会话。\n'
  else
    printf '如需 XFCE / X11，请先从菜单 4 → 1 安装 XFCE；如需 X11，再确保 Xorg 和 LightDM/Greeter 已就绪。\n'
  fi
  printf '切换后还需验证 X11 登录界面、RustDesk 远控及重启恢复。\n'
}
hdm_desktop_switch() {
  local desktop=$1
  hdm_root && hdm_guard_platform || return 1
  case "$desktop" in
    gnome) hdm_installed gnome-shell || { hdm_error '请先安装 GNOME'; return 1; }
      if hdm_gnome_wayland_only; then
        hdm_info '已检测 GNOME Wayland-only；保留系统默认 GDM/Wayland，会话切换请在登录管理器进行。'
      else
        hdm_gdm_x11 || return 1
        hdm_info '已配置 GNOME X11 支持；实际会话需在登录管理器选择。'
      fi;;
    xfce|mate)
      local pkg
      [[ $desktop == xfce ]] && pkg=xfce4-session || pkg=mate-session-manager
      if ! hdm_installed "$pkg"; then
        hdm_warn "未安装 $desktop 图形会话，请先从菜单 2 安装。"
        return 1
      fi
      hdm_warn '请先确认 SSH/云控制台可用，再在登录界面选择对应 X11 会话；HDM 不自动重启图形会话。'
      hdm_desktop_login_manager_guide;;
    *) return 1;;
  esac
}
hdm_desktop_repair() {
  if hdm_installed gnome-shell; then hdm_desktop_install_gnome repair; else hdm_warn 'GNOME 未安装。请先从菜单 4 选择安装。'; fi
}
hdm_desktop_compare() {
  cat <<'END_COMPARE'
桌面      典型空闲内存*     主机内存建议       适合情况
GNOME     约 1.2–2.0 GB    4 GB 起          完整现代桌面、Wayland
MATE      约 0.5–0.9 GB    2–4 GB           传统布局、轻量桌面
XFCE      约 0.4–0.8 GB    1–3 GB           小型云服务器、低资源

* 空闲内存为经验区间，不含浏览器、RustDesk 和实际业务，受发行版/服务影响。
Ubuntu 26 的 GNOME 使用 Wayland，不要通过 WaylandEnable=false 强制 X11。
已有桌面会被保留；低于 4 GB 内存且未安装桌面时，一键安装优先 XFCE。
END_COMPARE
}
