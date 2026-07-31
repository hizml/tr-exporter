#!/bin/sh
# export-torrents.sh — 按 Tracker 批量导出 Transmission / qBittorrent 的 .torrent 种子文件
# 交互式 + 非交互式(命令行参数)；支持增量导出、进度导出、导出小结报告、中英文切换。
# 适用：Docker / QNAP Container Station 终端等无 SSH 场景，或任意能访问 Web API 的环境。

VERSION="1.5.0"
REPO_RAW="https://raw.githubusercontent.com/hizml/torrent-toolkit/main/export-torrents.sh"
REPO_API="https://api.github.com/repos/hizml/torrent-toolkit/releases/latest"

# ============================================================
# i18n: 把所有提示文案抽成变量，开头选语言后全程使用该语言
# LANG_I18N: zh=中文, en=English
# ============================================================
set_lang() {
  case "$1" in
    en)
      T_TITLE="===== Torrent Exporter (Transmission / qBittorrent) ====="
      T_CLIENT="Select client"
      T_TR="Transmission"; T_QB="qBittorrent"
      T_CLIENT_PROMPT="Enter number (empty=1): "
      T_WEB="Web address"
      T_HOST_PRESETS="Common host presets:"
      T_HOST1="127.0.0.1   (inside container, most common)"
      T_HOST2="localhost"
      T_HOST3="Custom IP / domain (e.g. NAS LAN IP)"
      T_HOST_PROMPT="Choose number or enter host (empty=1): "
      T_HOST_INPUT="    Enter host IP/domain: "
      T_PORT_PROMPT="Port (empty=default %s): "
      T_AUTH="Auth"
      T_USER_PROMPT="Username (empty=no auth): "
      T_PASS_PROMPT="Password: "
      T_SKIP_AUTH="  -> skip auth"
      T_USE="  -> using:"
      T_INSTALL_JQ="Installing jq..."
      T_JQ_FAIL="ERROR: cannot install jq, please install manually"
      T_CONNECTING="Connecting..."
      T_CONNECT_OK="Connected, %s torrents total"
      T_CONNECT_FAIL="ERROR: connection failed, check address/port/credentials"
      T_LOGIN_FAIL="ERROR: login failed:"
      T_LOCATE_TORRENTS="Locating torrents dir..."
      T_LOCATE_FAIL="ERROR: auto-detect failed, enter torrents dir path (empty=cancel): "
      T_CANCELLED="Cancelled"
      T_TORRENTS_DIR="Torrents dir:"
      T_TRACKER_LIST="===== Tracker list (with counts) ====="
      T_NO_TRACKER="(no tracker)"
      T_EXPORT_ALL="Export all"
      T_SELECT_PROMPT="Choose number / keyword / enter a for all: "
      T_OUT_OF_RANGE="  WARN: out of range (1-%s), retry"
      T_NOT_EMPTY="  WARN: empty not allowed, enter number/keyword/a"
      T_SELECT="  -> select:"
      T_EXPORT_ALL_MSG="  -> export all"
      T_KEYWORD="  -> keyword:"
      T_RESUME_TITLE="Progress"
      T_RESUME_TR="progress files (.resume, for same-version Transmission migration)"
      T_RESUME_QB="progress files (.fastresume, for qBittorrent migration)"
      T_RESUME_PROMPT="Also export %s? (y/N): "
      T_RESUME_NO_DIR="  WARN: progress dir not auto-located, enter path (empty=skip): "
      T_RESUME_SKIP="  -> skip progress export"
      T_RESUME_EXPORT="  -> export progress:"
      T_OK="[OK]  "; T_MISS="[MISS]"; T_FAIL="[FAIL]"
      T_RESUME_TAG=" +resume"; T_NO_RESUME=" [no-resume]"
      T_SKIP_TAG=" [skip]"
      T_DONE="===== Done ====="
      T_OUT_DIR="Output dir:"
      T_COUNT_TORRENT="Torrents: %s"
      T_COUNT_RESUME="Progress files: %s"
      T_SKIPPED="Skipped (already exported): %s"
      T_ZIPPED="Zipped:"
      T_ZIP_HINT="-> Download this single zip via file manager (FileStation) to avoid missing files."
      T_NO_ZIP="Tip: zip not installed, download folder directly:"
      T_LANG_TITLE="Language / 语言"
      T_LANG_PROMPT="Enter number (empty=1): "
      T_REPORT_TITLE="Export report"
      T_REPORT_TIME="Time:"; T_REPORT_CLIENT="Client:"; T_REPORT_TRACKER="Tracker:"
      T_REPORT_OUT="Output:"; T_REPORT_MISS="Missing torrents:"; T_REPORT_FAIL="Failed:"
      T_VERSION_CUR="Current version: %s"
      T_VERSION_CHK="Checking for updates..."
      T_VERSION_LATEST="Latest: %s"
      T_VERSION_NEW="New version available! Run with --update to upgrade."
      T_VERSION_OK="Already up to date."
      T_VERSION_ERR="Update check failed (no network?), skipped."
      ;;
    *)  # zh 中文
      T_TITLE="===== 种子导出工具 (Transmission / qBittorrent) ====="
      T_CLIENT="选择客户端"
      T_TR="Transmission"; T_QB="qBittorrent"
      T_CLIENT_PROMPT="选择序号 (留空=默认 1): "
      T_WEB="Web 地址"
      T_HOST_PRESETS="常见主机预设："
      T_HOST1="127.0.0.1   (容器内本机，最常用)"
      T_HOST2="localhost"
      T_HOST3="自定义 IP / 域名  (例如 NAS 局域网 IP，从容器外访问)"
      T_HOST_PROMPT="选择序号或直接输入主机 (留空=默认 1): "
      T_HOST_INPUT="    请输入主机 IP/域名: "
      T_PORT_PROMPT="端口 (留空=默认 %s): "
      T_AUTH="认证"
      T_USER_PROMPT="用户名 (无认证可留空): "
      T_PASS_PROMPT="密码: "
      T_SKIP_AUTH="  → 跳过认证"
      T_USE="  → 使用:"
      T_INSTALL_JQ="正在安装 jq..."
      T_JQ_FAIL="❌ 无法安装 jq，请手动安装后重试"
      T_CONNECTING="正在连接..."
      T_CONNECT_OK="✅ 连接成功，共 %s 个种子"
      T_CONNECT_FAIL="❌ 连接失败，请检查地址 / 端口 / 账号 / 密码"
      T_LOGIN_FAIL="❌ 登录失败:"
      T_LOCATE_TORRENTS="正在定位种子目录..."
      T_LOCATE_FAIL="❌ 自动定位失败，请手动输入 torrents 目录路径 (留空取消): "
      T_CANCELLED="已取消"
      T_TORRENTS_DIR="种子目录:"
      T_TRACKER_LIST="===== Tracker 列表 (含种子数) ====="
      T_NO_TRACKER="(无 tracker)"
      T_EXPORT_ALL="全部导出"
      T_SELECT_PROMPT="选择序号 / 关键字 / 输入 a 全部导出: "
      T_OUT_OF_RANGE="  ⚠️ 序号超出范围 (1-%s)，请重新输入"
      T_NOT_EMPTY="  ⚠️ 不能留空，输入序号 / 关键字 / a(全部)"
      T_SELECT="→ 选择:"
      T_EXPORT_ALL_MSG="→ 全部导出"
      T_KEYWORD="→ 关键字:"
      T_RESUME_TITLE="进度"
      T_RESUME_TR="进度文件 (.resume，用于同版本 Transmission 迁移)"
      T_RESUME_QB="进度文件 (.fastresume，用于 qBittorrent 迁移)"
      T_RESUME_PROMPT="【进度】是否同时导出 %s? (y/N): "
      T_RESUME_NO_DIR="  ⚠️ 未自动定位到进度目录，请手动输入路径 (留空=跳过进度): "
      T_RESUME_SKIP="  → 跳过进度导出"
      T_RESUME_EXPORT="  → 导出进度:"
      T_OK="[OK]  "; T_MISS="[MISS]"; T_FAIL="[FAIL]"
      T_RESUME_TAG=" +resume"; T_NO_RESUME=" [no-resume]"
      T_SKIP_TAG=" [跳过]"
      T_DONE="===== 完成 ====="
      T_OUT_DIR="导出目录:"
      T_COUNT_TORRENT="种子数量: %s 个"
      T_COUNT_RESUME="进度文件: %s 个"
      T_SKIPPED="跳过已导出: %s 个"
      T_ZIPPED="已打包:"
      T_ZIP_HINT="→ 用文件管理器(FileStation 等)下载这一个 zip 文件即可，避免多选下载漏文件。"
      T_NO_ZIP="提示: 未安装 zip，请在文件管理器中直接下载文件夹"
      T_LANG_TITLE="语言 / Language"
      T_LANG_PROMPT="选择序号 (留空=默认 1): "
      T_REPORT_TITLE="导出报告"
      T_REPORT_TIME="导出时间:"; T_REPORT_CLIENT="客户端:"; T_REPORT_TRACKER="Tracker:"
      T_REPORT_OUT="导出目录:"; T_REPORT_MISS="缺失种子:"; T_REPORT_FAIL="导出失败:"
      T_VERSION_CUR="当前版本: %s"
      T_VERSION_CHK="正在检查更新..."
      T_VERSION_LATEST="最新版本: %s"
      T_VERSION_NEW="发现新版本！用 --update 升级。"
      T_VERSION_OK="已是最新版本。"
      T_VERSION_ERR="检查更新失败 (无网络?)，已跳过。"
      ;;
  esac
}

