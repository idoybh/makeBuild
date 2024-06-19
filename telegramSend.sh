#!/bin/bash
TG_SEND_CFG_FILE="telegram.conf"
LAST_MSG_ID_FILE="lastMsgId.txt"

isFile=0
isPreview=1
isCite=0
isEdit=0
isPin=0
tmpDir="./"
while [[ $# -gt 1 ]]; do
  case "$1" in
    "--config")
    if [[ "$2" != '' ]] && [[ -f "$2" ]]; then
      TG_SEND_CFG_FILE="$2"
    fi
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
    "--cite")
    isCite=1
    shift 1
    ;;
    "--edit")
    isEdit=1
    shift 1
    ;;
    "--pin")
    isPin=1
    shift 1
    ;;
    "--unpin")
    isPin=-1
    shift 1
    ;;
    "--tmp")
    if [[ "$2" != '' ]] && [[ -d "$2" ]]; then
      tmpDir="$2"
    fi
    shift 2
    ;;
    --*|-*)
    echo "Unknown flag ${1}"
    shift 1
    ;;
  esac
done

MSG="$1"
TOKEN="$(grep token "${TG_SEND_CFG_FILE}" | sed 's/token = //')"
CHAT_ID="$(grep chat_id "${TG_SEND_CFG_FILE}" | sed 's/chat_id = //')"
idFile="${tmpDir}${LAST_MSG_ID_FILE}"
[[ ! -f "$idFile" ]] && touch "$idFile"
mId=$(cat "${idFile}")

if [[ $isPin == -1 ]]; then
  curl -s -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"chat_id\": \"${CHAT_ID}\", \"message_id\": \"${mId}\"}" \
    https://api.telegram.org/bot"${TOKEN}"/unpinChatMessage &> /dev/null
  exit 0
fi

if [[ $isFile == 1 ]]; then # no edit here!
  params=""
  [[ $isPreview == 0 ]] && params="&disable_web_page_preview=True"
  [[ $isCite == 1 ]] && params="${params}&reply_to_message_id=${mId}"
  curl -s -F document=@"${MSG}" \
    https://api.telegram.org/bot$TOKEN/sendDocument?chat_id="${CHAT_ID}""${params}" \
    | jq -r .result | jq -r .message_id > "${idFile}"
  exit 0
fi

MSG="$(echo "$MSG" | sed 's/"/\\"/g')"
op="sendMessage"
[[ $isEdit == 1 ]] && op="editMessageText"
params="{\"chat_id\": \"${CHAT_ID}\", \"text\": \"${MSG}\", \"parse_mode\": \"HTML\""
[[ $isPreview == 0 ]] && params="${params}, \"disable_web_page_preview\": \"true\""
[[ $isCite == 1 ]] && params="${params}, \"reply_to_message_id\": \"${mId}\""
[[ $isEdit == 1 ]] && params="${params}, \"message_id\": \"${mId}\""
params="${params}}"
curl -s -X POST \
  -H 'Content-Type: application/json' \
  -d "${params}" \
  https://api.telegram.org/bot"${TOKEN}/${op}" \
  | jq -r .result | jq -r .message_id > "${idFile}"

if [[ $isPin == 1 ]]; then
  curl -s -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"chat_id\": \"${CHAT_ID}\", \"message_id\": \"$(cat "${idFile}")\", \"disable_notification\": \"true\"}" \
    https://api.telegram.org/bot"${TOKEN}"/pinChatMessage &> /dev/null
fi
