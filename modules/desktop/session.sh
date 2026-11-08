#!/usr/bin/env bash
# Graphical session tools separate packages, display managers, DRM outputs,
# actual X11/Wayland user sessions and RustDesk screen capture.
# All desktops use the same generic status: never require GDM on an XFCE host.
hdm_session_report() {
  local desktop drm session target rustdesk dm lightdm gdm3
  desktop=$(hdm_env_desktop_kind)
  drm=$(hdm_env_drm_state)
  session=$(hdm_env_active_session)
  gdm3=$(hdm_service_state gdm3)
  lightdm=$(hdm_service_state lightdm)
  rustdesk=$(hdm_service_state rustdesk)
  target=$(systemctl get-default 2>/dev/null || printf unknown)
  dm=$(hdm_v2_default_dm 2>/dev/null || printf unknown)
  hdm_show '图形会话状态（XFCE / GNOME / MATE 通用）'
  printf '已安装桌面       %s\n' "$desktop"
  printf '默认登录管理器   %s\n' "$dm"
  printf 'LightDM / GDM3   %s / %s\n' "$lightdm" "$gdm3"
  printf '默认启动目标     %s\n' "$target"
  printf 'DRM 显示输出     %s（不等于已有 X11/Wayland 会话）\n' "$(hdm_env_drm_short "$drm")"
  case "$session" in
    x11|wayland) printf '活动图形会话     %s（仍需测试实际画面）\n' "$session";;
    none) printf '活动图形会话     无（SSH 会话不计入）\n';;
    *) printf '活动图形会话     待确认（会话扫描失败或不完整）\n';;
  esac
  printf 'RustDesk 服务    %s（不证明远端可控）\n' "$rustdesk"
  if [[ $desktop == none ]]; then
    printf '[下一步] 先从菜单 2 选择 XFCE / GNOME / MATE 安装，再按需启动登录管理器。\n'
  elif [[ $lightdm != active && $gdm3 != active ]]; then
    printf '[下一步] 已有 %s，但没有登录管理器运行；从菜单 3 启动当前默认管理器。\n' "$desktop"
  elif [[ $session == none ]]; then
    printf '[下一步] 登录管理器可能正在显示登录界面；需要用户实际登录，不能从 SSH 自动视为已有桌面。\n'
  fi
}

hdm_session_protocol_report() {
  local current
  current=$(hdm_env_active_session)
  hdm_show '当前图形协议与可选会话'
  printf '当前活动图形用户会话：%s（SSH 会话不计算）\n' "$current"
  printf 'DRM/KMS 是内核显示输出，不是 X11 或 Wayland 协议。\n'
  if hdm_installed xserver-xorg-core; then
    printf 'Xorg（X11 图形服务器）：已安装；'
  else
    printf 'Xorg（X11 图形服务器）：未安装；'
  fi
  if pgrep -x Xorg >/dev/null 2>&1; then printf '有运行进程\n'; else printf '未运行（无图形会话时可能正常）\n'; fi
  printf '已安装的 X11 会话文件：\n'
  local found=0 file
  for file in /usr/share/xsessions/*.desktop; do
    [[ -f $file ]] || continue
    printf '  %s（X11）\n' "${file##*/}"
    found=1
  done
  ((found)) || printf '  无\n'
  printf '已安装的 Wayland 会话文件：\n'
  found=0
  for file in /usr/share/wayland-sessions/*.desktop; do
    [[ -f $file ]] || continue
    printf '  %s（Wayland）\n' "${file##*/}"
    found=1
  done
  ((found)) || printf '  无\n'
  printf '切换协议应选择实际存在的桌面会话，而不是卸载 DRM；Ubuntu 26 GNOME 不支持 GNOME Xorg 会话。\n'
}

