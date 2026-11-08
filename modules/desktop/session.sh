#!/usr/bin/env bash
# GNOME session checks deliberately separate packages, GDM greeter, DRM output,
# loginctl graphical *user* session and RustDesk screen capture.
hdm_session_report() {
  local desktop drm session target gdm rustdesk
  desktop=$(hdm_env_desktop_kind)
  drm=$(hdm_env_drm_state)
  session=$(hdm_env_active_session)
  gdm=$(hdm_service_state gdm3)
  rustdesk=$(hdm_service_state rustdesk)
  target=$(systemctl get-default 2>/dev/null || printf unknown)
  hdm_show '图形会话检查'
  printf '桌面软件       %s\n' "$desktop"
  printf '默认启动目标   %s\n' "$target"
  printf 'GDM3 登录服务  %s\n' "$gdm"
  printf 'DRM 连接状态   %s（不代表有可用画面）\n' "$(hdm_env_drm_short "$drm")"
  case "$session" in
    x11|wayland) printf '活动用户会话   %s（尚未验证远程画面）\n' "$session";;
    none) printf '活动用户会话   无\n';;
    *) printf '活动用户会话   无法确认（loginctl 数据不足）\n';;
  esac
  printf 'RustDesk 服务  %s（不代表可捕获画面）\n' "$rustdesk"
  if ! hdm_installed gdm3; then
    printf '\n[缺失] 未安装 GDM3；当前桌面环境为 %s，不能按已安装 GNOME 进行会话修复。\n' "$desktop"
    printf '下一步：如需 GNOME，先通过菜单 3 安装 GNOME/GDM3，再检查图形会话。\n'
  elif [[ "$gdm" != active ]]; then
    printf '\n[阻断] GDM3 已安装但未运行；软件包存在不等于图形登录服务已启动。\n'
    printf '下一步：菜单 4 → 管理图形会话 → 启动/检查 GDM3；或 sudo hdm --session-start\n'
  elif [[ "$session" != x11 && "$session" != wayland ]]; then
    printf '\n[未就绪] GDM3 已运行，但尚无活跃图形用户会话。登录界面不等于桌面。\n'
  else
    printf '\n[待验证] 已检测到图形用户会话；仍需从另一设备确认图像与输入。\n'
  fi
  if hdm_gnome_wayland_only && [[ "$drm" == not-connected ]]; then
    printf '[提示] Wayland 需要真实可用的 DRM/KMS 输出；Xorg Dummy 无法直接替代。\n'
  fi
}
hdm_session_protocol_report() {
  hdm_show '会话协议与 GDM 设置'
  if hdm_gnome_wayland_only; then
    printf '当前 GNOME 只提供 Wayland 会话。\n'
    printf 'WaylandEnable=false 不会创造显示输出，反而可能导致登录失败。\n'
  else
    if hdm_gdm_x11_enabled /etc/gdm3/custom.conf; then printf '已配置 GDM3 X11 模式。\n'; else printf '未强制 GDM3 X11。\n'; fi
  fi
  printf '活动图形用户会话：%s\n' "$(hdm_env_active_session)"
}
hdm_session_user_report() {
  local sid typ cls state remote desk count=0
  hdm_show 'D-Bus / 用户图形会话'
  if ! command -v loginctl >/dev/null 2>&1; then printf 'loginctl 不可用\n'; return 1; fi
  while IFS= read -r sid; do
    [[ $sid =~ ^[A-Za-z0-9_-]{1,48}$ ]] || continue
    typ=$(loginctl show-session "$sid" -p Type --value 2>/dev/null || :)
    [[ $typ == x11 || $typ == wayland ]] || continue
    cls=$(loginctl show-session "$sid" -p Class --value 2>/dev/null || :)
    state=$(loginctl show-session "$sid" -p State --value 2>/dev/null || :)
    remote=$(loginctl show-session "$sid" -p Remote --value 2>/dev/null || :)
    desk=$(loginctl show-session "$sid" -p Desktop --value 2>/dev/null || :)
    printf '会话 %s: %s / %s / %s / %s (Remote=%s)\n' "$sid" "$typ" "$desk" "$cls" "$state" "$remote"
    ((count+=1))
  done < <(loginctl list-sessions --no-legend --no-pager 2>/dev/null | awk 'NR<=128{print $1}')
  (( count > 0 )) || printf '没有可识别的 X11/Wayland 会话；SSH 会话已过滤。\n'
  printf '用户总线与桌面 Portal 仅在对应用户会话建立后才可验证。\n'
}
hdm_session_service_report() {
  hdm_show '图形登录服务状态'
  for svc in gdm3 display-manager rustdesk; do
    printf '%-17s %s\n' "$svc" "$(hdm_service_state "$svc")"
  done
  printf '启动目标：%s\n' "$(systemctl get-default 2>/dev/null || printf unknown)"
  systemctl is-enabled gdm3 2>/dev/null || :
  printf '备注：enabled 和 active 均不能证明已有 GNOME 用户会话。\n'
}
hdm_session_dependencies() {
  hdm_show 'GNOME 图形依赖'
  for pkg in gdm3 gnome-shell gnome-session-bin pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-gnome; do
    if hdm_installed "$pkg"; then printf '[已安装] %s\n' "$pkg"; else printf '[缺失] %s\n' "$pkg"; fi
  done
  if [[ -e /dev/dri/card0 ]]; then printf 'DRM 设备：/dev/dri/card0 存在\n'; else printf 'DRM 设备：未发现 card0（并非所有系统都以 card0 命名）\n'; fi
  if command -v modinfo >/dev/null 2>&1 && modinfo vkms >/dev/null 2>&1; then
    printf 'VKMS 内核模块：可用（并非已加载）\n'
  else
    printf 'VKMS 内核模块：不可确认/当前内核不提供\n'
  fi
}
hdm_session_logs() {
  hdm_show '近期图形服务日志'
  journalctl -u gdm3 -u display-manager -b --no-pager -n 80 2>&1 || :
}
hdm_session_start_gdm() {
  hdm_root && hdm_guard_platform || return 1
  hdm_installed gdm3 || { hdm_error '未安装 GDM3，请先安装 GNOME/GDM3'; return 1; }
  if [[ $(hdm_service_state gdm3) == active ]]; then
    printf 'GDM3 已在运行，无需重启。\n'
    hdm_session_report
    if [[ $(hdm_env_active_session) != x11 && $(hdm_env_active_session) != wayland ]]; then
      printf '[部分完成] 当前没有活动图形用户会话。\n'
      return 3
    fi
    return 0
  fi
  printf '将尝试启动 GDM3 登录管理器，不更改 Xorg/Wayland 配置、不启用自动登录、不重启服务器。\n'
  if [[ $(hdm_env_drm_state) == not-connected ]]; then
    printf '警告：当前没有检测到连接的 DRM 输出，GNOME Wayland 可能无法启动。\n'
  fi
  if [[ ${HDM_SESSION_APPROVED:-0} != 1 ]]; then
    hdm_confirm '启动 GDM3？' || return 2
  fi
  local rc=0
  hdm_run_quiet '启动 GDM3 登录服务' systemctl start gdm3 || rc=$?
  if (( rc != 0 )); then
    hdm_session_logs
    return "$rc"
  fi
  sleep "${HDM_SESSION_VERIFY_DELAY:-2}"
  if [[ $(hdm_service_state gdm3) != active ]]; then
    hdm_warn '启动命令返回成功，但 GDM3 并未保持运行。'
    hdm_session_logs
    return 1
  fi
  printf 'GDM3 已启动；继续检查是否出现实际图形用户会话。\n'
  hdm_session_report
  local detected
  detected=$(hdm_env_active_session)
  if [[ $detected != x11 && $detected != wayland ]]; then
    printf '[部分完成] 登录管理器运行，但没有已登录的图形用户会话；RustDesk 仍可能拒绝连接。\n'
    return 3
  fi
}

