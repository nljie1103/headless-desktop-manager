#!/usr/bin/env bash
hdm_diag_full() {
  hdm_show '全系统诊断（只读）'
  printf '系统：%s / %s\n' "$(hdm_os)" "$(hdm_arch)"
  if hdm_supported; then printf '[目标基线] Ubuntu 24.04 x86_64（仍需实机验证）\n'; else printf '[当前系统] 请根据实际软件源与显示协议配置组件\n'; fi
  for pkg in xserver-xorg-video-dummy xserver-xorg-core gnome-shell gdm3 xfce4-session mate-session-manager lightdm rustdesk; do
    if hdm_installed "$pkg"; then printf '[已安装] %s %s\n' "$pkg" "$(hdm_pkg_version "$pkg")"; else printf '[缺失] %s\n' "$pkg"; fi
  done
  if [[ -f /etc/X11/xorg.conf.d/20-hdm-dummy.conf ]]; then printf '[已配置] HDM Xorg Dummy 配置存在\n'; else printf '[未配置] HDM Dummy 模式\n'; fi
  if hdm_gnome_wayland_only; then
    printf '[Wayland-only] 当前 GNOME 不提供 Xorg 会话；不建议设置 GDM3 WaylandEnable=false。\n'
    for pkg in pipewire xdg-desktop-portal xdg-desktop-portal-gnome; do
      if hdm_installed "$pkg"; then printf '[已安装] %s\n' "$pkg"; else printf '[缺失] %s\n' "$pkg"; fi
    done
  elif hdm_gdm_x11_enabled /etc/gdm3/custom.conf; then printf '[已配置] GDM3 X11\n'; else printf '[待验证] GDM3 X11 设置\n'; fi
  for svc in gdm3 lightdm rustdesk; do
    case "$(hdm_service_state "$svc")" in active) printf '[服务运行] %s\n' "$svc";; *) printf '[服务异常/未启用] %s\n' "$svc";; esac
  done
  if [[ -f $HDM_STATE/pending-rollback ]]; then printf '[警告] 存在等待用户确认的自动回滚。请测试后 sudo hdm --confirm-display\n'; fi
  printf '当前活动图形协议：%s；GNOME 专用会话：%s\n' "$(hdm_env_active_session)" "$(hdm_env_gnome_session)"
  printf '[未验证] 当前桌面的远程画面、鼠标键盘、锁屏与重启恢复：需外部实际连接验证。\n'
}
hdm_diag_system() {
  hdm_show '系统环境'
  printf '内核：%s\n架构：%s\n包管理器：%s\n' "$(uname -r)" "$(uname -m)" "$(hdm_type)"
  if hdm_has free; then free -h; fi
  df -h / /opt 2>/dev/null | head -8 || :
  hdm_has lspci && lspci | grep -Ei 'VGA|Display' | head -10 || :
  hdm_has systemd-detect-virt && systemd-detect-virt || :
}
hdm_diag_log() {
  local type=${1:-hdm}
  case "$type" in
    hdm) [[ -f $HDM_LOG_FILE ]] && tail -n 100 "$HDM_LOG_FILE" || printf '尚无 HDM 日志\n';;
    display) journalctl -b --no-pager -u display-manager -u hdm-xvfb -n 65 2>/dev/null || :;;
    desktop) journalctl -b --no-pager -u gdm3 -u display-manager -n 65 2>/dev/null || :;;
    rustdesk) journalctl -b --no-pager -u rustdesk -n 65 2>/dev/null || :;;
    system) systemctl --failed --no-pager || :;;
    sources) if [[ -f $HDM_LOG_FILE ]]; then grep -Ei "APT|镜像|源|mirror|source|DNS|Failed to fetch" "$HDM_LOG_FILE" | tail -90 || :; else printf "未记录到软件源切换日志\n"; fi;;
    update) if [[ -f $HDM_LOG_FILE ]]; then grep -Ei "更新|升级|回滚|rollback|Release|update|版本" "$HDM_LOG_FILE" | tail -90 || :; else printf "未记录到更新/回滚日志\n"; fi;;
    *) hdm_warn '未知日志类别';;
  esac
}
hdm_diag_services() {
  hdm_show 'systemd 相关服务'
  systemctl status gdm3 rustdesk hdm-xvfb hdm-recovery.timer --no-pager --lines 5 2>&1 || true
}
hdm_diag_network() {
  hdm_show '网络连通性'
  getent ahostsv4 github.com | head -3 || :
  getent ahostsv4 api.github.com | head -3 || :
  hdm_info 'DNS 成功不等于下载可用；RustDesk TCP 可达也不等于 ID 注册成功。'
}
hdm_diag_repair_hint() {
  hdm_diag_full
  printf '\n建议修复路径：\n'
  if hdm_gnome_wayland_only; then
    printf 'GNOME Wayland-only：如需传统 X11，推荐菜单 3.2 的 XFCE + LightDM；GNOME 可继续使用。\n'
    printf 'VKMS 虚拟显示 → 菜单 1.3；RustDesk 服务异常 → 菜单 10.4.8；\n'
  else
    printf 'Dummy 未安装 → 菜单 1.1.1；桌面选择 → 菜单 3（GNOME/XFCE/MATE）；\n'
    printf 'GDM3 未配置 X11 → 菜单 3.1.5；RustDesk 服务异常 → 菜单 10.4.8；\n'
  fi
  printf '关键配置异常 → 菜单 10.9 恢复快照；请保留 SSH/云控制台。\n'
}
hdm_diag_export() {
  local out="${HDM_STATE}/diagnostic-$(date -u +%Y%m%dT%H%M%SZ).txt"
  hdm_root || return 1
  { printf 'HDM sanitized diagnostic\n'; hdm_diag_full; hdm_diag_system; } > "$out"
  chmod 600 "$out"
  hdm_info "已导出仅含状态信息的诊断文件：$out（无 RustDesk 配置、无密码与原始日志）"
}
hdm_diag_service_restart() {
  local svc=$1
  case "$svc" in gdm3|rustdesk|hdm-xvfb) ;; *) return 1;; esac
  hdm_root && hdm_guard_platform || return 1
  hdm_danger "重启 $svc 服务，可能断开远程图形连接？" || return 2
  systemctl restart "$svc" && hdm_info "已执行 $svc 重启，仍需验证远程连接。"
}
hdm_diag_service_enable() {
  local svc=$1
  case "$svc" in gdm3|rustdesk|hdm-xvfb) ;; *) return 1;; esac
  hdm_root && hdm_guard_platform || return 1
  hdm_danger "设置 $svc 开机自启（修改 systemd 状态）？" || return 2
  systemctl enable "$svc"
}

