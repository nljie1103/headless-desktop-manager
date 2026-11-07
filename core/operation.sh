#!/usr/bin/env bash
# Quiet package operations: keep full output in a protected log, show a short result.
# HDM_DEBUG_INSTALL=1 opts into historical verbose output for diagnosis.
hdm_failure_reason() {
  local file=${1:-} code=${2:-1}
  [[ -r $file ]] || { printf '未知错误（退出码 %s）' "$code"; return; }
  if grep -Eqi 'No space left on device|not enough free space|write error.*space|磁盘空间不足|空间不足' "$file"; then printf '磁盘空间不足'
  elif grep -Eqi 'BADSIG|NO_PUBKEY|EXPKEYSIG|GPG error|not signed|signature verification|Hash Sum mismatch' "$file"; then printf '软件源签名/完整性校验失败（已停止，不绕过校验）'
  elif grep -Eqi 'Temporary failure resolving|Could not resolve|Name or service not known|Name resolution|Could not resolve host' "$file"; then printf '网络/DNS 解析失败'
  elif grep -Eqi 'timed out|Timeout was reached|Connection timed out|Operation too slow' "$file" || [[ $code == 124 ]]; then printf '网络连接超时'
  elif grep -Eqi '404[[:space:]]+Not Found|Failed to fetch.*404|does not have a Release file|Release file.*not found' "$file"; then printf '镜像站/软件源资源不存在（404）'
  elif grep -Eqi 'Network is unreachable|Connection refused|Connection failed|Failed to connect|TLS connection|SSL connection' "$file"; then printf '网络连接失败'
  elif grep -Eqi 'Unable to correct problems|held broken packages|unmet dependencies|Depends:|Conflicts:|dpkg: error processing|subprocess installed.*error' "$file"; then printf '依赖冲突或软件包配置失败'
  elif grep -Eqi 'Permission denied|Operation not permitted|Could not open lock file' "$file"; then printf '权限不足或软件包管理器被占用'
  else printf '安装命令失败（退出码 %s，详情见日志）' "$code"; fi
}
hdm_operation_begin() {
  local title=$1
  [[ -d $HDM_LOG_DIR ]] || mkdir -p "$HDM_LOG_DIR" || return 1
  HDM_LAST_OPERATION_LOG=$(mktemp "$HDM_LOG_DIR/operation-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX.log") || return 1
  chmod 600 "$HDM_LAST_OPERATION_LOG"
  printf '  ⏳ %s ...
' "$title"
}
hdm_operation_exec() {
  local log=$1; shift
  if [[ ${HDM_DEBUG_INSTALL:-0} == 1 ]]; then
    "$@" 2>&1 | tee -a "$log"
    return "${PIPESTATUS[0]}"
  fi
  "$@" >>"$log" 2>&1
}
hdm_operation_ok() {
  printf '  [成功] %s
' "$1"
  if [[ ${HDM_DEBUG_INSTALL:-0} != 1 ]]; then
    # Do not delete the log; useful for a later bug report.
    :
  fi
}
hdm_operation_failed() {
  local label=$1 code=${2:-1} reason
  reason=$(hdm_failure_reason "$HDM_LAST_OPERATION_LOG" "$code")
  printf '  [失败] %s：%s
  日志：%s
' "$label" "$reason" "$HDM_LAST_OPERATION_LOG" >&2
  HDM_LAST_FAILURE_REASON=$reason
  return "$code"
}
hdm_run_quiet() {
  local label=$1 rc=0; shift
  hdm_operation_begin "$label" || return 1
  hdm_operation_exec "$HDM_LAST_OPERATION_LOG" "$@" || rc=$?
  if ((rc==0)); then hdm_operation_ok "$label"; else hdm_operation_failed "$label" "$rc"; fi
}
