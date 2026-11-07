#!/usr/bin/env bash
# Read-only environment detection. It NEVER equates a missing DRM connector with
# proof that no physical monitor exists, or an installed GUI with a usable session.
# Tests can inject a synthetic DRM sysfs root; production defaults to /sys/class/drm.
hdm_env_drm_state() {
  local root=${HDM_PROBE_DRM_ROOT:-/sys/class/drm} path status seen=0 uncertain=0
  [[ -d $root ]] || { printf 'unknown\n'; return 0; }
  for path in "$root"/*/status; do
    [[ -r $path ]] || continue
    seen=1
    IFS= read -r status < "$path" || :
    case "$status" in
      connected) printf 'connected\n'; return 0;;
      disconnected) ;;
      unknown) uncertain=1;;
      *) ;;
    esac
  done
  if ((seen && !uncertain)); then printf 'not-connected\n'; else printf 'unknown\n'; fi
}
hdm_env_desktop_kind() {
  # The desktop package is installed, not necessarily started.
  if hdm_installed gnome-shell; then printf 'GNOME\n'
  elif hdm_installed xfce4 || hdm_installed xfce4-session; then printf 'XFCE\n'
  elif hdm_installed mate-desktop-environment || hdm_installed mate-session-manager; then printf 'MATE\n'
  elif hdm_installed plasma-desktop; then printf 'KDE\n'
  elif hdm_has dpkg-query; then printf 'none\n'
  else printf 'unknown\n'; fi
}
hdm_env_active_session() {
  local sid typ seen=0 capped=0
  hdm_has loginctl || { printf 'unknown\n'; return 0; }
  # SSH/TTY sessions are ignored; scan at most 32 sessions, not a noisy full list.
  while IFS= read -r sid; do
    [[ $sid =~ ^[A-Za-z0-9_-]{1,48}$ ]] || continue
    ((seen >= 32)) && { capped=1; break; }
    ((seen+=1))
    typ=$(loginctl show-session "$sid" -p Type --value 2>/dev/null) || continue
    case "$typ" in wayland|x11) printf '%s\n' "$typ"; return 0;; esac
  done < <(loginctl list-sessions --no-legend --no-pager 2>/dev/null | awk 'NR<=33{print $1}')
  if ((seen && !capped)); then printf 'none\n'; else printf 'unknown\n'; fi
}
hdm_env_drm_short() {
  case "$1" in connected) printf 已连接;; not-connected) printf 未连接;; *) printf 未知;; esac
}
hdm_env_drm_label() {
  case "$1" in
    connected) printf '内核报告有连接输出（可能是虚拟设备）';;
    not-connected) printf '未检测到已连接的 DRM 输出';;
    *) printf '未知（DRM 信息不足）';;
  esac
}
hdm_env_desktop_label() {
  case "$1" in
    none) printf '未检测到已安装桌面';;
    unknown) printf '未知';;
    *) printf '%s 已安装' "$1";;
  esac
}
hdm_env_plan_hint() {
  local desktop=$1 output=$2
  if [[ $desktop != none && $desktop != unknown ]]; then
    case "$output" in
      connected) printf '保留桌面与显示设置；先确认图形会话正常，再检查 RustDesk。';;
      not-connected) printf '保留现有桌面，先核实虚拟输出兼容性，再配置远控。';;
      *) printf '保留现有桌面；显示状态未知，先只读诊断，勿强制更改 GDM/Xorg。';;
    esac
  else
    case "$output" in
      connected) printf '优先安装 GNOME，复用已有输出，不强装 Dummy。';;
      not-connected) printf '先安装 GNOME，再验证适配的虚拟输出；Wayland 不等于 Xorg Dummy。';;
      *) printf '先核实显示能力；可以安装 GNOME，但勿假定需要 Xorg Dummy。';;
    esac
  fi
}
hdm_env_summary() {
  local desktop output session
  desktop=$(hdm_env_desktop_kind)
  output=$(hdm_env_drm_state)
  session=$(hdm_env_active_session)
  printf '  桌面：%s  |  显示输出：%s  |  图形会话：%s\n' \
    "$(hdm_env_desktop_label "$desktop")" "$(hdm_env_drm_short "$output")" "$session"
  printf '  建议：%s\n' "$(hdm_env_plan_hint "$desktop" "$output")"
}
hdm_env_report() {
  local desktop output session
  desktop=$(hdm_env_desktop_kind)
  output=$(hdm_env_drm_state)
  session=$(hdm_env_active_session)
  printf '\n=== HDM 只读安装前检测 ===\n'
  printf '系统：%s / %s\n' "$(hdm_os)" "$(hdm_arch)"
  printf '桌面软件：%s\n' "$(hdm_env_desktop_label "$desktop")"
  printf '显示连接：%s\n' "$(hdm_env_drm_label "$output")"
  printf '图形登录会话：%s（SSH 会话不计入）\n' "$session"
  printf 'GDM3 服务：%s；RustDesk 服务：%s\n' "$(hdm_service_state gdm3)" "$(hdm_service_state rustdesk)"
  if [[ $desktop != none && $session != x11 && $session != wayland ]]; then
    printf '推荐操作：图形会话尚未证实运行；检查 GDM3 状态和日志，然后再连接 RustDesk。\n'
  else
    printf '推荐操作：%s\n' "$(hdm_env_plan_hint "$desktop" "$output")"
  fi
  if hdm_gnome_wayland_only; then
    printf '[兼容提示] 当前 GNOME Wayland-only，绝不自动强制 WaylandEnable=false。\n'
    printf '[远控限制] 标准 RustDesk 的 Wayland 登录前/无人值守捕获仍待验收。\n'
  else
    printf '[兼容提示] WaylandEnable=false 只针对仍可使用 Xorg 的 GDM；不是息屏/锁屏开关。\n'
  fi
  printf '[检测边界] DRM 未连接不证明没有实体显示器；软件已安装不证明画面可远控。\n'
  printf '[安全性] 本检测不会安装软件、修改显示配置或重启任何服务。\n'
}
