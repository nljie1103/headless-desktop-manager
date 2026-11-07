#!/usr/bin/env bash
# HTTPS-only download and SHA256 validation. Never execute downloaded code from JSON.
hdm_download_verified() {
  local url=$1 target=$2 digest=$3 host tmp
  [[ $url == https://* && $digest =~ ^[0-9a-fA-F]{64}$ ]] || { hdm_error '必须为 HTTPS URL 和已知 SHA256'; return 1; }
  host=${url#https://}; host=${host%%/*}
  case "$host" in github.com|objects.githubusercontent.com|release-assets.githubusercontent.com|github-releases.githubusercontent.com|raw.githubusercontent.com) ;; *) hdm_error "下载主机不在许可名单：$host"; return 1;; esac
  mkdir -p "$(dirname -- "$target")"
  tmp=$(mktemp "${target}.tmp.XXXXXX") || return 1
  hdm_info "正在下载验证过的资产：$host/$(basename -- "$target")"
  if ! curl --fail --location --show-error --silent --proto '=https' --proto-redir '=https' --tlsv1.2 --connect-timeout 15 --max-time 240 --retry 2 -o "$tmp" "$url"; then rm -f "$tmp"; return 1; fi
  if ! printf '%s  %s\n' "$digest" "$tmp" | sha256sum --status -c -; then rm -f "$tmp"; hdm_error 'SHA256 校验失败，拒绝安装'; return 1; fi
  chmod 600 "$tmp"; mv -f "$tmp" "$target"
}
hdm_fetch_json() {
  local url=$1 dest=$2
  case "$url" in
    https://api.github.com/repos/rustdesk/rustdesk/releases*|https://api.github.com/repos/nljie1103/headless-desktop-manager/releases*) ;;
    *) hdm_error '拒绝未知 GitHub API 地址'; return 1;;
  esac
  curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 --connect-timeout 10 --max-time 35 --retry 1 -H 'Accept: application/vnd.github+json' -H 'User-Agent: hdm/0.1.1' -o "$dest" "$url"
}
hdm_release_query() {
  # Prints: tag TAB asset_name TAB digest TAB URL. Filter metadata rather than using guessed asset names.
  local repo=$1 mode=$2 version=${3:-} file
  [[ $repo == hdm || $repo == rustdesk ]] || return 1
  if [[ $repo == rustdesk ]]; then
    local base=$RUSTDESK_UPSTREAM_API_BASE
  else
    local base=$HDM_GITHUB_API_BASE
  fi
  file=$(mktemp) || return 1
  if [[ $mode == tag ]]; then
    [[ $version =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || { rm -f "$file"; return 1; }
    hdm_fetch_json "$base/releases/tags/$version" "$file" || { rm -f "$file"; return 1; }
  else
    hdm_fetch_json "$base/releases?per_page=40" "$file" || { rm -f "$file"; return 1; }
  fi
  python3 "$HDM_ROOT/core/release_parser.py" "$repo" "${mode}" "$(hdm_arch)" "$file"
  local ret=$?
  rm -f "$file"
  return "$ret"
}
hdm_list_mirror() {
  local ID VERSION_ID arch file
  [[ -r /etc/os-release ]] || return 1
  . /etc/os-release
  [[ ${ID:-} == ubuntu && ${VERSION_ID:-} =~ ^[0-9]+\.[0-9]+$ ]] || return 1
  arch=$(dpkg --print-architecture 2>/dev/null || :)
  file="$HDM_ROOT/packages/manifests/ubuntu-${VERSION_ID}-${arch}.tsv"
  if [[ -r $file ]]; then grep -v '^#' "$file" | grep -v '^$' || true; fi
}
hdm_mirror_rustdesk() {
  local entry name version arch sha url package path
  entry=$(hdm_list_mirror | awk -F '\t' '$1=="rustdesk" {print;exit}')
  [[ -n $entry ]] || { hdm_warn '目前没有已发布、带校验值的 RustDesk GitHub 备份包，不会虚构下载地址。'; return 1; }
  IFS=$'\t' read -r name version arch package url sha <<< "$entry"
  [[ $arch == "$(dpkg --print-architecture 2>/dev/null)" && $package == *.deb && $url == "$HDM_RELEASE_ASSET_BASE"/* ]] || return 1
  path="$HDM_CACHE/downloads/$package"
  hdm_download_verified "$url" "$path" "$sha" || return 1
  hdm_rustdesk_install_deb "$path"
}
