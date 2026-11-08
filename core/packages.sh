#!/usr/bin/env bash
# All distro packages use the system package manager; never disable package signatures.
HDM_APT_OPTIONS=()
# Choose a matching Ubuntu mirror only when the host is actually Ubuntu.
# Never substitute a different release series (e.g. noble on resolute).
# Pure deb822 renderer: unit-tested for codename/architecture pairing.
hdm_ubuntu_source_render() {
  local codename=${1:-} arch=${2:-} mirror security
  [[ $codename =~ ^[a-z]+$ ]] || return 1
  case "$arch" in
    amd64) mirror='https://archive.ubuntu.com/ubuntu'; security='https://security.ubuntu.com/ubuntu' ;;
    arm64|armhf|ppc64el|riscv64|s390x) mirror='https://ports.ubuntu.com/ubuntu-ports'; security=$mirror ;;
    *) return 1 ;;
  esac
  cat <<CONF
Types: deb
URIs: $mirror
Suites: $codename $codename-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $security
Suites: $codename-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
CONF
}
hdm_apt_source_test() {
  hdm_guard_platform || return 1
  [[ -r /etc/os-release ]] || return 1
  local ID VERSION_CODENAME UBUNTU_CODENAME arch codename mirror security tmp
  . /etc/os-release
  [[ ${ID:-} == ubuntu ]] || { hdm_warn '非 Ubuntu 系统不自动添加 Ubuntu 软件源。'; return 1; }
  codename=${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}
  [[ $codename =~ ^[a-z]+$ ]] || { hdm_warn '无法确认发行版代号，不生成备用源。'; return 1; }
  hdm_has dpkg || return 1
  arch=$(dpkg --print-architecture)
  mkdir -p "$HDM_STATE"
  tmp=$(mktemp "$HDM_STATE/ubuntu-backup.XXXXXX.sources") || return 1
  if ! hdm_ubuntu_source_render "$codename" "$arch" > "$tmp"; then
    rm -f -- "$tmp"
    return 1
  fi
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
  hdm_has apt-get || { hdm_error '当前系统没有 apt-get'; return 1; }
  local src rc=0 label="APT ${1:-操作}" log
  local -a cmd=(apt-get "$@")
  if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then printf '[DRY RUN]'; printf ' %q' "${cmd[@]}"; printf '\n'; return 0; fi
  hdm_operation_begin "$label" || return 1
  log=$HDM_LAST_OPERATION_LOG
  hdm_operation_exec "$log" env DEBIAN_FRONTEND=noninteractive "${cmd[@]}" || rc=$?
  if ((rc==0)); then hdm_operation_ok "$label"; return 0; fi
  # Only transient download/connection failures are eligible for alternative sources.
  if [[ $HDM_SOURCE_POLICY == system-only ]] || ! hdm_apt_transient_error "$log"; then
    hdm_operation_failed "$label" "$rc"; return "$rc"
  fi
  if [[ $HDM_SOURCE_POLICY == ask ]]; then
    hdm_confirm '检测到网络故障。临时使用 Ubuntu 官方备用镜像？' || { hdm_operation_failed "$label" "$rc"; return "$rc"; }
  fi
  src=$(hdm_apt_source_test) || { hdm_operation_failed "$label" "$rc"; return "$rc"; }
  local -a apt_opts=(-o "Dir::Etc::sourcelist=$src" -o 'Dir::Etc::sourceparts=-')
  printf '  原软件源连接失败，尝试 Ubuntu 官方备用镜像 ...\n'
  if hdm_operation_exec "$log" env DEBIAN_FRONTEND=noninteractive apt-get "${apt_opts[@]}" update; then
    rc=0
    hdm_operation_exec "$log" env DEBIAN_FRONTEND=noninteractive apt-get "${apt_opts[@]}" "$@" || rc=$?
  else rc=$?; fi
  rm -f -- "$src"
  if ((rc==0)); then hdm_operation_ok "$label（备用源）"; return 0; fi
  hdm_operation_failed "$label（含备用源）" "$rc"; return "$rc"
}
hdm_pkg_install() {
  hdm_root || return 1; hdm_guard_platform || return 1
  local -a list=("$@")
  [[ ${#list[@]} -gt 0 ]] || return 1
  for pkg in "${list[@]}"; do [[ $pkg =~ ^[a-z0-9][a-z0-9.+-]*$ ]] || return 1; done
  hdm_info "将安装系统软件包：${list[*]}"
  if [[ ${HDM_QUICK_APPROVED:-0} != 1 && ${HDM_MENU_SELECTED:-0} != 1 ]]; then
    hdm_confirm '继续安装（可能使用大量磁盘空间）？' || { hdm_warn '用户取消安装。'; return 2; }
  fi
  case "$(hdm_type)" in
    apt) hdm_apt_call update && hdm_apt_call install -y -o Dpkg::Options::=--force-confold "${list[@]}" ;;
    dnf|yum)
      local pm; pm=$(hdm_type)
      hdm_warn "$pm 包名可能与 Ubuntu 不同；通过系统仓库解析，不使用 Ubuntu 安装包。"
      if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then printf '[DRY RUN] %s install -y %s\n' "$pm" "${list[*]}"; else hdm_run_quiet "$pm 安装" "$pm" install -y "${list[@]}"; fi ;;
    *) hdm_error '未识别 APT/DNF/YUM，无法自动安装系统软件包。' ;;
  esac
}
hdm_pkg_upgrade() {
  local -a list=("$@")
  [[ ${#list[@]} -gt 0 ]] || return 1
  for pkg in "${list[@]}"; do [[ $pkg =~ ^[a-z0-9][a-z0-9.+-]*$ ]] || return 1; done
  # Explicit update menu selection is already authorization. Retain the
  # prompt for callers outside the interactive HDM menu.
  if [[ ${HDM_MENU_SELECTED:-0} != 1 ]]; then
    hdm_confirm "仅升级指定软件包：${list[*]}？" || return 0
  fi
  case "$(hdm_type)" in
    apt) hdm_apt_call update && hdm_apt_call install -y --only-upgrade "${list[@]}" ;;
    dnf|yum) local pm; pm=$(hdm_type); hdm_run_quiet "$pm 更新" "$pm" upgrade -y "${list[@]}" ;;
    *) hdm_error '没有可用的系统包管理器' ;;
  esac
}
hdm_pkg_remove() {
  local -a list=("$@")
  [[ ${#list[@]} -gt 0 ]] || return 1
  for pkg in "${list[@]}"; do [[ $pkg =~ ^[a-z0-9][a-z0-9.+-]*$ ]] || return 1; done
  hdm_danger "移除软件包 ${list[*]}，可能破坏远程桌面；不会自动 autoremove" || return 0
  case "$(hdm_type)" in
    apt) hdm_apt_call remove -y "${list[@]}" ;;
    dnf|yum) local pm; pm=$(hdm_type); hdm_run_quiet "$pm 卸载" "$pm" remove -y "${list[@]}" ;;
    *) hdm_error '没有可用的系统包管理器' ;;
  esac
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
