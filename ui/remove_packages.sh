#!/usr/bin/env bash
# Guarded real package removals; never purge config, autoremove, or reboot.
hdm_v2_default_dm() {
  local val=''
  if [[ -r /etc/X11/default-display-manager ]]; then
    IFS= read -r val < /etc/X11/default-display-manager || :
  fi
  case "$val" in */gdm3) echo gdm3;; */lightdm) echo lightdm;; *) echo unknown;; esac
}

hdm_v2_choose_dm() {
  local pkg=$1
  case "$pkg" in lightdm|gdm3) ;; *) return 2;; esac
  hdm_root && hdm_guard_platform || return 1
  if [[ $(hdm_type) != apt ]] || ! hdm_has dpkg-reconfigure; then
    hdm_warn '需要 Debian/Ubuntu 的 dpkg-reconfigure。'
    return 2
  fi
  hdm_installed "$pkg" || { hdm_warn "$pkg 未安装。"; return 2; }
  if [[ $pkg == lightdm ]] && ! hdm_installed xfce4-session && ! hdm_installed mate-session-manager; then
    hdm_warn '请先安装 XFCE 或 MATE 的 X11 会话。'
    return 2
  fi
  if [[ ${HDM_TEST_MODE:-0} != 1 && ( ! -t 0 || ! -t 1 ) ]]; then
    hdm_warn '切换登录管理器需要 SSH -t 或云控制台的交互式终端。'
    return 2
  fi
  printf '当前登录管理器：%s；目标：%s\n' "$(hdm_v2_default_dm)" "$pkg"
  printf '即将打开系统登录管理器选择界面。不会自动重启或停止当前服务。\n'
  hdm_confirm "确认运行 dpkg-reconfigure $pkg？" || return 2
  if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then echo "[DRY RUN] dpkg-reconfigure $pkg"; return 0; fi
  dpkg-reconfigure "$pkg" || return 1
  if [[ $(hdm_v2_default_dm) != "$pkg" ]]; then
    hdm_warn "系统仍未选择 $pkg，请不要卸载旧登录管理器。"
    return 2
  fi
  printf '[已选择] $pkg。需在安全维护窗口重启并确认新的登录界面和 RustDesk。\n'
}

hdm_v2_remove_packages_for() {
  local target=$1 pkg
  local -a candidates=()
  HDM_REMOVE_PACKAGES=()
  case "$target" in
    gdm3) candidates=(gdm3);;
    lightdm) candidates=(lightdm);;
    gnome) candidates=(ubuntu-desktop ubuntu-desktop-minimal gnome-shell gnome-session gnome-session-bin);;
    xfce) candidates=(xfce4 xfce4-goodies xfce4-session);;
    mate) candidates=(mate-desktop-environment mate-desktop-environment-core mate-desktop-environment-extras mate-session-manager);;
    *) hdm_warn '不支持的卸载目标。'; return 2;;
  esac
  for pkg in "${candidates[@]}"; do
    if hdm_installed "$pkg"; then HDM_REMOVE_PACKAGES+=("$pkg"); fi
  done
  if ((${#HDM_REMOVE_PACKAGES[@]} == 0)); then
    printf '[无需卸载] %s 对应软件包未安装。\n' "$target"
    return 2
  fi
}

hdm_v2_remove_precheck() {
  local target=$1 active
  if [[ $(hdm_type) != apt ]] || ! hdm_has apt-get; then
    hdm_warn '真实卸载仅支持 Debian/Ubuntu APT。'
    return 2
  fi
  active=$(hdm_env_active_desktop_kind)
  case "$target" in
    gdm3|gnome)
      if ! hdm_installed lightdm || { ! hdm_installed xfce4-session && ! hdm_installed mate-session-manager; }; then
        hdm_warn '先安装 LightDM、XFCE/MATE 与 Xorg，不能先卸载旧图形链路。'
        return 2
      fi
      if ! hdm_installed xserver-xorg-core; then
        hdm_warn 'Xorg 核心组件尚未安装，先完成 XFCE/X11 环境安装。'
        return 2
      fi
      if [[ $(hdm_v2_default_dm) != lightdm || $(hdm_service_state lightdm) != active ]]; then
        hdm_warn 'LightDM 尚未被选为默认且正在运行。请先完成切换并重启验证。'
        return 2
      fi
      if [[ $(hdm_service_state gdm3) == active ]]; then
        hdm_warn '旧 GDM3 服务仍在运行，必须先完成 LightDM 接管与重启，禁止直接删除。'
        return 2
      fi
      if [[ $active == GNOME || $active == multiple || $active == unknown ]]; then
        hdm_warn '当前仍有 GNOME/多桌面会话，或无法确认用户会话；先通过 loginctl 核实并验证 XFCE/MATE。'
        return 2
      fi
      ;;
    lightdm)
      if [[ $(hdm_v2_default_dm) != gdm3 || $(hdm_service_state gdm3) != active ]] ||
         ! hdm_installed gdm3 || ! hdm_installed gnome-shell; then
        hdm_warn '必须先安装 GNOME/GDM3 并确认 GDM3 已为默认且正在运行。'
        return 2
      fi
      ;;
    xfce|mate)
      if [[ $active == multiple || $active == unknown ||
            ( $target == xfce && $active == XFCE ) ||
            ( $target == mate && $active == MATE ) ]]; then
        hdm_warn '当前桌面仍有活跃用户会话，拒绝卸载。'
        return 2
      fi
      if [[ $target == xfce ]] && ! hdm_installed gnome-shell && ! hdm_installed mate-session-manager; then
        hdm_warn '需要先安装替代的 GNOME/MATE 桌面。'
        return 2
      fi
      if [[ $target == mate ]] && ! hdm_installed gnome-shell && ! hdm_installed xfce4-session; then
        hdm_warn '需要先安装替代的 GNOME/XFCE 桌面。'
        return 2
      fi
      ;;
    *) return 2;;
  esac
}

