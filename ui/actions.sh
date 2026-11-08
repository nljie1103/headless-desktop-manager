#!/usr/bin/env bash
# Only approved action IDs are executable. Unavailable actions display an explicit notice.
hdm_action_not_ready() {
  local id=$1
  printf '[尚无自动处理逻辑] %s：%s\n' "$id" "$(hdm_menu_label "$id")"
  printf '此操作需要额外兼容性验证或安全前置条件。没有修改系统；参见 docs/AI_DEVELOPMENT_SPEC.md。\n'
  return 2
}
hdm_action_show_services() { systemctl status gdm3 rustdesk hdm-xvfb --no-pager --lines 6 2>&1 || :; }
hdm_action_rustdesk_version() { hdm_rustdesk_status; hdm_release_query rustdesk latest || hdm_warn '官方 Release 元数据不可用'; }
hdm_action_service_wizard() {
  local name mode=$1
  hdm_prompt '服务名 [gdm3/rustdesk/hdm-xvfb]：' name || return 1
  case "$name" in gdm3|rustdesk|hdm-xvfb) ;; *) hdm_warn '拒绝非白名单服务'; return 1;; esac
  hdm_root && hdm_guard_platform || return 1
  case "$mode" in
    start) hdm_confirm "启动 $name ？" && systemctl start "$name";;
    stop) hdm_danger "停止 $name 可能造成远程失联。请通过 SSH/云平台控制台操作！" && systemctl stop "$name";;
    restart) hdm_diag_service_restart "$name";;
    enable) hdm_diag_service_enable "$name";;
    disable) hdm_danger "禁用 $name 开机启动，重启后可能没有远控？" && systemctl disable "$name";;
    *) return 1;;
  esac
}
hdm_action_pkg_detail() { local pkg=$1; printf 'APT 软件包：%s\n' "$pkg"; hdm_pkg_versions "$pkg"; }
hdm_action_choose_version() {
  local ver
  hdm_prompt '输入 RustDesk 官方版本号（如 1.5.1）：' ver || return 1
  [[ $ver =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { hdm_warn '不接受非稳定版版本号'; return 1; }
  hdm_rustdesk_install_online tag "$ver"
}
hdm_action_rustdesk_reinstall() {
  local pkg; pkg=$(hdm_pkg_version rustdesk)
  [[ $pkg != 未安装 ]] || return 1
  hdm_danger '重新安装当前已配置 RustDesk 包（远控可能中断）？' || return 2
  hdm_apt_call install -y --reinstall rustdesk
}
hdm_action_remove_backup() {
  local id
  hdm_snapshots
  hdm_prompt '输入待删除快照 ID：' id || return 1
  [[ $id =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]+$ ]] || return 1
  [[ -f $HDM_STATE/backups/$id/manifest.tsv ]] || return 1
  if [[ -r $HDM_STATE/pending-rollback && $(cat "$HDM_STATE/pending-rollback") == "$id" ]]; then hdm_warn '该快照仍作为安全回滚目标，不可删除。'; return 1; fi
  hdm_danger "永久删除快照 $id ？" || return 2
  rm -rf -- "$HDM_STATE/backups/$id"
}
hdm_action_disk_network() { hdm_diag_system; hdm_diag_network; }

# Preview package-manager removal without making any system changes. Never
# feed free-form menu text to APT: accepted package names are fixed.
hdm_action_remove_preview() {
  local pkg=$1 simulation
  case "$pkg" in rustdesk|ubuntu-desktop|ubuntu-desktop-minimal|xfce4|mate-desktop-environment) ;; *) return 2;; esac
  if ! hdm_installed "$pkg"; then
    printf '[未安装] %s，无需执行卸载。\n' "$pkg"
    return 0
  fi
  if [[ $(hdm_type) != apt ]] || ! hdm_has apt-get; then
    hdm_warn '卸载模拟目前仅支持 APT 主机，未改动系统。'
    return 2
  fi
  printf 'APT 卸载模拟：%s（只读，不执行删除）\n' "$pkg"
  if ! simulation=$(LC_ALL=C apt-get -s remove "$pkg" 2>&1); then
    printf '%s\n' "$simulation" | tail -n 15
    return 2
  fi
  local count
  count=$(printf '%s\n' "$simulation" | grep -c '^Remv ' || :)
  printf 'APT 计划删除 %s 个软件包（下列最多列出 25 项）：\n' "$count"
  printf '%s\n' "$simulation" | grep '^Remv ' | head -n 25 || :
  printf '预览不会删除配置、注销用户、停止服务或执行 apt autoremove。\n'
  printf '远程环境切换前必须保留 SSH/云控制台和系统快照。\n'
}
hdm_action_desktop_remove_preview() {
  hdm_show '已安装桌面的卸载模拟'
  local pkg found=0
  for pkg in ubuntu-desktop ubuntu-desktop-minimal xfce4 mate-desktop-environment; do
    if hdm_installed "$pkg"; then
      found=1
      hdm_action_remove_preview "$pkg" || return $?
    fi
  done
  ((found)) || printf '未检测到所列桌面元软件包。独立安装的桌面组件需单独核查。\n'
}
hdm_action_other_desktop_plan() {
  local id=$1 plan=''
  case "$id" in
    9.2.2) plan='GNOME + Xvfb + RustDesk';;
    9.2.3) plan='GNOME + VKMS + RustDesk';;
    9.2.4) plan='XFCE + Xorg Dummy + LightDM + RustDesk';;
    9.2.5) plan='XFCE + Xvfb + RustDesk';;
    9.2.6) plan='MATE + Xorg Dummy + LightDM + RustDesk';;
    9.2.7) plan='自定义桌面 / 显示 / RustDesk 组合';;
    *) return 2;;
  esac
  hdm_show "$plan"
  printf '当前入口只展示选定方案，未对系统执行安装或切换。\n'
  printf '显示组件：菜单 1；桌面：菜单 3；RustDesk：菜单 5；安装后诊断：菜单 10。\n'
  printf '如需自动安装，请使用菜单 9.1 的实际主机推荐方案。\n'
  printf 'GNOME 与 Xvfb/VKMS、不同 X11 登录管理器的远端画面仍需目标主机验证。\n'
}
hdm_action_display_remove_preview() {
  hdm_show 'HDM 管理的显示配置'
  local file
  for file in /etc/X11/xorg.conf.d/20-hdm-dummy.conf /etc/systemd/system/hdm-xvfb.service; do
    if [[ -f $file ]]; then printf '[存在] %s\n' "$file"; else printf '[不存在] %s\n' "$file"; fi
  done
  printf '仅可在确认并建立恢复快照后移除 HDM 管理的配置，当前仅预览。\n'
}
hdm_dispatch() {
  local id=$1
  case "$id" in
  # 1. Install display: Xorg, Xvfb, VKMS
  1.1.1|1.4.3) hdm_display_install_dummy;;
  1.1.2.A|2.4.5) hdm_display_select_res;;
  1.2.3) hdm_xvfb_set_resolution;;
  1.1.2.B) hdm_warn 'Xorg Dummy 默认 24-bit，不自动更改色深。';;
  1.2.4) hdm_xvfb_set_depth;;
  1.1.2.C) hdm_warn '启用由 GDM3 及 Xorg 管理；HDM 不另起冲突的 Xorg 实例。';;
  1.1.2.D) hdm_display_dummy_render "$HDM_DEFAULT_RESOLUTION";;
  1.1.2.E) hdm_display_install_dummy;;
  1.1.3) hdm_action_pkg_detail xserver-xorg-video-dummy; df -h /;;
  1.1.4|1.4.1|2.4.6) hdm_display_status;;
  2.1.1) hdm_display_packages_report;;
  2.1.2) hdm_display_session_report;;
  2.1.3) hdm_display_modes_report;;
  1.2.1) hdm_display_install_xvfb;;
  1.2.2) hdm_xvfb_set_display;;
  1.2.5) hdm_xvfb_configure;;
  1.2.6) hdm_xvfb_verify;;
  1.2.7|1.5.2|1.4.2|2.3.4) hdm_display_compare;;
  1.3.1|1.3.4|1.3.5) hdm_display_vkms_check; ls -l /dev/dri 2>/dev/null || :;;
  1.3.2) hdm_display_vkms_load;;
  1.3.3) hdm_display_vkms_persist;;
  1.3.6) hdm_display_vkms_unset;;
  1.5.1|1.5.3) hdm_display_compare;;
  # 2. Display management
  2.2.1|2.2.4|2.2.5|2.2.6) hdm_action_pkg_detail "$(hdm_display_current_package)";;
  2.2.2) local pkg; pkg=$(hdm_display_current_package); [[ -n $pkg ]] && hdm_pkg_upgrade "$pkg" || hdm_warn '没有检测到可升级的 HDM 虚拟显示方案';;
  2.2.3|2.7.2) local pkg; pkg=$(hdm_display_current_package); [[ -n $pkg ]] && hdm_apt_call install -y --reinstall "$pkg" || hdm_warn '当前显示包未知';;
  2.3.1) hdm_display_install_dummy;;
  2.3.2) hdm_display_install_xvfb;;
  2.3.3) hdm_display_vkms_load;;
  2.3.5|2.9.2) hdm_snapshot_choose;;
  2.4.1) hdm_setting HDM_DEFAULT_RESOLUTION 1280x720 && hdm_display_dummy_config;;
  2.4.2) hdm_setting HDM_DEFAULT_RESOLUTION 1600x900 && hdm_display_dummy_config;;
  2.4.3) hdm_setting HDM_DEFAULT_RESOLUTION 1920x1080 && hdm_display_dummy_config;;
  2.4.4) hdm_setting HDM_DEFAULT_RESOLUTION 2560x1440 && hdm_display_dummy_config;;
  2.4.7) hdm_setting HDM_DEFAULT_RESOLUTION 1920x1080; hdm_info '已将默认值恢复 1920x1080；修改现有配置需单独确认。';;
  2.4.8) hdm_warn 'Xorg Dummy 当前仅提供经过预设的 24-bit 模式。';;
  2.5.1|2.6.1) hdm_diag_services;;
  2.5.2) hdm_action_service_wizard start;;
  2.5.3) hdm_action_service_wizard stop;;
  2.5.4) hdm_action_service_wizard restart;;
  2.6.2) hdm_action_service_wizard enable;;
  2.6.3) hdm_action_service_wizard disable;;
  2.7.1) hdm_display_status; hdm_warn '如 Dummy 配置缺失，请返回 1.1.1 安装或配置。';;
  2.8.1|2.8.3) hdm_display_remove_config;;
  2.8.2) hdm_warn '保守处理：仅允许删除 HDM 自己创建的配置。不要自动卸载其他桌面可能使用的 Xorg 依赖。';;
  2.8.4) hdm_action_display_remove_preview;;
  2.9.1) hdm_snapshots;;
  2.9.3) hdm_display_status;;
  # 3. Install desktops
  3.1.1) hdm_desktop_install_gnome full;;
  3.1.2) hdm_desktop_install_gnome minimal;;
  3.1.3) hdm_desktop_install_gnome repair;;
  3.1.4) hdm_pkg_install gdm3;;
  3.1.5) hdm_gdm_x11;;
  3.1.6) apt-cache show ubuntu-desktop 2>/dev/null | grep -E '^Package:|^Installed-Size:|^Depends:' | head -10 || :; df -h /;;
  3.1.7|3.6.1|3.6.2) hdm_desktop_status;;
  3.2.1) hdm_desktop_install_light xfce standard;;
  3.2.2) hdm_desktop_install_light xfce minimal;;
  3.2.3) hdm_desktop_login_manager_guide;;
  3.2.4|3.3.4) hdm_desktop_status;;
  3.2.5|3.3.5) hdm_action_disk_network;;
  3.2.6) hdm_desktop_install_light xfce standard;;
  3.3.1) hdm_desktop_install_light mate standard;;
  3.3.2) hdm_desktop_install_light mate minimal;;
  3.3.3) hdm_desktop_login_manager_guide;;
  3.3.6) hdm_desktop_install_light mate standard;;
  3.4.1) hdm_diag_system;;
  3.4.2) hdm_desktop_compare;;
  3.4.3|3.5.1|3.5.2) hdm_desktop_compare;;
  # 4. Manage desktop
  4.1.1|4.1.2|4.4.1|4.6.1|4.6.3|4.6.5) hdm_desktop_status;;
  4.5.1) hdm_session_report;;
  4.5.2) hdm_session_protocol_report;;
  4.5.3) hdm_session_service_report;;
  4.5.4) hdm_session_user_report;;
  4.5.5) hdm_session_start_gdm;;
  4.5.6) hdm_session_logs;;
  4.5.7) hdm_session_dependencies;;
  4.5.8) hdm_session_enable_graphical_boot;;
  4.5.9) hdm_session_repair;;
  4.2.1|4.2.6) hdm_action_pkg_detail ubuntu-desktop;;
  4.2.2) hdm_desktop_update;;
  4.2.3|4.7.2) hdm_apt_call install -f -y;;
  4.2.4|4.7.1) hdm_desktop_repair;;
  4.2.5) grep 'upgrade\|install' /var/log/apt/history.log 2>/dev/null | tail -25 || :;;
  4.3.1) hdm_desktop_switch gnome;;
  4.3.2) hdm_desktop_switch xfce;;
  4.3.3) hdm_desktop_switch mate;;
  4.3.4) hdm_desktop_status;;
  4.3.5|4.4.6|4.6.7|4.7.3|4.9.2) hdm_snapshot_choose;;
  4.4.2) hdm_session_protocol_report;;
  4.4.3|4.4.4) hdm_desktop_login_manager_guide;;
  4.4.5) hdm_action_service_wizard restart;;
  
  4.6.2|4.6.6) hdm_diag_log desktop; hdm_warn 'RustDesk 抓屏仍需从另一台设备确认。';;
  4.6.4) hdm_warn '默认保留屏幕锁定和用户认证。此版本不自动降低安全设置。';;
  4.8.1) hdm_action_desktop_remove_preview;;
  4.8.2) hdm_warn '桌面卸载需要审核菜单 4.8.1 的 APT 模拟结果。为防止远程失联，HDM 不自动删除桌面，请在保留独立 SSH/控制台后人工操作。';;
  4.8.3) hdm_display_remove_config;;
  4.9.1) hdm_snapshots;;
  4.9.3) hdm_desktop_status;;
  # 5. RustDesk install
  5.1.1|5.7.1|5.7.2|5.7.3|5.8.1) hdm_diag_full; hdm_sources_status;;
  5.1.2|5.8.2|5.8.3) printf '官方优先：%s\n备用库：%s\n' "$RUSTDESK_UPSTREAM_RELEASES_URL" "$HDM_RELEASES_URL"; hdm_warn '这里只展示安装来源；安装需进入菜单 5.1.3。';;
  5.1.3|5.2.2) hdm_rustdesk_install_online latest;;
  5.1.4) hdm_rustdesk_status; printf '后续请菜单 7 配置服务器/密码。\n';;
  5.2.1|5.3.1|5.6.3) hdm_release_query rustdesk list || hdm_warn '查询官方版本列表失败';;
  5.3.2|5.6.2) printf 'HDM 当前暂无经云端远控回归验证的固定推荐版本，使用官方稳定版并标记待验证。\n';;
  5.3.3|6.4.2|6.4.3|8.4.1) if [[ $id == 8* ]]; then local ver; hdm_prompt 'HDM tag（vX.Y.Z）：' ver && hdm_update_install tag "$ver"; else hdm_action_choose_version; fi;;
  5.3.4|6.5.2) hdm_rustdesk_rollback;;
  5.4.1|5.4.2|5.4.3) hdm_rustdesk_install_local;;
  5.5.1|5.5.4) hdm_mirror_rustdesk;;
  5.5.2|5.5.3) hdm_list_mirror; hdm_warn '没有经过签名/哈希确认的实际备用包时不可下载。';;
  5.5.5) hdm_danger '清理 HDM 下载缓存中的 RustDesk .deb（不修改已安装程序）？' && find "$HDM_CACHE/downloads" -maxdepth 1 -name 'rustdesk-*.deb' -type f -delete;;
  5.6.1) hdm_rustdesk_status;;
  # 6. RustDesk update
  6.1.1|6.9.1|6.9.2) hdm_rustdesk_status; hdm_state_get rustdesk-last-installed;;
  6.1.2|6.1.3|6.1.4|6.7.2) hdm_action_rustdesk_version;;
  6.2.1|6.3.1) hdm_rustdesk_install_online latest;;
  6.4.1) hdm_release_query rustdesk list || :;;
  6.5.1|6.5.3|6.5.4) hdm_rustdesk_rollback;;
  6.6.1) hdm_action_rustdesk_reinstall;;
  6.7.1) hdm_rustdesk_status;;
  6.8.1) printf '1. 官方 stable\n2. 已验证 recommended（当前暂无固定版本）\n'; local opt; hdm_prompt '选择：' opt && case "$opt" in 1) hdm_setting HDM_RUSTDESK_CHANNEL stable;; 2) hdm_setting HDM_RUSTDESK_CHANNEL tested;; esac;;
  6.8.2) hdm_warn 'V0.1 默认手动检查，不启用后台定时检查。';;
  6.8.3) du -sh "$HDM_CACHE/downloads" 2>/dev/null || :;;
  6.8.4) hdm_warn '更新后验证：RustDesk 服务、ID、用户实际远程连接。';;
  6.8.5) hdm_setting HDM_RUSTDESK_CHANNEL stable;;
  6.10.1) hdm_action_remove_preview rustdesk;;
  6.10.2) hdm_warn '本功能默认保留现有 RustDesk 客户端配置；如需清理，请手动核实配置目录并先备份。';;
  6.10.3) hdm_rustdesk_uninstall;;
  # 7. RustDesk ID/Relay config
  7.12) hdm_rustdesk_permission_report;;
  7.13) hdm_rustdesk_permissions_menu;;
  7.1.1) hdm_rustdesk_draft_wizard;;
  7.1.2|7.5.1) hdm_rustdesk_draft_edit relay;;
  7.1.3|7.6.1) hdm_rustdesk_draft_edit key;;
  7.1.4) hdm_rustdesk_draft_port_defaults;;
  7.1.5) hdm_rustdesk_check_connection id draft && hdm_rustdesk_check_connection relay draft;;
  7.1.6) hdm_rustdesk_draft_preview;;
  7.1.7) hdm_rustdesk_draft_apply;;
  7.1.8) hdm_rustdesk_get_id;;
  7.4.1) hdm_rustdesk_draft_edit id;;
  7.2.1) hdm_warn '由于服务端与用户作用域差异，默认服务器恢复暂不自动擦写配置；请先恢复菜单 7.11 的快照，或通过 RustDesk 官方 UI 恢复默认值。';;
  7.3.1|7.9.5|7.9.6) hdm_rustdesk_server_status;;
  7.7.3) printf 'RustDesk 不提供可靠的密码读取接口，只有实际连接认证才能确认。\n';;
  7.7.4) printf '密码从不写入 HDM 日志。命令行设置可能被同机管理员短暂看到；请使用独立强密码。\n';;
  7.8.5) hdm_rustdesk_registration_status;;
  7.7.1|7.7.2) hdm_rustdesk_password;;
  7.8.1|7.8.2|7.8.4) hdm_rustdesk_get_id;;
  7.8.3) hdm_rustdesk_set_id;;
  7.9.1) hdm_rustdesk_check_dns;;
  7.9.2) hdm_rustdesk_check_connection id;;
  7.9.3) hdm_warn 'UDP 可达性不能通过 TCP 探测确定；需服务端日志和真实 RustDesk 连接测试。';;
  7.9.4) hdm_rustdesk_check_connection relay;;
  7.9.7) hdm_rustdesk_check_full;;
  7.10.1) hdm_rustdesk_server_import_file;;
  7.10.3) hdm_rustdesk_check_import_file;;
  7.10.2) hdm_warn '为了避免泄露密钥，V0.1 不自动导出原始 RustDesk 配置；可在官方 UI 导出服务器配置。';;
  7.11.1) hdm_snapshots;;
  7.11.2) hdm_snapshot_create /root/.config/rustdesk/RustDesk2.toml;;
  7.11.3) hdm_snapshot_choose;;
  # 8. HDM manager update
  8.1.1) hdm_update_check;;
  8.2.1|8.7.1) sed -n '1,90p' "$HDM_ROOT/CHANGELOG.md";;
  8.2.2|8.2.3) hdm_update_install latest;;
  8.2.4) hdm_update_rollback;;
  8.2.5) hdm_update_preview_install;;
  8.3.1) hdm_update_list;;
  8.5.1) find /opt/hdm/releases -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null || :;;
  8.5.2) hdm_update_rollback;;
  8.6.1|8.6.7|8.9.1|8.9.2) hdm_update_integrity;;
  8.6.2|8.6.3|8.6.4|8.6.5|8.6.6) hdm_warn '模块必须与主程序同版本；无法单独替换。请使用 8.2 原子更新完整 HDM。';;
  8.8.1) printf '稳定版（Release）：菜单 8 → 2 → 2；开发版（main）：菜单 8 → 2 → 5。\n本菜单仅查看更新路径，实际安装前需预览和确认。\n';;
  8.8.2) hdm_warn '当前手动检查更新；未启用后台定时升级。';;
  8.8.3) du -sh "$HDM_CACHE/downloads" 2>/dev/null || :; find /opt/hdm/releases -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null || :;;
  8.10.1) hdm_danger '恢复 HDM 的下载策略和分辨率默认值，不修改系统桌面？' && { hdm_setting HDM_DEFAULT_RESOLUTION 1920x1080; hdm_setting HDM_SOURCE_POLICY official-mirror-github; };;
  # 9. One click install
  9.1.1|9.1.2|9.1.5|9.4.1|9.4.2|9.5.1|9.5.2) hdm_env_report; hdm_quick_plan;;
  9.1.7|9.6.1|9.7.1) hdm_quick_status;;
  9.1.3|9.3.4) hdm_display_select_res;;
  9.1.4|9.3.6) hdm_warn '可在完整安装后通过菜单 7 配置自建 ID/Relay；避免在 RustDesk 未安装时导入。';;
  9.1.6|9.2.1|9.4.3|9.7.2) hdm_quick_install;;
  9.2.2|9.2.3|9.2.4|9.2.5|9.2.6|9.2.7) hdm_action_other_desktop_plan "$id";;
  9.3.1) hdm_display_status;;
  9.3.2) hdm_desktop_compare; hdm_resource_recommendation;;
  9.3.3) hdm_rustdesk_status;;
  9.3.5) hdm_sources_policy;;
  9.3.7) hdm_quick_plan;;
  9.3.8) hdm_warn '自定义组合尚未保存为可自动执行的计划。菜单 9.1.6 可执行本机推荐组合；如选择其他方案，请分别使用菜单 1、3、5 安装。';;
   # 10. Diagnostics and mirrors
  10.1.1|10.1.2|10.1.4) hdm_diag_full;;
  10.2.1|10.2.2|10.2.3|10.2.4|10.2.6) hdm_diag_display;;
  10.3.1) hdm_session_dependencies;;
  10.3.2) hdm_session_report;;
  10.3.3) hdm_session_service_report;;
  10.3.4) hdm_session_user_report;;
  10.3.5) hdm_session_logs;;
  10.3.6) hdm_session_protocol_report;;
  10.4.1|10.4.2|10.4.6) hdm_diag_rustdesk;;
  10.1.3|10.10.1|10.10.7) hdm_diag_doctor;;
  10.1.5) hdm_diag_export_full;;
  10.1.6) hdm_readiness_report;;
  10.8.7) hdm_diag_export_full;;
  10.2.5|10.8.2) hdm_diag_log display;;
  10.3.7|10.8.3) hdm_diag_log desktop;;
  10.4.7|10.8.4) hdm_diag_log rustdesk;;
  10.7.8) hdm_diag_log system;;
  10.2.7|10.10.2) hdm_display_status; hdm_warn '建议按菜单 1.1.1 定向重装，或 10.9 恢复 HDM 配置。';;
  10.2.8|10.3.10|10.6.9|10.9.3|10.9.4|10.9.5|10.9.6|10.9.7|10.10.6) hdm_snapshot_choose;;
  10.3.8|10.10.3) hdm_gdm_x11;;
  10.3.9|10.10.5) hdm_desktop_repair;;
  10.4.3|10.4.5|10.4.4) hdm_rustdesk_server_status;;
  10.4.8|10.10.4) hdm_diag_service_restart rustdesk;;
  10.4.9) hdm_action_rustdesk_reinstall;;
  10.4.10) hdm_rustdesk_rollback;;
  10.5.1|10.5.3|10.5.7|10.5.8) hdm_diag_network;;
  10.5.2|10.6.1|10.6.2|10.6.6) hdm_sources_status;;
  10.5.4) hdm_rustdesk_check_connection id;;
  10.5.5) hdm_rustdesk_check_connection relay;;
  10.5.6) hdm_rustdesk_server_status;;
  10.6.3.A) hdm_setting HDM_SOURCE_POLICY system-only;;
  10.6.3.B|10.6.3.C) hdm_setting HDM_SOURCE_POLICY official-mirror; hdm_warn '备用官方源仅在网络故障时尝试，本版本不永久覆盖系统 sources.list。';;
  10.6.3.D) hdm_list_mirror; hdm_warn '必须存在真实资产与可信 SHA256 才可下载安装。';;
  10.6.3.E) hdm_setting HDM_SOURCE_POLICY official-mirror-github;;
  10.6.4.A|10.6.4.B|10.6.4.C|10.6.4.G) hdm_list_mirror; hdm_warn 'Manifest 为空表示尚未同步任何真实备用包。';;
  10.6.4.F) hdm_list_mirror; hdm_warn '此处只显示缓存信息；需要清理请进入 10.6.7 并确认。';;
  10.6.4.D|10.6.4.E) hdm_mirror_rustdesk;;
  10.6.5.A) hdm_setting HDM_SOURCE_POLICY system-only;;
  10.6.5.B) hdm_setting HDM_SOURCE_POLICY official-mirror;;
  10.6.5.C) hdm_setting HDM_SOURCE_POLICY official-mirror-github;;
  10.6.5.D) hdm_setting HDM_SOURCE_POLICY ask;;
  10.6.5.E) hdm_warn '下载超时/重试次数由 core/downloader.sh 定义，当前不允许远程输入不受限的值。';;
  10.6.5.F) hdm_setting HDM_SOURCE_POLICY official-mirror-github;;
  10.6.7) hdm_danger '清理 HDM 缓存文件（会失去离线回滚包）？' && find "$HDM_CACHE/downloads" -maxdepth 1 -type f -delete;;
  10.6.8) hdm_diag_log hdm;;
  10.7.1|10.7.2|10.7.3|10.7.4|10.7.7) hdm_diag_services;;
  10.7.5) hdm_action_service_wizard restart;;
  10.7.6) hdm_action_service_wizard enable;;
  10.8.1) hdm_diag_log hdm;;
  10.8.5) hdm_diag_log sources;;
  10.8.6) hdm_diag_log update;;
  10.8.9) hdm_diag_operation_list;;
  10.8.8) hdm_diag_prune_logs;;
  10.9.1) hdm_snapshot_create /etc/X11/xorg.conf.d/20-hdm-dummy.conf /etc/gdm3/custom.conf /etc/hdm/config.conf;;
  10.9.2) hdm_snapshots;;
  10.9.8) hdm_action_remove_backup;;
  10.11.1|10.11.2|10.11.3|10.11.4) hdm_diag_system;;
  *) hdm_action_not_ready "$id";;
  esac
}