# ============================================================
# 参数解析: 支持 --lang --client --host --port --user --tracker --resume --incr --out --update --help
# 提供的参数会跳过对应交互(混合模式)
# ============================================================
P_LANG=""; P_CLIENT=""; P_HOST=""; P_PORT=""; P_USER=""
P_TRACKER=""; P_RESUME=""; P_INCR=0; P_OUT=""; P_UPDATE=0; P_HELP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --lang)      P_LANG="$2"; shift 2 ;;
    --lang=*)    P_LANG="${1#--lang=}"; shift ;;
    --client)    P_CLIENT="$2"; shift 2 ;;
    --client=*)  P_CLIENT="${1#--client=}"; shift ;;
    --host)      P_HOST="$2"; shift 2 ;;
    --host=*)    P_HOST="${1#--host=}"; shift ;;
    --port)      P_PORT="$2"; shift 2 ;;
    --port=*)    P_PORT="${1#--port=}"; shift ;;
    --user)      P_USER="$2"; shift 2 ;;
    --user=*)    P_USER="${1#--user=}"; shift ;;
    --tracker)   P_TRACKER="$2"; shift 2 ;;
    --tracker=*) P_TRACKER="${1#--tracker=}"; shift ;;
    --resume)    P_RESUME="y"; shift ;;
    --no-resume) P_RESUME="n"; shift ;;
    --incr)      P_INCR=1; shift ;;
    --out)       P_OUT="$2"; shift 2 ;;
    --out=*)     P_OUT="${1#--out=}"; shift ;;
    --update)    P_UPDATE=1; shift ;;
    --help|-h)   P_HELP=1; shift ;;
    *) echo "Unknown option: $1" >&2; P_HELP=1; shift ;;
  esac