# Check the complete apt simulation before the destructive apt call.
hdm_v2_remove_plan() {
  local target=$1 output line name pkg found=0 blocked
  local -a removed=()
  hdm_v2_remove_packages_for "$target" || return $?
  hdm_v2_remove_precheck "$target" || return $?
  if ! output=$(LC_ALL=C apt-get -s remove "${HDM_REMOVE_PACKAGES[@]}" 2>&1); then
    printf '%s\n' "$output" | tail -n 15
    hdm_warn 'APT 模拟失败，卸载已阻止。'
    return 2
  fi
  while IFS= read -r line; do
    if [[ $line =~ ^Remv[[:space:]]+([^[:space:]]+) ]]; then
      name=${BASH_REMATCH[1]%%:*}
      removed+=("$name")
      for pkg in "${HDM_REMOVE_PACKAGES[@]}"; do [[ $name == "$pkg" ]] && found=1; done
      blocked=0
      case "$name" in
        bash|sudo|systemd|systemd-sysv|libc6|apt|dpkg|coreutils|base-files|openssh-server|network-manager|linux-image*|linux-generic|xorg|xserver-xorg*|rustdesk)
          blocked=1;;
        gdm3) [[ $target == gdm3 ]] || blocked=1;;
        lightdm) [[ $target == lightdm ]] || blocked=1;;
        xfce4|xfce4-session|xfce4-goodies) [[ $target == xfce ]] || blocked=1;;
        mate-desktop-environment|mate-session-manager) [[ $target == mate ]] || blocked=1;;
        gnome-shell) [[ $target == gnome ]] || blocked=1;;
      esac
      if ((blocked)); then
        hdm_warn "APT 模拟将删除受保护包 $name，拒绝执行。"
        return 2
      fi
    fi
  done <<< "$output"
  if ((!found || ${#removed[@]} == 0)); then
    hdm_warn '模拟没有可确认的目标删除记录，拒绝执行。'
    return 2
  fi
  printf '真实卸载目标：%s；APT remove %s\n' "$target" "${HDM_REMOVE_PACKAGES[*]}"
  printf 'APT 计划删除 %s 个软件包：\n' "${#removed[@]}"
  printf '  - %s\n' "${removed[@]}"
  printf '保留配置文件；不执行 purge / autoremove；不自动重启图形服务。\n'
}

hdm_v2_remove_real() {
  local target=$1
  hdm_root && hdm_guard_platform || return 1
  hdm_v2_remove_plan "$target" || return $?
  printf '请确保 SSH/云控制台和快照可用。APT 卸载可能中断当前图形登录。\n'
  # This prompt is never bypassed by HDM_QUICK_APPROVED.
  hdm_confirm "我已保留 SSH/控制台、测试替代桌面，确认立即真实卸载 $target？" || {
    hdm_warn '取消卸载，未执行删除。'
    return 2
  }
  hdm_v2_remove_plan "$target" || return $?
  hdm_apt_call remove -y "${HDM_REMOVE_PACKAGES[@]}" || return $?
  hdm_info "$target 已通过 APT 执行卸载；请核对服务与实际远控。"
}