# Optional persistent graphical boot is separate from starting the greeter once.
hdm_session_enable_graphical_boot() {
  hdm_root && hdm_guard_platform || return 1
  hdm_installed gdm3 || { hdm_error '缺少 GDM3，请先安装桌面组件'; return 1; }
  local old target
  old=$(systemctl get-default 2>/dev/null) || { hdm_error '无法读取 systemd 默认启动目标'; return 1; }
  if [[ "$old" == graphical.target ]]; then
    printf '当前已使用 graphical.target，无需修改。\n'
    return 0
  fi
  printf '当前启动目标：%s；将修改为 graphical.target，以便开机尝试启动图形登录管理器。\n' "$old"
  printf '此操作不会创建图形用户会话，也不会自动登录。\n'
  hdm_confirm '更改系统默认启动目标？' || return 2
  hdm_run_quiet '设置图形开机目标' systemctl set-default graphical.target || return 1
  target=$(systemctl get-default 2>/dev/null || :)
  if [[ "$target" != graphical.target ]]; then hdm_error '设置后读回不一致'; return 1; fi
  printf '已保存 graphical.target；下次开机仍需检查 GDM3 是否启动。\n'
}

# Guided first-pass repair. Never enable autologin or force Xorg on GNOME 49+.
# A virtual DRM module is attempted only if no connected DRM output exists,
# available as an actual kernel module, and explicitly approved once.
hdm_session_repair() {
  hdm_root && hdm_guard_platform || return 1
  hdm_installed gdm3 || { hdm_error '尚未安装 GDM3，先通过菜单 3 安装 GNOME'; return 1; }
  local output loaded=0
  output=$(hdm_env_drm_state)
  printf '图形会话修复：当前 DRM %s；GDM3 %s；会话 %s\n' \
     "$output" "$(hdm_service_state gdm3)" "$(hdm_env_active_session)"
  if [[ $(hdm_service_state gdm3) == active ]]; then
    hdm_session_report
    if [[ $(hdm_env_active_session) != x11 && $(hdm_env_active_session) != wayland ]]; then return 3; fi
    return 0
  fi
  if [[ "$output" == not-connected ]]; then
    if command -v modinfo >/dev/null 2>&1 && modinfo vkms >/dev/null 2>&1; then
      printf '没有连接的 DRM 输出；发现可用的 VKMS 模块，尝试临时启用后再启动 GDM3。\n'
      hdm_confirm '尝试 VKMS 与 GDM3 修复？' || return 2
      if ! (command -v lsmod >/dev/null 2>&1 && lsmod | grep -q '^vkms '); then
        hdm_run_quiet '临时加载 VKMS' modprobe vkms || return 1
        loaded=1
      fi
      output=$(hdm_env_drm_state)
      printf '加载 VKMS 后 DRM 状态：%s（内核输出不代表 Wayland 已运行）。\n' "$output"
    else
      printf '[阻断] 未检测到 DRM 连接，且内核不提供可加载的 VKMS 模块。\n'
      printf '不能强行创建 GNOME Wayland 画面；先检查云平台 GPU/DRM 能力或更换支持的显示方案。\n'
      return 4
    fi
  else
    hdm_confirm '尝试启动 GDM3 并检查会话？' || return 2
  fi
  HDM_SESSION_APPROVED=1 hdm_session_start_gdm
}
