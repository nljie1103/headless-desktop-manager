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
  printf '  ID 服务器：%s\n  中继服务器：%s\n  公钥：%s\n' "${id:-未填写}" "${relay:-未填写}" "$([[ -n $key ]] && echo '已填写（隐藏）' || echo '未填写')"
  if hdm_rustdesk_draft_ready; then printf '  输入完整，可选择 7.1.7 保存。\n'; else printf '  尚缺必需字段，请完成填写。\n'; fi
}
hdm_rustdesk_draft_wizard() {
  local id relay key
  printf '一次填写三个字段，保存到待应用草稿；不会立即修改 RustDesk。\n'
  hdm_rustdesk_input_host id 'ID 服务器（可带端口）' || return 1
  hdm_rustdesk_input_host relay '中继服务器（可带端口）' || return 1
  printf '服务器公钥（输入不回显）：'; IFS= read -rs key || return 1; printf '\n'
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
    key) printf '输入新公钥（不回显）：'; IFS= read -rs value || return 1; printf '\n';;
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

hdm_rustdesk_import_config() {
  local id_server=$1 relay=$2 public_key=$3 tmp
  hdm_root && hdm_guard_platform || return 1
  hdm_has rustdesk || { hdm_error '请先安装 RustDesk'; return 1; }
  [[ $public_key =~ ^[A-Za-z0-9+/=:_-]{20,256}$ ]] || { hdm_error '服务器公钥格式无效（字符/长度不符合要求）'; return 1; }
  hdm_rustdesk_endpoint_valid "$id_server" && hdm_rustdesk_endpoint_valid "$relay" || { hdm_error 'ID/中继服务器地址不合法'; return 1; }
  # Config import delegates persistence and version-specific handling to the upstream CLI.
  hdm_snapshot_create "$(hdm_rustdesk_root_config)" || return 1
  tmp=$(mktemp "$HDM_CACHE/downloads/.rustdesk-config.XXXXXX") || return 1
  chmod 600 "$tmp"
  cat > "$tmp" <<EOF_CFG
rendezvous_server = '$id_server'
[options]
custom-rendezvous-server = '$id_server'
relay-server = '$relay'
key = '$public_key'
EOF_CFG
  hdm_danger '将导入 RustDesk 自建服务器配置，现有连接可能中断；请确保 SSH 可用' || { rm -f "$tmp"; return 2; }
  # Do not copy credentials to log and do not claim registration success from CLI success alone.
  if rustdesk --import-config "$tmp" >/dev/null 2>&1; then
    if python3 "$HDM_ROOT/scripts/rustdesk_config.py" verify "$(hdm_rustdesk_root_config)" --draft "$(hdm_rustdesk_draft_file)"; then
      hdm_info '配置文件读回与输入一致；但服务加载、服务器注册和远控仍待实测。'
    else
      hdm_warn 'RustDesk CLI 返回成功，但无法从 root CLI 配置文件读回一致结果。不能认定保存成功。'
      rm -f "$tmp"
      return 1
    fi
  else
    rm -f "$tmp"
    # A failed upstream CLI might have partially changed its root-scope TOML.
    # Restore the captured file state, rather than falsely claiming it is untouched.
    if ! hdm_snapshot_restore "$HDM_LAST_SNAPSHOT"; then
      hdm_warn 'RustDesk 配置导入失败且自动恢复未完成，请使用菜单 10.9 手动恢复快照。'
    fi
    hdm_error '当前 RustDesk 版本/服务账户未能导入配置；已尝试恢复原配置，请从另一台设备检查实际状态。'
    return 1
  fi
  rm -f "$tmp"
}
hdm_rustdesk_server_wizard() {
  local id relay key
  hdm_rustdesk_input_host id 'ID 服务器（域名或 IP，可带端口；默认 21116）' || return 1
  hdm_rustdesk_input_host relay '中继服务器（域名或 IP，可带端口；默认 21117）' || return 1
  printf '请输入服务器公钥（不会进入 HDM 日志）：'; IFS= read -r key || return 1
  [[ $key =~ ^[A-Za-z0-9+/=:_-]{20,256}$ ]] || { hdm_error '服务器公钥格式无效'; return 1; }
  printf '\nID 服务器：%s\n中继服务器：%s\n公钥：%s...（已遮蔽）\n' "$id" "$relay" "${key:0:4}"
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
  local p1 p2
  hdm_root || return 1
  hdm_has rustdesk || return 1
  cat <<'SEC'
RustDesk CLI --password 可能短暂暴露密码于同机 /proc 进程参数。
HDM 不记录密码、不会写入明文 TOML，但不能消除上游 CLI 的进程参数泄露风险。
如无法接受，请用 RustDesk 官方图形设置界面手动设置。
SEC
  hdm_danger '理解上述风险，继续使用 RustDesk 官方 CLI 设置永久密码？' || return 2
  printf '请输入永久密码（输入不回显）：'; IFS= read -rs p1 || return 1; printf '\n'
  printf '再次输入永久密码（输入不回显）：'; IFS= read -rs p2 || return 1; printf '\n'
  [[ $p1 == "$p2" && ${#p1} -ge 12 ]] || { unset p1 p2; hdm_error '两次输入不一致或少于12字符'; return 1; }
  if rustdesk --password "$p1" >/dev/null 2>&1; then unset p1 p2; hdm_info 'RustDesk CLI 已处理密码设置请求；请从另一台设备验证认证有效。'; else unset p1 p2; hdm_error '设置失败，请核对 RustDesk 版本及服务账户'; return 1; fi
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
