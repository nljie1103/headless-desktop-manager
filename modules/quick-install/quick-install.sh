#!/usr/bin/env bash
# Resumable, idempotent recommended GNOME + Dummy + RustDesk installer.
# The ledger is a progress hint, not proof that a GUI is externally usable.
HDM_QUICK_STEPS=(dummy-pkg gnome-pkg rustdesk-pkg dummy-config gdm-x11)
hdm_quick_init_steps() {
  if hdm_gnome_wayland_only; then
    HDM_QUICK_STEPS=(gnome-pkg wayland-deps rustdesk-pkg)
  else
    HDM_QUICK_STEPS=(dummy-pkg gnome-pkg rustdesk-pkg dummy-config gdm-x11)
  fi
}

hdm_quick_ledger() { printf '%s/quick-install-state.tsv' "$HDM_STATE"; }
hdm_quick_step_valid() {
  case "$1" in dummy-pkg|gnome-pkg|wayland-deps|rustdesk-pkg|dummy-config|gdm-x11) return 0;; *) return 1;; esac
}
hdm_quick_mark() {
  hdm_root || return 1
  local step=$1 state=$2 file tmp
  hdm_quick_step_valid "$step" || return 1
  case "$state" in pending|running|done|failed|stale) ;; *) return 1;; esac
  mkdir -p "$HDM_STATE"
  file=$(hdm_quick_ledger)
  tmp=$(mktemp "$HDM_STATE/.quick-state.XXXXXX") || return 1
  if [[ -f $file ]]; then awk -F '\t' -v step="$step" '$1!=step' "$file" > "$tmp"; fi
  printf '%s\t%s\t%s\n' "$step" "$state" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$tmp"
  chmod 600 "$tmp" && mv -f "$tmp" "$file"
}
hdm_quick_recorded() {
  local file; file=$(hdm_quick_ledger)
  [[ -f $file ]] || { printf '未开始'; return 0; }
  awk -F '\t' -v step="$1" '$1==step {state=$2} END {if (state=="") print "未开始"; else print state}' "$file"
}
# A successful ledger entry alone is never enough. Re-evaluate the current host.
hdm_quick_check() {
  case "$1" in
    dummy-pkg) hdm_installed xserver-xorg-video-dummy && hdm_installed xserver-xorg-core ;;
    gnome-pkg) hdm_installed ubuntu-desktop && hdm_installed gdm3 && hdm_installed gnome-shell ;;
    wayland-deps) hdm_installed pipewire && hdm_installed xdg-desktop-portal && hdm_installed xdg-desktop-portal-gnome ;;
    rustdesk-pkg) hdm_installed rustdesk && hdm_has rustdesk ;;
    dummy-config)
      [[ -s /etc/X11/xorg.conf.d/20-hdm-dummy.conf ]] &&
        grep -Fq 'Managed by HDM' /etc/X11/xorg.conf.d/20-hdm-dummy.conf &&
        grep -Fq 'HDM Dummy Device' /etc/X11/xorg.conf.d/20-hdm-dummy.conf &&
        grep -Fq "Modes \"${HDM_DEFAULT_RESOLUTION}_60.00\"" /etc/X11/xorg.conf.d/20-hdm-dummy.conf ;;
    gdm-x11) hdm_gdm_x11_enabled /etc/gdm3/custom.conf ;;
    *) return 1;;
  esac
}
hdm_quick_step_label() {
  case "$1" in
    dummy-pkg) printf 'Xorg Dummy 系统软件包';;
    gnome-pkg) printf '完整 GNOME + GDM3';;
    wayland-deps) printf 'Wayland/PipeWire/Portal 组件';;
    rustdesk-pkg) printf 'RustDesk 客户端';;
    dummy-config) printf 'Xorg Dummy 虚拟屏幕配置';;
    gdm-x11) printf 'GDM3 使用 X11';;
  esac
}
hdm_quick_status() {
  hdm_quick_init_steps
  hdm_show '一键安装进度（记录状态 / 实际检测）'
  local step recorded actual
  for step in "${HDM_QUICK_STEPS[@]}"; do
    recorded=$(hdm_quick_recorded "$step")
    if hdm_quick_check "$step"; then actual='已检测到'; else actual='缺失/待修复'; fi
    printf '%-26s %-12s %s\n' "$(hdm_quick_step_label "$step")" "$recorded" "$actual"
  done
  if [[ -r $HDM_STATE/pending-rollback ]]; then
    printf '[待确认] 显示配置处于安全回滚期，完成外部画面测试后 sudo hdm --confirm-display。\n'
  fi
  if hdm_gnome_wayland_only; then
    printf '[重要] GNOME Wayland-only：本方案不会强制 GDM X11，不会写入 Xorg Dummy 全局配置。\n'
    if [[ $(hdm_arch) == aarch64 ]]; then
      printf '[待验证] ARM64 RustDesk 标准版不保证无人值守登录界面捕获。\n'
    else
      printf '[待验证] Wayland 登录界面无人值守需要专门支持的 RustDesk 构建。\n'
    fi
  fi
  printf '[必须实测] 从其他电脑连接 RustDesk、GNOME 画面、鼠标键盘、重启后无人值守。\n'
}
hdm_quick_preflight() {
  hdm_quick_init_steps
  hdm_root && hdm_guard_platform || return 1
  local avail_kb mem_kb failed=0
  avail_kb=$(df -Pk / | awk 'NR==2{print $4}')
  mem_kb=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)
  [[ $avail_kb =~ ^[0-9]+$ ]] || { hdm_error '无法读取可用磁盘空间'; return 1; }
  printf '根分区剩余：%s MiB；可用内存：%s MiB\n' "$((avail_kb/1024))" "$((${mem_kb:-0}/1024))"
  # 4GiB free is a conservative minimum for Ubuntu Desktop installation and updates.
  if ((avail_kb < 4 * 1024 * 1024)); then
    if ! hdm_installed ubuntu-desktop || ! hdm_installed rustdesk || { ! hdm_gnome_wayland_only && ! hdm_installed xserver-xorg-video-dummy; }; then
      hdm_warn '根分区剩余不足 4 GiB，停止安装缺失软件包以避免填满系统盘。'; failed=1
    else
      hdm_warn '剩余空间不足 4 GiB，但核心软件包已存在；允许验证和配置，建议尽快清理磁盘。'
    fi
  fi
  if [[ $mem_kb =~ ^[0-9]+$ ]] && ((mem_kb < 2 * 1024 * 1024)); then
    hdm_warn '可用内存不足 2 GiB，GNOME 安装/运行可能需要更多内存或 swap；不自动切换 XFCE。'
  fi
  if [[ -r $HDM_STATE/pending-rollback ]]; then
    hdm_warn '存在尚未确认的显示配置回滚任务。请先验证并确认或恢复；为了避免覆盖恢复点，暂不继续。'
    failed=1
  fi
  ((failed == 0))
}
hdm_quick_plan() {
  hdm_quick_init_steps
  if hdm_gnome_wayland_only; then
    cat <<'MODERN'
实验组合：GNOME (Wayland-only) + PipeWire/Portal + RustDesk。
Ubuntu 26.xx ARM64 不再默认执行 Xorg Dummy 全局配置与 GDM3 X11 强制设置。
可在菜单1单独试验 VKMS / Xvfb / Xorg Dummy，但不保证 GNOME Wayland 捕获画面。
RustDesk 官方无人值守 Wayland 预览版目前主要针对 x86_64，ARM64 未验收。
保留 SSH/云控制台及快照；安装包成功不等于可无人值守远程登录。
MODERN
    hdm_quick_status
    return 0
  fi
  cat <<'INFO'
推荐组合：Ubuntu 24.04 x86_64 + Xorg Dummy + 完整 GNOME + GDM3/X11 + RustDesk。
优先使用系统 APT；对网络失败尝试可信 Ubuntu 官方镜像；RustDesk 优先官方 Releases。
不自动启用 GNOME 自动登录、不关闭锁屏、不停用 SSH、不重启 GDM3、不强制重启机器。
安装进度会保存在 /var/lib/hdm/quick-install-state.tsv；重新执行将复核组件并跳过已满足的步骤。
注意：软件包安装成功 != 图形桌面可被 RustDesk 远程控制；必须外部测试并冷启动验证。
INFO
  hdm_quick_status
}
hdm_quick_execute_step() {
  case "$1" in
    dummy-pkg) hdm_pkg_install xserver-xorg-video-dummy xserver-xorg-core ;;
    gnome-pkg) hdm_desktop_install_gnome full ;;
    wayland-deps) hdm_pkg_install pipewire xdg-desktop-portal xdg-desktop-portal-gnome ;;
    rustdesk-pkg) hdm_rustdesk_install_online latest ;;
    dummy-config) hdm_display_dummy_config ;;
    gdm-x11) hdm_gdm_x11 ;;
    *) return 1;;
  esac
}
hdm_quick_install() {
  hdm_quick_init_steps
  hdm_quick_preflight || return 1
  hdm_quick_plan
  if hdm_gnome_wayland_only; then
    hdm_danger '在新版本 Ubuntu / ARM64 测试 GNOME Wayland + RustDesk？不强制 GDM X11，也不保证无人值守成功；请保留 SSH/快照。' || return 2
  else
    hdm_danger '执行/续装 GNOME + Dummy + RustDesk？显示配置可能改变远程访问。请保留 SSH、云控制台与快照。' || return 2
  fi
  local lock_file="$HDM_STATE/quick-install.lock"
  mkdir -p "$HDM_STATE"
  # Child subshell releases the lock descriptor even if a stage fails; safe to resume
  # from the same long-lived terminal menu without restarting HDM.
  (
    flock -n 9 || { hdm_error '另一项 HDM 一键安装正在运行，拒绝并发修改。'; exit 1; }
    local step rc
    HDM_QUICK_APPROVED=1
  for step in "${HDM_QUICK_STEPS[@]}"; do
    if hdm_quick_check "$step"; then
      hdm_quick_mark "$step" done || return 1
      hdm_info "跳过已满足的步骤：$(hdm_quick_step_label "$step")"
      continue
    fi
    hdm_quick_mark "$step" running || return 1
    hdm_info "开始：$(hdm_quick_step_label "$step")"
    if hdm_quick_execute_step "$step"; then
      if hdm_quick_check "$step"; then
        hdm_quick_mark "$step" done || return 1
      else
        hdm_quick_mark "$step" failed || return 1
        hdm_warn "步骤返回成功但验证不通过：$step；停止，并保留已安装组件。"
        return 1
      fi
    else
      rc=$?
      hdm_quick_mark "$step" failed || :
      hdm_warn "安装中断于 $step（退出码 $rc）。稍后可从菜单 9.7.2 安全续装；不会重做已验证的组件。"
      return "$rc"
    fi
  done
  hdm_quick_status
  hdm_diag_full
  hdm_warn '安装步骤已完成，但图形捕获/远控/冷启动仍需人工验收；不得标记为生产稳定。'
  ) 9> "$lock_file"
}
