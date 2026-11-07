#!/usr/bin/env bash
hdm_display_status() {
  hdm_show '虚拟显示器状态'
  printf 'Xorg Dummy 包：%s\n' "$(hdm_pkg_version xserver-xorg-video-dummy)"
  printf 'Xvfb 包：%s\n' "$(hdm_pkg_version xvfb)"
  printf 'VKMS 模块：'; if lsmod 2>/dev/null | grep -q '^vkms '; then printf '已加载\n'; else printf '未加载 / 不可查看\n'; fi
  printf 'HDM Dummy 配置：'; [[ -f /etc/X11/xorg.conf.d/20-hdm-dummy.conf ]] && printf '存在\n' || printf '不存在\n'
  printf 'Xvfb 服务：%s\n' "$(hdm_service_state hdm-xvfb)"
  printf '当前会话：'; loginctl list-sessions --no-legend 2>/dev/null | head -6 || true
  if hdm_has xrandr && [[ -n ${DISPLAY:-} ]]; then xrandr --current 2>&1 | head -24 || :; else printf '当前 shell 无可连接的 DISPLAY；不能据此断言图形服务失败。\n'; fi
  printf 'GDM3：%s\n' "$(hdm_service_state gdm3)"
  printf '服务/驱动安装状态并不代表 GNOME 会话可用。\n'
}
hdm_display_res_validate() { [[ ${1:-} =~ ^(1280x720|1600x900|1920x1080|2560x1440)$ ]]; }
hdm_display_select_res() {
  local choice value
  printf '%s\n' '1. 1280x720' '2. 1600x900' '3. 1920x1080（推荐）' '4. 2560x1440'
  hdm_prompt '请输入分辨率编号：' choice || return 1
  case "$choice" in 1) value=1280x720;; 2) value=1600x900;; 3) value=1920x1080;; 4) value=2560x1440;; *) hdm_warn '尚不支持该分辨率；避免生成不可用的 Xorg Modeline。'; return 1;; esac
  hdm_setting HDM_DEFAULT_RESOLUTION "$value" && hdm_info "分辨率选择为 $value"
}
hdm_display_dummy_render() {
  local resolution=$1 mode
  hdm_display_res_validate "$resolution" || return 1
  case "$resolution" in
    1280x720)  mode='74.50 1280 1344 1472 1664 720 723 728 748 -hsync +vsync';;
    1600x900)  mode='118.25 1600 1696 1856 2112 900 903 908 934 -hsync +vsync';;
    1920x1080) mode='173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync';;
    2560x1440) mode='241.50 2560 2608 2640 2720 1440 1443 1448 1481 +hsync -vsync';;
  esac
  cat <<CONF
# Managed by HDM. Backups in /var/lib/hdm/backups. Xorg Dummy without a physical monitor.
Section "Device"
    Identifier "HDM Dummy Device"
    Driver "dummy"
    VideoRam 256000
EndSection
Section "Monitor"
    Identifier "HDM Dummy Monitor"
    HorizSync 28.0-90.0
    VertRefresh 48.0-76.0
    Modeline "${resolution}_60.00" ${mode}
    Option "PreferredMode" "${resolution}_60.00"
EndSection
Section "Screen"
    Identifier "HDM Dummy Screen"
    Device "HDM Dummy Device"
    Monitor "HDM Dummy Monitor"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "${resolution}_60.00"
    EndSubSection
EndSection
Section "ServerLayout"
    Identifier "HDM Dummy Layout"
    Screen 0 "HDM Dummy Screen"
