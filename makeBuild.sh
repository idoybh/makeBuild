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
  echo -e "${GREEN}Waiting for device${NC}"
  while [[ $isDet != '0' ]]; do # wait until detected
    adb kill-server &> /dev/null
    adb start-server &> /dev/null
    adb devices | grep -w "${state}" &> /dev/null
    isDet=$?
    sleep $delay
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
    if [[ -f "${tgmsg}" ]]; then
      telegram-send --file "${tgmsg}"
    else
      telegram-send --disable-web-page-preview --format html "${tgmsg}"
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
  echo -e "${BLUE}-p${NC} for ADB push"
  echo -e "${BLUE}-c${NC} for a clean build"
  echo -e "${BLUE}-s${NC} to disbale telegram-send bot"
  echo -e "${BLUE}-d${NC} to perform a dry run (no build)"
  echo -e "${BLUE}--power [ARG]${NC} to power off / reboot when done"
  echo -e "   ${BLUE}Suppoeted ARG(s): ${NC} off, reboot"
  echo -e "${BLUE}--choose [CMD]${NC} to change target choose command"
  echo -e "${BLUE}--product [ARG]${NC} to change target product name"
  echo -e "${BLUE}--config [FILE]${NC} to select a different config file"
  echo -e "${GREEN}Default configuration file: ${BLUE}build.conf${NC}"
  echo -e "${GREEN}For more help visit: ${BLUE}https://github.com/idoybh/makeBuild/blob/master/README.md${NC}"
}

# returns a property value from the config file
# $1: property name to read
# $2: config file name
config_read()
{
  rProp=$1
  cFile=$2
  lineNO=$(awk "/${rProp}/{ print NR; exit }" $cFile)
  echo $(sed "${lineNO}q;d" $cFile | awk -F  "=" '{print $NF}')
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
  config_write "BUILD_CMD" "${BUILD_CMD}" $confPath
  config_write "FILE_MANAGER_CMD" "${FILE_MANAGER_CMD}" $confPath
  config_write "UPLOAD_CMD" "${UPLOAD_CMD}" $confPath
  config_write "UPLOAD_LINK_CMD" "${UPLOAD_LINK_CMD}" $confPath
  config_write "TG_SEND_PRIOR_CMD" "${TG_SEND_PRIOR_CMD}" $confPath
  config_write "UPLOAD_DEST" "${UPLOAD_DEST}" $confPath
  config_write "UPLOAD_PATH" "${UPLOAD_PATH}" $confPath
  config_write "SOURCE_PATH" "${SOURCE_PATH}" $confPath
  config_write "BUILD_PRODUCT_NAME" "${BUILD_PRODUCT_NAME}" $confPath
  config_write "BUILD_FILE_NAME" "${BUILD_FILE_NAME}" $confPath
  config_write "ADB_DEST_FOLDER" "${ADB_DEST_FOLDER}" $confPath
  config_write "UNHANDLED_PATH" "${UNHANDLED_PATH}" $confPath
  config_write "AUTO_RM_BUILD" "${AUTO_RM_BUILD}" $confPath
  config_write "AUTO_REBOOT" "${AUTO_REBOOT}" $confPath
  config_write "TWRP_PIN" "${TWRP_PIN}" $confPath
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
    for (( ii = 1; ii <= $linesNO; ii++ )); do
      curLine=$(sed "${ii}q;d" $cFile)
      firstChar="${curLine:0:1}"
      if [[ $firstChar != "#" ]] && [[ $firstChar != '' ]]; then
        cVar=$(echo $curLine | awk '{print $1}')
        cVal=$(config_read $cVar $cFile)
        eval "export ${cVar}=\"${cVal}\""
      fi
    done
  else
    echo -e "${RED}ERROR! No ${BLUE}build.config${RED} file${NC}"
    exit 2
  fi
}

# performes required pre build operations
pre_build()
{
  source "${SOURCE_PATH}/build/envsetup.sh"
  if [[ $isClean == 1 ]]; then
    echo -e "${GREEN}Cleanning build${NC}"
    eval $CLEAN_CMD
  fi
  eval $TARGET_CHOOSE_CMD # target
  tg_send "Build started for <code>${BUILD_PRODUCT_NAME}</code>"
  start_time=$(date +"%s")
}

