#!/usr/bin/env bash
# Resumable, opt-in and protocol-aware desktop + RustDesk installer.
# The ledger is a progress hint, not proof that a GUI is externally usable.
HDM_QUICK_STEPS=(dummy-pkg gnome-pkg rustdesk-pkg dummy-config gdm-x11)
hdm_physical_ram_mib() {
  local mem
  mem=$(awk '/^MemTotal:/ {print $2; exit}' "${HDM_MEMINFO_PATH:-/proc/meminfo}" 2>/dev/null)
  [[ $mem =~ ^[0-9]+$ ]] || { printf '0\n'; return; }
  printf '%s\n' "$((mem / 1024))"
}
hdm_quick_desktop_choice() {
  local desktop=$1 ram
  # Ubuntu 25.10+ removed GNOME Xorg sessions, NOT Xorg itself.
  # For the conventional RustDesk login-screen route, offer XFCE/X11 rather
  # than attempting to force GNOME Wayland into X11. Existing systems are
  # never uninstalled or switched to a different display manager silently.
  if hdm_gnome_wayland_only; then
    case "$desktop" in
      XFCE|MATE|KDE) printf '%s\n' "$desktop"; return 0;;
      none|GNOME) printf 'XFCE\n'; return 0;;
    esac
  fi
  [[ $desktop != none ]] && { printf '%s\n' "$desktop"; return 0; }
  ram=$(hdm_physical_ram_mib)
  if ((ram > 0 && ram < 4096)); then printf 'XFCE\n'
  else printf 'GNOME\n'; fi
}
hdm_resource_recommendation() {
  local total available kind
  total=$(hdm_physical_ram_mib)
  available=$(awk '/^MemAvailable:/ {print int($2/1024); exit}' "${HDM_MEMINFO_PATH:-/proc/meminfo}" 2>/dev/null)
  kind=$(hdm_quick_desktop_choice none)
  printf '内存：总量 %s MiB · 当前可用 %s MiB\n' "$total" "${available:-未知}"
  if hdm_gnome_wayland_only; then
    printf '桌面推荐：XFCE + X11 / LightDM（GNOME Wayland 可单独选装，原有桌面保留）。\n'
  else
    printf '桌面推荐：%s（小于 4 GiB 推荐 XFCE，其余按可用图形协议选择；原有桌面保留）。\n' "$kind"
  fi
  printf '显示方案按桌面协议、DRM 和内核能力选择；推荐不代表远控、锁屏或无人值守已验证。\n'
}

hdm_quick_init_steps() {
  local desktop output choice
  desktop=$(hdm_env_desktop_kind)
  output=$(hdm_env_drm_state)
  choice=$(hdm_quick_desktop_choice "$desktop")
  HDM_QUICK_STEPS=()
  if hdm_gnome_wayland_only; then
    case "$choice" in
      XFCE)
        if [[ $output == not-connected ]]; then HDM_QUICK_STEPS+=(dummy-pkg); fi
        # XFCE + LightDM remain an available X11 combination on newer Ubuntu.
        HDM_QUICK_STEPS+=(xfce-pkg rustdesk-pkg)
        if [[ $output == not-connected ]]; then HDM_QUICK_STEPS+=(dummy-config); fi
        ;;
      GNOME)
        if [[ $desktop == none ]]; then HDM_QUICK_STEPS+=(gnome-pkg); fi
        HDM_QUICK_STEPS+=(wayland-deps rustdesk-pkg)
        ;;
      *) HDM_QUICK_STEPS+=(rustdesk-pkg);;
    esac
  else
    if [[ $output == not-connected && $choice == GNOME ]]; then
      HDM_QUICK_STEPS+=(dummy-pkg)
    fi
    if [[ $desktop == none ]]; then
      [[ $choice == XFCE ]] && HDM_QUICK_STEPS+=(xfce-pkg) || HDM_QUICK_STEPS+=(gnome-pkg)
    fi
    HDM_QUICK_STEPS+=(rustdesk-pkg)
    if [[ $output == not-connected && $choice == GNOME ]]; then
      HDM_QUICK_STEPS+=(dummy-config gdm-x11)
    fi
  fi
  return 0
}

