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
# $1: device state
# $2: delay between scans in seconds
adb_wait()
{
  state=$1
  delay=$2
  if [[ $state != 'device' ]]; then
    echo -e "${GREEN}Waiting for device in ${BLUE}${state}${NC}"
  else
    echo -e "${GREEN}Waiting for device"
  fi
  while [[ $isDet != '0' ]]; do # wait until detected
    adb kill-server &> /dev/null
    adb start-server &> /dev/null
    adb devices | grep -w "${state}" &> /dev/null
    isDet=$?
    [[ $isDet != '0' ]] && sleep $delay
  done
}

# sends a msg in telegram if not silent.
# $1: the msg / file to send
tg_send()
{
  tgmsg=$1
  if [[ $isSilent == 0 ]]; then
    if [[ $TG_SEND_PRIOR_CMD != '' ]]; then
      eval $TG_SEND_PRIOR_CMD
    fi
    tgcmd=''
    if [[ $TG_SEND_CFG_FILE != '' ]]; then
      tgcmd="--config ${TG_SEND_CFG_FILE}"
    fi
    if [[ -f "${tgmsg}" ]]; then
      telegram-send $tgcmd --file "${tgmsg}"
    else
      telegram-send $tgcmd --disable-web-page-preview --format html "${tgmsg}"
    fi
  fi
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
  echo -e "${BLUE}-s${NC} to disable telegram-send bot"
  echo -e "${BLUE}-d${NC} to perform a dry run (no build)"
  echo -e "${BLUE}--keep-file | -k${NC} to skip removal of original build file"
  echo -e "${BLUE}--power [ARG]${NC} to power off / reboot when done"
  echo -e "   ${BLUE}Supported ARG(s): ${NC} off, reboot"
  echo -e "${BLUE}--choose [CMD]${NC} to change target choose command"
  echo -e "${BLUE}--type [CMD]${NC} to change build type command"
  echo -e "${BLUE}--product [ARG]${NC} to change target product name"
  echo -e "${BLUE}--config [FILE]${NC} to select a different config file"
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
  eval "echo ${res}"
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
  config_write "TWRP_PIN" "${TWRP_PIN}" $confPath
  config_write "TWRP_SIDELOAD" "${TWRP_SIDELOAD}" $confPath
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

# performes required pre build operations
pre_build()
{
  source "${SOURCE_PATH}/build/envsetup.sh"
  if [[ $isClean == 1 ]]; then
    echo -e "${GREEN}Cleaning build${NC}"
    eval $CLEAN_CMD
  fi
  eval $TARGET_CHOOSE_CMD # target
  if [[ $installClean == 1 ]]; then
    make installclean
  fi
  if [[ $BUILD_TYPE_CMD != '' ]]; then
    eval $BUILD_TYPE_CMD # build type
  fi
  if [[ $PRE_BUILD_SCRIPT != '' ]] && [[ -f $PRE_BUILD_SCRIPT ]]; then
    source $PRE_BUILD_SCRIPT
  fi
  tg_send "Build started for <code>${BUILD_PRODUCT_NAME}</code>"
  start_time=$(date +"%s")
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
powerOpt=0
installClean=0
flagConflict=0
flashConflict=0
productChanged=0
targetChanged=0
typeChanged=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h) # help
    print_help
    shift
    exit 0
    ;;
    -i) # initialize (write a new build.conf)
    init_conf
    echo -en "${YELLOW}Continue script? [${BLUE}y${YELLOW}]/n: ${NC}"
    read isExit
    if [[ $isExit == 'n' ]]; then
      exit 0
    fi
    shift
    ;;
    -u) # upload / user build
    isUpload=1
    shift
    ;;
    -p) # push
    isPush=1
    if [[ $flashConflict == 0 ]]; then
      flashConflict="-p"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}-p${RED} with ${BLUE}${flashConflict}${NC}"
      exit 3
    fi
    shift
    ;;
    -f) # fastboot
    isFastboot=1
    if [[ $flashConflict == 0 ]]; then
      flashConflict="-f"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}-f${RED} with ${BLUE}${flashConflict}${NC}"
      exit 3
    fi
    shift
    ;;
    -c) # clean
    isClean=1
    shift
    ;;
    -s) # silent
    isSilent=1
    shift
    ;;
    -d) # dry
    isDry=1
    shift
    ;;
    "--keep-file"|-k) # keep original build file
    isKeep=1
    shift
    ;;
    "--power") #power operations
    powerOpt=$2
    if [[ $powerOpt != "off" ]] && [[ $powerOpt != "reboot" ]]; then
      echo -e "${RED}ERROR! Power option not recognized.${NC}"
      exit 1
    fi
    shift 2
    ;;
    "--choose") # diff lunch commands
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
    "--product") # diff product fileName
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
    "--type") # diff build type command
    BUILD_TYPE_CMD=$2
    typeChanged=1
    shift 2
    ;;
    "--config") # diff config file
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
    "--installclean"|"--i-c") # make installclean
    installClean=1
    shift
    ;;
    --*|-*) # unsupported flags
    echo -e "${RED}ERROR! Unsupported flag ${BLUE}$1${NC}" >&2
    print_help
    exit 1
    ;;
  esac