# Fine-grained diagnostics: a parent menu must not disguise itself as a check for all components.
hdm_diag_display() {
  hdm_show '虚拟显示与 X11 独立检测'
  hdm_display_status
  for path in /tmp/.X11-unix/X0 /tmp/.X11-unix/X1 /tmp/.X11-unix/X99; do
    [[ ! -S $path ]] || printf '[X11 Socket] %s 存在\n' "$path"
  done
  if hdm_has pgrep; then pgrep -a -x Xorg 2>/dev/null | head -10 || :; fi
  hdm_warn 'Xorg Dummy 配置存在，不等于 GDM3 正在使用它；必须检查 Xorg 日志及 GNOME 实际会话。'
}
hdm_diag_gnome() {
  hdm_show 'GNOME 与会话独立检测'
  for package in gdm3 gnome-shell gnome-session-bin ubuntu-desktop; do
    printf '%-28s %s\n' "$package" "$(hdm_pkg_version "$package")"
  done
  printf 'GDM3 服务状态：%s\n' "$(hdm_service_state gdm3)"
  if hdm_has loginctl; then
    local session type desktop state
    while read -r session _; do
      [[ $session =~ ^[A-Za-z0-9_-]+$ ]] || continue
      type=$(loginctl show-session "$session" -p Type --value 2>/dev/null || :)
      desktop=$(loginctl show-session "$session" -p Desktop --value 2>/dev/null || :)
      state=$(loginctl show-session "$session" -p State --value 2>/dev/null || :)
      printf '会话 %s：%s / %s / %s\n' "$session" "$type" "$desktop" "$state"
    done < <(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}' | head -15)
  fi
  if hdm_gnome_wayland_only; then hdm_warn 'GNOME Wayland-only：标准 RustDesk ARM64 仍需要活动会话/Portal 授权，登录界面无人值守需专门验证。'; fi
  hdm_warn 'GDM3 运行、GNOME Shell 存在或 session=active 均不能单独证明远端能够捕获桌面。'
}
hdm_diag_rustdesk() {
  hdm_show 'RustDesk 独立检测'
  printf '软件版本：%s\n服务状态：%s\n' "$(hdm_pkg_version rustdesk)" "$(hdm_service_state rustdesk)"
  if hdm_has rustdesk; then
    printf '设备 ID：'; timeout 8 rustdesk --get-id 2>/dev/null || printf '查询失败/请检查服务账户\n'
  fi
  printf '未在此输出配置文件、服务器公钥或远控密码。\n'
  if hdm_has journalctl && journalctl -u rustdesk -b --since '30 minutes ago' --no-pager -n 100 2>/dev/null | grep -Fq 'cannot open display'; then
    hdm_warn '最近 RustDesk 日志含 cannot open display：进程无法连接指定的 X11 DISPLAY。此错误与服务器配置保存独立。'
    printf '排查：sudo hdm --preflight；sudo hdm --doctor；systemctl is-active gdm3\n'
  fi
  if hdm_gnome_wayland_only; then
    printf 'GNOME Wayland-only：DISPLAY=:0 不是有效虚拟屏幕的保证。登录前无人值守在当前 ARM64 标准版未验证。\n'
  fi
  hdm_warn '外部远控认证、画面和冷启动尚未在本机诊断中验证。'
}
hdm_diag_status_json() {
  python3 "$HDM_ROOT/modules/diagnostics/status_json.py"
}

