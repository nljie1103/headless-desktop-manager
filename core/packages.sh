#!/usr/bin/env bash
# All distro packages use the system package manager; never disable package signatures.
HDM_APT_OPTIONS=()
hdm_apt_source_test() {
  # Ubuntu 24.04 archive mirror via a TEMPORARY deb822 source; does not modify user's global sources.
  hdm_guard_platform || return 1
  local tmp mirror security arch
  arch=$(dpkg --print-architecture)
  case "$arch" in amd64) mirror='https://archive.ubuntu.com/ubuntu'; security='https://security.ubuntu.com/ubuntu';; arm64) mirror='https://ports.ubuntu.com/ubuntu-ports'; security=$mirror;; *) return 1;; esac
  tmp=$(mktemp "$HDM_STATE/ubuntu-backup.XXXXXX.sources") || return 1
  cat > "$tmp" <<CONF
Types: deb
URIs: $mirror
Suites: noble noble-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $security
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
CONF
  printf '%s\n' "$tmp"
}
hdm_apt_transient_error() {
  local file=$1
  # Refuse fallback for broken deps, signature failures or disk errors.
  if grep -Eqi 'NO_PUBKEY|BADSIG|EXPKEYSIG|not signed|signature|Hash Sum mismatch|Unable to correct problems|held broken packages|No space left|dpkg: error' "$file"; then return 1; fi
  grep -Eqi 'Temporary failure resolving|Could not resolve|Connection timed out|Connection failed|Failed to fetch|Network is unreachable|Connection refused|TLS connection' "$file"
}
hdm_apt_call() {
  hdm_root || return 1; hdm_guard_platform || return 1
  local log choice src
  log=$(mktemp "$HDM_CACHE/downloads/.apt-log.XXXXXX") || return 1
  local -a cmd=(apt-get "$@")
  if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then printf '[DRY RUN]'; printf ' %q' "${cmd[@]}"; printf '\n'; rm -f "$log"; return 0; fi
  if DEBIAN_FRONTEND=noninteractive "${cmd[@]}" 2>&1 | tee "$log"; then rm -f "$log"; return 0; fi
  if [[ $HDM_SOURCE_POLICY == system-only ]] || ! hdm_apt_transient_error "$log"; then
    hdm_warn "APT 操作失败，未绕过校验；详细日志：$log"; return 1
  fi
  if [[ $HDM_SOURCE_POLICY == ask ]]; then hdm_confirm '尝试官方 Ubuntu 备用镜像（仅此操作临时切换）？' || return 1; fi
  hdm_warn '检测到软件源网络故障，尝试系统官方临时镜像（不覆盖源文件）。'
  src=$(hdm_apt_source_test) || return 1
  local -a apt_opts=(-o "Dir::Etc::sourcelist=$src" -o 'Dir::Etc::sourceparts=-')
  # Cache update required when switching source. Never pass --allow-unauthenticated.
  if ! DEBIAN_FRONTEND=noninteractive apt-get "${apt_opts[@]}" update; then rm -f "$src"; return 1; fi
  if DEBIAN_FRONTEND=noninteractive apt-get "${apt_opts[@]}" "$@"; then rm -f "$src" "$log"; return 0; fi
  rm -f "$src"
  hdm_warn "备用镜像仍不可用；完整 GNOME 的依赖不以散装 GitHub 包代替。"
  return 1
}
hdm_pkg_install() {
  hdm_root || return 1; hdm_guard_platform || return 1
  local -a list=("$@")
  [[ ${#list[@]} -gt 0 ]] || return 1
  for pkg in "${list[@]}"; do [[ $pkg =~ ^[a-z0-9][a-z0-9.+-]*$ ]] || return 1; done
  hdm_info "将安装系统软件包：${list[*]}"
  if [[ ${HDM_QUICK_APPROVED:-0} != 1 ]]; then
    hdm_confirm '继续安装（可能使用大量磁盘空间）？' || { hdm_warn '用户取消安装。'; return 2; }
  fi
  hdm_apt_call update && hdm_apt_call install -y -o Dpkg::Options::=--force-confold "${list[@]}"
}
hdm_pkg_upgrade() {
  local -a list=("$@")
  [[ ${#list[@]} -gt 0 ]] || return 1
  for pkg in "${list[@]}"; do [[ $pkg =~ ^[a-z0-9][a-z0-9.+-]*$ ]] || return 1; done
  hdm_confirm "仅升级指定软件包：${list[*]}？" || return 0
  hdm_apt_call update && hdm_apt_call install -y --only-upgrade "${list[@]}"
}
hdm_pkg_remove() {
  local -a list=("$@")
  [[ ${#list[@]} -gt 0 ]] || return 1
  for pkg in "${list[@]}"; do [[ $pkg =~ ^[a-z0-9][a-z0-9.+-]*$ ]] || return 1; done
  hdm_danger "移除软件包 ${list[*]}，可能破坏远程桌面；不会自动 autoremove" || return 0
  hdm_apt_call remove -y "${list[@]}"
}
hdm_pkg_versions() { local pkg=$1; apt-cache policy "$pkg" 2>/dev/null || true; }
hdm_sources_status() {
  hdm_show '系统软件源（只读）'
  if hdm_has apt-cache; then apt-cache policy | head -45; else printf '当前非 APT 系统，仅开放读取。\n'; fi
  printf '\nHDM 故障切换策略：%s\n' "$HDM_SOURCE_POLICY"
}
hdm_sources_policy() {
  printf '%s\n' '1. 仅系统默认源' '2. 系统源 → 官方备用镜像' '3. 系统源 → 官方镜像 → GitHub 已校验备份(适用时)' '4. 切换前询问'
  local n; hdm_prompt '选择 [1-4]：' n || return 1
  case "$n" in 1) hdm_setting HDM_SOURCE_POLICY system-only;; 2) hdm_setting HDM_SOURCE_POLICY official-mirror;; 3) hdm_setting HDM_SOURCE_POLICY official-mirror-github;; 4) hdm_setting HDM_SOURCE_POLICY ask;; *) hdm_warn '无效选项';; esac
}