done
echo

# Printing a table to summarize flags
if [[ $productChanged != 0 ]] || [[ $targetChanged != 0 ]] || [[ $typeChanged != 0 ]] || [[ $configFile != "build.conf" ]]; then
  echo -e "${YELLOW}----OVERRIDES----${NC}"
fi
[[ $configFile != "build.conf" ]] && echo -en "${RED}"
echo -e "Config file  : ${BLUE}${configFile}${NC}"
[[ $configFile != "build.conf" ]] && diff --color build.conf $configFile && echo "-----------------"
[[ $productChanged != 0 ]] && echo -e "${RED}Product      : ${BUILD_PRODUCT_NAME}${NC}"
[[ $targetChanged != 0 ]] && echo -e "${RED}Type cmd     : ${BUILD_TYPE_CMD}${NC}"
[[ $typeChanged != 0 ]] && echo -e "${RED}Target cmd   : ${TARGET_CHOOSE_CMD}${NC}"
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
echo
echo -e "${YELLOW}-------ETC-------${NC}"
[[ $isSilent == 1 ]] && echo -en "${RED}"
echo -e "Silent       : ${isSilent}${NC}"
[[ $powerOpt != 0 ]] && echo -en "${RED}"
echo -e "Power        : ${powerOpt}${NC}"

# checking configs (paths only, there's a limit for the spoonfeed)
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
  sleep 3
fi

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
echo
echo -en "${YELLOW}Waiting for ${BLUE}5${NC} ${YELLOW}seconds${NC}"
for (( i = 5; i >= 1; i-- )); do
  echo -e '\e[1A\e[K'
  echo -en "${YELLOW}Waiting for ${BLUE}${i}${NC} ${YELLOW}seconds${NC}"
  sleep 1
done
echo -e '\e[1A\e[K'
echo -e "${GREEN}Starting build       ${NC}"
sleep 1

# changing dir to source path
cd $SOURCE_PATH ||
    echo -e "${RED}ERROR! Invalid source path ${BLUE}${SOURCE_PATH}${NC}"

# build
if [[ $isDry == 0 ]]; then
  pre_build
  eval $BUILD_CMD # build
  # no commands allowed in here!
  buildRes=$? # save result (exit code)
  get_time
else
  buildRes=0
fi