done

if [ "$P_HELP" = "1" ]; then
  cat <<USAGE
export-torrents.sh v$VERSION
Usage: sh export-torrents.sh [OPTIONS]
  Interactive mode by default; options skip corresponding prompts.

Options:
  --lang zh|en        Language (zh=Chinese, en=English)
  --client tr|qb      Client: tr=Transmission, qb=qBittorrent
  --host HOST         Web host (e.g. 127.0.0.1)
  --port PORT         Web port (default: tr=9091, qb=8080)
  --user USER:PASS    Auth credentials (user:password)
  --tracker KEY       Tracker keyword, 'a' for all, or '__NONE__' for no-tracker
  --resume            Also export progress files
  --no-resume         Skip progress files (default)
  --incr              Incremental: skip already-exported torrents
  --out DIR           Output directory
  --update            Update this script to the latest release
  --help              Show this help
USAGE
  exit 0
fi

# --update: 自更新
if [ "$P_UPDATE" = "1" ]; then
  set_lang "${P_LANG:-zh}"
  printf "$T_VERSION_CUR\n" "$VERSION"
  echo "$T_VERSION_CHK"
  LATEST=$(curl -fsSL "$REPO_API" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null)
  if [ -z "$LATEST" ]; then echo "$T_VERSION_ERR"; exit 0; fi
  LATEST=${LATEST#v}
  printf "$T_VERSION_LATEST\n" "$LATEST"
  if [ "$LATEST" != "$VERSION" ]; then
    echo "$T_VERSION_NEW"
    SCRIPT_PATH="$0"
    [ "$SCRIPT_PATH" = "sh" ] && SCRIPT_PATH=""
    if [ -n "$SCRIPT_PATH" ] && [ -w "$SCRIPT_PATH" ]; then
      cp "$SCRIPT_PATH" "${SCRIPT_PATH}.bak"
      if curl -fsSL "$REPO_RAW" -o "$SCRIPT_PATH" 2>/dev/null; then
        echo "Updated: $SCRIPT_PATH (backup: ${SCRIPT_PATH}.bak)"
      else
        cp "${SCRIPT_PATH}.bak" "$SCRIPT_PATH"; echo "Download failed, restored."
      fi
    else
      echo "Run: curl -fsSL $REPO_RAW -o export-torrents.sh"
    fi
  else
    echo "$T_VERSION_OK"
  fi
  exit 0
fi

# ============================================================
# 0. 选语言
# ============================================================
echo "$T_TITLE"
echo
if [ -z "$P_LANG" ]; then
  echo "$T_LANG_TITLE"
  echo "   1) 中文"
  echo "   2) English"
  printf "$T_LANG_PROMPT"
  read LANG_INPUT
  case "$LANG_INPUT" in
    2|en|EN) P_LANG="en" ;;
    *)       P_LANG="zh" ;;
  esac