# formats the time passed relative to $start_time and stores it in $buildTime
get_time()
{
  end_time=$(date +"%s")
  tdiff=$(($end_time-$start_time)) # time diff

  # Formatting total build time
  hours=$(($tdiff / 3600 ))
  hoursOut=$hours
  if [[ ${#hours} -lt 2 ]]; then
    hoursOut="0${hours}"
  fi

  mins=$((($tdiff % 3600) / 60))
  minsOut=$mins
  if [[ ${#mins} -lt 2 ]]; then
    minsOut="0${mins}"
  fi

  secs=$(($tdiff % 60))
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
isClean=0
isSilent=0
isDry=0
powerOpt=0
flagConflict=0
while [[ $# > 0 ]]; do
  case "$1" in
    -h) # help
    print_help
    shift
    exit 0
    ;;
    -i) # initialize (write a new build.conf)
    echo -e "${GREEN}Initializing settings${NC}"
    echo -e "${GREEN}Default values are inside [] just press enter to apply them${NC}"
    echo -en "${YELLOW}Enter clean command [${BLUE}make clobber${YELLOW}]: ${NC}"
    read CLEAN_CMD
    if [[ $CLEAN_CMD = '' ]]; then
      CLEAN_CMD='make clobber'
    fi
    echo -en "${YELLOW}Enter target choose command [${BLUE}lunch derp_dumpling-userdebug${YELLOW}]: ${NC}"
    read TARGET_CHOOSE_CMD
    if [[ $TARGET_CHOOSE_CMD = '' ]]; then
      TARGET_CHOOSE_CMD='lunch derp_dumpling-userdebug'
    fi
    echo -en "${YELLOW}Enter build command [${BLUE}mka kronic${YELLOW}]: ${NC}"
    read BUILD_CMD
    if [[ $BUILD_CMD = '' ]]; then
      BUILD_CMD='mka kronic'
    fi
    echo -en "${YELLOW}Enter file manager command ('c' for none) [${BLUE}dolphin${YELLOW}]: ${NC}"
    read FILE_MANAGER_CMD
    if [[ $FILE_MANAGER_CMD = '' ]]; then
      FILE_MANAGER_CMD='dolphin'
    fi
    if [[ $FILE_MANAGER_CMD = 'c' ]]; then
      FILE_MANAGER_CMD=''
    fi
    echo -en "${YELLOW}Enter upload command [${BLUE}rclone copy -v${YELLOW}]: ${NC}"
    read UPLOAD_CMD
    if [[ $UPLOAD_CMD = '' ]]; then
      UPLOAD_CMD='rclone copy -v'
    fi
    echo -en "${YELLOW}Enter upload link command [${BLUE}rclone link${YELLOW}]: ${NC}"
    read UPLOAD_LINK_CMD
    if [[ $UPLOAD_LINK_CMD = '' ]]; then
      UPLOAD_LINK_CMD='rclone link'
    fi
    echo -en "${YELLOW}Enter telegram send prior command [${BLUE}none${YELLOW}]: ${NC}"
    read TG_SEND_PRIOR_CMD
    echo -en "${YELLOW}Enter upload destination (remote) [${BLUE}GDrive:/builds${YELLOW}]: ${NC}"
    read UPLOAD_DEST
    if [[ $UPLOAD_DEST = '' ]]; then
      UPLOAD_DEST='GDrive:/builds'
    fi
    echo -en "${YELLOW}Enter upload folder path (local) ('c' for none) [${BLUE}gdrive:/idoybh2/builds/${YELLOW}]: ${NC}"
    read UPLOAD_PATH
    if [[ $UPLOAD_PATH = '' ]]; then
      UPLOAD_PATH='gdrive:/idoybh2/builds/'
    fi
    if [[ $UPLOAD_PATH = 'c' ]]; then
      UPLOAD_PATH=''
    fi
    echo -en "${YELLOW}Enter source path [${BLUE}.${YELLOW}]: ${NC}"
    read SOURCE_PATH
    if [[ $SOURCE_PATH = '' ]]; then
      SOURCE_PATH='.'
    fi
    echo -en "${YELLOW}Enter build product name [${BLUE}dumpling${YELLOW}]: ${NC}"
    read BUILD_PRODUCT_NAME
    if [[ $BUILD_PRODUCT_NAME = '' ]]; then
      BUILD_PRODUCT_NAME='dumpling'
    fi
    echo -en "${YELLOW}Enter built zip file name [${BLUE}Derp*.zip${YELLOW}]: ${NC}"
    read BUILD_FILE_NAME
    if [[ $BUILD_FILE_NAME = '' ]]; then
      BUILD_FILE_NAME='Derp*.zip'
    fi
    echo -en "${YELLOW}Enter ADB push destination folder [${BLUE}Flash/Derp${YELLOW}]: ${NC}"
    read ADB_DEST_FOLDER
    if [[ $ADB_DEST_FOLDER = '' ]]; then
      ADB_DEST_FOLDER='Flash/Derp'
    fi
    echo -en "${YELLOW}Enter default move path ('c' for none) [${BLUE}~/Desktop${YELLOW}]: ${NC}"
    read UNHANDLED_PATH
    if [[ $UNHANDLED_PATH = '' ]]; then
      UNHANDLED_PATH='~/Desktop'
    fi
    if [[ $UNHANDLED_PATH = 'c' ]]; then
      UNHANDLED_PATH=''
    fi
    echo -en "${YELLOW}Automatically remove build file? y/[${BLUE}n${YELLOW}]/N(ever): ${NC}"
    read AUTO_RM_BUILD
    if [[ $AUTO_RM_BUILD = 'y' ]]; then
      AUTO_RM_BUILD=1
    elif [[ $AUTO_RM_BUILD = 'N' ]]; then
      AUTO_RM_BUILD=0
    else
      AUTO_RM_BUILD=2
    fi
    echo -en "${YELLOW}Automatically reboot (to and from recovery)? y/[${BLUE}n${YELLOW}]: ${NC}"
    read AUTO_REBOOT
    if [[ $AUTO_REBOOT = 'y' ]]; then
      AUTO_REBOOT=1
    else
      AUTO_REBOOT=0
    fi
    echo -en "${YELLOW}Set TWRP decryption pin (0 for decrypted; blank to wait) [${BLUE}blank${YELLOW}]: ${NC}"
    read TWRP_PIN
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
    echo -en "${YELLOW}Continue script? [${BLUE}y${YELLOW}]/n: ${NC}"
    read isExit
    if [[ $isExit == 'n' ]]; then
      exit 0
    fi
    shift
    ;;
    -u) # upload / user build
    echo -e "${GREEN}User build!${NC}"
    isUpload=1
    shift
    ;;
    -p) # push
    echo -e "${GREEN}Push build!${NC}"
    isPush=1
    shift
    ;;
    -c) # clean
    isClean=1
    shift
    ;;
    -s) # silent
    echo -e "${GREEN}Silent build!${NC}"
    isSilent=1
    shift
    ;;
    -d) # dry
    echo -e "${GREEN}Dry run!${NC}"
    isDry=1
    shift
    ;;
    "--power") #power operations
    powerOpt=$2
    echo
    if [[ $powerOpt == "off" ]]; then
      echo -e "${GREEN}Script will wait ${RED}1 minute${GREEN} and than perform a ${RED}power off${NC}"
      shift 2
    elif [[ $powerOpt == "reboot" ]]; then
      echo -e "${GREEN}Script will wait ${RED}1 minute${GREEN} and than perform a ${RED}reboot${NC}"
      shift 2
    else
      echo -e "${GREEN}ERROR! Power option not recognized.${NC}"
      exit 1
    fi
    echo
    ;;
    "--choose") # diff lunch commands
    echo
    if [[ $flagConflict == 0 ]]; then
      flagConflict="--choose"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}--choose${RED} with ${BLUE}${flagConflict}${NC}"
      exit 3
    fi
    TARGET_CHOOSE_CMD=$2
    echo -e "${GREEN}One-time target choose: ${BLUE}${TARGET_CHOOSE_CMD}${NC}"
    shift 2
    echo
    ;;
    "--product") # diff product fileName
    echo
    if [[ $flagConflict == 0 ]]; then
      flagConflict="--product"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}--product${RED} with ${BLUE}${flagConflict}${NC}"
      exit 3
    fi
    BUILD_PRODUCT_NAME=$2
    echo -e "${GREEN}One-time poduct name: ${BLUE}${TARGET_CHOOSE_CMD}${NC}"
    echo
    shift 2
    ;;
    "--config") # diff config file
    echo
    if [[ $flagConflict == 0 ]]; then
      flagConflict="--config"
    else
      echo -e "${RED}ERROR! Can't use ${BLUE}--config${RED} with ${BLUE}${flagConflict}${NC}"
      exit 3
    fi
    configFile=$2
    echo -e "${GREEN}Using one-time config file: ${BLUE}${configFile}${NC}"
    load_config $configFile
    shift 2
    ;;
    -*|--*=) # unsupported flags
    echo -e "${RED}ERROR! Unsupported flag ${BLUE}$1${NC}" >&2
    print_help
    exit 1
    ;;
  esac
