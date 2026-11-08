#!/usr/bin/env bash
# Real package removal: choose to keep or purge package configuration.
# No automatic autoremove, reboot, or removal of user home directories.
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
  # The user's menu selection is enough; the system choice dialog is the
  # only additional interaction. Do not ask "continue?" before it opens.
  if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then echo "[DRY RUN] dpkg-reconfigure $pkg"; return 0; fi
  dpkg-reconfigure "$pkg" || return 1
  if [[ $(hdm_v2_default_dm) != "$pkg" ]]; then
    hdm_warn "系统仍未选择 $pkg，请不要卸载旧登录管理器。"
    return 2
  fi
  printf '[已选择] %s。需在安全维护窗口验证新的登录界面和 RustDesk。\n' "$pkg"
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
  local target=$1
  # Both valid workflows are supported: uninstall old first, OR install new
  # first. Do not impose the latter as a technical requirement.
  case "$target" in gdm3|lightdm|gnome|xfce|mate) ;; *) return 2;; esac
  if [[ $(hdm_type) != apt ]] || ! hdm_has apt-get; then
    hdm_warn '卸载需要 Debian/Ubuntu APT。'
    return 2
  fi
}

# Check the complete apt simulation before the destructive apt call.
hdm_v2_remove_plan() {
  local target=$1 mode=${2:-remove} output line name pkg found=0 blocked
  [[ $mode == remove || $mode == purge ]] || return 2
  local -a removed=()
  hdm_v2_remove_packages_for "$target" || return $?
  hdm_v2_remove_precheck "$target" || return $?
  if ! output=$(LC_ALL=C apt-get -s "$mode" "${HDM_REMOVE_PACKAGES[@]}" 2>&1); then
    printf '%s\n' "$output" | tail -n 15
    hdm_warn 'APT 模拟失败，卸载已阻止。'
    return 2
  fi
  while IFS= read -r line; do
    if [[ $line =~ ^(Remv|Purg)[[:space:]]+([^[:space:]]+) ]]; then
      name=${BASH_REMATCH[2]%%:*}
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
  printf '目标：%s；APT %s %s\n' "$target" "$mode" "${HDM_REMOVE_PACKAGES[*]}"
  printf 'APT 计划删除 %s 个软件包：\n' "${#removed[@]}"
  printf '  - %s\n' "${removed[@]}"
  if [[ $mode == purge ]]; then
    printf '将清除所列软件包由 APT 管理的系统配置；不会清空用户主目录。\n'
  else
    printf '保留软件包的系统配置。\n'
  fi
  printf '不执行 autoremove，不自动重启。\n'
}

hdm_v2_remove_real() {
  local target=$1 choice mode
  hdm_root && hdm_guard_platform || return 1
  # Show the expected removal scope before the single user choice.
  hdm_v2_remove_plan "$target" remove || return $?
  printf '\n[注意] 卸载正在使用的登录管理器或桌面可能立即中断 RustDesk 图形连接。\n'
  printf '请在独立 SSH / 云控制台执行。\n\n'
  printf '  1. 卸载软件，保留配置（APT remove）\n'
  printf '  2. 卸载软件，同时清除配置（APT purge）\n'
  printf '  0/q. 取消返回\n'
  hdm_prompt '  请选择 > ' choice || return 0
  case "$choice" in
    1) mode=remove ;;
    2) mode=purge ;;
    0|q|Q|'') printf '已取消，没有删除任何软件包。\n'; return 0 ;;
    *) hdm_warn '无效选择，系统未更改。'; return 0 ;;
  esac
  # Always simulate the chosen APT mode immediately before acting.
  # A purge simulation may contain Purg rather than Remv records.
  if [[ $mode == purge ]]; then
    hdm_v2_remove_plan "$target" "$mode" || return $?
  else
    hdm_v2_remove_plan "$target" "$mode" >/dev/null || return $?
  fi
  hdm_apt_call "$mode" -y "${HDM_REMOVE_PACKAGES[@]}" || return $?
  hdm_info "$target 已执行 APT $mode；未自动清理依赖或用户目录。"
}
