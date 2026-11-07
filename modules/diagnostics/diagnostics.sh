#!/usr/bin/env bash
hdm_diag_full() {
  hdm_show '全系统诊断（只读）'
  printf '系统：%s / %s\n' "$(hdm_os)" "$(hdm_arch)"
  if hdm_supported; then printf '[通过] 当前系统满足 Ubuntu 24.04 x86_64 目标\n'; else printf '[未验证] 当前系统不在 V0.1 验证目标范围内\n'; fi
  for pkg in xserver-xorg-video-dummy gnome-shell gdm3 rustdesk; do
    if hdm_installed "$pkg"; then printf '[已安装] %s %s\n' "$pkg" "$(hdm_pkg_version "$pkg")"; else printf '[缺失] %s\n' "$pkg"; fi
  done
  if [[ -f /etc/X11/xorg.conf.d/20-hdm-dummy.conf ]]; then printf '[已配置] HDM Xorg Dummy 配置存在\n'; else printf '[未配置] HDM Dummy 模式\n'; fi
  if [[ -r /etc/gdm3/custom.conf ]] && grep -Eq '^[[:space:]]*WaylandEnable=false' /etc/gdm3/custom.conf; then printf '[已配置] GDM3 X11\n'; else printf '[未验证] GDM3 登录是否使用 X11\n'; fi
  for svc in gdm3 rustdesk; do
    case "$(hdm_service_state "$svc")" in active) printf '[服务运行] %s\n' "$svc";; *) printf '[服务异常/未启用] %s\n' "$svc";; esac
  done
  if [[ -f $HDM_STATE/pending-rollback ]]; then printf '[警告] 存在等待用户确认的自动回滚。请测试后 sudo hdm --confirm-display\n'; fi
  printf '[未验证] 真实 GNOME X11 会话/远程画面/鼠标键盘控制/重启恢复：需外部实际连接验证。\n'
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
  printf 'Dummy 未安装 → 菜单 1.1.1；GNOME 未安装 → 菜单 3.1.1；\n'
  printf 'GDM3 未配置 X11 → 菜单 3.1.5；RustDesk 服务异常 → 菜单 10.4.8；\n'
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
