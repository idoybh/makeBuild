#!/bin/bash
TG_SEND_CFG_FILE="telegram.conf"

isFile=0
isPreview=1
while [[ $# -gt 1 ]]; do
  case "$1" in
    "--config")
    TG_SEND_CFG_FILE="$2"
    shift 2
    ;;
    "--file")
    isFile=1
    shift 1
    ;;
    "--disable-preview")
    isPreview=0
    shift 1
    ;;
  esac
done

MSG="$1"
TOKEN="$(cat "${TG_SEND_CFG_FILE}" | grep token | sed 's/token = //')"
CHAT_ID="$(cat "${TG_SEND_CFG_FILE}" | grep chat_id | sed 's/chat_id = //')"

if [[ $isFile == 1 ]]; then
  params=""
  [[ $isPreview == 0 ]] && params="&disable_web_page_preview=True"
  curl -s -F document=@"$MSG" \
    https://api.telegram.org/bot$TOKEN/sendDocument?chat_id="$CHAT_ID"$params &> /dev/null
  exit 0
fi

MSG="$(echo "$MSG" | sed 's/"/\\"/g')"
params="{\"chat_id\": \"$CHAT_ID\", \"text\": \"$MSG\", \"parse_mode\": \"HTML\"}"
if [[ $isPreview == 0 ]]; then
  params="{\"chat_id\": \"$CHAT_ID\", \"text\": \"$MSG\", \"parse_mode\": \"HTML\", \"disable_web_page_preview\": \"true\"}"
fi
curl -s -X POST \
  -H 'Content-Type: application/json' \
  -d "$params" \
  https://api.telegram.org/bot$TOKEN/sendMessage &> /dev/null
