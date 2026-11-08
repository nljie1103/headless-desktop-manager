#!/usr/bin/env bash
# Formal release: archived + API SHA-256; preview main: GitHub HTTPS + immutable commit SHA.
# Neither GitHub-sourced hash is an independently signed trust anchor.
hdm_update_preview_metadata() {
  local file sha version
  file=$(mktemp) || return 1
  if ! curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 \
      --connect-timeout 10 --max-time 35 --retry 1 -H 'Accept: application/vnd.github+json' \
      -H 'User-Agent: HDM-preview-updater' -o "$file" \
      'https://api.github.com/repos/nljie1103/headless-desktop-manager/commits/main'; then
    rm -f -- "$file"; return 1
  fi
  sha=$(python3 - "$file" <<'PY_SHA'
import json, re, sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        data = json.load(f)
    sha = data.get('sha', '')
    if not isinstance(sha, str) or not re.fullmatch(r'[a-f0-9]{40}', sha):
        raise ValueError('missing pinned commit SHA')
    print(sha)
except (OSError, ValueError, TypeError):
    sys.exit(1)
PY_SHA
) || { rm -f -- "$file"; return 1; }
  rm -f -- "$file"
  version=$(curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 \
      --connect-timeout 10 --max-time 30 --retry 1 \
      "https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/$sha/VERSION") || return 1
  version=${version//$'\r'/}
  [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { hdm_warn '远端 VERSION 无效，拒绝更新。'; return 1; }
  printf '%s\t%s\n' "$version" "$sha"
}
hdm_update_newer() {
  python3 - "$1" "$2" <<'PY_VERSION'
import re, sys
v = sys.argv[1:]
if any(not re.fullmatch(r'\d+\.\d+\.\d+', x) for x in v):
    sys.exit(2)
sys.exit(0 if tuple(map(int, v[0].split('.'))) > tuple(map(int, v[1].split('.'))) else 1)
PY_VERSION
}
hdm_update_check() {
  hdm_show 'HDM 在线更新检查'
  printf '本地版本：v%s\n' "$HDM_VERSION"
  local release meta version sha found=0
  if release=$(hdm_release_query hdm latest); then
    printf '正式 Release：%s\n' "${release%%$'\t'*}"
    found=1
  else
    printf '正式 Release：尚未发布可验证安装包（并非安装故障）\n'
  fi
  if meta=$(hdm_update_preview_metadata); then
    IFS=$'\t' read -r version sha <<< "$meta"
    printf '开发分支 main：v%s（提交 %.12s）\n' "$version" "$sha"
    if hdm_update_newer "$version" "$HDM_VERSION"; then
      printf '检测到更新：菜单 8 → 更新脚本 → 安装更新 → 从 main 更新 可安装 main 更新。\n'
    else
      printf '本机版本不低于 main 版本；无须更新。\n'
    fi
    found=1
  else
    hdm_warn 'main 版本查询失败，请检查网络或 GitHub API 限流。'
  fi
  ((found == 1))
}
hdm_update_preview_install() {
  hdm_root || return 1
  for cmd in curl python3 tar mktemp flock; do command -v "$cmd" >/dev/null 2>&1 || { hdm_warn "缺少依赖：$cmd"; return 1; }; done
  local meta version sha archive base stage unpacked target lock_fd length
  meta=$(hdm_update_preview_metadata) || { hdm_warn '无法查询 GitHub main 版本。检查网络、DNS 或 GitHub API 限流。'; return 1; }
  IFS=$'\t' read -r version sha <<< "$meta"
  printf '当前 v%s / GitHub main v%s (%s)\n' "$HDM_VERSION" "$version" "${sha:0:12}"
  if ! hdm_update_newer "$version" "$HDM_VERSION"; then
    hdm_info '服务器已是同版本或更高版本。要更新代码必须先增加 VERSION。'
    return 0
  fi
  printf '来源：GitHub main 的固定提交 %s\n' "$sha"
  hdm_warn '当前更新来源为 GitHub main 的固定提交，通过 HTTPS 传输，未使用独立签名。'
  # Selecting Update is explicit consent to replace HDM code; no duplicate YES.
  base=${HDM_UPDATE_BASE:-/opt/hdm}
  [[ $base == /* && $base != / ]] || { hdm_error '非法 HDM 安装根目录'; return 1; }
  mkdir -p "$base/releases" || return 1
  exec {lock_fd}>"$base/.update.lock" || return 1
  if ! flock -n "$lock_fd"; then hdm_warn '另一个 HDM 更新正在运行'; exec {lock_fd}>&-; return 1; fi
  target="$base/releases/v$version"
  if [[ -e $target || -L $target ]]; then
    hdm_warn "已有同版本目录：$target。为避免覆盖，拒绝重复更新。"
    exec {lock_fd}>&-; return 1
  fi
  stage=$(mktemp -d "$base/.preview.XXXXXXXX") || { exec {lock_fd}>&-; return 1; }
  archive="$stage/preview.tar.gz"
  if ! curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 \
      --connect-timeout 15 --max-time 180 --retry 1 -o "$archive" \
      "https://codeload.github.com/nljie1103/headless-desktop-manager/tar.gz/$sha"; then
    hdm_warn '下载失败：检查连接 GitHub 的网络、DNS、代理或超时。'; rm -rf -- "$stage"; exec {lock_fd}>&-; return 1
  fi
  length=$(wc -c < "$archive")
  if ((length > 52428800)); then hdm_warn '下载体积异常（超过 50 MiB）'; rm -rf -- "$stage"; exec {lock_fd}>&-; return 1; fi
  if ! python3 "$HDM_ROOT/core/verify_archive.py" "$archive" "headless-desktop-manager-$sha"; then
    hdm_warn 'GitHub main 归档校验失败'; rm -rf -- "$stage"; exec {lock_fd}>&-; return 1
  fi
  mkdir -p "$stage/source"
  if ! tar -xzf "$archive" --strip-components=1 --no-same-owner --no-same-permissions -C "$stage/source"; then
    hdm_warn 'GitHub 快照解压失败'; rm -rf -- "$stage"; exec {lock_fd}>&-; return 1
  fi
  unpacked="$stage/source"
  if [[ ! -f "$unpacked/VERSION" || ! -f "$unpacked/hdm.sh" || ! -f "$unpacked/scripts/verify-menus.py" || $(cat "$unpacked/VERSION") != "$version" ]] ||
      ! bash -n "$unpacked/hdm.sh" || ! python3 "$unpacked/scripts/verify-menus.py" ||
      ! bash "$unpacked/hdm.sh" --self-test; then
    hdm_warn '下载的 HDM 代码未通过启动前自检，未切换当前版本。'
    rm -rf -- "$stage"; exec {lock_fd}>&-; return 1
  fi
  if ! mv -- "$unpacked" "$target"; then
    hdm_warn '写入新版本目录失败'; rm -rf -- "$stage"; exec {lock_fd}>&-; return 1
  fi
  chmod +x "$target/hdm.sh" "$target/install.sh" || :
  if ! ln -s "$target" "$base/.current.$$" || ! mv -Tf "$base/.current.$$" "$base/current"; then
    hdm_warn '原子切换失败；当前版本未确认改变，请检查 /opt/hdm/current。'
    rm -f -- "$base/.current.$$"; rm -rf -- "$stage"; exec {lock_fd}>&-; return 1
  fi
  rm -rf -- "$stage"
  exec {lock_fd}>&-
  hdm_info "HDM 已更新到 v$version（main ${sha:0:12}）；旧版本已保留。"
  printf '正在切换到新版 HDM 菜单...\n'
}
hdm_update_trusted_digest() {
  local tag=$1 digest=$2 manifest="$HDM_ETC/trusted-releases.tsv"
  # Owner must publish digest independently; in HDM it is explicitly configured locally.
  [[ -r $manifest ]] || return 1
  awk -F '\t' -v t="$tag" -v d="$digest" '$1==t && $2==d {ok=1}END{exit !ok}' "$manifest"
}
hdm_update_install() {
  local mode=${1:-latest} tag=${2:-} meta mtag asset digest url asset_id file staging release_dir
  hdm_root || return 1
  meta=$(hdm_release_query hdm "$mode" "$tag") || { hdm_warn '无法读取真实的 HDM Release，或者不存在匹配的发行包与哈希。'; return 1; }
  IFS=$'\t' read -r mtag asset digest url asset_id <<< "${meta%%$'\n'*}"
  if ! hdm_update_newer "${mtag#v}" "$HDM_VERSION"; then
    hdm_info "已经是 v$HDM_VERSION 或更高版本，不执行降级。需要回滚请使用菜单 8 → 更新脚本 → 回滚 HDM。"
    return 0
  fi
  if [[ -r $HDM_ETC/trusted-releases.tsv ]]; then
    if ! hdm_update_trusted_digest "$mtag" "$digest"; then
      hdm_warn "本地独立可信哈希与 GitHub Release 不符，拒绝更新 $mtag。"
      return 1
    fi
  else
    hdm_warn '未配置独立可信 SHA256；将通过 GitHub API 的资产摘要验证下载，安全性依赖 GitHub HTTPS/API。'
  fi
  file="$HDM_CACHE/downloads/$asset"
  hdm_download_verified "$url" "$file" "$digest" "$asset_id" || return 1
  # Verify extracted archive names before extraction; no absolute paths, .. or symlinks.
  if ! python3 "$HDM_ROOT/core/verify_archive.py" "$file"; then hdm_error 'Release tarball 内容不安全'; return 1; fi
  staging=$(mktemp -d /opt/hdm/.staging.XXXXXX) || return 1
  if ! tar -xzf "$file" --no-same-owner --no-same-permissions -C "$staging"; then rm -rf "$staging"; return 1; fi
  [[ -f $staging/headless-desktop-manager/VERSION && -f $staging/headless-desktop-manager/hdm.sh ]] || { rm -rf "$staging"; return 1; }
  [[ $(cat "$staging/headless-desktop-manager/VERSION") == "${mtag#v}" ]] || { rm -rf "$staging"; return 1; }
  bash -n "$staging/headless-desktop-manager/hdm.sh" || { rm -rf "$staging"; return 1; }
  hdm_danger "将 HDM 更新为 $mtag，受影响的是管理器代码而不是 GNOME/RustDesk，确定继续？" || { rm -rf "$staging"; return 2; }
  release_dir="/opt/hdm/releases/$mtag"
  [[ ! -e $release_dir ]] || { rm -rf "$staging"; hdm_warn '版本目录已经存在，未覆盖。'; return 1; }
  mkdir -p /opt/hdm/releases
  mv "$staging/headless-desktop-manager" "$release_dir"
  rmdir "$staging" || :
  ln -s "$release_dir" "/opt/hdm/.current.$$"
  mv -Tf "/opt/hdm/.current.$$" /opt/hdm/current
  hdm_info "HDM 已切换至 $mtag。旧版本目录保留，支持回滚。"
}
hdm_update_rollback() {
  local version target
  hdm_root || return 1
  printf '已安装的 HDM 版本：\n'
  find /opt/hdm/releases -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null || :
  hdm_prompt '输入要回滚的版本（如 v0.1.0）：' version || return 1
  [[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  target="/opt/hdm/releases/$version"
  [[ -f $target/hdm.sh && -f $target/VERSION && $(cat "$target/VERSION") == "${version#v}" ]] || return 1
  bash -n "$target/hdm.sh" || return 1
  hdm_danger "回滚管理器代码至 $version？" || return 2
  ln -s "$target" "/opt/hdm/.current.$$" && mv -Tf "/opt/hdm/.current.$$" /opt/hdm/current
  hdm_info "已切换到 $version；下一次 sudo hdm 生效。"
}
hdm_update_list() { hdm_release_query hdm list || hdm_warn '暂未找到正式 Release。'; }
hdm_update_integrity() {
  local errors=0 file
  for file in "$HDM_ROOT/hdm.sh" "$HDM_ROOT/ui/menus.tsv" "$HDM_ROOT/core/common.sh" "$HDM_ROOT/modules/display/display.sh" "$HDM_ROOT/modules/desktop/desktop.sh" "$HDM_ROOT/modules/rustdesk/rustdesk.sh"; do
    [[ -s $file ]] || { hdm_warn "文件缺失：$file"; errors=$((errors+1)); }
  done
  [[ $errors -eq 0 ]] && hdm_info '核心文件存在。该检测不代替 Release 签名校验。' || return 1
}
