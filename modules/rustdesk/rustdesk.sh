#!/usr/bin/env bash
hdm_rustdesk_status() {
  hdm_show 'RustDesk 客户端'
  printf '安装版本：%s\n' "$(hdm_pkg_version rustdesk)"
  printf '系统服务：%s\n' "$(hdm_service_state rustdesk)"
  printf '设备 ID：'; if hdm_has rustdesk; then timeout 8 rustdesk --get-id 2>/dev/null || printf '无法获取 / 需进一步检查\n'; else printf '未安装\n'; fi
  printf '系统使用的配置位置需按服务实际运行账户核实。\n'
}
hdm_rustdesk_install_deb() {
  local deb=$1 arch package
  hdm_root && hdm_guard_platform || return 1
  [[ -f $deb && $deb == *.deb ]] || return 1
  arch=$(dpkg-deb -f "$deb" Architecture 2>/dev/null || :)
  package=$(dpkg-deb -f "$deb" Package 2>/dev/null || :)
  local expected_arch
  expected_arch=$(dpkg --print-architecture 2>/dev/null || :)
  [[ -n $expected_arch && $arch == "$expected_arch" && $package == rustdesk ]] || { hdm_error "RustDesk 包名或架构不匹配：$package / $arch；当前需要 $expected_arch"; return 1; }
  if [[ ${HDM_QUICK_APPROVED:-0} != 1 ]]; then
    hdm_danger "将通过 APT 安装 $(basename -- "$deb")，可能重启 RustDesk 并断开远程会话" || return 2
  fi
  hdm_apt_call install -y "$deb" || return 1
  systemctl enable --now rustdesk 2>/dev/null || hdm_warn 'RustDesk systemd 服务未成功启动，请查看诊断菜单。'
  hdm_state_set rustdesk-last-installed "$(dpkg-query -W -f='${Version}' rustdesk 2>/dev/null || echo unknown)" || :
  hdm_rustdesk_status
}
hdm_rustdesk_install_online() {
  local mode=${1:-latest} ver=${2:-} selected tag asset digest url file
  hdm_root && hdm_guard_platform || return 1
  if [[ $mode == latest ]]; then
    hdm_info '先检查系统已配置的可信软件源是否提供 RustDesk。若无可用包，将从官方 Releases 下载。'
    if apt-cache show rustdesk >/dev/null 2>&1; then
      if [[ ${HDM_QUICK_APPROVED:-0} == 1 ]] || hdm_confirm 'APT 已提供 RustDesk 包。优先直接使用当前系统软件源安装？'; then
        hdm_pkg_install rustdesk || return 1
        systemctl enable --now rustdesk 2>/dev/null || hdm_warn 'RustDesk 服务未启动，请通过诊断菜单检查。'
        return 0
      fi
    fi
  fi
  selected=$(hdm_release_query rustdesk "$mode" "$ver") || {
    hdm_warn '官方 RustDesk Release 元数据无法获取或缺少已知 SHA256。'
    if [[ $HDM_SOURCE_POLICY == official-mirror-github ]]; then hdm_mirror_rustdesk; return $?; fi
    return 1
  }
  IFS=$'\t' read -r tag asset digest url <<< "${selected%%$'\n'*}"
  [[ -n $tag && -n $asset && -n $digest && -n $url ]] || return 1
  file="$HDM_CACHE/downloads/$asset"
  if [[ -f $file ]] && printf '%s  %s\n' "$digest" "$file" | sha256sum --status -c -; then hdm_info '复用经 SHA256 验证的本地缓存。'; else hdm_download_verified "$url" "$file" "$digest" || { [[ $HDM_SOURCE_POLICY == official-mirror-github ]] && hdm_mirror_rustdesk; return 1; }; fi
  hdm_rustdesk_cache_record "$tag" "$asset" "$digest" "$url" || hdm_warn "已验证安装包但未能记录缓存索引。"
  hdm_rustdesk_install_deb "$file"
}
# Record only upstream assets whose expected SHA-256 was obtained from Release metadata
# and whose local bytes have passed the digest check. This is a local cache index,
# NOT an independent upstream signature or a guarantee of compatibility.
hdm_rustdesk_cache_record() {
  local tag=$1 asset=$2 digest=$3 url=$4 manifest="$HDM_STATE/rustdesk-cache.tsv" temp
  [[ $tag =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  [[ $asset =~ ^rustdesk-[0-9]+\.[0-9]+\.[0-9]+-(x86_64|aarch64)\.deb$ && $asset == *-"$(hdm_arch)".deb ]] || return 1
  [[ $digest =~ ^[0-9a-fA-F]{64}$ ]] || return 1
  [[ $url == https://github.com/rustdesk/rustdesk/releases/download/* ]] || return 1
  [[ -r $HDM_CACHE/downloads/$asset ]] || return 1
  printf '%s  %s\n' "$digest" "$HDM_CACHE/downloads/$asset" | sha256sum --status -c - || return 1
  mkdir -p "$HDM_STATE"
  temp=$(mktemp "$HDM_STATE/.rustdesk-cache.XXXXXX") || return 1
  [[ ! -r $manifest ]] || awk -F '\t' -v a="$asset" '$2!=a' "$manifest" > "$temp"
  printf '%s\t%s\t%s\t%s\n' "$tag" "$asset" "$digest" "$url" >> "$temp"
  chmod 600 "$temp" && mv -f -- "$temp" "$manifest"
}
hdm_rustdesk_cache_list() {
  local manifest="$HDM_STATE/rustdesk-cache.tsv" tag asset digest url file
  [[ -r $manifest ]] || { hdm_warn '本机尚无经 HDM 校验的历史 RustDesk 安装包。'; return 1; }
  while IFS=$'\t' read -r tag asset digest url; do
    [[ $asset =~ ^rustdesk-[0-9]+\.[0-9]+\.[0-9]+-(x86_64|aarch64)\.deb$ && $asset == *-"$(hdm_arch)".deb && $digest =~ ^[0-9a-fA-F]{64}$ ]] || continue
    file="$HDM_CACHE/downloads/$asset"
    if [[ -f $file ]] && printf '%s  %s\n' "$digest" "$file" | sha256sum --status -c -; then
      printf '%s\t%s\t%s\t%s\n' "$tag" "$asset" "$digest" "$url"
    fi
  done < "$manifest"
}
hdm_rustdesk_install_local() {
  local file
  hdm_prompt '本地 RustDesk .deb 绝对路径：' file || return 1
  [[ $file == /* && -f $file && $file == *.deb ]] || { hdm_error '必须输入存在的 .deb 绝对路径'; return 1; }
  hdm_warn '本地包不一定有可信供应链信息。请独立核对官方 SHA256 或签名。'
  hdm_confirm '已核实该文件来源，仍要继续？' || return 2
  hdm_rustdesk_install_deb "$file"
}
hdm_rustdesk_rollback() {
  hdm_root && hdm_guard_platform || return 1
  local -a entries=()
  local i answer tag asset digest url file
  mapfile -t entries < <(hdm_rustdesk_cache_list 2>/dev/null)
  if [[ ${#entries[@]} -eq 0 ]]; then
    hdm_warn '没有可用的经校验本地历史安装包；可从菜单 5.3 下载官方历史版本。'; return 1
  fi
  hdm_show '已验证的 RustDesk 本地版本（不包含未知来源包）'
  for i in "${!entries[@]}"; do
    IFS=$'\t' read -r tag asset digest url <<< "${entries[$i]}"
    printf '%2d. %s  %s\n' "$((i+1))" "$tag" "$asset"
  done
  hdm_prompt '选择回滚版本编号（输入0取消）：' answer || return 1
  [[ $answer =~ ^[0-9]+$ ]] || return 1
  ((answer == 0)) && return 0
  ((answer>=1 && answer<=${#entries[@]})) || return 1
  IFS=$'\t' read -r tag asset digest url <<< "${entries[$((answer-1))]}"
  file="$HDM_CACHE/downloads/$asset"
  [[ -f $file ]] && printf '%s  %s\n' "$digest" "$file" | sha256sum --status -c - || {
    hdm_error '缓存内容的 SHA-256 与记录不一致，拒绝回滚'; return 1;
  }
  hdm_warn '版本回退不会自动保证新版配置向后兼容。保留 SSH 和已有配置快照。'
  hdm_rustdesk_install_deb "$file"
}
hdm_rustdesk_uninstall() {
  hdm_warn '卸载 RustDesk 可能失去图形远程连接。将保留配置并仅确认一次。'
  hdm_pkg_remove rustdesk
}
# Validate a RustDesk ID/relay host endpoint without calling shell or DNS.
# Supports DNS/IPv4 optionally with :port, and bracketed IPv6 optionally with :port.
# This is syntactic validation only; remote connectivity is tested separately.
hdm_rustdesk_endpoint_valid() {
  local endpoint=${1:-} name port label
  [[ -n $endpoint && ${#endpoint} -le 253 ]] || return 1
  if [[ $endpoint =~ ^\[([0-9A-Fa-f:]+)\](:([0-9]+))?$ ]]; then
    name=${BASH_REMATCH[1]}
    port=${BASH_REMATCH[3]:-}
    [[ $name == *:* ]] || return 1
  elif [[ $endpoint =~ ^([A-Za-z0-9.-]+)(:([0-9]+))?$ ]]; then
    name=${BASH_REMATCH[1]}
    port=${BASH_REMATCH[3]:-}
    [[ $name != .* && $name != *. && $name != *..* ]] || return 1
    local IFS=.
    for label in $name; do
      [[ -n $label && ${#label} -le 63 && $label =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] || return 1
    done
  else
    return 1
  fi
  if [[ -n $port ]]; then
    [[ ${#port} -le 5 && $port =~ ^[0-9]+$ ]] || return 1
    ((10#$port >= 1 && 10#$port <= 65535)) || return 1
  fi
}

hdm_rustdesk_input_host() {
  local variable=$1 label=$2 host
  hdm_prompt "$label：" host || return 1
  hdm_rustdesk_endpoint_valid "$host" || { hdm_error '地址格式错误（仅支持合法域名/IPv4 或 [IPv6]:1-65535）'; return 1; }
  printf -v "$variable" '%s' "$host"
}
# Independent editable draft. File is data, never sourced/executed; saved root-only.
hdm_rustdesk_draft_file() { printf '%s/rustdesk-server-draft.tsv' "$HDM_STATE"; }
hdm_rustdesk_draft_get() {
  local field=$1 path
  path=$(hdm_rustdesk_draft_file)
  [[ -r $path ]] || return 0
  awk -F '\t' -v k="$field" '$1==k {v=$2} END {print v}' "$path"
}
hdm_rustdesk_draft_set() {
  local field=$1 value=$2 file temp
  hdm_root || return 1
  case "$field" in
    id|relay) hdm_rustdesk_endpoint_valid "$value" || { hdm_error '地址格式无效'; return 1; } ;;
    key) [[ $value =~ ^[A-Za-z0-9+/=:_-]{20,256}$ ]] || { hdm_error '公钥格式无效'; return 1; } ;;
    *) return 1;;
  esac
  [[ $value != *$'\n'* && $value != *$'\t'* ]] || return 1
  mkdir -p "$HDM_STATE"
  file=$(hdm_rustdesk_draft_file)
  temp=$(mktemp "$HDM_STATE/.server-draft.XXXXXX") || return 1
  if [[ -f $file ]]; then awk -F '\t' -v k="$field" '$1!=k' "$file" > "$temp"; fi
  printf '%s\t%s\n' "$field" "$value" >> "$temp"
  chmod 600 "$temp" && mv -f -- "$temp" "$file"
}
hdm_rustdesk_draft_ready() {
  local id relay key
  id=$(hdm_rustdesk_draft_get id)
  relay=$(hdm_rustdesk_draft_get relay)
  key=$(hdm_rustdesk_draft_get key)
  hdm_rustdesk_endpoint_valid "$id" && hdm_rustdesk_endpoint_valid "$relay" && [[ $key =~ ^[A-Za-z0-9+/=:_-]{20,256}$ ]]
}
hdm_rustdesk_draft_preview() {
  local id relay key
  id=$(hdm_rustdesk_draft_get id); relay=$(hdm_rustdesk_draft_get relay); key=$(hdm_rustdesk_draft_get key)
  printf '当前待应用配置（草稿，并非已生效）：\n'
  printf '  ID 服务器：%s\n  中继服务器：%s\n  公钥：%s\n' "${id:-未填写}" "${relay:-未填写}" "${key:-未填写}"
  if hdm_rustdesk_draft_ready; then printf '  输入完整，可选择 7.1.7 保存。\n'; else printf '  尚缺必需字段，请完成填写。\n'; fi
}
hdm_rustdesk_draft_wizard() {
  local id relay key
  printf '一次填写三个字段，保存到待应用草稿；不会立即修改 RustDesk。\n'
  hdm_rustdesk_input_host id 'ID 服务器（可带端口）' || return 1
  hdm_rustdesk_input_host relay '中继服务器（可带端口）' || return 1
  printf '服务器公钥：'; IFS= read -r key || return 1
  [[ $key =~ ^[A-Za-z0-9+/=:_-]{20,256}$ ]] || { hdm_error '公钥格式无效'; return 1; }
  hdm_rustdesk_draft_set id "$id" && hdm_rustdesk_draft_set relay "$relay" && hdm_rustdesk_draft_set key "$key" || return 1
  unset key
  hdm_rustdesk_draft_preview
}
hdm_rustdesk_draft_edit() {
  local field=$1 value
  case "$field" in
    id) hdm_rustdesk_input_host value '新的 ID 服务器（主机:端口）' || return 1;;
    relay) hdm_rustdesk_input_host value '新的中继服务器（主机:端口）' || return 1;;
    key) printf '输入新公钥：'; IFS= read -r value || return 1;;
    *) return 1;;
  esac
  hdm_rustdesk_draft_set "$field" "$value" || return 1
  unset value
  printf '已保存至待应用草稿，选择 7.1.7 才会导入。\n'
}
hdm_rustdesk_draft_apply() {
  local id relay key
  hdm_rustdesk_draft_ready || { hdm_error '草稿不完整，先在 7.1.1 填写。'; return 1; }
  id=$(hdm_rustdesk_draft_get id); relay=$(hdm_rustdesk_draft_get relay); key=$(hdm_rustdesk_draft_get key)
  hdm_rustdesk_import_config "$id" "$relay" "$key"
  local rc=$?
  unset key
  return "$rc"
}
hdm_rustdesk_root_config() { printf '%s' "${HDM_RUSTDESK_CONFIG_ROOT:-/root/.config/rustdesk/RustDesk2.toml}"; }
hdm_rustdesk_root_inspect() {
  python3 "$HDM_ROOT/scripts/rustdesk_config.py" inspect "$(hdm_rustdesk_root_config)"
}
hdm_rustdesk_draft_port_defaults() {
  printf 'RustDesk 常见端口：ID 21116，Relay 21117。当前自定义端口不会被静默覆盖。\n'
  hdm_rustdesk_draft_preview
}
# Read-only ID is never coupled to configuration editing.
hdm_rustdesk_registration_status() {
  hdm_rustdesk_get_id
  printf '注意：取得设备 ID 不代表自建服务器注册、认证或画面捕获成功。\n'
}

# A root RustDesk service can launch the GUI helper as a login user. We must
# inspect/persist BOTH explicit profile scopes rather than blindly assuming the
# root CLI import wrote to /root/.config/rustdesk/RustDesk2.toml.
hdm_rustdesk_login_profile() {
  local user=${SUDO_USER:-} account home uid gid
  [[ -n $user && $user != root && $user =~ ^[a-z_][a-z0-9_-]*$ ]] || return 1
  account=$(getent passwd "$user" 2>/dev/null) || return 1
  IFS=: read -r _ _ uid gid _ home _ <<< "$account"
  [[ $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ && $home == "/home/$user" ]] || return 1
  printf '%s\t%s\t%s\n' "$home/.config/rustdesk/RustDesk2.toml" "$uid" "$gid"
}
hdm_rustdesk_import_config() {
  local id_server=$1 relay=$2 public_key=$3 root_file user_profile='' user_file='' user_uid='' user_gid=''
  local state snapshot rc=0 path attempt
  local -a config_paths=()
  hdm_root && hdm_guard_platform || return 1
  hdm_has rustdesk || { hdm_error '请先安装 RustDesk'; return 1; }
  [[ $public_key =~ ^[A-Za-z0-9+/=:_-]{20,256}$ ]] || { hdm_error '服务器公钥格式无效'; return 1; }
  hdm_rustdesk_endpoint_valid "$id_server" && hdm_rustdesk_endpoint_valid "$relay" || { hdm_error 'ID/中继服务器地址不合法'; return 1; }
  root_file=$(hdm_rustdesk_root_config)
  config_paths=("$root_file")
  if user_profile=$(hdm_rustdesk_login_profile); then
    IFS=$'\t' read -r user_file user_uid user_gid <<< "$user_profile"
    [[ $user_file == "$root_file" ]] || config_paths+=("$user_file")
  fi
  for path in "${config_paths[@]}"; do
    [[ ! -L $path && ! -L $(dirname -- "$path") ]] || { hdm_error "配置路径为符号链接，拒绝覆盖：$path"; return 1; }
  done
  # An explicit Save action is sufficient; avoid redundant confirmation.
  state=$(hdm_service_state rustdesk)
  if [[ $state == active ]]; then
    if ! systemctl stop rustdesk >/dev/null 2>&1; then
      hdm_error 'RustDesk 服务无法停止，拒绝在运行时覆写配置'; return 1
    fi
  fi
  # Snapshot after stopping RustDesk, so the service cannot overwrite one
  # profile in the middle of capturing a consistent pair of TOML files.
  if ! hdm_snapshot_create "${config_paths[@]}"; then
    if [[ $state == active ]]; then systemctl start rustdesk >/dev/null 2>&1 || :; fi
    return 1
  fi
  snapshot=$HDM_LAST_SNAPSHOT
  if ! python3 "$HDM_ROOT/scripts/rustdesk_config.py" apply "$root_file" --draft "$(hdm_rustdesk_draft_file)" --uid 0 --gid 0; then rc=1; fi
  if ((rc == 0)) && [[ -n $user_file ]]; then
    if ! python3 "$HDM_ROOT/scripts/rustdesk_config.py" apply "$user_file" --draft "$(hdm_rustdesk_draft_file)" --uid "$user_uid" --gid "$user_gid"; then rc=1; fi
  fi
  if ((rc == 0)); then
    for path in "${config_paths[@]}"; do
      if ! python3 "$HDM_ROOT/scripts/rustdesk_config.py" verify "$path" --draft "$(hdm_rustdesk_draft_file)" >/dev/null; then rc=1; break; fi
    done
  fi
  if ((rc == 0)) && [[ $state == active ]]; then
    if ! systemctl start rustdesk >/dev/null 2>&1; then rc=1; fi
    # Some RustDesk builds rewrite TOML during service startup. Verify again.
    if ((rc == 0)); then
      for attempt in 1 2 3; do
        sleep 1
        rc=0
        for path in "${config_paths[@]}"; do
          if ! python3 "$HDM_ROOT/scripts/rustdesk_config.py" verify "$path" --draft "$(hdm_rustdesk_draft_file)" >/dev/null; then rc=1; break; fi
        done
        ((rc == 0)) || break
      done
    fi
  fi
  if ((rc != 0)); then
    hdm_warn '至少一个 RustDesk 配置作用域写入失败、服务启动失败或保存后被覆盖，正在恢复快照。'
    if [[ $state == active ]]; then systemctl stop rustdesk >/dev/null 2>&1 || :; fi
    hdm_snapshot_restore "$snapshot" || hdm_warn '自动恢复失败，请通过菜单 7.11 查看并手动恢复配置快照。'
    if [[ $state == active ]]; then systemctl start rustdesk >/dev/null 2>&1 || hdm_warn 'RustDesk 恢复后服务未能启动，需人工检查。'; fi
    hdm_error '配置保存验证失败。未宣称成功；查看菜单 7.3 和 RustDesk 服务日志。'
    return 1
  fi
  hdm_info 'root 配置已保存并读回一致。'
  if [[ -n $user_file ]]; then
    hdm_info "用户 ${SUDO_USER} 配置已保存并读回一致。"
  else
    hdm_warn '未检测到可确定的普通登录用户配置作用域；只更新了 root 配置。'
  fi
  if [[ $state == active ]]; then
    hdm_info 'RustDesk 服务已重新启动；不代表自建 ID 服务器注册或图形捕获成功。'
  else
    hdm_warn "RustDesk 原服务状态为 $state；未自行启动原本未运行的服务。"
  fi
  hdm_rustdesk_get_id || :
  hdm_warn '如果仍显示 cannot open display :0，须另行修复无显示器 GNOME/Wayland 会话；与配置保存无关。'
}

hdm_rustdesk_server_wizard() {
  local id relay key
  hdm_rustdesk_input_host id 'ID 服务器（域名或 IP，可带端口；默认 21116）' || return 1
  hdm_rustdesk_input_host relay '中继服务器（域名或 IP，可带端口；默认 21117）' || return 1
  printf '请输入服务器公钥（不会进入 HDM 日志）：'; IFS= read -r key || return 1
  [[ $key =~ ^[A-Za-z0-9+/=:_-]{20,256}$ ]] || { hdm_error '服务器公钥格式无效'; return 1; }
  printf '\nID 服务器：%s\n中继服务器：%s\n公钥：%s\n' "$id" "$relay" "$key"
  hdm_rustdesk_import_config "$id" "$relay" "$key"
  unset key
}
hdm_rustdesk_server_import_file() {
  local path
  hdm_prompt 'RustDesk 原生配置文件完整路径：' path || return 1
  [[ $path == /* && -f $path && $path == *.toml ]] || { hdm_error '无效的 .toml 路径'; return 1; }
  hdm_danger '通过 RustDesk 原生导入接口导入该配置，可能改变远控服务器？' || return 2
  hdm_snapshot_create "$(hdm_rustdesk_root_config)" || return 1
  rustdesk --import-config "$path" >/dev/null 2>&1 && hdm_info '已执行原生导入，仍需验证实际生效。'
}
hdm_rustdesk_password() {
  local password
  hdm_root || return 1
  hdm_has rustdesk || { hdm_error 'RustDesk 尚未安装'; return 1; }
  # No HDM-specific arbitrary length requirement. RustDesk itself validates.
  # The user specifically requested visible input without repeated prompts.
  printf '永久密码（输入可见）：'
  IFS= read -r password || return 1
  [[ -n $password ]] || { hdm_error '密码不能为空'; return 1; }
  if rustdesk --password "$password" >/dev/null 2>&1; then
    unset password
    hdm_info 'RustDesk 已接受永久密码设置。'
    # Permit password-only authorization where a GUI acceptance dialog cannot
    # be displayed. Verify on-disk auth options independently from CLI success.
    if ! hdm_rustdesk_permissions_apply auth N; then
      hdm_warn '永久密码已提交，但无人值守密码验证模式尚未配置成功。'
      return 1
    fi
    printf '仍需从另一台设备验证连接；没有图形会话时连接可能被拒绝。\n'
  else
    unset password
    hdm_error 'RustDesk 拒绝设置密码，请检查客户端日志'; return 1
  fi
}

hdm_rustdesk_get_id() {
  local id
  hdm_has rustdesk || { hdm_warn 'RustDesk 未安装，无法查询设备 ID'; return 1; }
  id=$(timeout 8 rustdesk --get-id 2>/dev/null) || { hdm_warn '查询设备 ID 失败（超时、服务异常或运行账户问题）'; return 1; }
  [[ -n $id ]] || { hdm_warn 'RustDesk 返回了空 ID，需检查服务与注册状态'; return 1; }
  printf '本机 RustDesk ID：%s\n' "$id"
}
hdm_rustdesk_set_id() {
  local id
  hdm_prompt '输入期望 ID（必须以字母开头，可能被自建服务器拒绝）：' id || return 1
  [[ $id =~ ^[a-zA-Z][a-zA-Z0-9_-]{4,31}$ ]] || { hdm_error 'ID 格式不符合要求'; return 1; }
  hdm_danger '尝试设置自定义设备 ID，可能与原设备 ID 连接中断？' || return 2
  rustdesk --set-id "$id" >/dev/null 2>&1 || return 1
  hdm_rustdesk_get_id
}
hdm_rustdesk_server_status() {
  local file user_home
  printf 'RustDesk 已安装：%s；systemd 服务：%s\n' "$(hdm_pkg_version rustdesk)" "$(hdm_service_state rustdesk)"
  file=$(hdm_rustdesk_root_config)
  printf '\n[Root CLI 已保存配置（读取磁盘，不代表服务生效）]\n'
  hdm_rustdesk_root_inspect || printf '无法确认 root CLI 配置，菜单 7.1.7 保存后可复查。\n'
  if [[ -n ${SUDO_USER:-} && ${SUDO_USER:-root} != root ]] && hdm_has getent; then
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [[ -n $user_home && -r $user_home/.config/rustdesk/RustDesk2.toml ]]; then
      printf '\n[用户 %s 的配置（可能与系统服务不同）]\n' "$SUDO_USER"
      python3 "$HDM_ROOT/scripts/rustdesk_config.py" inspect "$user_home/.config/rustdesk/RustDesk2.toml" || :
    fi
  fi
  printf '\n[当前编辑草稿]\n'
  hdm_rustdesk_draft_preview
  printf '\n[本机设备 ID]\n'
  hdm_rustdesk_get_id
  if hdm_has journalctl && journalctl -u rustdesk -b --since '30 minutes ago' --no-pager -n 100 2>/dev/null | grep -Fq 'cannot open display'; then
    hdm_warn '最近服务日志含 cannot open display：图形输出仍需单独修复，配置文件一致并不能解决黑屏。'
  fi
}
hdm_network_test() {
  local host=${1:-} port=${2:-21116}
  [[ $host =~ ^[A-Za-z0-9.-]+$ && $port =~ ^[0-9]{1,5}$ && $port -ge 1 && $port -le 65535 ]] || { hdm_error '无效的测试地址或端口'; return 1; }
  if getent ahosts "$host" >/dev/null 2>&1; then hdm_info "DNS/地址解析通过：$host"; else hdm_warn "地址解析失败：$host"; return 1; fi
  if timeout 4 bash -c 'exec 3<>/dev/tcp/$1/$2' _ "$host" "$port" 2>/dev/null; then hdm_info "TCP $host:$port 可达；不代表 RustDesk 已注册。"; else hdm_warn "TCP $host:$port 不可达"; return 1; fi
}
hdm_rustdesk_server_network_wizard() {
  local endpoint pair host port
  hdm_prompt '输入服务器地址（主机:端口，允许省略端口默认 21116）：' endpoint || return 1
  pair=$(hdm_rustdesk_endpoint_parts "$endpoint" 21116) || { hdm_error '地址格式错误'; return 1; }
  read -r host port <<< "$pair"
  hdm_network_test "$host" "$port"
}

# Connection tests consume configured endpoints; never ask for the same address again.
hdm_rustdesk_endpoint_parts() {
  local endpoint=$1 default_port=$2 host port
  hdm_rustdesk_endpoint_valid "$endpoint" || return 1
  if [[ $endpoint =~ ^\[([^]]+)\](:([0-9]+))?$ ]]; then
    host=${BASH_REMATCH[1]}; port=${BASH_REMATCH[3]:-$default_port}
  elif [[ $endpoint == *:* ]]; then
    host=${endpoint%:*}; port=${endpoint##*:}
  else host=$endpoint; port=$default_port; fi
  printf '%s %s\n' "$host" "$port"
}
hdm_rustdesk_current_endpoint() {
  local field=$1 path value
  path=$(hdm_rustdesk_root_config)
  if [[ -r $path ]]; then
    value=$(python3 "$HDM_ROOT/scripts/rustdesk_config.py" "get-$field" "$path" 2>/dev/null) || value=''
    if [[ -n $value ]]; then printf '%s\n' "$value"; return 0; fi
  fi
  # Do NOT fall back to a draft silently and call it an active configuration.
  return 1
}
hdm_rustdesk_check_connection() {
  local role=$1 mode=${2:-active} endpoint host port pair
  case "$role" in id|relay) ;; *) return 1;; esac
  if [[ $mode == draft ]]; then endpoint=$(hdm_rustdesk_draft_get "$role"); else endpoint=$(hdm_rustdesk_current_endpoint "$role") || { hdm_error '未读到已保存的服务器地址，无法测试；请先检查 7.3。'; return 1; }; fi
  [[ -n $endpoint ]] || { hdm_error '当前地址为空，无法检查'; return 1; }
  pair=$(hdm_rustdesk_endpoint_parts "$endpoint" "$([[ $role == id ]] && echo 21116 || echo 21117)") || return 1
  read -r host port <<< "$pair"
  printf '目标：%s（%s 配置；TCP 连通性）\n' "$endpoint" "$mode"
  hdm_network_test "$host" "$port"
}
hdm_rustdesk_check_dns() {
  local endpoint pair host port
  endpoint=$(hdm_rustdesk_current_endpoint id) || { hdm_error '未读到已保存的 ID 地址'; return 1; }
  pair=$(hdm_rustdesk_endpoint_parts "$endpoint" 21116) || return 1
  read -r host port <<< "$pair"
  if getent ahosts "$host" >/dev/null 2>&1; then printf 'DNS/地址解析成功：%s\n' "$host"; else hdm_error "DNS/地址解析失败：$host"; fi
}
hdm_rustdesk_check_full() {
  local rc=0
  hdm_rustdesk_server_status
  hdm_rustdesk_check_connection id || rc=1
  hdm_rustdesk_check_connection relay || rc=1
  printf '提示：以上无法确认 UDP 打洞、服务器公钥握手或远端画面可用，需外部 RustDesk 客户端验证。\n'
  return "$rc"
}
hdm_rustdesk_check_import_file() {
  local path
  hdm_prompt '要检查的 .toml 绝对路径：' path || return 1
  [[ $path == /* && -f $path && $path == *.toml ]] || { hdm_error '路径无效'; return 1; }
  python3 "$HDM_ROOT/scripts/rustdesk_config.py" validate "$path"
}

# Diagnose disabled GUI settings without bypassing polkit or weakening permissions.
hdm_rustdesk_permission_report() {
  local service_user root_cfg user_home user_cfg
  hdm_show 'RustDesk 安全/网络设置：只读权限诊断'
  printf 'RustDesk 版本：%s；系统服务：%s\n' "$(hdm_pkg_version rustdesk)" "$(hdm_service_state rustdesk)"
  if hdm_has systemctl; then
    service_user=$(systemctl show rustdesk -p User --value 2>/dev/null) || service_user=''
    printf 'systemd 服务用户：%s（留空表示系统默认，通常是 root）\n' "${service_user:-未显式指定}"
  fi
  if hdm_has pkexec; then printf '[存在] pkexec：界面解锁通常通过 Polkit 进行授权。\n'
  else printf '[缺失] pkexec：部分图形化授权按钮可能无法正常弹出。\n'; fi
  if hdm_has systemctl; then
    printf 'Polkit 进程：%s（不等于图形授权代理一定可用）\n' "$(hdm_service_state polkit)"
  fi
  root_cfg=$(hdm_rustdesk_root_config)
  if [[ -r $root_cfg ]]; then
    printf '[存在] root CLI 配置（不代表已被 RustDesk 后台或桌面用户加载）\n'
    hdm_rustdesk_root_inspect || printf '[无法解析] root CLI 配置\n'
  else
    printf '[未发现] root CLI 配置文件；并不证明其他账户没有配置。\n'
  fi
  if [[ -n ${SUDO_USER:-} && ${SUDO_USER:-root} != root ]] && hdm_has getent; then
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    user_cfg="$user_home/.config/rustdesk/RustDesk2.toml"
    if [[ -r $user_cfg ]]; then
      printf '[存在] 当前登录用户 %s 的配置（可能与服务不同）\n' "$SUDO_USER"
      python3 "$HDM_ROOT/scripts/rustdesk_config.py" inspect "$user_cfg" || :
    else
      printf '[未发现] 用户 %s 的 RustDesk2.toml 配置文件\n' "$SUDO_USER"
    fi
  fi
  printf 'GUI 的 Security / Network 通常需要 Unlock 并通过管理员/Polkit 授权。\n'
  printf 'HDM 可用菜单 7.1 保存自建服务器，再做磁盘读回校验；不能据此证明服务已加载。\n'
  printf '不建议 sudo rustdesk 图形界面、chmod 777、关闭认证或手动复制密码到配置文件。\n'
  if hdm_gnome_wayland_only; then
    printf '[Wayland] 未登录、锁屏、熄屏和没有任何显示输出互不等同；标准版预登录捕获可能不可用。\n'
  fi
  hdm_rustdesk_get_id || :
  printf '[待实测] 以上诊断不证明管理员解锁按钮已可用，也不证明自建服务器注册成功。\n'
}

# RustDesk documented permissions are stored in [options]. Different accounts
# and server-side Override/Strategy policies may have distinct effective values.
hdm_rustdesk_permissions_apply() {
  local mode=$1 remote=${2:-N} state root_file profile user_file='' uid='' gid='' snapshot='' rc=0 file
  local -a files=()
  hdm_root || return 1
  hdm_has rustdesk || { hdm_error '请先安装 RustDesk'; return 1; }
  case "$mode" in custom|full|view|auth) ;; *) return 1;; esac
  [[ $remote == Y || $remote == N ]] || return 1
  root_file=$(hdm_rustdesk_root_config)
  files=("$root_file")
  if profile=$(hdm_rustdesk_login_profile); then
    IFS=$'\t' read -r user_file uid gid <<< "$profile"
    [[ $user_file == "$root_file" ]] || files+=("$user_file")
  fi
  # Check every ancestor before snapshotting; root backups must not follow
  # an attacker-controlled symlink into an unrelated system path.
  python3 - "${files[@]}" <<'PY_PATHCHECK' || return 1
import pathlib, sys
for name in sys.argv[1:]:
    path = pathlib.Path(name)
    if not path.is_absolute() or any(part.is_symlink() for part in (path, *path.parents)):
        raise SystemExit('Refusing unsafe RustDesk configuration path')
PY_PATHCHECK
  state=$(hdm_service_state rustdesk)
  if [[ $state == active ]] && ! systemctl stop rustdesk >/dev/null 2>&1; then
    hdm_error '无法停止 RustDesk，配置保持不变'; return 1
  fi
  if ! hdm_snapshot_create "${files[@]}"; then
    [[ $state != active ]] || systemctl start rustdesk >/dev/null 2>&1 || :
    return 1
  fi
  snapshot=$HDM_LAST_SNAPSHOT
  python3 "$HDM_ROOT/scripts/rustdesk_permissions.py" apply "$root_file" --mode "$mode" --remote "$remote" --uid 0 --gid 0 >/dev/null || rc=1
  if ((rc == 0)) && [[ -n $user_file ]]; then
    python3 "$HDM_ROOT/scripts/rustdesk_permissions.py" apply "$user_file" --mode "$mode" --remote "$remote" --uid "$uid" --gid "$gid" >/dev/null || rc=1
  fi
  if ((rc == 0)) && [[ $state == active ]]; then
    systemctl start rustdesk >/dev/null 2>&1 || rc=1
  fi
  if ((rc == 0)); then
    for file in "${files[@]}"; do
      python3 "$HDM_ROOT/scripts/rustdesk_permissions.py" verify "$file" --mode "$mode" --remote "$remote" >/dev/null || { rc=1; break; }
    done
  fi
  if ((rc != 0)); then
    [[ $state != active ]] || systemctl stop rustdesk >/dev/null 2>&1 || :
    hdm_snapshot_restore "$snapshot" || hdm_warn '权限设置恢复快照失败，请手动恢复。'
    [[ $state != active ]] || systemctl start rustdesk >/dev/null 2>&1 || :
    hdm_error '权限写入或读回验证失败，已尝试恢复原设置'; return 1
  fi
  printf '权限配置已保存并读回一致（%s）。\n' "$mode"
  printf '服务是否实际采用，仍取决于 RustDesk 运行账户和更高优先级策略。\n'
}
hdm_rustdesk_permissions_show() {
  local profile file
  file=$(hdm_rustdesk_root_config)
  printf 'root 账户：\n'
  python3 "$HDM_ROOT/scripts/rustdesk_permissions.py" inspect "$file" || :
  if profile=$(hdm_rustdesk_login_profile); then
    file=${profile%%$'\t'*}
    printf '\n登录用户：\n'
    python3 "$HDM_ROOT/scripts/rustdesk_permissions.py" inspect "$file" || :
  fi
}
hdm_rustdesk_permissions_menu() {
  local choice value
  printf '\nRustDesk 访问权限\n  1 自定义（常用权限开启，远程修改配置关闭）\n  2 完全访问\n  3 仅共享屏幕\n  4 允许远程修改配置\n  5 禁止远程修改配置\n  6 查看当前设置\n'
  hdm_prompt '请选择：' choice || return 1
  case "$choice" in
    1) hdm_rustdesk_permissions_apply custom N;;
    2) hdm_rustdesk_permissions_apply full N;;
    3) hdm_rustdesk_permissions_apply view N;;
    4) printf '启用后已授权的远程用户可以修改本机 RustDesk 配置。\n'; hdm_rustdesk_permissions_apply custom Y;;
    5) hdm_rustdesk_permissions_apply custom N;;
    6) hdm_rustdesk_permissions_show;;
    *) hdm_error '无效选项'; return 1;;
  esac
}
