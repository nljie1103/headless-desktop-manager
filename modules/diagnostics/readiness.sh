#!/usr/bin/env bash
# Read-only inventory. Package presence, service state, persisted settings, and
# graphical user sessions are independent dimensions; never collapse them.
hdm_readiness_pkg() {
  local package=$1 title=$2 required=${3:-1}
  if hdm_installed "$package"; then
    printf '[已安装] %-23s %s\n' "$title" "$(hdm_pkg_version "$package")"
  elif [[ $required == 1 ]]; then
    printf '[待安装] %-23s 软件包 %s\n' "$title" "$package"
    HDM_READINESS_MISSING=$((HDM_READINESS_MISSING+1))
  else
    printf '[未选装] %-23s %s\n' "$title" "$package"
  fi
}
hdm_readiness_rustdesk_config() {
  local file=$1 label=$2
  [[ -f $file ]] || { printf '[待配置] %-23s 配置文件不存在\n' "$label"; return 1; }
  [[ -r $file ]] || { printf '[待核实] %-23s 权限不足，无法读取\n' "$label"; return 2; }
  if python3 - "$file" <<'PY' >/dev/null 2>&1
import pathlib, sys, tomllib
with pathlib.Path(sys.argv[1]).open('rb') as stream:
    data = tomllib.load(stream)
options = data.get('options') or {}
if not isinstance(options,dict): raise ValueError('options is not a table')
ident = options.get('custom-rendezvous-server') or data.get('rendezvous_server')
relay = options.get('relay-server') or data.get('relay-server')
key = options.get('key') or data.get('key')
if not all(isinstance(x,str) and x.strip() for x in (ident,relay,key)):
    raise ValueError('incomplete server configuration')
PY
  then
    printf '[已配置] %-23s 服务器地址及公钥已写入配置文件\n' "$label"
    return 0
  fi
  printf '[待配置] %-23s 服务器地址/中继/公钥未填写完整，或 TOML 格式无效\n' "$label"
  return 1
}
hdm_readiness_report() {
  local desktop connector session gnome_session svc mem_kib user_profile user_file='' preferred
  HDM_READINESS_MISSING=0
  desktop=$(hdm_env_desktop_kind)
  connector=$(hdm_env_drm_state)
  session=$(hdm_env_active_session)
  gnome_session=$(hdm_env_gnome_session)
  mem_kib=$(awk '/^MemTotal:/ {print $2;exit}' /proc/meminfo 2>/dev/null || :)
  preferred=GNOME
  if [[ $mem_kib =~ ^[0-9]+$ ]] && ((mem_kib < 4194304)); then preferred=XFCE; fi
  printf 'HDM 部署检查｜%s / %s\n' "$(hdm_os)" "$(hdm_arch)"
  printf '%s\n' '──────────────────────────────────────────────────'
  printf '桌面组件\n'
  case "$desktop" in
    GNOME)
      hdm_readiness_pkg gnome-shell 'GNOME Shell'
      hdm_readiness_pkg gnome-session-bin 'GNOME Session'
      hdm_readiness_pkg gdm3 'GDM3 登录管理器'
      if hdm_gnome_wayland_only; then
        hdm_readiness_pkg pipewire 'PipeWire'
        hdm_readiness_pkg xdg-desktop-portal 'Desktop Portal'
        hdm_readiness_pkg xdg-desktop-portal-gnome 'GNOME Portal'
      fi
      ;;
    XFCE)
      hdm_readiness_pkg xfce4-session 'XFCE 会话'
      hdm_readiness_pkg lightdm 'LightDM 登录管理器'
      ;;
    MATE)
      hdm_readiness_pkg mate-session-manager 'MATE 会话'
      hdm_readiness_pkg lightdm 'LightDM 登录管理器'
      ;;
    KDE)
      hdm_readiness_pkg plasma-desktop 'Plasma 桌面'
      ;;
    *)
      printf '[待安装] 桌面环境                 尚未检测到完整桌面，建议 %s\n' "$preferred"
      HDM_READINESS_MISSING=$((HDM_READINESS_MISSING+1))
      if [[ $preferred == GNOME ]]; then
        hdm_readiness_pkg gdm3 'GDM3 登录管理器'
      else
        hdm_readiness_pkg lightdm 'LightDM 登录管理器'
      fi
      ;;
  esac
  printf '\n显示与图形会话\n'
  case "$connector" in
    connected) printf '[已检测] DRM 输出                 内核报告有已连接输出\n';;
    not-connected) printf '[待配置] DRM 输出                 未检测到已连接输出；需检查 VKMS/显示能力\n';;
    *) printf '[待检查] DRM 输出                 设备信息不足，不能判断是否有可用屏幕\n';;
  esac
  case "$desktop" in
    GNOME) svc=gdm3;; XFCE|MATE) svc=lightdm;; *) svc='';;
  esac
  if [[ -n $svc ]]; then
    case "$(hdm_service_state "$svc")" in
      active) printf '[服务运行] %-23s active\n' "$svc";;
      *) printf '[待启动] %-23s 登录管理器尚未正常运行\n' "$svc";;
    esac
  fi
  case "$session" in
    wayland|x11) printf '[会话运行] 图形用户会话           %s\n' "$session";;
    none) printf '[未建立] 图形用户会话           未发现活动的 X11/Wayland 用户会话\n';;
    *) printf '[待检查] 图形用户会话           登录管理器或 logind 信息不足\n';;
  esac
  if [[ $desktop == GNOME ]]; then
    case "$gnome_session" in
      x11|wayland) printf '[GNOME 会话] GNOME 用户会话         %s（外部画面仍待验证）\n' "$gnome_session";;
      none) printf '[未建立] GNOME 用户会话         没有已确认的 GNOME 会话；其他桌面会话不能代替\n';;
      *) printf '[待检查] GNOME 用户会话         桌面类型或会话数据不足\n';;
    esac
  fi
  printf '\n远程控制\n'
  hdm_readiness_pkg rustdesk 'RustDesk 客户端'
  case "$(hdm_service_state rustdesk)" in
    active) printf '[服务运行] RustDesk 后台           active\n';;
    *) printf '[待启动] RustDesk 后台           服务未运行\n';;
  esac
  if [[ $EUID == 0 ]]; then
    hdm_readiness_rustdesk_config "$(hdm_rustdesk_root_config)" 'root 服务器配置' || :
    if user_profile=$(hdm_rustdesk_login_profile); then
      user_file=${user_profile%%$'\t'*}
      hdm_readiness_rustdesk_config "$user_file" '登录用户服务器配置' || :
    fi
  else
    printf '[待检查] RustDesk 服务器配置     使用 sudo 运行可检查受限配置文件\n'
  fi
  printf '[待实测] 远程画面                 请从另一台设备完成真实连接验证\n'
  printf '\n可选显示组件\n'
  hdm_readiness_pkg xserver-xorg-video-dummy 'Xorg Dummy' 0
  hdm_readiness_pkg xvfb 'Xvfb' 0
  printf '\n建议\n'
  if ((HDM_READINESS_MISSING > 0)); then
    printf '有 %s 项必需软件包待补齐。通过菜单 9 查看安装计划。\n' "$HDM_READINESS_MISSING"
  else
    printf '本机目标桌面的必需软件包检查完成；继续核实服务、会话和远端画面。\n'
  fi
  if [[ $desktop == GNOME && $gnome_session != x11 && $gnome_session != wayland ]]; then
    printf 'GNOME 会话尚未确认：运行 sudo hdm --session-status 查看原因。\n'
  elif [[ $session != x11 && $session != wayland ]]; then
    printf '图形会话未确认：运行 sudo hdm --session-status 查看原因。\n'
  fi
  printf '上述操作为只读检测，没有改变系统。\n'
}
