#!/usr/bin/env bash
# Transaction snapshots: only HDM-owned or explicitly allowed system files.
hdm_backup_allow() {
  case "$1" in
    /etc/X11/xorg.conf.d/20-hdm-dummy.conf|/etc/gdm3/custom.conf|/etc/modules-load.d/hdm-vkms.conf|/etc/systemd/system/hdm-xvfb.service|/etc/hdm/config.conf|/etc/lightdm/lightdm.conf.d/90-hdm.conf|/etc/gdm3/daemon.conf) return 0;;
    /root/.config/rustdesk/RustDesk2.toml|/root/.config/rustdesk/RustDesk.toml) return 0;;
    /home/*/.config/rustdesk/RustDesk2.toml)
      # Allow only a real account's own config path, never an arbitrary home file.
      local username home
      username=${1#/home/}; username=${username%%/*}
      [[ $username =~ ^[a-z_][a-z0-9_-]*$ ]] || return 1
      home=$(getent passwd "$username" 2>/dev/null | cut -d: -f6)
      [[ $home == "/home/$username" && $1 == "$home/.config/rustdesk/RustDesk2.toml" ]] ;;

    *) return 1;;
  esac
}
hdm_snapshot_create() {
  hdm_root || return 1
  local id dir path
  id="$(date -u +%Y%m%dT%H%M%SZ)-$RANDOM"
  dir="$HDM_STATE/backups/$id"
  mkdir -p "$dir/files" || return 1
  chmod 700 "$dir" "$dir/files"
  : > "$dir/manifest.tsv"
  for path in "$@"; do
    hdm_backup_allow "$path" || { hdm_error "禁止备份未授权路径：$path"; return 1; }
    if [[ -e $path ]]; then
      mkdir -p "$dir/files$(dirname -- "$path")"
      cp -a -- "$path" "$dir/files$path" || return 1
      printf '%s\tpresent\n' "$path" >> "$dir/manifest.tsv"
    else
      printf '%s\tmissing\n' "$path" >> "$dir/manifest.tsv"
    fi
  done
  chmod 600 "$dir/manifest.tsv"
  HDM_LAST_SNAPSHOT=$id
  hdm_info "配置快照已创建：$id"
}
hdm_snapshots() { if [[ -d $HDM_STATE/backups ]]; then find "$HDM_STATE/backups" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | head -30; fi; }
hdm_snapshot_restore() {
  hdm_root || return 1
  local id=$1 path status
  [[ $id =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]+$ && -r $HDM_STATE/backups/$id/manifest.tsv ]] || { hdm_error '无效快照'; return 1; }
  while IFS=$'\t' read -r path status; do
    hdm_backup_allow "$path" || { hdm_error "快照包含非法路径 $path"; return 1; }
    case "$status" in
      present)
        [[ -f $HDM_STATE/backups/$id/files$path ]] || return 1
        mkdir -p "$(dirname -- "$path")"
        cp -a -- "$HDM_STATE/backups/$id/files$path" "$path" || return 1
        ;;
      missing) rm -f -- "$path" || return 1 ;;
      *) return 1 ;;
    esac
  done < "$HDM_STATE/backups/$id/manifest.tsv"
  hdm_info "快照 $id 已还原。相关服务可能需要重启；仍需实际验证。"
}
hdm_snapshot_choose() {
  local id
  hdm_snapshots
  hdm_prompt '输入要恢复的快照 ID：' id || return 1
  hdm_danger "恢复快照 $id 会覆盖当前配置" || return 0
  hdm_snapshot_restore "$id"
}
hdm_recovery_arm() {
  # Persistent across reboot. Timer triggers ~7 minutes after activation or boot.
  local id=$1
  hdm_root || return 1
  [[ $id =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]+$ ]] || return 1
  printf '%s\n' "$id" > "$HDM_STATE/pending-rollback"
  chmod 600 "$HDM_STATE/pending-rollback"
  install -m 644 "$HDM_ROOT/templates/systemd/hdm-recovery.service" /etc/systemd/system/hdm-recovery.service
  install -m 644 "$HDM_ROOT/templates/systemd/hdm-recovery.timer" /etc/systemd/system/hdm-recovery.timer
  systemctl daemon-reload
  systemctl enable --now hdm-recovery.timer
  # Restart the timer to ensure a new seven-minute window on every high-risk change.
  systemctl restart hdm-recovery.timer
  hdm_warn '已启动安全回滚计时器。操作后请运行 sudo hdm --confirm-display 确认画面可用，否则约7分钟后自动恢复备份。'
}
hdm_recovery_confirm() { hdm_root || return 1; rm -f "$HDM_STATE/pending-rollback"; systemctl disable --now hdm-recovery.timer >/dev/null 2>&1 || :; hdm_info '已确认保留当前显示配置，取消待执行回滚。'; }
hdm_recovery_rollback_pending() {
  hdm_root || return 1
  local id
  [[ -r $HDM_STATE/pending-rollback ]] || return 0
  id=$(cat "$HDM_STATE/pending-rollback")
  hdm_snapshot_restore "$id" || return 1
  rm -f "$HDM_STATE/pending-rollback"
  systemctl try-restart gdm3 >/dev/null 2>&1 || :
  hdm_warn "自动回滚已执行（快照 $id）。"
}