fi
set_lang "$P_LANG"
echo

# ============================================================
# 1. 选客户端
# ============================================================
if [ -z "$P_CLIENT" ]; then
  echo "【$T_CLIENT】"
  echo "   1) $T_TR"
  echo "   2) $T_QB"
  printf "$T_CLIENT_PROMPT"
  read CLIENT_INPUT
  case "$CLIENT_INPUT" in
    2|qb|QB) CLIENT="qb" ;;
    *)       CLIENT="tr" ;;
  esac
else
  case "$P_CLIENT" in
    qb|QB|2) CLIENT="qb" ;;
    *)       CLIENT="tr" ;;
  esac
fi
[ "$CLIENT" = "qb" ] && echo "  → $T_QB" || echo "  → $T_TR"
echo

# ============================================================
# 2. 地址 + 端口
# ============================================================
if [ -z "$P_HOST" ]; then
  echo "【$T_WEB】"
  echo "  $T_HOST_PRESETS"
  echo "   1) $T_HOST1"
  echo "   2) $T_HOST2"
  echo "   3) $T_HOST3"
  printf "$T_HOST_PROMPT"
  read HOST_INPUT
  case "$HOST_INPUT" in
    ""|1) HOST="127.0.0.1" ;;
    2)    HOST="localhost" ;;
    3)    printf "$T_HOST_INPUT"; read HOST ;;
    *)    HOST="$HOST_INPUT" ;;
  esac
else
  HOST="$P_HOST"
fi

# 默认端口
if [ "$CLIENT" = "qb" ]; then DEFAULT_PORT="8080"; else DEFAULT_PORT="9091"; fi
if [ -z "$P_PORT" ]; then
  printf "$T_PORT_PROMPT" "$DEFAULT_PORT"
  read PORT_INPUT
  [ -z "$PORT_INPUT" ] && PORT_INPUT="$DEFAULT_PORT"
else
  PORT_INPUT="$P_PORT"
fi

if [ "$CLIENT" = "qb" ]; then
  BASE="http://${HOST}:${PORT_INPUT}"
  API="$BASE/api/v2"
else
  RPC="http://${HOST}:${PORT_INPUT}/transmission/rpc"
fi
echo "$T_USE ${RPC:-$BASE}"
echo

# ============================================================
# 3. 账号密码
# ============================================================
if [ -z "$P_USER" ]; then
  printf "【$T_AUTH】$T_USER_PROMPT"
  read USER
  if [ -n "$USER" ]; then
    printf "$T_PASS_PROMPT"
    stty -echo 2>/dev/null
    read PASS
    stty echo 2>/dev/null
    echo
    AUTH="-u ${USER}:${PASS}"
  else
    AUTH=""
    echo "$T_SKIP_AUTH"
  fi
else
  USER="$P_USER"
  PASS="${P_USER#*:}"
  USER="${P_USER%%:*}"
  [ "$USER" = "$PASS" ] && PASS=""
  AUTH="-u ${USER}:${PASS}"
fi

# ============================================================
# 4. 依赖
# ============================================================
command -v jq >/dev/null || {
  echo "$T_INSTALL_JQ"
  apk add --no-cache jq 2>/dev/null || { apt-get update >/dev/null 2>&1 && apt-get install -y jq >/dev/null 2>&1; }
}
command -v jq >/dev/null || { echo "$T_JQ_FAIL"; exit 1; }

# cookie 文件 (qB 登录用)
COOKIE=$(mktemp)
trap 'rm -f "$COOKIE" /tmp/tr_find_*.txt' EXIT 2>/dev/null

# ============================================================
# 5. 连接 + 认证
# ============================================================
echo "$T_CONNECTING"

if [ "$CLIENT" = "tr" ]; then
  SID=$(curl -s $AUTH -D - -o /dev/null "$RPC" | grep -i 'X-Transmission-Session-Id' | awk '{print $2}' | tr -d '\r')
  COUNT=$(curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
    -d '{"method":"torrent-get","arguments":{"fields":["id"]}}' | jq '.arguments.torrents|length' 2>/dev/null)
