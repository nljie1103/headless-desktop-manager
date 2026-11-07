#!/usr/bin/env bash
hdm_update_check() {
  hdm_show 'HDM 更新'
  printf '本地版本：%s\n' "$HDM_VERSION"
  local release
  release=$(hdm_release_query hdm latest) || { hdm_warn '未找到可验证的 HDM 项目正式 Release。镜像资产不会被当成项目更新。'; return 1; }
  printf 'GitHub 已发布：%s\n' "${release%%$'\t'*}"
  printf '下载资源：%s\n' "$(printf '%s' "$release" | cut -f2)"
  printf '注意：Release API 自带 SHA256 不等于独立的签名信任锚。\n'
}
hdm_update_trusted_digest() {
  local tag=$1 digest=$2 manifest="$HDM_ETC/trusted-releases.tsv"
  # Owner must publish digest independently; in HDM it is explicitly configured locally.
  [[ -r $manifest ]] || return 1
  awk -F '\t' -v t="$tag" -v d="$digest" '$1==t && $2==d {ok=1}END{exit !ok}' "$manifest"
}
hdm_update_install() {
  local mode=${1:-latest} tag=${2:-} meta mtag asset digest url file staging release_dir
  hdm_root || return 1
  meta=$(hdm_release_query hdm "$mode" "$tag") || { hdm_warn '无法读取真实的 HDM Release，或者不存在匹配的发行包与哈希。'; return 1; }
  IFS=$'\t' read -r mtag asset digest url <<< "${meta%%$'\n'*}"
  if ! hdm_update_trusted_digest "$mtag" "$digest"; then
    hdm_warn "尚未为 $mtag 配置经独立渠道核实的受信任 SHA256。为了防止自更新供应链劫持，拒绝自动升级。"
    hdm_warn "请先独立核对发布资产哈希，再在 $HDM_ETC/trusted-releases.tsv 添加：<tag><TAB><sha256>。"
    return 1
  fi
  file="$HDM_CACHE/downloads/$asset"
  hdm_download_verified "$url" "$file" "$digest" || return 1
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