# handle built file
buildH=0 # build handled?
if [[ $buildRes == 0 ]]; then # if build succeeded
  # Count build files:
  NOFiles=$(find "${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}" \
      -maxdepth 1 -type f -name "${BUILD_FILE_NAME}" -prune -print | grep -c /)
  if [[ $NOFiles -gt 1 ]]; then
    echo -e "${GREEN}Found ${BLUE}${NOFiles}${GREEN} build files. Using newest${NC}"
    PATH_TO_BUILD_FILE=$(find "${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}" \
      -maxdepth 1 -type f -name "${BUILD_FILE_NAME}" | sed -n -e "1{p;q}")
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
    tg_send "Build done for <code>${BUILD_PRODUCT_NAME}</code> in <code>${buildTime}</code>"
  fi
  # push build
  if [[ $isPush == 1 ]]; then
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
        tg_send "Flashing <code>${BUILD_PRODUCT_NAME}</code> build"
        start_time=$(date +"%s")
        if [[ $isOn == 0 ]]; then
          echo -e "${GREEN}Rebooting to recovery${NC}"
          adb reboot recovery
          isDecrypted=0
          if [[ $TWRP_SIDELOAD == 0 ]]; then
            adb_wait 'recovery' 3
            echo -e "${GREEN}Device detected in ${BLUE}recovery${NC}"
          fi
          if [[ $TWRP_PIN != '' ]] && [[ $TWRP_PIN != '0' ]] && [[ $TWRP_SIDELOAD == 0 ]]; then
            adb_reset
            echo -e "${GREEN}Trying decryption with provided pin${NC}"
            adb shell twrp decrypt $TWRP_PIN
            if [[ $? == 0 ]]; then
              isDecrypted=1
              echo -e "${GREEN}Data decrypted${NC}"
              echo -e "${GREEN}Waiting for ${BLUE}5 seconds${NC}"
              sleep 5
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
            adb_wait 'sideload' 3
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
        tg-send "Flashing <code>${BUILD_PRODUCT_NAME}</code> done in <code>${buildTime}</code>"
      fi
    fi
  fi
  # fastboot flash
  if [[ $isFastboot == 1 ]] && [[ $isPush != 1 ]]; then
    if [[ $AUTO_REBOOT == 1 ]]; then
      adb reboot bootloader
    else
      echo -en "${YELLOW}Reboot to fastboot? y/[n]: ${NC}"
      read ans
      [[ $ans == 'y' ]] && adb reboot bootloader
    fi
    echo -e "${GREEN}Waiting for device in ${BLUE}bootloader${NC}"
    fastboot wait-for-device &> /dev/null
    sleep 3
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
    tg_send "Flashing <code>${BUILD_PRODUCT_NAME}</code> build"
    fastboot update --skip-reboot --skip-secondary $PATH_TO_BUILD_FILE
    # after flash operations here (magisk as an example):
    # fastboot flash boot magisk_patched*
    if [[ $AUTO_REBOOT != 1 ]]; then
      echo -en "${YELLOW}Continue boot now? y/[n]: ${NC}"
      read ans
    else
      ans=y
    fi
    [[ $ans == 'y' ]] && sleep 5 && fastboot reboot
  fi
  # upload build
  if [[ $isUpload == 1 ]]; then
    tg_send "Uploading <code>${BUILD_PRODUCT_NAME}</code> build"
    echo -e "${GREEN}Uploading...${NC}"
    isUploaded=0
    if [[ -f $PATH_TO_BUILD_FILE ]]; then
      start_time=$(date +"%s")
      eval "${UPLOAD_CMD} ${PATH_TO_BUILD_FILE} ${UPLOAD_DEST}"
      if [[ $? == 0 ]]; then
        isUploaded=1
        get_time
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
        cmd="${UPLOAD_LINK_CMD} ${UPLOAD_DEST}/${fileName}"
        fileLink=$(eval $cmd)
        isFileLinkFailed=$?
        cmd="${UPLOAD_LINK_CMD} ${UPLOAD_DEST}/${fileName}.sha256sum"
        md5Link=$(eval $cmd)
        isMD5LinkFailed=$?
        if [[ $isFileLinkFailed == 0 ]]; then
          echo -e "${GREEN}Link: ${BLUE}${fileLink}${NC}"
          if [[ $isMD5LinkFailed == 0 ]]; then
            tg_send "Uploading <code>${BUILD_PRODUCT_NAME}</code> done in \
<code>${buildTime}</code>: <a href=\"${fileLink}\">LINK</a>, <a href=\"${md5Link}\">SHA-256</a>"
          else
            tg_send "Uploading <code>${BUILD_PRODUCT_NAME}</code> done in \
<code>${buildTime}</code>: <a href=\"${fileLink}\">LINK</a>"
          fi
        else
          echo -e "${RED}Getting link for ${BLUE}${BUILD_PRODUCT_NAME}${GREEN} failed${NC}"
          tg_send "Uploading <code>${BUILD_PRODUCT_NAME}</code> done in <code>${buildTime}</code>"
        fi
        if [[ $UPLOAD_DONE_MSG != '' ]]; then
          tg_send "${UPLOAD_DONE_MSG}"
        fi
      fi
      if [[ $UPLOAD_PATH != '' ]] && [[ $FILE_MANAGER_CMD != '' ]]; then
        eval "${FILE_MANAGER_CMD} ${UPLOAD_PATH} &> /dev/null &"
        disown
      fi
      buildH=1
    else
      echo -e "${RED}Upload failed${NC}"
      tg_send "Upload failed for <code>${BUILD_PRODUCT_NAME}</code>"
      buildH=0
    fi
  fi
  # remove original build file
  if [[ $buildH == 1 ]] && [[ $TWRP_SIDELOAD == 0 ]]; then
    if [[ $AUTO_RM_BUILD == 2 ]]; then
      echo -en "${YELLOW}Remove original build file? [y]/n/A(lways)/N(ever): ${NC}"
      read isRM
      if [[ $isRM == 'A' ]]; then
        config_write "AUTO_RM_BUILD" 1 $configFile
        isRM='y'
      elif [[ $isRM == 'N' ]]; then
        config_write "AUTO_RM_BUILD" 0 $configFile
        isRM='n'
      fi
    elif [[ $AUTO_RM_BUILD == 1 ]]; then
      isRM='y'
    else
      isRM='n'
    fi
    if [[ $isRM != 'n' ]] && [[ $isKeep != 1 ]]; then
      rm $PATH_TO_BUILD_FILE
      rm $PATH_TO_BUILD_FILE.sha256sum
      echo -e "${GREEN}Original build file (${BLUE}${PATH_TO_BUILD_FILE}${GREEN}) removed${NC}"
      exit 0
    fi
  fi
  # Should only reach here if not handled yet
  if [[ $UNHANDLED_PATH != '' ]] && [[ $isKeep != 1 ]]; then
    mv $PATH_TO_BUILD_FILE "${UNHANDLED_PATH}"/
    mv $PATH_TO_BUILD_FILE.sha256sum "${UNHANDLED_PATH}"/
    if [[ $FILE_MANAGER_CMD != '' ]]; then
      eval "${FILE_MANAGER_CMD} ${UNHANDLED_PATH} &> /dev/null &"
    fi
    disown
  fi

  # power operations
  if [[ $powerOpt == "off" ]]; then
    echo -e "${GREEN}Powering off in ${BLUE}1 minute${NC}"
    echo -e "${GREEN}Press ${BLUE}Ctrl+C${GREEN} to cancel${NC}"
    sleep 60
    poweroff
  elif [[ $powerOpt == "reboot" ]]; then
    echo -e "${GREEN}Rebooting in ${BLUE}1 minute${NC}"
    echo -e "${GREEN}Press ${BLUE}Ctrl+C${GREEN} to cancel${NC}"
    sleep 60
    reboot
  fi

  exit $([[ $isUpload == 0 ]] || [[ $isUploaded == 1 ]])
fi
# If build fails:
if [[ $isSilent == 0 ]]; then
  if [[ -f "${SOURCE_PATH}/out/error.log" ]] && [[ -s "${SOURCE_PATH}/out/error.log" ]]; then
    tg_send "Build failed after <code>${buildTime}</code>."
    tg_send "${SOURCE_PATH}/out/error.log"
  else
    echo -e "${RED}Can't find error file. Assuming build got canceled${NC}"
    tg_send "Build was canceled after <code>${buildTime}</code>."
  fi
fi
exit $buildRes
