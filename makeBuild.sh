#!/bin/bash
# Script was made by Ido Ben-Hur (@idoybh) due to pure bordom and to save time building diff roms

#######################
##     Functions     ##
#######################

# resets adb server
adb_reset()
{
  echo -e "${GREEN}Restarting ADB server${NC}"
  adb kill-server
  adb start-server
}

# waits for a recognizeable device in given state
# $1: delay between scans in seconds
# $2: device states array
adb_wait()
{
  delay=$1
  shift
  states=("$@")
  if [[ ${#states[@]} == 1 ]]; then
    state=${states[$i]}
    if [[ $state != 'device' ]]; then
      echo -e "${GREEN}Waiting for device in ${BLUE}${state}${NC}"
    else
      echo -e "${GREEN}Waiting for device${NC}"
    fi
  else
    outp="${GREEN}Waiting for device in"
    for i in "${!states[@]}"; do
      [[ $i -gt 0 ]] && outp="${outp} or"
      if [[ ${states[$i]} == 'device' ]]; then
        outp="${outp} ${BLUE}on${GREEN}"
        continue
      fi
      outp="${outp} ${BLUE}${states[$i]}${GREEN}"
    done
    echo -e "${outp} state${NC}"
  fi
  waitCount=0
  waitSent=0
  isDet=1 # reversed logic
  while [[ $isDet != 0 ]]; do # wait until detected
    for i in "${!states[@]}"; do
      if [[ $waitCount -gt 0 ]] && [[ $waitSent == 0 ]]; then
        tg_send "Waiting for device"
        waitSent=1
      fi
      waitCount=$(( waitCount + 1 ))
      if [[ ${states[$i]} == 'bootloader' ]] || [[ ${states[$i]} == 'fastboot' ]]; then
        if [[ $(fastboot devices) ]]; then
          isDet=0
          break
        fi
        continue
      fi
      adb kill-server &> /dev/null
      adb start-server &> /dev/null
      adb devices | grep -w "${states[$i]}" &> /dev/null
      isDet=$?
      [[ $isDet == 0 ]] && break
    done
    [[ $isDet != 0 ]] && sleep $delay
  done
}

# sends a msg in telegram if not silent.
# $1: the msg / file to send
isEdit=0 # global var so we don't edit the 1st msg
tmpDir="$(mktemp -d)/" # global var for the tmp file dir
currMsg="" # a var that stores the current message for edits
tg_send()
{
  tgmsg=$1
  if [[ $isSilent == 0 ]]; then
    if [[ $TG_SEND_PRIOR_CMD != '' ]]; then
      eval "$TG_SEND_PRIOR_CMD"
    fi
    tgcmd="--tmp ${tmpDir}"
    if [[ $TG_SEND_CFG_FILE != '' ]]; then
      tgcmd="${tgcmd} --config ${TG_SEND_CFG_FILE}"
    fi
    if [[ $isEdit == 1 ]] && [[ ! -f "${tgmsg}" ]]; then
      tgcmd="${tgcmd} --edit"
    elif [[ ! -f "${tgmsg}" ]]; then
      tgcmd="${tgcmd} --pin"
      isEdit=1
    fi
    if [[ -f "${tgmsg}" ]]; then
      # always unpin when we send a file (error)
      currMsg=""
      isEdit=0
      ./telegramSend.sh $tgcmd --unpin " "
      ./telegramSend.sh $tgcmd --file --cite "${tgmsg}"
    else
      [[ $currMsg != "" ]] && currMsg="${currMsg}\n"
      currMsg="${currMsg}${tgmsg}"
      ./telegramSend.sh $tgcmd --disable-preview "${currMsg}"
    fi
  fi
}

# returns a progress bar for a given % in $1
# $1 percentage in decimal (out of 100)
get_bar()
{
  per=$1
  len=25
  cLen=$(bc -l <<< "${len} * (${per} / 100)" | cut -d "." -f 1)
  bar="["
  for ((i = 0; i < len; i++)); do
    if [[ $i -lt $cLen ]]; then
      bar="${bar}#"
      continue
    fi
    bar="${bar}-"
  done
  bar="${bar}]"
  echo "$bar"
}

# returns some cpu & ccache details
get_stats()
{
  bar=""
  sOut=$(sensors)
  cUsage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
  cTemp=$(echo "$sOut" | grep "CPU Temperature" | tr -d -c "0-9.")
  ramInf=$(free -g -t | grep Total | cut -d ":" -f 2 | tr -s ' ' | sed "s/ //" | sed "s/ /:/g")
  cCurr=$(echo "$sOut" | grep -i "CPU VRM Output Current" | cut -d ":" -f 2 | sed 's/ //g' | sed 's/A//')
  cVolt=$(echo "$sOut" | grep -m 1 -i "CPU Core Voltage" | cut -d ":" -f 2 | sed 's/ //g' | sed 's/V//')
  cWatt=$(echo "${cCurr} * ${cVolt}" | bc)
  [[ $cUsage != "" ]] && bar="${bar}CPU: ${cUsage}"
  if [[ $cTemp != "" ]]; then
    if ! echo "$bar" | grep -q "CPU"; then
      bar="${bar}CPU:"
    fi
    bar="${bar} ${cTemp}°C"
  fi
  if [[ $cWatt != "" ]]; then
    if ! echo "$bar" | grep -q "CPU"; then
      bar="${bar}CPU:"
    fi
    bar="${bar} ${cWatt}W"
  fi
  if echo "$bar" | grep -q "CPU"; then
    cPer="${cUsage//%/}"
    pBar="$(get_bar ${cPer})"
    bar="${bar}\n${pBar}"
  fi
  if [[ $ramInf != "" ]]; then
    ramT=$(cut -d ":" -f 1 <<< "$ramInf")
    ramU=$(cut -d ":" -f 2 <<< "$ramInf")
    ramP=$(bc -l <<< "${ramU} * 100 / ${ramT}" | cut -d "." -f 1)
    pBar="$(get_bar ${ramP})"
    bar="${bar}\nRAM: ${ramU}/${ramT} GiB (${ramP}%)\n${pBar}"
  fi
  if [[ $USE_CCACHE == 1 ]]; then
    sOut=$(ccache -s | grep size | cut -d ":" -f 2)
    ccSize=$(echo "$sOut" | cut -d "/" -f 1 | tr -d -c "0-9.")
    ccMax=$(echo "$sOut" | cut -d "/" -f 2 | cut -d "(" -f 1 | tr -d -c "0-9.")
    if [[ $ccSize != "" ]]; then
      bar="${bar}\nccache: ${ccSize}"
      [[ $ccMax != "" ]] && bar="${bar}/${ccMax}"
      bar="${bar} GB"
    fi
  fi
  echo "$bar"
}

# tracks the build progress (requires a soong change) and sends it
# meant to be started on a "thread"
prog_send()
{
  initMsg="${currMsg}\n"
  alt=":"
  while true; do
    sleep 5
    trap "" SIGTERM
    [ ! -f "build_status.txt" ] && continue
    statusTxt=$(cat "build_status.txt")
    [[ $statusTxt == "" ]] && continue
    ! grep -q "/" <<< "$statusTxt" && continue
    ! grep -q "," <<< "$statusTxt" && continue
    if [[ $alt == ":" ]]; then
      alt=";"
    else
      alt=":"
    fi
    targets=$(cut -d "," -f 1 <<< "$statusTxt") || continue
    percent=$(cut -d "," -f 2 <<< "$statusTxt") || continue
    progMsg="${initMsg}\n<code>[${targets}] targets ${alt} ${percent}%</code>" || continue
    progMsg="${progMsg}\n<code>$(get_bar "$percent")</code>" || continue
    progMsg="${progMsg}\n\n<code>$(get_stats)</code>" || continue
    ./telegramSend.sh --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" --edit --disable-preview "${progMsg}" || continue
    trap - SIGTERM
  done
}

# tracks the upload progress and sends it
# meant to be started on a "thread"
# modify to match your utility if changed
upload_prog_send()
{
  initMsg="${currMsg}\n"
  alt=":"
  while true; do
    sleep 5
    trap "" SIGTERM
    statusTxt=$(rclone rc core/stats | jq -r ".transferring?.[0]")
    [[ $? != 0 ]] && continue
    [[ $statusTxt == "" ]] && continue
    [[ $statusTxt == "null" ]] && continue
    ! grep -q "percentage" <<< "$statusTxt" && continue
    ! grep -q "speed" <<< "$statusTxt" && continue
    ! grep -q "eta" <<< "$statusTxt" && continue
    percent=$(jq -r ".percentage" <<< "$statusTxt") || continue
    speed=$(jq -r ".speed" <<< "$statusTxt" | cut -d "." -f 1) || continue
    etaTime=$(jq -r ".eta" <<< "$statusTxt") || continue
    [[ $percent == "" ]] && continue
    [[ $speed == "" ]] && continue
    [[ $etaTime == "" ]] && continue
    if [[ $alt == ":" ]]; then
      alt=";"
    else
      alt=":"
    fi
    speed=$(bc -l <<< "${speed} / 1000000")
    speed=$(printf "%.2f" "${speed}")
    etaTime="$(( etaTime / 60 ))m$(( etaTime % 60 ))s"
    progMsg="${initMsg}\n<code>${speed} MiB/s ${alt} ETA ${etaTime} ${alt} ${percent}%</code>" || continue
    progMsg="${progMsg}\n<code>$(get_bar "$percent")</code>" || continue
    ./telegramSend.sh --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" --edit --disable-preview "${progMsg}" || continue
    trap - SIGTERM
  done
}

# prints the help msg
print_help()
{
  echo -e "${GREEN}Flags available:${NC}"
  echo -e "${BLUE}-h${NC} to show this dialog and exit"
  echo -e "${BLUE}-i${NC} for setup"
  echo -e "${BLUE}-u${NC} for upload"
  echo -e "${BLUE}-p${NC} for ADB push (and recovery flash)"
  echo -e "${BLUE}-f${NC} for fastboot flash"
  echo -e "${BLUE}-c${NC} for a clean build"
  echo -e "${BLUE}-s${NC} to disable sending telegram messages"
  echo -e "${BLUE}-d${NC} to perform a dry run (no build)"
  echo -e "${BLUE}--keep-file | -k${NC} to skip removal of original build file"
  echo -e "${BLUE}--power [ARG]${NC} to power off / reboot when done"
  echo -e "   ${BLUE}Supported ARG(s): ${NC} off, reboot"
  echo -e "${BLUE}--choose [CMD]${NC} to change target choose command"
  echo -e "${BLUE}--type [CMD]${NC} to change build type command"
  echo -e "${BLUE}--product [ARG]${NC} to change target product name"
  echo -e "${BLUE}--config [FILE]${NC} to select a different config file"
  echo -e "${BLUE}--tg-config [FILE]${NC} to select a different telegram config file"
  echo -e "${BLUE}--installclean | --i-c${NC} to run ${BLUE}make installclean${NC} before the build"
  echo -e "${GREEN}Default configuration file: ${BLUE}build.conf${NC}"
  echo -en "${GREEN}For more help visit: "
  echo -e "${BLUE}https://github.com/idoybh/makeBuild/blob/master/README.md${NC}"
}

# returns a property value from the config file
# $1: property name to read
# $2: config file name
config_read()
{
  rProp=$1
  cFile=$2
  lineNO=$(awk "/${rProp}/{ print NR; exit }" $cFile)
  res="$(sed "${lineNO}q;d" $cFile | cut -d '=' -f 2-)"
  res="$(echo $res | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  eval "echo \"${res}\""
}

# sets a property vlaue to the config file
# $1: property name
# $2: value
# $3: config file name
config_write()
{
  wProp=$1
  wVal=$2
  cFile=$3
  lineNO=$(awk "/${wProp}/{ print NR; exit }" $cFile)
  sed -i "${lineNO}s,=.*,=${wVal}," $cFile
}

# rewrites given config file
# $1: config file path
rewrite_config()
{
  confPath=$1
  config_write "WAS_INIT" 1 $confPath
  config_write "CLEAN_CMD" "${CLEAN_CMD}" $confPath
  config_write "TARGET_CHOOSE_CMD" "${TARGET_CHOOSE_CMD}" $confPath
  config_write "PRE_BUILD_SCRIPT" "${PRE_BUILD_SCRIPT}" $confPath
  config_write "BUILD_TYPE_CMD" "${BUILD_TYPE_CMD}" $confPath
  config_write "BUILD_CMD" "${BUILD_CMD}" $confPath
  config_write "FILE_MANAGER_CMD" "${FILE_MANAGER_CMD}" $confPath
  config_write "UPLOAD_CMD" "${UPLOAD_CMD}" $confPath
  config_write "UPLOAD_LINK_CMD" "${UPLOAD_LINK_CMD}" $confPath
  config_write "UPLOAD_LINK_ALT_CMD" "${UPLOAD_LINK_ALT_CMD}" $confPath
  config_write "TG_SEND_PRIOR_CMD" "${TG_SEND_PRIOR_CMD}" $confPath
  config_write "TG_SEND_CFG_FILE" "${TG_SEND_CFG_FILE}" $confPath
  config_write "UPLOAD_DEST" "${UPLOAD_DEST}" $confPath
  config_write "UPLOAD_PATH" "${UPLOAD_PATH}" $confPath
  config_write "SOURCE_PATH" "${SOURCE_PATH}" $confPath
  config_write "BUILD_PRODUCT_NAME" "${BUILD_PRODUCT_NAME}" $confPath
  config_write "BUILD_FILE_NAME" "${BUILD_FILE_NAME}" $confPath
  config_write "ADB_DEST_FOLDER" "${ADB_DEST_FOLDER}" $confPath
  config_write "UNHANDLED_PATH" "${UNHANDLED_PATH}" $confPath
  config_write "AUTO_RM_BUILD" "${AUTO_RM_BUILD}" $confPath
  config_write "AUTO_REBOOT" "${AUTO_REBOOT}" $confPath
  config_write "AUTO_SLOT" "${AUTO_REBOOT}" $confPath
  config_write "UPLOAD_DONE_MSG" "${UPLOAD_DONE_MSG}" $confPath
  config_write "FAILURE_MSG" "${FAILURE_MSG}" $confPath
  config_write "TWRP_PIN" "${TWRP_PIN}" $confPath
  config_write "TWRP_SIDELOAD" "${TWRP_SIDELOAD}" $confPath
  config_write "FASTBOOT_PKG" "${FASTBOOT_PKG}" $confPath
}

# loads given config file
# exists script if not found
# $1: config file path
load_config()
{
  cFile=$1
  if [[ -f $cFile ]]; then
    linesNO=$(wc -l $cFile)
    linesNO="${linesNO:0:2}"
    for (( ii = 1; ii <= linesNO; ii++ )); do
      curLine=$(sed "${ii}q;d" $cFile)
      firstChar="${curLine:0:1}"
      if [[ $firstChar != "#" ]] && [[ $firstChar != '' ]]; then
        cVar="$(echo $curLine | awk '{print $1}')"
        cVal="$(config_read $cVar $cFile)"
        export $cVar="${cVal}"
      fi
    done
  else
    echo -e "${RED}ERROR! ${BLUE}${cFile}${RED} not found${NC}"
    exit 2
  fi
}

# writes a new build.conf file
init_conf()
{
  echo -e "${GREEN}Initializing settings${NC}"
  echo -e "${GREEN}Default values are inside [] just press enter to apply them${NC}"
  echo -en "${YELLOW}Enter clean command [${BLUE}make clobber${YELLOW}]: ${NC}"
  read CLEAN_CMD
  if [[ $CLEAN_CMD == '' ]]; then
    CLEAN_CMD='make clobber'
  fi
  echo -en "${YELLOW}Enter target choose command "
  echo -en "[${BLUE}lunch yaap_guacamole-user${YELLOW}]: ${NC}"
  read TARGET_CHOOSE_CMD
  if [[ $TARGET_CHOOSE_CMD == '' ]]; then
    TARGET_CHOOSE_CMD='lunch yaap_guacamole-user'
  fi
  echo -en "${YELLOW}Enter pre build script path "
  echo -en "[${BLUE}blank${YELLOW}]: ${NC}"
  read PRE_BUILD_SCRIPT
  echo -en "${YELLOW}Enter build type command "
  echo -en "[${BLUE}blank${YELLOW}]: ${NC}"
  read BUILD_TYPE_CMD
  echo -en "${YELLOW}Enter build command [${BLUE}mka kronic${YELLOW}]: ${NC}"
  read BUILD_CMD
  if [[ $BUILD_CMD == '' ]]; then
    BUILD_CMD='mka kronic'
  fi
  echo -en "${YELLOW}Enter file manager command "
  echo -en "('c' for none) [${BLUE}dolphin${YELLOW}]: ${NC}"
  read FILE_MANAGER_CMD
  if [[ $FILE_MANAGER_CMD == '' ]]; then
    FILE_MANAGER_CMD='dolphin'
  fi
  if [[ $FILE_MANAGER_CMD == 'c' ]]; then
    FILE_MANAGER_CMD=''
  fi
  echo -en "${YELLOW}Enter upload command [${BLUE}rclone copy -v${YELLOW}]: ${NC}"
  read UPLOAD_CMD
  if [[ $UPLOAD_CMD == '' ]]; then
    UPLOAD_CMD='rclone copy -P'
  fi
  echo -en "${YELLOW}Enter upload link command [${BLUE}rclone link${YELLOW}]: ${NC}"
  read UPLOAD_LINK_CMD
  if [[ $UPLOAD_LINK_CMD == '' ]]; then
    UPLOAD_LINK_CMD='rclone link'
  fi
  echo -en "${YELLOW}Enter upload link alternative command [${BLUE}none${YELLOW}]: ${NC}"
  read UPLOAD_LINK_ALT_CMD
  echo -en "${YELLOW}Enter telegram send prior command [${BLUE}none${YELLOW}]: ${NC}"
  read TG_SEND_PRIOR_CMD
  echo -en "${YELLOW}Enter telegram send config file path [${BLUE}none${YELLOW}]: ${NC}"
  read TG_SEND_CFG_FILE
  echo -en "${YELLOW}Enter upload destination (remote) "
  echo -en "[${BLUE}GDrive:/builds${YELLOW}]: ${NC}"
  read UPLOAD_DEST
  if [[ $UPLOAD_DEST == '' ]]; then
    UPLOAD_DEST='GDrive:/builds'
  fi
  echo -en "${YELLOW}Enter upload folder path (local) ('c' for none) "
  echo -en "[${BLUE}gdrive:/idoybh2/builds/${YELLOW}]: ${NC}"
  read UPLOAD_PATH
  if [[ $UPLOAD_PATH == '' ]]; then
    UPLOAD_PATH='gdrive:/idoybh2/builds/'
  fi
  if [[ $UPLOAD_PATH == 'c' ]]; then
    UPLOAD_PATH=''
  fi
  echo -en "${YELLOW}Enter source path [${BLUE}.${YELLOW}]: ${NC}"
  read SOURCE_PATH
  if [[ $SOURCE_PATH == '' ]]; then
    SOURCE_PATH='.'
  fi
  echo -en "${YELLOW}Enter build product name [${BLUE}dumpling${YELLOW}]: ${NC}"
  read BUILD_PRODUCT_NAME
  if [[ $BUILD_PRODUCT_NAME == '' ]]; then
    BUILD_PRODUCT_NAME='dumpling'
  fi
  echo -en "${YELLOW}Enter built zip file name [${BLUE}YAAP*.zip${YELLOW}]: ${NC}"
  read BUILD_FILE_NAME
  if [[ $BUILD_FILE_NAME == '' ]]; then
    BUILD_FILE_NAME='YAAP*.zip'
  fi
  echo -en "${YELLOW}Enter ADB push destination folder "
  echo -en "[${BLUE}Flash/YAAP${YELLOW}]: ${NC}"
  read ADB_DEST_FOLDER
  if [[ $ADB_DEST_FOLDER == '' ]]; then
    ADB_DEST_FOLDER='Flash/YAAP'
  fi
  echo -en "${YELLOW}Enter default move path ('c' for none) "
  echo -en "[${BLUE}\$HOME/Desktop${YELLOW}]: ${NC}"
  read UNHANDLED_PATH
  if [[ $UNHANDLED_PATH == '' ]]; then
    UNHANDLED_PATH="${HOME}/Desktop"
  fi
  if [[ $UNHANDLED_PATH == 'c' ]]; then
    UNHANDLED_PATH=''
  fi
  echo -en "${YELLOW}Automatically remove build file? "
  echo -en "y/[${BLUE}n${YELLOW}]/N(ever): ${NC}"
  read AUTO_RM_BUILD
  if [[ $AUTO_RM_BUILD == 'y' ]]; then
    AUTO_RM_BUILD=1
  elif [[ $AUTO_RM_BUILD == 'N' ]]; then
    AUTO_RM_BUILD=0
  else
    AUTO_RM_BUILD=2
  fi
  echo -en "${YELLOW}Automatically reboot (to and from recovery)? "
  echo -en "y/[${BLUE}n${YELLOW}]: ${NC}"
  read AUTO_REBOOT
  if [[ $AUTO_REBOOT == 'y' ]]; then
    AUTO_REBOOT=1
  else
    AUTO_REBOOT=0
  fi
  echo -en "${YELLOW}Automatically switch slots on fastboot flash? "
  echo -en "y/[${BLUE}n${YELLOW}]: ${NC}"
  read AUTO_SLOT
  if [[ $AUTO_SLOT == 'y' ]]; then
    AUTO_SLOT=1
  else
    AUTO_SLOT=0
  fi
  echo -en "${YELLOW}Set extra upload message [${BLUE}blank${YELLOW}]: ${NC}"
  read UPLOAD_DONE_MSG
  echo -en "${YELLOW}Set extra failure message [${BLUE}blank${YELLOW}]: ${NC}"
  read FAILURE_MSG
  echo -en "${YELLOW}Set TWRP decryption pin "
  echo -en "(0 for decrypted; blank to wait) [${BLUE}blank${YELLOW}]: ${NC}"
  read TWRP_PIN
  echo -en "${YELLOW}ADB sideload instead of push? "
  echo -en "y/[${BLUE}n${YELLOW}]: ${NC}"
  read TWRP_SIDELOAD
  if [[ $TWRP_SIDELOAD = 'y' ]]; then
    TWRP_SIDELOAD=1
  else
    TWRP_SIDELOAD=0
  fi
  echo -en "${YELLOW}Fastboot package flashing ? "
  echo -en "[${BLUE}y${YELLOW}]/n: ${NC}"
  read FASTBOOT_PKG
  if [[ $FASTBOOT_PKG = 'n' ]]; then
    FASTBOOT_PKG=0
  else
    FASTBOOT_PKG=1
  fi
  echo -e "${RED}Note! If you chose 'n' settings will only persist for current session${NC}"
  echo -en "${YELLOW}Write current config to file? [${BLUE}y${YELLOW}]/n: ${NC}"
  read isWriteConf
  if [[ $isWriteConf != 'n' ]]; then
    echo -en "${YELLOW}Enter config file name [${BLUE}build.conf${YELLOW}]: ${NC}"
    read confPath
    if [[ $confPath == '' ]]; then
      confPath="build.conf"
    fi
    echo -e "${GREEN}Rewriting file${NC}"
    rewrite_config $confPath
  fi
}

# checking configs (paths only, there's a limit for the spoonfeed)
check_confs()
{
  SOURCE_PATH=$(realpath "$SOURCE_PATH")
  if [[ ! -d $SOURCE_PATH ]]; then
    echo -en "${RED}ERROR! Provided source path "
    echo -e "${BLUE}${SOURCE_PATH}${RED} is invalid${NC}"
    exit 1
  fi
  if [[ $UNHANDLED_PATH != '' ]]; then
    UNHANDLED_PATH=$(realpath "$UNHANDLED_PATH")
    if [[ ! -d $UNHANDLED_PATH ]]; then
      echo -en "${RED}ERROR! Provided unhandled path "
      echo -e "${BLUE}${UNHANDLED_PATH}${RED} is invalid${NC}"
      exit 1
    fi
  fi
  if [[ $PRE_BUILD_SCRIPT != '' ]] && [[ ! -f $PRE_BUILD_SCRIPT ]]; then
    echo -en "${RED}ERROR! Provided pre-build script "
    echo -e "${BLUE}${PRE_BUILD_SCRIPT}${RED} does not exist${NC}"
    exit 1
  fi
  if [[ $TG_SEND_CFG_FILE != '' ]] && [[ ! -f $TG_SEND_CFG_FILE ]]; then
    echo -en "${RED}ERROR! Provided tlegram-send config "
    echo -e "${BLUE}${TG_SEND_CFG_FILE}${RED} does not exist${NC}"
    exit 1
  fi

  if [[ $WAS_INIT == 0 ]]; then # show not configured warning
    echo -e "${RED}WARNING! Script configs were never initialized!${NC}"
    echo -en "${GREEN}Please set ${BLUE}WAS_INIT${GREEN} to ${BLUE}1${GREEN} "
    echo -e "in ${BLUE}build.config${GREEN} to hide this warning${NC}"
    echo -e "${GREEN}You can also re run the script with ${BLUE}-i${GREEN} flag to do so"
    wait_for 3
  fi
}

# Prints a table to summarize flags
print_flags()
{
  if [[ $productChanged != 0 ]] || [[ $targetChanged != 0 ]] || [[ $typeChanged != 0 ]] || [[ $tgConfigChanged != 0 ]] || [[ $configFile != "build.conf" ]]; then
    echo -e "${YELLOW}----OVERRIDES----${NC}"
  fi
  [[ $configFile != "build.conf" ]] && echo -en "${RED}"
  echo -e "Config file  : ${BLUE}${configFile}${NC}"
  [[ $configFile != "build.conf" ]] && diff --color build.conf $configFile && echo "-----------------"
  [[ $productChanged != 0 ]] && echo -e "${RED}Product      : ${BUILD_PRODUCT_NAME}${NC}"
  [[ $targetChanged != 0 ]] && echo -e "${RED}Type cmd     : ${BUILD_TYPE_CMD}${NC}"
  [[ $typeChanged != 0 ]] && echo -e "${RED}Target cmd   : ${TARGET_CHOOSE_CMD}${NC}"
  [[ $tgConfigChanged != 0 ]] && echo -e "${RED}TG config    : ${TG_SEND_CFG_FILE}${NC}"
  echo
  echo -e "${YELLOW}------BUILD------${NC}"
  [[ $isClean == 1 ]] && echo -en "${RED}"
  echo -e "Clean        : ${isClean}${NC}"
  [[ $installClean == 1 ]] && echo -en "${RED}"
  echo -e "Installclean : ${installClean}${NC}"
  [[ $isDry == 1 ]] && echo -en "${RED}"
  echo -e "Dry          : ${isDry}${NC}"
  echo
  echo -e "${YELLOW}------FILE-------${NC}"
  [[ $isUpload == 1 ]] && echo -en "${RED}"
  echo -e "Upload       : ${isUpload}${NC}"
  [[ $isPush == 1 ]] && echo -en "${RED}"
  echo -e "Push         : ${isPush}${NC}"
  [[ $isFastboot == 1 ]] && echo -en "${RED}"
  echo -e "Fastboot     : ${isFastboot}${NC}"
  [[ $isKeep == 1 ]] && echo -en "${RED}"
  echo -e "Keep file    : ${isKeep}${NC}"
  [[ $isMagisk == 1 ]] && echo -en "${RED}"
  echo -e "Magisk       : ${isMagisk}${NC}"
  echo
  echo -e "${YELLOW}-------ETC-------${NC}"
  [[ $isSilent == 1 ]] && echo -en "${RED}"
  echo -e "Silent       : ${isSilent}${NC}"
  [[ $powerOpt != 0 ]] && echo -en "${RED}"
  echo -e "Power        : ${powerOpt}${NC}"
}

# Prints a table to summarize configs
print_confs()
{
  echo
  echo -e "${YELLOW}-----CONFIGS-----${NC}"
  echo -e "Script dir             :${BLUE} ${PWD}${NC}"
  echo -e "Source dir             :${BLUE} ${SOURCE_PATH}${NC}"
  echo -e "Product name           :${BLUE} ${BUILD_PRODUCT_NAME}${NC}"
  echo -e "Upload destination     :${BLUE} ${UPLOAD_DEST}${NC}"
  echo -e "ADB push destination   :${BLUE} ${ADB_DEST_FOLDER}${NC}"
  if [[ $UNHANDLED_PATH != '' ]]; then
    echo -e "Move build destination :${BLUE} ${UNHANDLED_PATH}${NC}"
  fi
  if [[ $UPLOAD_DONE_MSG != '' ]]; then
    echo -e "Upload done message    :${BLUE} ${UPLOAD_DONE_MSG}${NC}"
  fi
  if [[ $FAILURE_MSG != '' ]]; then
    echo -e "Failure message        :${BLUE} ${FAILURE_MSG}${NC}"
  fi
  if [[ $preBuildScripts != "" ]]; then
    for script in ${preBuildScripts// / }; do
      [[ ! -f $script ]] && continue
      echo -e "Pre-build script       :${BLUE} ${script}${NC}"
    done
  fi
}

# performs required pre build operations
pre_build()
{
  tg_send "[pre-build] Preparing env for <code>${BUILD_PRODUCT_NAME}</code>"
  source "${SOURCE_PATH}/build/envsetup.sh"
  eval $TARGET_CHOOSE_CMD # target
  if [[ $isClean == 1 ]]; then
    echo -e "${GREEN}Cleaning build${NC}"
    tg_send "[pre-build] Cleaning build</code>"
    eval $CLEAN_CMD
  fi
  if [[ $installClean == 1 ]]; then
    echo -e "${GREEN}Running installclean${NC}"
    tg_send "[pre-build] Running installclean"
    make installclean
  fi
  if [[ $BUILD_TYPE_CMD != '' ]]; then
    eval $BUILD_TYPE_CMD # build type
  fi
  if [[ $PRE_BUILD_SCRIPT != '' ]] && [[ -f $PRE_BUILD_SCRIPT ]]; then
    echo -e "${GREEN}Running ${BLUE}${PRE_BUILD_SCRIPT}${NC}"
    tg_send "[pre-build] Running <code>${PRE_BUILD_SCRIPT}</code>"
    source "${PRE_BUILD_SCRIPT}"
  fi
  if [[ $preBuildScripts != '' ]]; then
    for script in ${preBuildScripts// / }; do
      [[ ! -f $script ]] && continue
      echo -e "${GREEN}Running ${BLUE}${script}${NC}"
      tg_send "[pre-build] Running <code>${script}</code>"
      source "${script}"
    done
  fi
  currMsg="" # edit over pre-build ops
  tg_send "Build started for <code>${BUILD_PRODUCT_NAME}</code>"
  start_time=$(date +"%s")
}

# magisk patch and pull
magisk_patch()
{
  stateA=('device')
  adb_wait 1 "${stateA[@]}"
  tg_send "Patching boot.img with magisk"
  echo -e "${GREEN}Magisk patching${NC}"
  echo -e "${GREEN}Env setup${NC}"
  idir="${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}/obj/PACKAGING/target_files_intermediates/*_${BUILD_PRODUCT_NAME}-target_files*/IMAGES"
  idir=$(eval echo "${idir}")
  # set these flags according to your device
  mflags="KEEPVERITY=true LEGACYSAR=true RECOVERYMODE=false"
  cryptoState=$(adb shell getprop ro.crypto.state)
  [[ $cryptoState == "encrypted" ]] && mflags="${mflags} KEEPFORCEENCRYPT=true"
  if ls "${idir}/vbmeta.img" &> /dev/null; then
    mflags="${mflags} PATCHVBMETAFLAG=true"
  fi
  echo -e "${GREEN}Pushing ${BLUE}boot.img${NC}"
  adb push "${idir}/boot.img" "/sdcard/" || exit 1
  adb shell su -c "rm -f /data/adb/magisk/new-boot.img"
  echo -e "${GREEN}Patching ${BLUE}/sdcard/boot.img${NC}"
  adb shell su -c "${mflags} /data/adb/magisk/boot_patch.sh /sdcard/boot.img" || exit 1
  ver=$(adb shell magisk -V) || exit 1
  adb shell rm "/sdcard/Download/magisk_patched-*.img" &> /dev/null
  adb shell su -c "mv /data/adb/magisk/new-boot.img /sdcard/Download/magisk_patched-${ver}.img" || exit 1
  adb shell su -c "/data/adb/magisk/magiskboot cleanup"
  echo -e "${GREEN}Pulling version ${BLUE}${ver}${NC}"
  rm ./magisk_patched-*.img
  adb pull "/sdcard/Download/magisk_patched-${ver}.img" ./ || exit 1
  fpath=$(realpath "./magisk_patched-${ver}.img")
  echo -e "${GREEN}Magisk patching done. Image: ${BLUE}${fpath}${NC}"
}

# handles the push flag (-p)
handle_push()
{
  echo -e "${GREEN}Pushing...${NC}"
  isOn=1 # Device is booted (reverse logic)
  isRec=1 # Device is on recovery mode (reverse logic)
  isPushed=1 # Weater the push went fine (reverse logic)
  while [[ $isOn != 0 ]] && [[ $isRec != 0 ]] && [[ $isPushed != 0 ]]; do
    adb_reset
    adb devices | grep -w 'device' &> /dev/null
    isOn=$?
    adb devices | grep -w 'recovery' &> /dev/null
    isRec=$?
    sdcardPath=""
    if [[ $isRec == 0 ]]; then
      echo -e "${GREEN}Device detected in ${BLUE}recovery${NC}"
      sdcardPath="/sdcard"
    elif [[ $isOn == 0 ]]; then
      echo -e "${GREEN}Device detected${NC}"
      sdcardPath="/storage/emulated/0/"
    else
      if [[ $TWRP_SIDELOAD == 1 ]]; then
        isPushed=0
        buildH=1
        break
      fi
      echo -en "${RED}Please plug in a device with ADB enabled and press any key${NC}"
      read -n1 temp
      echo
    fi
    if [[ $isRec != 0 ]] && [[ $isOn != 0 ]]; then
      continue
    fi
    if [[ $TWRP_SIDELOAD == 1 ]]; then
      isPushed=0
      buildH=1
      break
    fi
    adb push "${PATH_TO_BUILD_FILE}" "${sdcardPath}/${ADB_DEST_FOLDER}/"
    isPushed=$?
    if [[ $isPushed == 0 ]]; then
      echo -e "${GREEN}Pushed to: ${BLUE}${ADB_DEST_FOLDER}${NC}"
      buildH=1
    else
      isOn=1
      isRec=1
      isPushed=1
      echo -en "${RED}Push error (see output). Press any key to try again${NC}"
      read -n1 temp
      echo
    fi
  done
  if [[ $isPushed == 0 ]]; then
    if [[ $AUTO_REBOOT == 0 ]]; then
      echo -en "${YELLOW}Flash now? y/[n]/A(lways): ${NC}"
      read isFlash
      if [[ $isFlash == 'A' ]]; then
        config_write "AUTO_REBOOT" 1 $configFile
        isFlash='y'
      fi
    else
      isFlash='y'
    fi
    # flash build
    if [[ $isFlash == 'y' ]]; then
      tg_send "Flashing build"
      start_time=$(date +"%s")
      if [[ $isOn == 0 ]]; then
        echo -e "${GREEN}Rebooting to recovery${NC}"
        adb reboot recovery
        isDecrypted=0
        if [[ $TWRP_SIDELOAD == 0 ]]; then
          stateA=('recovery')
          adb_wait 3 "${stateA[@]}"
          echo -e "${GREEN}Device detected in ${BLUE}recovery${NC}"
        fi
        if [[ $TWRP_PIN != '' ]] && [[ $TWRP_PIN != '0' ]] && [[ $TWRP_SIDELOAD == 0 ]]; then
          adb_reset
          echo -e "${GREEN}Trying decryption with provided pin${NC}"
          adb shell twrp decrypt $TWRP_PIN
          if [[ $? == 0 ]]; then
            isDecrypted=1
            echo -e "${GREEN}Data decrypted${NC}"
            wait_for 5
            adb_reset
          else
            echo -e "${RED}Data decryption failed. Please try manually${NC}"
          fi
        fi
        if [[ $TWRP_PIN != '0' ]] && [[ $isDecrypted != 1 ]] && [[ $TWRP_SIDELOAD == 0 ]]; then
          echo -en "${YELLOW}Press any key ${RED}after${YELLOW} decrypting data in TWRP${NC}"
          read -n1 temp
          echo
          adb_reset
        fi
      else
        adb_reset
      fi
      # Add extra pre-flash operations here
      fileName=$(basename $PATH_TO_BUILD_FILE)
      echo -e "${GREEN}Flashing ${BLUE}${fileName}${NC}"
      isFlashed=1 # reverse logic
      while [[ $isFlashed != 0 ]]; do
        if [[ $TWRP_SIDELOAD == 1 ]]; then
          stateA=('sideload')
          adb_wait 3 "${stateA[@]}"
          adb sideload $PATH_TO_BUILD_FILE
          isFlashed=$?
        else
          adb shell twrp install "/sdcard/${ADB_DEST_FOLDER}/${fileName}"
          isFlashed=$?
        fi
        if [[ $isFlashed != 0 ]]; then
          echo -e "${RED}Flash error. Press any key to try again."
          echo -en "Press 'c' to continue anyway${NC}"
          read -n1 temp
          [[ $temp != 'c' ]] && continue
        fi
        # Add additional flash operations here (magisk provided as example)
        # adb shell twrp install "/sdcard/Flash/Magisk/Magisk-v20.1\(20100\).zip"
      done
      if [[ $AUTO_REBOOT == 0 ]]; then
        echo -en "${YELLOW}Press any key to reboot${NC}"
        read -n1 temp
        echo
      fi
      adb reboot
      get_time
      tg-send "Flashing done in <code>${buildTime}</code>"
    fi
  fi
}

# handles the fastboot flag (-f)
handle_fastboot()
{
  ans='n'
  if [[ $AUTO_REBOOT == 1 ]]; then
    ans='y'
  else
    echo -en "${YELLOW}Reboot to fastboot? y/[n]: ${NC}"
    read ans
  fi
  if [[ $ans == 'y' ]]; then
    adb reboot bootloader &> /dev/null
    if [[ $? != 0 ]]; then
      stateA=('device' 'bootloader')
      adb_wait 2 "${stateA[@]}"
    fi
    adb devices | grep -w "device" &> /dev/null
    [[ $? == 0 ]] && adb reboot bootloader &> /dev/null
  fi
  if ! [[ $(fastboot devices) ]]; then
    echo -e "${GREEN}Waiting for device in ${BLUE}bootloader${NC}"
  fi
  fastboot wait-for-device &> /dev/null
  wait_for 3
  slot=$(fastboot getvar current-slot 2>&1 | head -n 1)
  slot="$(echo $slot | sed "s/current-slot: //")"
  echo -e "Currently on slot ${BLUE}${slot}${NC}"
  slot2="a"
  [[ $slot == "a" ]] && slot2="b"
  if [[ $AUTO_SLOT == 1 ]]; then
    ans=y
  else
    echo -en "${YELLOW}Switch to slot ${BLUE}${slot2}${YELLOW}? [y]/n: ${NC}"
    read ans
  fi
  [[ $ans != 'n' ]] && fastboot --set-active=$slot2
  # flashing
  tg_send "Flashing build via fastboot"
  start_time=$(date +"%s")
  if [[ $FASTBOOT_PKG != 1 ]]; then
    for img in ./out/target/product/"${BUILD_PRODUCT_NAME}"/obj/PACKAGING/target_files_intermediates/*_*"${BUILD_PRODUCT_NAME}"-target_files/IMAGES/*.img; do
      [[ $img == "userdata" ]] && continue
      partName=$(basename "${img}" | sed 's/.img//')
      fastboot flash "${partName}" "${img}"
    done
  else
    fastboot update --skip-reboot --skip-secondary $PATH_TO_BUILD_FILE
  fi
  # after flash operations here (magisk as an example):
  # fastboot flash boot magisk_patched*.img
  get_time
  if [[ $AUTO_REBOOT != 1 ]]; then
    echo -en "${YELLOW}Continue boot now? y/[n]: ${NC}"
    read ans
  else
    ans=y
  fi
  if [[ $ans == 'y' ]]; then
    wait_for 5
    fastboot reboot
  fi
  tg_send "Flashing done in <code>${buildTime}</code>"
}

# handles the upload flag (-h)
handle_upload()
{
  tg_send "Uploading build"
  echo -e "${GREEN}Uploading...${NC}"
  isUploaded=0
  if [[ -f $PATH_TO_BUILD_FILE ]]; then
    start_time=$(date +"%s")
    pid=""
    if [[ $isSilent == 0 ]]; then
      upload_prog_send &
      pid=$!
    fi
    eval "${UPLOAD_CMD} ${PATH_TO_BUILD_FILE} ${UPLOAD_DEST}"
    if [[ $? == 0 ]]; then
      isUploaded=1
      get_time
    fi
    if [[ $isSilent == 0 ]] && [[ $pid != "" ]]; then
      while ps -p "$pid" > /dev/null; do
        kill -TERM "$pid"
        sleep 0.5
      done
    fi
  fi
  if [[ ! -f "${PATH_TO_BUILD_FILE}.sha256sum" ]]; then
    echo -e "${RED}Couldn't find sha256sum file. Generating.${NC}"
    touch "${PATH_TO_BUILD_FILE}.sha256sum"
    sha256sum "${PATH_TO_BUILD_FILE}" | cut -d ' ' -f1 > "${PATH_TO_BUILD_FILE}.sha256sum"
    echo >> "${PATH_TO_BUILD_FILE}.sha256sum"
  fi
  eval "${UPLOAD_CMD} ${PATH_TO_BUILD_FILE}.sha256sum ${UPLOAD_DEST}"
  if [[ $isUploaded == 1 ]]; then
    echo -e "${GREEN}Uploaded to: ${BLUE}${UPLOAD_DEST}${NC}"
    if [[ $isSilent == 0 ]]; then
      fileName=$(basename $PATH_TO_BUILD_FILE)
      # Edit next line according to the way you fetch the link:
      isFileLinkFailed=1
      isSHALinkFailed=1
      if [[ $UPLOAD_LINK_CMD != "" ]]; then
        cmd="${UPLOAD_LINK_CMD} ${UPLOAD_DEST}/${fileName}"
        fileLink=$(eval $cmd)
        isFileLinkFailed=$?
        cmd="${UPLOAD_LINK_CMD} ${UPLOAD_DEST}/${fileName}.sha256sum"
        shaLink=$(eval $cmd)
        isSHALinkFailed=$?
      fi
      if [[ $isFileLinkFailed != 0 ]] && [[ $isSHALinkFailed != 0 ]] && [[ $UPLOAD_LINK_ALT_CMD != '' ]]; then
        combinedLinks=$(eval $UPLOAD_LINK_ALT_CMD)
        res1=$?
        fileLink=$(echo "$combinedLinks" | cut -f 1 -d " ")
        res2=$?
        shaLink=$(echo "$combinedLinks" | cut -f 2 -d " ")
        res3=$?
        if [[ $res1 == 0 ]] && [[ $res2 == 0 ]] && [[ $fileLink != "" ]]; then
          isFileLinkFailed=0
        fi
        if [[ $res1 == 0 ]] && [[ $res3 == 0 ]] && [[ $shaLink != "" ]]; then
          isSHALinkFailed=0
        fi
      fi
      if [[ $isFileLinkFailed == 0 ]]; then
        echo -e "${GREEN}Link: ${BLUE}${fileLink}${NC}"
        if [[ $isSHALinkFailed == 0 ]]; then
          tg_send "Uploading done in \
<code>${buildTime}</code>: <a href=\"${fileLink}\">LINK</a>, <a href=\"${shaLink}\">SHA-256</a>"
        elif [[ $isFileLinkFailed == 0 ]]; then
          tg_send "Uploading done in \
<code>${buildTime}</code>: <a href=\"${fileLink}\">LINK</a>"
        else
          tg_send "Uploading done in \
<code>${buildTime}</code>"
        fi
      else
        echo -e "${RED}Getting link for ${BLUE}${BUILD_PRODUCT_NAME}${GREEN} failed${NC}"
        tg_send "Uploading done in <code>${buildTime}</code>"
      fi
      # unpin as we are done!
      if [[ $isSilent == 0 ]]; then
        ./telegramSend.sh --unpin --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" " "
      fi
      if [[ $UPLOAD_DONE_MSG != '' ]] && [[ $isSilent == 0 ]]; then
        ./telegramSend.sh --cite --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" "${UPLOAD_DONE_MSG}"
      fi
    fi
    if [[ $UPLOAD_PATH != '' ]] && [[ $FILE_MANAGER_CMD != '' ]]; then
      eval "${FILE_MANAGER_CMD} ${UPLOAD_PATH} &> /dev/null &"
      disown
    fi
    buildH=1
  else
    echo -e "${RED}Upload failed${NC}"
    tg_send "Upload failed"
    # unpin as we are done!
    if [[ $isSilent == 0 ]]; then
      ./telegramSend.sh --unpin --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" " "
      if [[ $FAILURE_MSG != '' ]]; then
        ./telegramSend.sh --cite --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" "${FAILURE_MSG}"
      fi
    fi
    buildH=0
  fi
}

# handles remaining build file
handle_rm()
{
  if [[ $AUTO_RM_BUILD == 2 ]]; then
    echo -en "${YELLOW}Remove original build file? [y]/n/A(lways)/N(ever): ${NC}"
    read isRM
    if [[ $isRM == 'A' ]]; then
      config_write "AUTO_RM_BUILD" 1 "${configFile}"
      isRM='y'
    elif [[ $isRM == 'N' ]]; then
      config_write "AUTO_RM_BUILD" 0 "${configFile}"
      isRM='n'
    fi
  elif [[ $AUTO_RM_BUILD == 1 ]]; then
    isRM='y'
  else
    isRM='n'
  fi
  if [[ $isRM != 'n' ]] && [[ $isKeep != 1 ]]; then
    rm "${PATH_TO_BUILD_FILE}"
    rm "${PATH_TO_BUILD_FILE}".sha256sum
    echo -e "${GREEN}Original build file (${BLUE}${PATH_TO_BUILD_FILE}${GREEN}) removed${NC}"
    # unpin as we are done!
    if [[ $isSilent == 0 ]]; then
      ./telegramSend.sh --unpin --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" " "
    fi
    exit 0
  fi
}

# formats the time passed relative to $start_time and stores it in $buildTime
get_time()
{
  end_time=$(date +"%s")
  tdiff=$(( end_time - start_time )) # time diff

  # Formatting total build time
  hours=$(( tdiff / 3600 ))
  hoursOut=$hours
  if [[ ${#hours} -lt 2 ]]; then
    hoursOut="0${hours}"
  fi

  mins=$(((tdiff % 3600) / 60))
  minsOut=$mins
  if [[ ${#mins} -lt 2 ]]; then
    minsOut="0${mins}"
  fi

  secs=$((tdiff % 60))
  if [[ ${#secs} -lt 2 ]]; then
    secs="0${secs}"
  fi

  buildTime="" # will store the formatted time to output
  if [[ $hours -gt 0 ]]; then
    buildTime="${hoursOut}:${minsOut}:${secs} (hh:mm:ss)"
  elif [[ $mins -gt 0 ]]; then
    buildTime="${minsOut}:${secs} (mm:ss)"
  else
    buildTime="${secs} seconds"
  fi
}

# wait for a given amount of time and outputs
# $1 time to wait in seconds
wait_for()
{
  secs=$1
  for (( i = $secs; i >= 1; i-- )); do
    tput sc
    echo -en "${YELLOW}Waiting for ${BLUE}${i}${NC} ${YELLOW}seconds${NC}"
    sleep 1
    tput rc
  done
  # clear this line, but remain on it
  tput sc
  tput ed
  tput rc
}

######################
##       Main       ##
######################

cd "$(dirname "$0")"

# Colors
RED="\033[1;31m" # For errors / warnings
GREEN="\033[1;32m" # For info
YELLOW="\033[1;33m" # For input requests
BLUE="\033[1;36m" # For info
NC="\033[0m" # reset color

# Load default config file
load_config build.conf

# handle arguments
configFile="build.conf"
isUpload=0
isPush=0
isFastboot=0
isClean=0
isSilent=0
isDry=0
isKeep=0
isMagisk=0
powerOpt=0
installClean=0
flagConflict=0
flashConflict=0
productChanged=0
targetChanged=0
typeChanged=0
tgConfigChanged=0
preBuildScripts=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h)
    # help
    print_help
    shift
    exit 0
    ;;
    -i)
    # initialize (write a new build.conf)
    init_conf
    echo -en "${YELLOW}Continue script? [${BLUE}y${YELLOW}]/n: ${NC}"
    read isExit
    if [[ $isExit == 'n' ]]; then
      exit 0
    fi
    shift
    ;;
    -u)
    # upload / user build
    isUpload=1
    shift
    ;;
    -p)
    # push
    isPush=1
    if [[ $flashConflict == 0 ]]; then
      flashConflict="-p"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}-p${RED} with ${BLUE}${flashConflict}${NC}"
      exit 3
    fi
    shift
    ;;
    -f)
    # fastboot
    isFastboot=1
    if [[ $flashConflict == 0 ]]; then
      flashConflict="-f"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}-f${RED} with ${BLUE}${flashConflict}${NC}"
      exit 3
    fi
    shift
    ;;
    -c)
    # clean
    isClean=1
    shift
    ;;
    -s)
    # silent
    isSilent=1
    shift
    ;;
    -d)
    # dry
    isDry=1
    shift
    ;;
    "--keep-file"|-k)
    # keep original build file
    isKeep=1
    shift
    ;;
    "--magisk"|-m)
    # patch and pull magisk from boot
    isMagisk=1
    shift
    ;;
    "--power")
    # power operations
    powerOpt=$2
    if [[ $powerOpt != "off" ]] && [[ $powerOpt != "reboot" ]]; then
      echo -e "${RED}ERROR! Power option not recognized.${NC}"
      exit 1
    fi
    shift 2
    ;;
    "--choose")
    # diff lunch commands
    if [[ $flagConflict == 0 ]]; then
      flagConflict="--choose"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}--choose${RED} with ${BLUE}${flagConflict}${NC}"
      exit 3
    fi
    TARGET_CHOOSE_CMD=$2
    targetChanged=1
    shift 2
    ;;
    "--product")
    # diff product fileName
    if [[ $flagConflict == 0 ]]; then
      flagConflict="--product"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}--product${RED} with ${BLUE}${flagConflict}${NC}"
      exit 3
    fi
    BUILD_PRODUCT_NAME=$2
    productChanged=1
    shift 2
    ;;
    "--type")
    # diff build type command
    BUILD_TYPE_CMD=$2
    typeChanged=1
    shift 2
    ;;
    "--config")
    # diff config file
    if [[ $flagConflict == 0 ]]; then
      flagConflict="--config"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}--config${RED} with ${BLUE}${flagConflict}${NC}"
      exit 3
    fi
    configFile=$2
    load_config $configFile
    shift 2
    ;;
    "--tg-config")
    # diff telegram config file
    TG_SEND_CFG_FILE=$2
    tgConfigChanged=1
    shift 2
    ;;
    "--installclean"|"--i-c")
    # make installclean
    installClean=1
    shift
    ;;
    "--script")
    # run a pre-build script
    preBuildScripts="${preBuildScripts}$2 "
    shift 2
    ;;
    --*|-*)
    # unsupported flags
    echo -e "${RED}ERROR! Unsupported flag ${BLUE}$1${NC}" >&2
    print_help
    exit 1
    ;;
  esac
done
echo

print_flags
check_confs
print_confs

echo
wait_for 5
echo -e "${GREEN}Starting build${NC}"
sleep 1

# changing dir to source path
cd $SOURCE_PATH ||
    echo -e "${RED}ERROR! Invalid source path ${BLUE}${SOURCE_PATH}${NC}"

# build
if [[ $isDry == 0 ]]; then
  pre_build
  pid=""
  if [[ $isSilent == 0 ]]; then
    prog_send &
    pid=$!
  fi
  eval $BUILD_CMD # build
  # no commands allowed in here!
  buildRes=$? # save result (exit code)
  get_time
  if [[ $isSilent == 0 ]] && [[ $pid != "" ]]; then
    while ps -p "$pid" > /dev/null; do
      kill -TERM "$pid"
      sleep 0.5
    done
  fi
else
  buildRes=0
fi

# handle built file
if [[ $buildRes == 0 ]]; then # if build succeeded
  # Count build files:
  NOFiles=$(find "${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}" \
      -maxdepth 1 -type f -name "${BUILD_FILE_NAME}" -prune -print | grep -c /)
  if [[ $NOFiles -gt 1 ]]; then
    echo -e "${GREEN}Found ${BLUE}${NOFiles}${GREEN} build files. Using newest${NC}"
    PATH_TO_BUILD_FILE=$(find "${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}" \
      -maxdepth 1 -type f -name "${BUILD_FILE_NAME}" -printf "%B@;%h/%f\n" \
      | sort -n | sed -n -e "1{p;q}" | cut -d ";" -f 2)
  elif [[ $NOFiles == 1 ]]; then
    PATH_TO_BUILD_FILE=$(find "${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}" \
      -maxdepth 1 -type f -name "${BUILD_FILE_NAME}")
  else
    echo -en "${RED}ERROR! Could not find build file ${BLUE}${BUILD_FILE_NAME}${RED} "
    echo -e "in ${BLUE}${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}${NC}"
    exit 1
  fi
  echo -e "${GREEN}Build file: ${BLUE}${PATH_TO_BUILD_FILE}${NC}"
  if [[ $isDry == 0 ]]; then
    tg_send "Build done in <code>${buildTime}</code>"
  fi

  buildH=0 # build handled? is set inside handle_* macros

  # magisk patching
  if [[ $isMagisk == 1 ]]; then
    magisk_patch
  fi
  # push build
  if [[ $isPush == 1 ]]; then
    handle_push
  fi
  # fastboot flash
  if [[ $isFastboot == 1 ]] && [[ $isPush != 1 ]]; then
    handle_fastboot
  fi
  # upload build
  if [[ $isUpload == 1 ]]; then
    handle_upload
  fi
  # remove original build file
  if [[ $buildH == 1 ]] && [[ $TWRP_SIDELOAD == 0 ]]; then
    handle_rm
  fi

  # unpin as we are done!
  if [[ $isSilent == 0 ]]; then
    ./telegramSend.sh --unpin --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" " "
  fi

  # Should only reach here if not handled yet
  if [[ $UNHANDLED_PATH != '' ]] && [[ $isKeep != 1 ]]; then
    mv $PATH_TO_BUILD_FILE "${UNHANDLED_PATH}"/
    mv $PATH_TO_BUILD_FILE.sha256sum "${UNHANDLED_PATH}"/
    if [[ $FILE_MANAGER_CMD != '' ]]; then
      eval "${FILE_MANAGER_CMD} ${UNHANDLED_PATH} &> /dev/null &"
      disown
    fi
  fi

  # power operations
  if [[ $powerOpt == "off" ]]; then
    echo -e "${GREEN}Powering off in ${BLUE}1 minute${NC}"
    echo -e "${GREEN}Press ${BLUE}Ctrl+C${GREEN} to cancel${NC}"
    wait_for 60
    poweroff
  elif [[ $powerOpt == "reboot" ]]; then
    echo -e "${GREEN}Rebooting in ${BLUE}1 minute${NC}"
    echo -e "${GREEN}Press ${BLUE}Ctrl+C${GREEN} to cancel${NC}"
    wait_for 60
    reboot
  fi

  exit $([[ $isUpload == 0 ]] || [[ $isUploaded == 1 ]])
elif [[ $isSilent == 0 ]]; then # if build failed
  if [[ -f "${SOURCE_PATH}/out/error.log" ]] && [[ -s "${SOURCE_PATH}/out/error.log" ]]; then
    tg_send "Build failed after <code>${buildTime}</code>."
    tg_send "${SOURCE_PATH}/out/error.log" # unpins for us
    if [[ $FAILURE_MSG != '' ]]; then
      ./telegramSend.sh --cite --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" "${FAILURE_MSG}"
    fi
  else
    echo -e "${RED}Can't find error file. Assuming build got canceled${NC}"
    tg_send "Build was canceled after <code>${buildTime}</code>."
    # unpin as we are done!
    if [[ $isSilent == 0 ]]; then
      ./telegramSend.sh --unpin --tmp "${tmpDir}" --config "${TG_SEND_CFG_FILE}" " "
    fi
  fi
fi

exit $buildRes # only reach if build fails