# Independent, read-only recommendation engine using sanitized local signals.
hdm_diag_doctor() { python3 "$HDM_ROOT/modules/diagnostics/doctor.py"; }
hdm_diag_doctor_json() { python3 "$HDM_ROOT/modules/diagnostics/doctor.py" --json; }

# Collect all retained HDM package operation logs plus apt/dpkg and journal
# evidence; this is not the old status-only diagnostic text.
hdm_diag_export_full() {
  hdm_root || return 1
  local bundle
  bundle=$(python3 "$HDM_ROOT/scripts/export_diagnostics.py" --output-dir "$HDM_STATE/exports" --hdm-log-dir "$HDM_LOG_DIR") || {
    hdm_error '诊断包创建失败；请检查可用磁盘空间及 /var/lib/hdm 权限'; return 1;
  }
  printf '\n[完成] 已汇总历史安装步骤、APT、GDM3、RustDesk、系统状态与启动错误：\n%s\n' "$bundle"
  printf '仅汇总系统仍保留的日志。部分内容会自动脱敏；分享给 AI 前仍请检查敏感信息。\n'
}
# Retain persistent HDM and system logs. Only old, regular operation logs
# under HDM's own log directory may be deleted after explicit confirmation.
# Never touch journalctl, apt/dpkg logs, steps.log, or hdm.log.
hdm_diag_prune_logs() {
  hdm_root || return 1
  local dir="$HDM_LOG_DIR" file
  local -a expired=()
  if [[ $dir != /var/log/hdm && !( ${HDM_TEST_MODE:-0} == 1 && $dir == /tmp/* ) ]]; then
    hdm_warn '日志清理只能在 HDM 专用日志目录执行。'
    return 2
  fi
  [[ -d $dir && ! -L $dir ]] || { printf 'HDM 日志目录不存在或无效，无需清理。\n'; return 0; }
  while IFS= read -r -d '' file; do expired+=("$file"); done < <(
    find "$dir" -maxdepth 1 -type f -name 'operation-*.log' -mmin +43200 -print0 2>/dev/null
  )
  if ((${#expired[@]} == 0)); then printf '没有超过 30 天的 HDM 操作日志需要清理。\n'; return 0; fi
  printf '准备清理 %s 个超过 30 天的 HDM 操作日志；保留主日志、步骤记录及系统 journal。\n' "${#expired[@]}"
  hdm_danger '仅删除以上 HDM 历史操作日志？' || return 2
  for file in "${expired[@]}"; do
    [[ -f $file && ! -L $file ]] || continue
    rm -f -- "$file" || return 1
  done
  hdm_info '过期 HDM 操作日志已清理；系统日志与正在使用的记录保持不变。'
}
hdm_diag_operation_list() {
  hdm_show '历史安装操作日志'
  if [[ ! -d $HDM_LOG_DIR ]]; then printf '尚无 HDM 操作日志\n'; return 0; fi
  find "$HDM_LOG_DIR" -maxdepth 1 -type f -name 'operation-*.log' -printf '%TY-%Tm-%Td %TH:%TM:%TS  %f\n' 2>/dev/null | sort -r | head -40 || :
  printf '完整日志位于：%s（root 可读）\n' "$HDM_LOG_DIR"
  printf '菜单 10 → 日志查看 → 一键导出完整诊断包，可合并后分享。\n'
}