done
echo

# Setting absolute paths, and checking configs
if [[ $SOURCE_PATH = '.' ]]; then # converting SOURCE_PATH
  SOURCE_PATH=$PWD
elif [[ ${SOURCE_PATH:0:1} = '.' ]]; then
  SOURCE_PATH=${SOURCE_PATH#"."}
  SOURCE_PATH="${PWD}/${SOURCE_PATH}"
elif [[ ${SOURCE_PATH:0:1} != '/' ]] && [[ ${SOURCE_PATH:0:1} != '~' ]]; then
  echo -e "${RED}ERROR! Invalid source path in config. Must start with '${NC}.${RED}' or '${NC}/${RED}' or '${NC}~${RED}'${NC}"
  exit 2
fi
if [[ $UNHANDLED_PATH = '.' ]]; then # converting UNHANDLED_PATH
  UNHANDLED_PATH=$PWD
elif [[ ${UNHANDLED_PATH:0:1} = '.' ]]; then
  UNHANDLED_PATH=${UNHANDLED_PATH#"."}
  UNHANDLED_PATH="${PWD}/${UNHANDLED_PATH}"
elif [[ ${UNHANDLED_PATH:0:1} != '/' ]] && [[ ${UNHANDLED_PATH:0:1} != '~' ]] && [[ $UNHANDLED_PATH != 'c' ]]; then
  echo -e "${RED}ERROR! Invalid source path in config. Must start with '${NC}.${RED}' or '${NC}/${RED}' or '${NC}~${RED}' or be exactly '${NC}c${RED}'${NC}"
  exit 2
fi

if [[ $WAS_INIT == 0 ]]; then # show not configured warning
  echo -e "${RED}WARNING! Script configs were never initialized!${NC}"
  echo -e "${GREEN}Please set ${BLUE}WAS_INIT${GREEN} to ${BLUE}1${GREEN} in ${BLUE}build.config${GREEN} to hide this warning${NC}"
  echo -e "${GREEN}You can also re run the script with ${BLUE}-i${GREEN} flag to do so"
  sleep 3
fi
echo -e "${GREEN}Script dir:${BLUE} ${PWD}${NC}"
echo -e "${GREEN}Source dir:${BLUE} ${SOURCE_PATH}${NC}"
echo -e "${GREEN}Product name:${BLUE} ${BUILD_PRODUCT_NAME}${NC}"
echo -e "${GREEN}Upload destination:${BLUE} ${UPLOAD_DEST}${NC}"
echo -e "${GREEN}ADB push destination:${BLUE} ${ADB_DEST_FOLDER}${NC}"
if [[ $UNHANDLED_PATH != 'c' ]]; then
  echo -e "${GREEN}Move build destination:${BLUE} ${UNHANDLED_PATH}${NC}"
fi
sleep 3

cd $SOURCE_PATH || echo -e "${RED}ERROR! Invalid source path ${BLUE}${SOURCE_PATH}${NC}" # changing dir to source path

# build
pre_build

if [[ $isDry == 0 ]]; then
  eval $BUILD_CMD # build
  # no commands allowed in here!
  buildRes=$? # save result (exit code)
else
  buildRes=0
fi

get_time

# handle built file
buildH=0 # build handled?
if [[ $buildRes == 0 ]]; then # if build succeeded
  # Count build files:
  NOFiles=`find "${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}" -maxdepth 1 -type f -name "${BUILD_FILE_NAME}" -prune -print | grep -c /`
  if [[ $NOFiles > 1 ]]; then
    echo -e "${GREEN}Found ${BLUE}${NOFiles}${GREEN} build files. Using newest${NC}"
    PATH_TO_BUILD_FILE=`find "${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}" -maxdepth 1 -type f -name "${BUILD_FILE_NAME}" | sed -n -e "1{p;q}"`
  elif [[ $NOFiles == 1 ]]; then
    PATH_TO_BUILD_FILE=`find "${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}" -maxdepth 1 -type f -name "${BUILD_FILE_NAME}"`
  else
    echo -e "${RED}ERROR! Failed to find build file ${BLUE}${BUILD_FILE_NAME}${RED} in ${BLUE}${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}${NC}"
    exit 1
  fi
  echo -e "${GREEN}Build file: ${BLUE}${PATH_TO_BUILD_FILE}${NC}"
  tg_send "Build done for <code>${BUILD_PRODUCT_NAME}</code> in <code>${buildTime}</code>"
  # push build
  if [[ $isPush == 1 ]]; then
    echo -e "${GREEN}Pushing...${NC}"
    isOn='1' # Device is booted (reverse logic)
    isRec='1' # Device is on recovery mode (reverse logic)
    isPushed='1' # Weater the push went fine (reverse logic)
    while [[ $isOn != '0' ]] && [[ $isRec != '0' ]] && [[ $isPushed != '0' ]]; do
      adb_reset
      adb devices | grep -w 'device' &> /dev/null
      isOn=$?
      adb devices | grep -w 'recovery' &> /dev/null
      isRec=$?
      if [[ $isRec == 0 ]]; then
        echo -e "${GREEN}Device detected in ${BLUE}recovery${NC}"
        eval "adb push ${PATH_TO_BUILD_FILE} /sdcard/${ADB_DEST_FOLDER}/"
        isPushed=$?
        if [[ $isPushed == 0 ]]; then
          echo -e "${GREEN}Pushed to: ${BLUE}${ADB_DEST_FOLDER}${NC}"
          buildH=1
        else
          echo -en "${RED}Push error (see output). Press any key to try again${NC}"
          read -n1 temp
          isPushed='0'
          echo
        fi
      elif [[ $isOn == 0 ]]; then
        echo -e "${GREEN}Device detected${NC}"
        eval "adb push ${PATH_TO_BUILD_FILE} /storage/emulated/0/${ADB_DEST_FOLDER}/"
        isPushed=$?
        if [[ $isPushed == 0 ]]; then
          echo -e "${GREEN}Pushed to: ${BLUE}${ADB_DEST_FOLDER}${NC}"
          buildH=1
        else
          echo -en "${RED}Push error (see output). Press any key to try again${NC}"
          read -n1 temp
          echo
        fi
      else
        echo -en "${RED}Please plug in a device with ADB enabled and press any key${NC}"
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
        if [[ $isOn == 0 ]]; then
          echo -e "${GREEN}Rebooting to recovery${NC}"
          adb reboot recovery
          adb_wait 'recovery' 3
          isDecrypted=0
          echo -e "${GREEN}Device detected in ${BLUE}recovery${NC}"
          if [[ $TWRP_PIN != '' ]] && [[ $TWRP_PIN != '0' ]]; then
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
          if [[ $TWRP_PIN != '0' ]] && [[ $isDecrypted != 1 ]]; then
            echo -en "${YELLOW}Press any key ${RED}after${YELLOW} decrypting data in TWRP${NC}"
            read -n1 temp
            echo
            adb_reset
          fi
        else
          adb_reset
        fi
        # Add extra pre-flash operations here
        fileName=`basename $PATH_TO_BUILD_FILE`
        echo -e "${GREEN}Flashing ${BLUE}${fileName}${NC}"
        isFlashed=0
        while [[ $isFlashed == 0 ]]; do
          adb shell twrp install "/sdcard/${ADB_DEST_FOLDER}/${fileName}"
          if [[ $? != 0 ]]; then
            echo -en "${RED}Flash error. Press any key to try again"
            read -n1 temp
          else
            isFlashed=1
          fi
          # Add additional flash operations here (magisk provided as example)
          # adb shell twrp install "/sdcard/Flash/Magisk/Magisk-v20.1\(20100\).zip"
        done
        if [[ $AUTO_REBOOT == 0 ]]; then
          echo -en "${YELLOW}Press any key to reboot${NC}"
          read -n1 temp
          echo
        fi
        adb shell twrp reboot
      fi
    fi
  fi
  # upload build
  if [[ $isUpload == 1 ]]; then
    tg_send "Uploading build"
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
    isMD5Uploaded=0
    if [[ -f "${PATH_TO_BUILD_FILE}.md5sum" ]]; then
      eval "${UPLOAD_CMD} ${PATH_TO_BUILD_FILE}.md5sum ${UPLOAD_DEST}"
      isMD5Uploaded=1
    else
      echo -e "${RED}Couldn't find md5sum file. Not uploading${NC}"
    fi
    if [[ $isUploaded == 1 ]]; then
      echo -e "${GREEN}Uploaded to: ${BLUE}${UPLOAD_DEST}${NC}"
      if [[ $isSilent == 0 ]]; then
        fileName=`basename $PATH_TO_BUILD_FILE`
        # Edit next line according to the way you fetch the link:
        cmd="${UPLOAD_LINK_CMD} ${UPLOAD_DEST}/${fileName}"
        fileLink=`eval $cmd`
        isFileLinkFailed=$?
        if [[ $isMD5Uploaded == 1 ]]; then
          cmd="${UPLOAD_LINK_CMD} ${UPLOAD_DEST}/${fileName}.md5sum"
          md5Link=`eval $cmd`
          isMD5LinkFailed=$?
        fi
        if [[ $isFileLinkFailed == 0 ]]; then
          echo -e "${GREEN}Link: ${BLUE}${fileLink}${NC}"
          if [[ $isMD5LinkFailed == 0 ]]; then
            tg_send "Uploading <code>${BUILD_PRODUCT_NAME}</code> done in <code>${buildTime}</code>: <a href=\"${fileLink}\">LINK</a>, <a href=\"${md5Link}\">MD5</a>"
          else
            tg_send "Uploading <code>${BUILD_PRODUCT_NAME}</code> done in <code>${buildTime}</code>: <a href=\"${fileLink}\">LINK</a>"
          fi
        else
          echo -e "${RED}Getting link for ${BLUE}${BUILD_PRODUCT_NAME}${GREEN} failed${NC}"
          tg_send "Getting link for <code>${BUILD_PRODUCT_NAME}</code> failed"
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
    fi
  fi
  # remove original build file
  if [[ $buildH == 1 ]]; then
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
    if [[ $isRM != 'n' ]]; then
      eval "rm ${PATH_TO_BUILD_FILE}"
      eval "rm ${PATH_TO_BUILD_FILE}.md5sum"
      echo -e "${GREEN}Original build file (${BLUE}${PATH_TO_BUILD_FILE}${GREEN}) removed${NC}"
      exit 0
    fi
  fi
  # Should only reach here if not handled yet
  if [[ $UNHANDLED_PATH != '' ]]; then
    eval "mv ${PATH_TO_BUILD_FILE} ${UNHANDLED_PATH}/"
    eval "rm ${PATH_TO_BUILD_FILE}.md5sum"
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

  exit 0
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
exit $?