else
  if [ -n "$USER" ]; then
    LOGIN_BODY=$(curl -s -c "$COOKIE" -b "$COOKIE" -H "Referer: $BASE" \
      --data-urlencode "username=$USER" --data-urlencode "password=$PASS" \
      "$API/auth/login")
    if [ "$LOGIN_BODY" != "Ok." ]; then
      echo "$T_LOGIN_FAIL $LOGIN_BODY"; exit 1
    fi
  fi
  COUNT=$(curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" | jq 'length' 2>/dev/null)
fi

if ! echo "$COUNT" | grep -qE '^[0-9]+$'; then
  echo "$T_CONNECT_FAIL"; exit 1
fi
printf "$T_CONNECT_OK\n" "$COUNT"
echo

# ============================================================
# 工具函数
# ============================================================
has_hex_files() {
  _dir="$1"; _suf="$2"; _len="$3"
  for f in "$_dir"/*."$_suf"; do
    [ -e "$f" ] || continue
    _b=$(basename "$f" ".$_suf")
    [ "$_len" = "0" ] && return 0
    case "$_b" in
      *[!0-9a-fA-F]*) continue ;;
      *) [ ${#_b} -eq "$_len" ] && return 0 ;;
    esac
  done
  return 1
}

find_first_dir() {
  _name="$1"; _suf="$2"; _len="$3"
  find / -type d -name "$_name" 2>/dev/null > /tmp/tr_find_$$.txt
  while IFS= read -r _d; do
    [ -z "$_d" ] && continue
    has_hex_files "$_d" "$_suf" "$_len" && { printf '%s' "$_d"; return 0; }
  done < /tmp/tr_find_$$.txt
  rm -f /tmp/tr_find_$$.txt
  return 1
}

find_best_resume_dir() {
  _name="$1"; _suf="$2"; shift 2
  find / -type d -name "$_name" 2>/dev/null > /tmp/tr_find_$$.txt
  _best=""; _best_hit=0
  while IFS= read -r _d; do
    [ -z "$_d" ] && continue
    has_hex_files "$_d" "$_suf" 0 || continue
    _hit=0
    for _h in "$@"; do
      [ -n "$_h" ] && [ -e "$_d/${_h}.${_suf}" ] && _hit=$((_hit+1))
    done
    [ "$_hit" -gt "$_best_hit" ] && { _best_hit=$_hit; _best=$_d; }
  done < /tmp/tr_find_$$.txt
  rm -f /tmp/tr_find_$$.txt
  [ -n "$_best" ] && printf '%s' "$_best" && return 0
  return 1
}

# ============================================================
# 6. 定位种子目录 (仅 Transmission)
# ============================================================
TORRENTS_DIR=""
if [ "$CLIENT" = "tr" ]; then
  echo "$T_LOCATE_TORRENTS"
  TORRENTS_DIR=$(find_first_dir torrents torrent 40)
  if [ -z "$TORRENTS_DIR" ]; then
    printf "$T_LOCATE_FAIL"
    read TORRENTS_DIR
    [ -z "$TORRENTS_DIR" ] && { echo "$T_CANCELLED"; exit 1; }
  fi
  echo "$T_TORRENTS_DIR $TORRENTS_DIR"
  echo
fi

# Transmission resume 目录
TR_RESUME_DIR=""
if [ "$CLIENT" = "tr" ] && [ -n "$TORRENTS_DIR" ]; then
  TR_RESUME_DIR=$(dirname "$TORRENTS_DIR")/resume
  [ -d "$TR_RESUME_DIR" ] || TR_RESUME_DIR=""
fi

# ============================================================
# 7. 列出 Tracker (含数量)
# ============================================================
echo "$T_TRACKER_LIST"
if [ "$CLIENT" = "tr" ]; then
  curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
    -d '{"method":"torrent-get","arguments":{"fields":["trackers"]}}' \
    | jq -r '
        [ .arguments.torrents[]
          | (if (.trackers|length)==0 then "__NONE__"
             else (.trackers[].announce | sub("^https?://"; "") | sub("/.*$"; "")) end)
        ] | group_by(.)[] | "\(.[0])\t\(length)"
      ' 2>/dev/null
else
  curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
    | jq -r '
        [ .[]
          | (.tracker | sub("^https?://"; "") | sub("/.*$"; "")
             | if . == "" then "__NONE__" else . end)
        ] | group_by(.)[] | "\(.[0])\t\(length)"
      ' 2>/dev/null
fi | sort -t"	" -k1 > /tmp/tr_list.txt

i=1
while IFS="	" read -r domain count; do
  [ -z "$domain" ] && continue
  [ "$domain" = "__NONE__" ] && domain="$T_NO_TRACKER"
  printf "  %s) %s (%s)\n" "$i" "$domain" "$count"
  i=$((i+1))
done < /tmp/tr_list.txt
ALL_N=$((i-1))
printf "  a) %s (%s)\n" "$T_EXPORT_ALL" "$COUNT"
echo

# ============================================================
# 8. 选 Tracker
# ============================================================
if [ -z "$P_TRACKER" ]; then
  while true; do
    printf "$T_SELECT_PROMPT"
    read SEL
    KEY=""
    if [ "$SEL" = "a" ] || [ "$SEL" = "A" ]; then
      echo "$T_EXPORT_ALL_MSG"; break
    elif echo "$SEL" | grep -qE '^[0-9]+$'; then
      if [ "$SEL" -ge 1 ] && [ "$SEL" -le "$ALL_N" ]; then
        KEY=$(sed -n "${SEL}p" /tmp/tr_list.txt | cut -f1)
        if [ "$KEY" = "__NONE__" ]; then echo "$T_SELECT $T_NO_TRACKER"
        else echo "$T_SELECT $KEY"; fi
        break
      fi
      printf "$T_OUT_OF_RANGE\n" "$ALL_N"
    elif [ -z "$SEL" ]; then
      echo "$T_NOT_EMPTY"
    else
      KEY="$SEL"; echo "$T_KEYWORD $KEY"; break
    fi
  done
else
  KEY="$P_TRACKER"
  case "$KEY" in
    a|A) KEY=""; echo "$T_EXPORT_ALL_MSG" ;;
    *)   echo "$T_KEYWORD $KEY" ;;
  esac
fi
echo

# ============================================================
# 8.5 定位 qB 进度目录 (反查)
# ============================================================
QB_RESUME_DIR=""
if [ "$CLIENT" = "qb" ]; then
  KEY_LOWER=$(printf '%s' "$KEY" | tr '[:upper:]' '[:lower:]')
  if [ -z "$KEY" ]; then
    SAMPLE_HASHES=$(curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
      | jq -r '.[0:5][].hash' 2>/dev/null)
  elif [ "$KEY" = "__NONE__" ]; then
    SAMPLE_HASHES=$(curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
      | jq -r '[.[] | select(.tracker == "")][0:5][].hash' 2>/dev/null)
  else
    SAMPLE_HASHES=$(curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
      | jq -r --arg k "$KEY_LOWER" '[.[] | select((.tracker|ascii_downcase)|contains($k))][0:5][].hash' 2>/dev/null)
  fi
  if [ -n "$SAMPLE_HASHES" ]; then
    QB_RESUME_DIR=$(find_best_resume_dir BT_backup fastresume $SAMPLE_HASHES)
  fi
  [ -z "$QB_RESUME_DIR" ] && QB_RESUME_DIR=$(find_first_dir BT_backup fastresume 0)
fi

# ============================================================
# 9. 是否导出进度
# ============================================================
EXPORT_RESUME="n"
if [ "$P_RESUME" != "y" ]; then P_RESUME=""; fi
if [ "$CLIENT" = "tr" ]; then
  PROGRESS_DESC="$T_RESUME_TR"; HAVE_DIR="$TR_RESUME_DIR"
else
  PROGRESS_DESC="$T_RESUME_QB"; HAVE_DIR="$QB_RESUME_DIR"
fi
if [ -z "$P_RESUME" ]; then
  printf "【$T_RESUME_TITLE】$T_RESUME_PROMPT" "$PROGRESS_DESC"
  read RESUME_INPUT
  case "$RESUME_INPUT" in
    y|Y|yes|YES) P_RESUME="y" ;;
  esac
fi
if [ "$P_RESUME" = "y" ]; then
  if [ -z "$HAVE_DIR" ]; then
    printf "$T_RESUME_NO_DIR"
    read HAVE_DIR
    [ -z "$HAVE_DIR" ] && { echo "$T_RESUME_SKIP"; HAVE_DIR=""; }
  fi
  EXPORT_RESUME="$HAVE_DIR"
  echo "$T_RESUME_EXPORT $EXPORT_RESUME"
else
  echo "$T_RESUME_SKIP"
fi
echo

# ============================================================
# 10. 导出
# ============================================================
if [ -n "$P_OUT" ]; then
  OUT="$P_OUT"
elif [ "$P_INCR" = "1" ]; then
  # 增量模式: 默认用按 tracker 命名的固定目录，这样重复跑是同一目录，增量才生效
  if [ -z "$KEY" ]; then
    OUT="/config/backup_all"
  elif [ "$KEY" = "__NONE__" ]; then
    OUT="/config/backup_no_tracker"
  else
    # tracker 关键字清理成合法目录名(只保留字母数字点下划线)
    SAFE_KEY=$(printf '%s' "$KEY" | tr -cd 'A-Za-z0-9._-')
    OUT="/config/backup_${SAFE_KEY}"
  fi
else
  OUT="/config/export_$(date +%Y%m%d_%H%M%S)"
fi
mkdir -p "$OUT/torrents" 2>/dev/null || OUT="./export_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT/torrents"
[ "$EXPORT_RESUME" != "n" ] && mkdir -p "$OUT/resume"

# 增量导出: 收集输出目录已存在的 hash
if [ "$P_INCR" = "1" ]; then
  EXIST_HASHES=""
  for _f in "$OUT"/torrents/*.torrent; do
    [ -e "$_f" ] && EXIST_HASHES="$EXIST_HASHES $(basename "$_f" .torrent)"
  done
fi

export AUTH SID RPC API BASE COOKIE CLIENT KEY OUT TORRENTS_DIR EXPORT_RESUME P_INCR EXIST_HASHES

# 统计变量(通过临时文件累计，子 shell 里无法直接改父变量)
STAT_OK="/tmp/tr_stat_ok_$$"; STAT_MISS="/tmp/tr_stat_miss_$$"; STAT_FAIL="/tmp/tr_stat_fail_$$"
STAT_SKIP="/tmp/tr_stat_skip_$$"; STAT_RSUME="/tmp/tr_stat_rsume_$$"
PATHS_TMP="/tmp/tr_paths_$$"
: > "$STAT_OK"; : > "$STAT_MISS"; : > "$STAT_FAIL"; : > "$STAT_SKIP"; : > "$STAT_RSUME"
: > "$PATHS_TMP"
export STAT_OK STAT_MISS STAT_FAIL STAT_SKIP STAT_RSUME PATHS_TMP
export T_OK T_MISS T_FAIL T_RESUME_TAG T_NO_RESUME T_SKIP_TAG

incr_exists() {
  [ "$P_INCR" != "1" ] && return 1
  for _h in $EXIST_HASHES; do [ "$_h" = "$1" ] && return 0; done
  return 1
}

if [ "$CLIENT" = "tr" ]; then
  curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
    -d '{"method":"torrent-get","arguments":{"fields":["name","hashString","trackers","downloadDir"]}}' \
  | jq -c '.arguments.torrents[]' | while read -r t; do
      MATCH=0
      if [ -z "$KEY" ]; then MATCH=1
      elif [ "$KEY" = "__NONE__" ]; then
        [ "$(echo "$t" | jq -r '.trackers|length')" = "0" ] && MATCH=1
      elif echo "$t" | jq -r '.trackers[].announce' | grep -qiF "$KEY"; then MATCH=1; fi
      if [ "$MATCH" = "1" ]; then
        name=$(echo "$t" | jq -r '.name')
        hash=$(echo "$t" | jq -r '.hashString')
        ddir=$(echo "$t" | jq -r '.downloadDir // empty')
        # 增量跳过
        if incr_exists "$hash"; then echo "$hash" >> "$STAT_SKIP"; continue; fi
        src="$TORRENTS_DIR/$hash.torrent"
        if [ -f "$src" ]; then
          cp "$src" "$OUT/torrents/${hash}.torrent"
          # 记录原路径(用于导入时恢复)
          [ -n "$ddir" ] && printf '%s\t%s\n' "$hash" "$ddir" >> "$PATHS_TMP"
          rlog=""
          if [ "$EXPORT_RESUME" != "n" ]; then
            rsrc="$EXPORT_RESUME/$hash.resume"
            if [ -f "$rsrc" ]; then cp "$rsrc" "$OUT/resume/${hash}.resume"; rlog="$T_RESUME_TAG"; echo x >> "$STAT_RSUME"
            else rlog="$T_NO_RESUME"; fi
          fi
          printf "%s%s %s%s\n" "$T_OK" "$rlog" "$name" "" ; echo x >> "$STAT_OK"
        else
          printf "%s %s\n" "$T_MISS" "$name"; echo "$name" >> "$STAT_MISS"
        fi
      fi
    done
else
  curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
    | jq -c '.[]' | while read -r t; do
        name=$(echo "$t" | jq -r '.name')
        hash=$(echo "$t" | jq -r '.hash')
        tracker=$(echo "$t" | jq -r '.tracker')
        spath=$(echo "$t" | jq -r '.save_path // empty')
        MATCH=0
        if [ -z "$KEY" ]; then MATCH=1
        elif [ "$KEY" = "__NONE__" ]; then
          [ -z "$tracker" ] && MATCH=1
        elif echo "$tracker" | grep -qiF "$KEY"; then MATCH=1; fi
        if [ "$MATCH" = "1" ]; then
          if incr_exists "$hash"; then echo "$hash" >> "$STAT_SKIP"; continue; fi
          dst="$OUT/torrents/${hash}.torrent"
          http=$(curl -s -b "$COOKIE" -H "Referer: $BASE" -o "$dst" -w "%{http_code}" \
            "$API/torrents/export?hash=$hash")
          if [ "$http" = "200" ] && [ -s "$dst" ] && head -c1 "$dst" | grep -q 'd'; then
            # 记录原路径(用于导入时恢复)
            [ -n "$spath" ] && printf '%s\t%s\n' "$hash" "$spath" >> "$PATHS_TMP"
            rlog=""
            if [ "$EXPORT_RESUME" != "n" ]; then
              rsrc="$EXPORT_RESUME/$hash.fastresume"
              if [ -f "$rsrc" ]; then cp "$rsrc" "$OUT/resume/${hash}.fastresume"; rlog="$T_RESUME_TAG"; echo x >> "$STAT_RSUME"
              else rlog="$T_NO_RESUME"; fi
            fi
            printf "%s%s %s\n" "$T_OK" "$rlog" "$name"; echo x >> "$STAT_OK"
          else
            rm -f "$dst"
            printf "%s %s (HTTP %s)\n" "$T_FAIL" "$name" "$http"; echo "$name (HTTP $http)" >> "$STAT_FAIL"
          fi
        fi
      done
fi

N_OK=$(wc -l < "$STAT_OK"); N_MISS=$(wc -l < "$STAT_MISS"); N_FAIL=$(wc -l < "$STAT_FAIL")
N_SKIP=$(wc -l < "$STAT_SKIP"); N_RSUME=$(wc -l < "$STAT_RSUME")

# 生成 paths.json (记录每个种子原始下载路径，供导入脚本恢复)
if [ -s "$PATHS_TMP" ]; then
  # tab 分隔的 hash<TAB>path 转成 JSON 对象
  jq -Rn '[inputs | split("\t") | {(.[0]): .[1]}] | add' "$PATHS_TMP" > "$OUT/paths.json" 2>/dev/null
fi
rm -f "$STAT_OK" "$STAT_MISS" "$STAT_FAIL" "$STAT_SKIP" "$STAT_RSUME" "$PATHS_TMP"

# ============================================================
# 11. 完成 + 小结报告
# ============================================================
echo
echo "$T_DONE"
echo "$T_OUT_DIR $OUT"
printf "$T_COUNT_TORRENT\n" "$N_OK"
if [ "$N_MISS" -gt 0 ]; then printf "  $T_MISS: %s\n" "$N_MISS"; fi
if [ "$N_FAIL" -gt 0 ]; then printf "  $T_FAIL: %s\n" "$N_FAIL"; fi
if [ "$EXPORT_RESUME" != "n" ]; then printf "$T_COUNT_RESUME\n" "$N_RSUME"; fi
if [ "$P_INCR" = "1" ] && [ "$N_SKIP" -gt 0 ]; then printf "$T_SKIPPED\n" "$N_SKIP"; fi

# 生成 report.txt
REPORT="$OUT/report.txt"
{
  echo "$T_REPORT_TITLE"
  echo "$T_REPORT_TIME $(date '+%Y-%m-%d %H:%M:%S')"
  if [ "$CLIENT" = "tr" ]; then echo "$T_REPORT_CLIENT Transmission ($RPC)"
  else echo "$T_REPORT_CLIENT qBittorrent ($BASE)"; fi
  if [ -z "$KEY" ]; then echo "$T_REPORT_TRACKER $T_EXPORT_ALL"
  elif [ "$KEY" = "__NONE__" ]; then echo "$T_REPORT_TRACKER $T_NO_TRACKER"
  else echo "$T_REPORT_TRACKER $KEY"; fi
  echo "$T_REPORT_OUT $OUT"
  echo "----------------------------------------"
  printf "$T_COUNT_TORRENT\n" "$N_OK"
  if [ "$EXPORT_RESUME" != "n" ]; then printf "$T_COUNT_RESUME\n" "$N_RSUME"; fi
  if [ "$P_INCR" = "1" ] && [ "$N_SKIP" -gt 0 ]; then printf "$T_SKIPPED\n" "$N_SKIP"; fi
  [ "$N_MISS" -gt 0 ] && printf "  %s: %s\n" "$T_REPORT_MISS" "$N_MISS"
  [ "$N_FAIL" -gt 0 ] && printf "  %s: %s\n" "$T_REPORT_FAIL" "$N_FAIL"
} > "$REPORT"
echo "report.txt: $REPORT"

# ============================================================
# 12. 打包 zip
# ============================================================
if command -v zip >/dev/null; then
  BASE_NAME="${OUT##*/}"
  (cd "$(dirname "$OUT")" && zip -qr "${BASE_NAME}.zip" "$BASE_NAME")
  echo "$T_ZIPPED $(dirname "$OUT")/${BASE_NAME}.zip"
  echo "$T_ZIP_HINT"
else
  echo "$T_NO_ZIP $OUT"
fi
