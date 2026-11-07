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
  [[ $arch == amd64 && $package == rustdesk ]] || { hdm_error "RustDesk 包名或架构不匹配：$package / $arch"; return 1; }
  hdm_danger "将通过 APT 安装 $(basename -- "$deb")，可能重启 RustDesk 并断开远程会话" || return 2
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
      if hdm_confirm 'APT 已提供 RustDesk 包。优先直接使用当前系统软件源安装？'; then hdm_pkg_install rustdesk; return $?; fi
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
  hdm_rustdesk_install_deb "$file"
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
  hdm_show '可用本地安装包'
  find "$HDM_CACHE/downloads" -maxdepth 1 -type f -name 'rustdesk-*.deb' -printf '%f\n' 2>/dev/null || :
  hdm_warn '历史本地包需要原始可信 SHA256 才能自动回滚。请通过菜单 5.3 指定官方历史版本，或先独立验证包。'
}
hdm_rustdesk_uninstall() {
  hdm_danger '卸载 RustDesk 客户端？默认保留配置，可能失去图形远程连接。' || return 2
  hdm_apt_call remove -y rustdesk
}
hdm_rustdesk_input_host() {
  local variable=$1 label=$2 host
  hdm_prompt "$label：" host || return 1
  [[ $host =~ ^[A-Za-z0-9.-]+(:[0-9]{1,5})?$ || $host =~ ^\[[0-9A-Fa-f:]+\](:[0-9]{1,5})?$ ]] || { hdm_error '地址格式错误（支持域名/IPv4 或 [IPv6]:端口）'; return 1; }
  printf -v "$variable" '%s' "$host"
}
hdm_rustdesk_import_config() {
  local id_server=$1 relay=$2 public_key=$3 tmp
  hdm_root && hdm_guard_platform || return 1
  hdm_has rustdesk || { hdm_error '请先安装 RustDesk'; return 1; }
  [[ $public_key =~ ^[A-Za-z0-9+/=:_-]{20,256}$ ]] || { hdm_error '服务器公钥格式无效（字符/长度不符合要求）'; return 1; }
  [[ $id_server != *\'* && $relay != *\'* ]] || return 1
  # Config import delegates persistence and version-specific handling to the upstream CLI.
  hdm_snapshot_create /root/.config/rustdesk/RustDesk2.toml || return 1
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
    hdm_info 'RustDesk CLI 已接受配置导入。实际 ID 注册/运行账户配置仍需菜单 7.9 和远端验证。'
  else
    rm -f "$tmp"
    hdm_error '当前 RustDesk 版本/服务账户未能导入配置；保留旧配置，建议通过官方 UI 或已验证的专用配置方式操作。'
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
  hdm_snapshot_create /root/.config/rustdesk/RustDesk2.toml || return 1
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
hdm_rustdesk_get_id() { if hdm_has rustdesk; then timeout 8 rustdesk --get-id 2>/dev/null || hdm_warn '无法获得 ID'; else hdm_warn 'RustDesk 未安装'; fi; }
hdm_rustdesk_set_id() {
  local id
  hdm_prompt '输入期望 ID（必须以字母开头，可能被自建服务器拒绝）：' id || return 1
  [[ $id =~ ^[a-zA-Z][a-zA-Z0-9_-]{4,31}$ ]] || { hdm_error 'ID 格式不符合要求'; return 1; }
  hdm_danger '尝试设置自定义设备 ID，可能与原设备 ID 连接中断？' || return 2
  rustdesk --set-id "$id" >/dev/null 2>&1 || return 1
  hdm_rustdesk_get_id
}
hdm_rustdesk_server_status() {
  local file=/root/.config/rustdesk/RustDesk2.toml
  printf 'RustDesk（root CLI）配置文件：%s\n' "$file"
  if [[ -r $file ]]; then
    # Output only endpoint names and redacted key; do not dump full toml or private settings.
    awk -F "'" '/^[[:space:]]*(rendezvous_server|custom-rendezvous-server|relay-server)[[:space:]]*=/{print $1 "<已配置/请验证>"} /^[[:space:]]*key[[:space:]]*=/{print "key = <已隐藏>"}' "$file"
  else printf '尚未找到 root CLI 配置；可能使用其他服务账户。\n'; fi
  hdm_rustdesk_status
}
hdm_network_test() {
  local host=${1:-} port=${2:-21116}
  [[ $host =~ ^[A-Za-z0-9.-]+$ && $port =~ ^[0-9]{1,5}$ && $port -ge 1 && $port -le 65535 ]] || { hdm_error '无效的测试地址或端口'; return 1; }
  if getent ahosts "$host" >/dev/null 2>&1; then hdm_info "DNS/地址解析通过：$host"; else hdm_warn "地址解析失败：$host"; return 1; fi
  if timeout 4 bash -c 'exec 3<>/dev/tcp/$1/$2' _ "$host" "$port" 2>/dev/null; then hdm_info "TCP $host:$port 可达；不代表 RustDesk 已注册。"; else hdm_warn "TCP $host:$port 不可达"; return 1; fi
}
hdm_rustdesk_server_network_wizard() {
  local host port
  hdm_prompt '输入要测试的服务器域名 / IPv4：' host || return 1
  hdm_prompt '输入 TCP 端口（21116 / 21117）：' port || return 1
  hdm_network_test "$host" "$port"
}