EndSection
CONF
}
hdm_display_dummy_config() {
  hdm_root && hdm_guard_platform || return 1
  hdm_installed xserver-xorg-video-dummy || { hdm_error '请先安装 Xorg Dummy 软件包'; return 1; }
  local target=/etc/X11/xorg.conf.d/20-hdm-dummy.conf tmp
  hdm_display_dummy_render "$HDM_DEFAULT_RESOLUTION" || return 1
  hdm_danger '会创建 Xorg Dummy 全局配置，可能改变 GDM/已有显示器。请确保保留 SSH 和云控制台恢复入口。' || return 2
  if [[ ! -e $HDM_STATE/pending-rollback ]]; then
    hdm_snapshot_create "$target" /etc/gdm3/custom.conf || return 1
    hdm_recovery_arm "$HDM_LAST_SNAPSHOT" || return 1
  fi
  mkdir -p /etc/X11/xorg.conf.d
  tmp=$(mktemp /etc/X11/xorg.conf.d/.hdm-dummy.XXXXXX) || return 1
  hdm_display_dummy_render "$HDM_DEFAULT_RESOLUTION" > "$tmp"
  chmod 644 "$tmp"
  mv -f -- "$tmp" "$target"
  hdm_info "写入 Dummy 配置：$target；分辨率 $HDM_DEFAULT_RESOLUTION。请先测试图形显示，再 sudo hdm --confirm-display。"
  hdm_info '不自动重启 GDM3/系统，避免断开当前远程操作。'
}
hdm_display_install_dummy() {
  hdm_root && hdm_guard_platform || return 1
  hdm_pkg_install xserver-xorg-video-dummy xserver-xorg-core || return 1
  hdm_display_dummy_config
}
hdm_display_install_xvfb() {
  hdm_warn '实验性 Xvfb 路线：仅安装独立 X display；不保证 GNOME/GDM/RustDesk 可见。'
  hdm_pkg_install xvfb x11-utils || return 1
  if hdm_confirm '安装 HDM 独立 Xvfb systemd 服务模板（默认不启用）？'; then
    install -m 644 "$HDM_ROOT/templates/systemd/hdm-xvfb.service" /etc/systemd/system/hdm-xvfb.service
    systemctl daemon-reload
    hdm_info '已安装 hdm-xvfb.service，尚未启用。可在服务菜单手动启动。'
  fi
}
hdm_display_vkms_check() {
  printf '内核：%s\n' "$(uname -r)"
  if modinfo vkms >/dev/null 2>&1; then printf 'VKMS 模块：内核包含\n'; else printf 'VKMS 模块：不可用（请勿盲目编译未知模块）\n'; return 1; fi
}
hdm_display_vkms_load() {
  hdm_root && hdm_guard_platform || return 1
  hdm_display_vkms_check || return 1
  hdm_danger '加载实验性 VKMS（可能影响图形设备选择）？' || return 0
  modprobe vkms && hdm_info 'VKMS 内核模块已加载。此时未验证 GNOME / RustDesk 捕获。'
}
hdm_display_vkms_persist() {
  hdm_display_vkms_check || return 1
  hdm_danger '让 VKMS 内核模块在开机时自动加载？' || return 0
  hdm_snapshot_create /etc/modules-load.d/hdm-vkms.conf || return 1
  printf 'vkms\n' > /etc/modules-load.d/hdm-vkms.conf
  chmod 644 /etc/modules-load.d/hdm-vkms.conf
}
hdm_display_vkms_unset() {
  hdm_danger '移除 HDM VKMS 自启配置，不会卸载系统内核？' || return 0
  rm -f /etc/modules-load.d/hdm-vkms.conf
  hdm_info 'VKMS 自启配置已删除。当前已加载的模块未强制移除。'
}
hdm_display_change_res() {
  hdm_display_select_res || return 1
  if [[ -f /etc/X11/xorg.conf.d/20-hdm-dummy.conf ]]; then hdm_display_dummy_config; else hdm_info '已保存下次 Dummy 安装使用的分辨率。'; fi
}
hdm_display_remove_config() {
  hdm_danger '删除 HDM 自己创建的 Dummy 配置（可能造成远程黑屏）？' || return 0
  hdm_snapshot_create /etc/X11/xorg.conf.d/20-hdm-dummy.conf || return 1
  hdm_recovery_arm "$HDM_LAST_SNAPSHOT" || return 1
  rm -f /etc/X11/xorg.conf.d/20-hdm-dummy.conf
  hdm_info '仅清理 HDM Dummy 配置，未删除系统驱动软件包。'
}
hdm_display_current_package() {
  if [[ -f /etc/X11/xorg.conf.d/20-hdm-dummy.conf ]]; then printf 'xserver-xorg-video-dummy'; elif hdm_installed xvfb; then printf 'xvfb'; else printf ''; fi
}