# Display only graphical user logins, not the often dozens of SSH/TTY sessions.
hdm_session_candidates() {
  python3 - "$HDM_ROOT/modules/diagnostics/status_json.py" <<'PYSESSION'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("hdm_status_json", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
sessions, incomplete = module.sessions()
if incomplete:
    sys.exit(3)  # Don't take destructive actions on partial listing.
for s in sessions:
    if s.get('state') not in ('active', 'online'):
        continue
    values = [str(s.get(k, '')).replace('|', '').replace('\n','')[:80]
              for k in ('id', 'name', 'desktop', 'type', 'state')]
    print('|'.join(values))
PYSESSION
}

# The LightDM greeter and a logged-in graphical desktop are different things.
hdm_session_list_graphical() {
  local entries dm
  hdm_show '图形会话与登录界面'
  dm=$(hdm_v2_default_dm 2>/dev/null || printf unknown)
  case "$dm" in
    lightdm|gdm3) printf '默认登录管理器：%s（%s）\n' "$dm" "$(hdm_service_state "$dm")";;
    *) printf '默认登录管理器：未识别\n';;
  esac
  printf 'Xorg：'
  if pgrep -x Xorg >/dev/null 2>&1; then printf '正在运行\n'; else printf '未运行\n'; fi
  if ! entries=$(hdm_session_candidates); then
    hdm_warn '图形会话扫描不完整；不能据此断言没有图形用户。'
    return 2
  fi
  if [[ -z $entries ]]; then
    printf '已登录图形用户会话：0（SSH/TTY 和登录界面不计入）\n'
    if [[ $dm == lightdm || $dm == gdm3 ]]; then
      if [[ $(hdm_service_state "$dm") == active ]]; then
        printf '登录管理器已运行：请从登录界面输入密码，才能创建新的桌面用户会话。\n'
      else
        printf '登录管理器未运行：可以选择“创建新会话入口”来启动它。\n'
      fi
    fi
    return 0
  fi
  printf '%-12s %-16s %-16s %-9s %s\n' '会话 ID' '用户' '桌面' '协议' '状态'
  while IFS='|' read -r sid name desktop typ state; do
    printf '%-12s %-16s %-16s %-9s %s\n' "$sid" "$name" "$desktop" "$typ" "$state"
  done <<< "$entries"
}

hdm_session_show_detail() {
  local entries chosen sid name desk proto state found=0 typ cls usr
  hdm_show '查看指定图形用户会话详情'
  if ! entries=$(hdm_session_candidates); then
    hdm_warn '会话扫描不完整，暂不提供详情。'; return 2
  fi
  [[ -n $entries ]] || { printf '当前没有已登录的图形用户会话。\n'; return 0; }
  hdm_session_list_graphical || return $?
  hdm_prompt '输入会话 ID（0 取消）：' chosen || return 2
  [[ $chosen == 0 || -z $chosen ]] && return 0
  [[ $chosen =~ ^[A-Za-z0-9_-]{1,48}$ ]] || { hdm_warn '会话 ID 格式无效。'; return 2; }
  while IFS='|' read -r sid name desk proto state; do
    if [[ $sid == "$chosen" ]]; then found=1; break; fi
  done <<< "$entries"
  ((found)) || { hdm_warn '会话不在已确认的图形用户列表中。'; return 2; }
  typ=$(loginctl show-session "$chosen" -p Type --value 2>/dev/null || :)
  cls=$(loginctl show-session "$chosen" -p Class --value 2>/dev/null || :)
  usr=$(loginctl show-session "$chosen" -p Name --value 2>/dev/null || :)
  [[ ( $typ == x11 || $typ == wayland ) && $cls == user && $usr == "$name" ]] || {
    hdm_warn '会话身份或类型已经改变，停止查询。'; return 2
  }
  printf 'ID：%s；用户：%s；桌面：%s；协议：%s；状态：%s\n' "$sid" "$name" "$desk" "$proto" "$state"
  loginctl show-session "$chosen" -p Seat -p Service -p TTY -p Remote -p Display -p Leader -p State || :
  printf '结束会话只会注销桌面，不会删除账号或文件。\n'
}

hdm_session_terminate_graphical() {
  local entries sid name desk proto state chosen candidate current_type current_cls
  hdm_root && hdm_guard_platform || return 1
  if ! entries=$(hdm_session_candidates); then
    hdm_warn '无法读取完整的图形会话列表，已拒绝结束会话。'
    return 2
  fi
  if [[ -z $entries ]]; then
    printf '没有可结束的图形用户会话；不会终止 SSH 或登录管理器。\n'
    return 0
  fi
  hdm_session_list_graphical
  hdm_prompt '输入要结束的图形会话 ID（0 取消）：' chosen || return 2
  [[ $chosen == 0 || -z $chosen ]] && { printf '已取消。\n'; return 0; }
  [[ $chosen =~ ^[A-Za-z0-9_-]{1,48}$ ]] || { hdm_warn '无效会话 ID。'; return 2; }
  candidate=''
  while IFS='|' read -r sid name desk proto state; do
    if [[ $sid == "$chosen" ]]; then candidate="$sid|$name|$desk|$proto|$state"; break; fi
  done <<< "$entries"
  [[ -n $candidate ]] || { hdm_warn '会话不在已验证的图形用户列表中。'; return 2; }
  if [[ $chosen == "${XDG_SESSION_ID:-__none__}" ]]; then
    hdm_warn '拒绝结束当前执行 HDM 的会话。'
    return 2
  fi
  # Revalidate immediately before action: session IDs may disappear/recycle.
  current_type=$(loginctl show-session "$chosen" -p Type --value 2>/dev/null || :)
  current_cls=$(loginctl show-session "$chosen" -p Class --value 2>/dev/null || :)
  [[ ( $current_type == x11 || $current_type == wayland ) && $current_cls == user ]] || {
    hdm_warn '会话类型已变化或已经退出，拒绝操作。'
    return 2
  }
  printf '即将结束：%s\n' "$candidate"
  hdm_warn '结束会话会关闭该桌面上的程序，未保存的编辑可能丢失；不等于删除账户。'
  hdm_confirm '确定结束这个图形用户会话？' || { printf '已取消。\n'; return 0; }
  if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then
    printf '[DRY RUN] loginctl terminate-session %s\n' "$chosen"
    return 0
  fi
  # Re-check after interactive confirmation; logind session IDs may be reused.
  current_type=$(loginctl show-session "$chosen" -p Type --value 2>/dev/null || :)
  current_cls=$(loginctl show-session "$chosen" -p Class --value 2>/dev/null || :)
  local current_name
  current_name=$(loginctl show-session "$chosen" -p Name --value 2>/dev/null || :)
  if [[ ( $current_type != x11 && $current_type != wayland ) || $current_cls != user ||
        $current_name != "$name" ]]; then
    hdm_warn '会话身份/类型在确认期间发生变化，已取消操作。'
    return 2
  fi
  loginctl terminate-session "$chosen"
}