hdm_quick_ledger() { printf '%s/quick-install-state.tsv' "$HDM_STATE"; }
hdm_quick_step_valid() {
  case "$1" in dummy-pkg|gnome-pkg|xfce-pkg|wayland-deps|rustdesk-pkg|dummy-config|gdm-x11) return 0;; *) return 1;; esac
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
    xfce-pkg) hdm_installed xfce4 && hdm_installed xserver-xorg-core && hdm_installed lightdm && hdm_installed lightdm-gtk-greeter ;;
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
    xfce-pkg) printf 'XFCE + LightDM';;
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
  if hdm_gnome_wayland_only && [[ $(hdm_quick_desktop_choice "$(hdm_env_desktop_kind)") == XFCE ]]; then
    printf '[方案] XFCE / LightDM / X11：不会强制 GNOME 使用 Xorg，也不会卸载现有 GNOME。\n'
    printf '[需核实] 安装 LightDM 不等于它已成为默认登录管理器；请在菜单 4.4 检查并在控制台确认后切换。\n'
    printf '[必须实测] X11 实际显示输出、登录界面、RustDesk 画面及键鼠控制。\n'
  elif hdm_gnome_wayland_only; then
    printf '[重要] GNOME Wayland-only：本方案不会强制 GDM X11，不会写入 Xorg Dummy 全局配置。\n'
    if [[ $(hdm_arch) == aarch64 ]]; then
      printf '[待验证] ARM64 RustDesk 标准版不保证无人值守登录界面捕获。\n'
    else
      printf '[待验证] Wayland 登录界面无人值守需要专门支持的 RustDesk 构建。\n'
    fi
  fi
  printf '[必须实测] 从其他电脑检查 RustDesk 画面与键鼠；锁屏、登录界面和重启需分别验证。\n'
}
hdm_quick_preflight() {
  hdm_quick_init_steps
  hdm_root && hdm_guard_platform || return 1
  local avail_kb mem_kb failed=0
  avail_kb=$(df -Pk / | awk 'NR==2{print $4}')
  mem_kb=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)
  [[ $avail_kb =~ ^[0-9]+$ ]] || { hdm_error '无法读取可用磁盘空间'; return 1; }
  printf '根分区剩余：%s MiB；可用内存：%s MiB\n' "$((avail_kb/1024))" "$((${mem_kb:-0}/1024))"
  # Large GNOME install needs more space than a RustDesk-only update.
  local required_kb=$((1024 * 1024)) step
  for step in "${HDM_QUICK_STEPS[@]}"; do
    if [[ $step == gnome-pkg ]] && ! hdm_quick_check gnome-pkg; then
      required_kb=$((4 * 1024 * 1024))
    fi
  done
  if ((avail_kb < required_kb)); then
    for step in "${HDM_QUICK_STEPS[@]}"; do
      if ! hdm_quick_check "$step"; then
        hdm_warn "空间不足（至少建议 $((required_kb/1024)) MiB 可用），停止缺失组件的安装。"; failed=1; break
      fi
    done
  fi
  if [[ $mem_kb =~ ^[0-9]+$ ]] && ((mem_kb < 1024 * 1024)); then
    hdm_warn '可用内存较少，安装大型桌面时可能需要 swap。'
  fi
  if [[ -r $HDM_STATE/pending-rollback ]]; then
    hdm_warn '存在尚未确认的显示配置回滚任务。请先验证并确认或恢复；为了避免覆盖恢复点，暂不继续。'
    failed=1
  fi
  ((failed == 0))
}
hdm_quick_plan() {
  hdm_quick_init_steps
  hdm_env_report
  hdm_resource_recommendation
  printf '\n=== 按本机状态生成的安装步骤 ===\n'
  local step
  for step in "${HDM_QUICK_STEPS[@]}"; do
    printf '  - %s\n' "$(hdm_quick_step_label "$step")"
  done
  if hdm_gnome_wayland_only && [[ $(hdm_quick_desktop_choice "$(hdm_env_desktop_kind)") == XFCE ]]; then
    cat <<'MODERN_XFCE'
当前 GNOME 为 Wayland-only，优先选用 XFCE + LightDM / X11。原 GNOME 保留，HDM 不会自动卸载桌面或切换登录管理器。
无已连接 DRM 输出时才列出 Xorg Dummy 安装/配置步骤；配置前需明确确认风险。安装后请到菜单 4.4 检查默认登录管理器。
即使使用 X11，也要实际验证显示输出、RustDesk 远程连接以及锁屏/登录前场景。
MODERN_XFCE
  elif hdm_gnome_wayland_only; then
    cat <<'MODERN'
当前 GNOME Wayland-only：不强制 GDM X11、不创建 Xorg Dummy 全局配置。
若需传统 RustDesk 登录前连接，请考虑菜单 3 安装 XFCE + LightDM，并在菜单 4 明确选择登录管理器。
MODERN
  else
    printf '如果有现成显示输出或检测结果未知，不会强制写入 Xorg Dummy/GDM X11 配置。\n'
  fi
  printf '自动跳过已安装且已验证的组件，保留 SSH、桌面配置、锁屏及防火墙。\n'
  hdm_quick_status
}

hdm_quick_execute_step() {
  case "$1" in
    dummy-pkg) hdm_pkg_install xserver-xorg-video-dummy xserver-xorg-core ;;
    gnome-pkg) hdm_desktop_install_gnome full ;;
    xfce-pkg) hdm_desktop_install_light xfce standard ;;
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
  if [[ " ${HDM_QUICK_STEPS[*]} " == *' dummy-config '* || " ${HDM_QUICK_STEPS[*]} " == *' gdm-x11 '* ]]; then
    hdm_danger '将写入全局 Xorg/GDM 配置，可能影响远程连接。请确保 SSH、云控制台与快照可用。继续？' || return 2
  else
    hdm_confirm '仅对上述缺失步骤进行安装/修复（不更改全局 Xorg/GDM 配置），继续？' || return 2
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