# Logind only creates a user desktop after authentication through the greeter.
# Starting LightDM/GDM3 does NOT bypass PAM or enable auto-login.
hdm_session_has_x11_desktop() {
  local file
  for file in /usr/share/xsessions/*.desktop; do
    [[ -f $file ]] && return 0
  done
  return 1
}
hdm_session_prepare_login() {
  local dm
  hdm_root && hdm_guard_platform || return 1
  dm=$(hdm_v2_default_dm)
  case "$dm" in
    lightdm|gdm3) ;;
    *) hdm_warn '默认登录管理器未知；请先到菜单 2 → 11 选择 LightDM 或 GDM3。'; return 2;;
  esac
  hdm_installed "$dm" || { hdm_warn "$dm 未安装，请先从菜单 2 安装。"; return 2; }
  if [[ $dm == lightdm ]]; then
    hdm_installed lightdm-gtk-greeter || {
      hdm_warn 'LightDM 缺少 GTK Greeter；请先从菜单 2 补齐。'; return 2
    }
    hdm_session_has_x11_desktop || { hdm_warn '缺少 X11 桌面会话文件，请先安装 XFCE 或 MATE。'; return 2; }
    hdm_installed xserver-xorg-core || {
      hdm_warn '没有安装 Xorg，暂时无法建立 LightDM 的 X11 登录界面。'; return 2
    }
  fi
  if [[ $(hdm_service_state "$dm") == active ]]; then
    printf '%s 登录界面服务已经运行；请输入密码登录才能创建新的桌面用户会话。\n' "$dm"
    printf '服务 active 仍不保证 RustDesk 已能捕获画面。\n'
    return 0
  fi
  printf '将启动 %s 的登录界面；需要在图形界面输入密码后才有新的用户会话。\n' "$dm"
  printf '不会开启免密码自动登录，也不会结束 SSH 会话。\n'
  # The selected create-login menu action is sufficient for a non-destructive
  # service start. Direct callers still explicitly confirm.
  if [[ ${HDM_MENU_SELECTED:-0} != 1 ]]; then
    hdm_confirm "启动 $dm 登录界面？" || return 2
  fi
  hdm_v2_dm_service start || return $?
  if [[ $(printenv HDM_DRY_RUN 2>/dev/null) == 1 ]]; then
    printf '[DRY RUN] 不创建真实的已登录图形会话。\n'
    return 0
  fi
  sleep 1
  if [[ $(hdm_service_state "$dm") != active ]]; then
    hdm_warn "$dm 启动操作后未保持运行；请查看诊断日志。"
    hdm_session_greeter_logs
    return 1
  fi
  printf '%s 登录界面服务运行中。请从控制台/RustDesk 登录后再查看会话列表。\n' "$dm"
  printf '登录管理器运行不等于已登录桌面或远程画面可用。\n'
}

hdm_session_greeter_logs() {
  local dm
  dm=$(hdm_v2_default_dm 2>/dev/null || printf unknown)
  hdm_show '登录界面启动日志（只读）'
  case "$dm" in
    lightdm|gdm3)
      printf '%s 服务：%s\n' "$dm" "$(hdm_service_state "$dm")"
      journalctl -b -u "$dm" --no-pager -n 35 2>&1 || :
      ;;
    *) printf '未识别默认登录管理器。\n';;
  esac
  printf 'Xorg 进程：'
  pgrep -a -x Xorg 2>/dev/null || printf '未运行\n'
  if [[ $dm == lightdm && -f /var/log/lightdm/lightdm.log ]]; then
    printf 'LightDM 日志尾部：\n'
    tail -n 35 /var/log/lightdm/lightdm.log 2>/dev/null || :
  fi
  printf '还需从另一设备验证登录画面与键鼠。\n'
}

# Choose one installed X11 desktop as the LightDM default. This is a genuine
# configuration operation, not a fictitious global 'DRM -> Wayland switch'.
hdm_session_select_default() {
  local chosen pkg target tmp session
  hdm_root && hdm_guard_platform || return 1
  if [[ $(hdm_v2_default_dm) != lightdm ]]; then
    hdm_warn '默认登录管理器不是 LightDM。GNOME/Wayland 请在 GDM3 登录界面选择；不能直接把 DRM 切成 Wayland。'
    return 2
  fi
  hdm_installed lightdm || { hdm_warn 'LightDM 未安装。'; return 2; }
  printf '可设置为 LightDM 默认 X11 会话：\n'
  if hdm_installed xfce4-session && [[ -f /usr/share/xsessions/xfce.desktop ]]; then
    printf '  1. XFCE（X11）\n'
  fi
  if hdm_installed mate-session-manager && [[ -f /usr/share/xsessions/mate.desktop ]]; then
    printf '  2. MATE（X11）\n'
  fi
  printf '  0. 取消\n'
  hdm_prompt '请选择：' chosen || return 2
  case "$chosen" in
    0|'') return 0;;
    1) session=xfce; pkg=xfce4-session;;
    2) session=mate; pkg=mate-session-manager;;
    *) hdm_warn '无效选项。'; return 2;;
  esac
  [[ -f /usr/share/xsessions/$session.desktop ]] && hdm_installed "$pkg" || {
    hdm_warn "未安装 $session 桌面会话，不能将它设为默认。"
    return 2
  }
  target=/etc/lightdm/lightdm.conf.d/99-zz-hdm-session.conf
  [[ ! -L $target ]] || { hdm_warn '目标配置为符号链接，拒绝覆盖。'; return 2; }
  printf '将把 LightDM 默认会话设为 %s（X11），不会自动重启/注销。\n' "$session"
  if [[ ${HDM_MENU_SELECTED:-0} != 1 ]]; then
    hdm_confirm '确认写入 HDM 管理的 LightDM 会话配置？' || return 2
  fi
  if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then
    printf '[DRY RUN] LightDM user-session=%s\n' "$session"
    return 0
  fi
  install -d -m 755 /etc/lightdm/lightdm.conf.d || return 1
  if [[ -f $target ]]; then hdm_snapshot_create "$target" || return 1; fi
  tmp=$(mktemp /etc/lightdm/lightdm.conf.d/.hdm-session.XXXXXX) || return 1
  printf '[Seat:*]\nuser-session=%s\n' "$session" > "$tmp" || { rm -f "$tmp"; return 1; }
  chmod 644 "$tmp" && mv -f -- "$tmp" "$target" || { rm -f "$tmp"; return 1; }
  printf '已保存默认 %s X11 会话。请在登录界面登录或安全维护窗口重启 LightDM 后验证。\n' "$session"
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
  done < <(loginctl list-sessions --no-legend --no-pager 2>/dev/null | awk 'NR<=256{print $1}')
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
    if [[ $(hdm_env_gnome_session) != x11 && $(hdm_env_gnome_session) != wayland ]]; then
      printf '[部分完成] 当前没有可确认的 GNOME 图形用户会话（其他桌面不算）。\n'
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
  detected=$(hdm_env_gnome_session)
  if [[ $detected != x11 && $detected != wayland ]]; then
    printf '[部分完成] 登录管理器运行，但没有已登录的 GNOME 图形用户会话；RustDesk 仍可能拒绝连接。\n'
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
  hdm_installed gdm3 || { hdm_error '尚未安装 GDM3，先通过菜单 4 安装 GNOME'; return 1; }
  local output loaded=0
  output=$(hdm_env_drm_state)
  printf '图形会话修复：当前 DRM %s；GDM3 %s；会话 %s\n' \
     "$output" "$(hdm_service_state gdm3)" "$(hdm_env_active_session)"
  if [[ $(hdm_service_state gdm3) == active ]]; then
    hdm_session_report
    if [[ $(hdm_env_gnome_session) != x11 && $(hdm_env_gnome_session) != wayland ]]; then return 3; fi
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
