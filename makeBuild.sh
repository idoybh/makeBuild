#!/bin/bash
# Script was made by Ido Ben-Hur (@idoybh) due to pure bordom and to save time building diff roms

# Colors
RED="\033[1;31m" # For errors / warnings
GREEN="\033[1;32m" # For info
YELLOW="\033[1;33m" # For input requests
BLUE="\033[1;36m" # For info
NC="\033[0m" # reset color

source build.conf || (echo -e "${RED}Error! no ${BLUE}build.config${RED} file${NC}" && exit 2) # read configs

# handle arguments
isUpload=0
isPush=0
isClean=0
isSilent=0
isDry=0
while getopts ":hiupcsd" opt; do
  case $opt in
    h ) # help
    echo -e "${GREEN}Arguments available:${NC}"
    echo -e "${BLUE}-h${NC} to show this dialog and exit"
    echo -e "${BLUE}-i${NC} for setup"
    echo -e "${BLUE}-u${NC} for upload"
    echo -e "${BLUE}-p${NC} for ADB push"
    echo -e "${BLUE}-c${NC} for a clean build"
    echo -e "${BLUE}-s${NC} to disbale telegram-send bot"
    echo -e "${GREEN}Configuration file: ${BLUE}build.conf${NC}"
    echo -e "${GREEN}For more help visit: ${BLUE}https://github.com/idoybh/makeBuild/blob/master/README.md${NC}"
    exit 0
    ;;
    i ) # initialize (write a new build.conf)
    echo -e "${GREEN}Initializing settings${NC}"
    echo -e "${GREEN}Default values are inside [] just press enter to apply them${NC}"
    echo -en "${YELLOW}Enter clean command [${BLUE}make clobber${YELLOW}]: ${NC}"
    read CLEAN_CMD
    if [[ $CLEAN_CMD = '' ]]; then
      CLEAN_CMD='make clobber'
    fi
    echo -en "${YELLOW}Enter target choose command [${BLUE}lunch aosip_dumpling-userdebug${YELLOW}]: ${NC}"
    read TARGET_CHOOSE_CMD
    if [[ $TARGET_CHOOSE_CMD = '' ]]; then
      TARGET_CHOOSE_CMD='lunch aosip_dumpling-userdebug'
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
    echo -en "${YELLOW}Enter upload command [${BLUE}rclone copy -v${YELLOW}]: ${NC}"
    read UPLOAD_CMD
    if [[ $UPLOAD_CMD = '' ]]; then
      UPLOAD_CMD='rclone copy -v'
    fi
    echo -en "${YELLOW}Enter upload command [${BLUE}c${YELLOW}]: ${NC}"
    read TG_SEND_PRIOR_CMD
    if [[ $TG_SEND_PRIOR_CMD = '' ]]; then
      TG_SEND_PRIOR_CMD='c'
    fi
    echo -en "${YELLOW}Enter upload destination (remote) [${BLUE}GDrive:/builds${YELLOW}]: ${NC}"
    read UPLOAD_DEST
    if [[ $UPLOAD_DEST = '' ]]; then
      UPLOAD_DEST='GDrive:/builds'
    fi
    echo -en "${YELLOW}Enter upload folder path (local) ('c' for none) [${BLUE}gdrive:/idoybh2@gmail.com/builds/${YELLOW}]: ${NC}"
    read UPLOAD_PATH
    if [[ $UPLOAD_PATH = '' ]]; then
      UPLOAD_PATH='gdrive:/idoybh2@gmail.com/builds/'
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
    echo -en "${YELLOW}Enter built zip file name [${BLUE}AOSiP*.zip${YELLOW}]: ${NC}"
    read BUILD_FILE_NAME
    if [[ $BUILD_FILE_NAME = '' ]]; then
      BUILD_FILE_NAME='AOSiP*.zip'
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
    echo -e "${RED}Note! If you chose 'n' settings will only persist for current session${NC}"
    echo -en "${YELLOW}Write current config to file? [y]/n: ${NC}"
    read isWriteConf
    if [[ $isWriteConf != 'n' ]]; then
      echo -e "${GREEN}Rewriting file${NC}"
      rm build.conf
      touch build.conf
      echo "# config file for makeBuild.sh. Paths can be absolute / relative to script dir" > build.conf
      echo "# Except UPLOAD_PATH - Must be absolute" >> build.conf
      echo "export WAS_INIT=1 # weather initialized or not" >> build.conf
      echo "export CLEAN_CMD='${CLEAN_CMD}' # command for clean build" >> build.conf
      echo "export TARGET_CHOOSE_CMD='${TARGET_CHOOSE_CMD}' # command to choose target" >> build.conf
      echo "export BUILD_CMD='${BUILD_CMD}' # command to make the build" >> build.conf
      echo "export FILE_MANAGER_CMD='${FILE_MANAGER_CMD}' # command to open file manager (set to 'c' for none)" >> build.conf
      echo "export UPLOAD_CMD='${UPLOAD_CMD}' # command to upload the build" >> build.conf
      echo "export TG_SEND_PRIOR_CMD='c' # command to run before each telegram-send ('c' for none)" >> build.conf
      echo "export UPLOAD_DEST='${UPLOAD_DEST}' # upload command suffix (destiny)" >> build.conf
      echo "export UPLOAD_PATH='${UPLOAD_PATH}' # upload folder path in local ('c' for none)" >> build.conf
      echo "export SOURCE_PATH='${SOURCE_PATH}' # source path" >> build.conf
      echo "export BUILD_PRODUCT_NAME='${BUILD_PRODUCT_NAME}' # product name in out folder" >> build.conf
      echo "export BUILD_FILE_NAME='${BUILD_FILE_NAME}' # built zip file to handle in out folder" >> build.conf
      echo "export ADB_DEST_FOLDER='${ADB_DEST_FOLDER}' # path from internal storage to desired folder" >> build.conf
      echo "export UNHANDLED_PATH='${UNHANDLED_PATH}' # default path to move built zip file ('c' for none)" >> build.conf
      echo "" >> build.conf
    fi
    echo -en "${YELLOW}Continue script? [y]/n: ${NC}"
    read isExit
    if [[ isExit != 'n' ]]; then
      exit 0
    fi
    ;;
    u ) # upload / user build
    echo -e "${GREEN}User build!${NC}"
    isUpload=1
    ;;
    p ) # push
    echo -e "${GREEN}Push build!${NC}"
    isPush=1
    ;;
    c ) # clean
    isClean=1
    ;;
    s ) # silent
    echo -e "${GREEN}Silent build!${NC}"
    isSilent=1
    ;;
    d ) # dry
    echo -e "${GREEN}Dry run!${NC}"
    isDry=1
    ;;
  esac
done

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

cd $SOURCE_PATH # changing dir to source path
PATH_TO_BUILD_FILE="${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}/${BUILD_FILE_NAME}"

# build
source "${SOURCE_PATH}/build/envsetup.sh"
if [[ $isClean == 1 ]]; then
  echo -e "${GREEN}Cleanning build${NC}"
  eval $CLEAN_CMD
fi
eval $TARGET_CHOOSE_CMD # target
if [[ $isSilent == 0 ]]; then
  if [[ $TG_SEND_PRIOR_CMD != 'c' ]]; then
    eval $TG_SEND_PRIOR_CMD
  fi
  telegram-send --format html "Build started for <code>${BUILD_PRODUCT_NAME}</code>"
fi
start_time=$(date +"%s")

if [[ $isDry == 0 ]]; then
  eval $BUILD_CMD # build
  # no commands allowed in here!
  buildRes=$? # save result (exit code)
else
  buildRes=0
fi

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

# handle built file
buildH=0 # build handled?
if [[ $buildRes == 0 ]]; then # if build succeeded
  if [[ $isSilent == 0 ]]; then
    if [[ $TG_SEND_PRIOR_CMD != 'c' ]]; then
      eval $TG_SEND_PRIOR_CMD
    fi
    telegram-send --format html "Build done in <code>${buildTime}</code>"
  fi
  if [[ $isUpload == 1 ]]; then
    if [[ $isSilent == 0 ]]; then
      if [[ $TG_SEND_PRIOR_CMD != 'c' ]]; then
        eval $TG_SEND_PRIOR_CMD
      fi
      telegram-send "Uploading build"
    fi
    echo -e "${GREEN}Uploading...${NC}"
    eval "${UPLOAD_CMD} ${PATH_TO_BUILD_FILE} ${UPLOAD_DEST}"
    eval "${UPLOAD_CMD} ${PATH_TO_BUILD_FILE}.md5sum ${UPLOAD_DEST}"
    if [[ $? == 0 ]]; then
      echo -e "${GREEN}Uploaded to: ${BLUE}${UPLOAD_DEST}${NC}"
      if [[ $isSilent == 0 ]]; then
        if [[ $TG_SEND_PRIOR_CMD != 'c' ]]; then
          eval $TG_SEND_PRIOR_CMD
        fi
        telegram-send "Upload done"
      fi
      if [[ $UPLOAD_PATH != 'c' ]] && [[ $FILE_MANAGER_CMD != 'c' ]]; then
        eval "${FILE_MANAGER_CMD} ${UPLOAD_PATH} &> /dev/null &"
        disown
      fi
      buildH=1
    fi
  fi
  if [[ $isPush == 1 ]]; then
    echo -e "${GREEN}Pushing...${NC}"
    isOn='1' # Device is booted (reverse logic)
    isRec='1' # Device is on recovery mode (reverse logic)
    isPushed='1' # Weater the push went fine (reverse logic)
    while [[ $isOn != '0' ]] && [[ $isRec != '0' ]] && [[ $isPushed != '0' ]]; do
      echo -e "${GREEN}Restarting ADB server${NC}"
      adb kill-server
      adb start-server
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
      echo -en "${YELLOW}Flash now? y/[n]: ${NC}"
      read isFlash
      if [[ $isFlash == 'y' ]]; then
        if [[ $isOn == 0 ]]; then
          echo -e "${GREEN}Rebooting recovery${NC}"
          adb reboot recovery
          echo -e "${GREEN}Waiting for device${NC}"
          adb wait-for-device
          echo -en "${YELLOW}Press any key ${RED}after${YELLOW} decrypting data in TWRP${NC}"
          read -n1 temp
        fi
        # Add extra pre-flash operations here
        fileName=`basename $PATH_TO_BUILD_FILE`
        echo -e "${GREEN}Flashing ${BLUE}${fileName}${NC}"
        adb shell twrp install "/sdcard/${ADB_DEST_FOLDER}/${fileName}"
        # Add additional flash operations here (magisk provided as example)
        adb shell twrp install "/sdcard/Flash/Magisk/Magisk-v20.1\(20100\).zip"
        echo -en "${YELLOW}Press any key to reboot${NC}"
        read -n1 temp
        adb shell twrp reboot
      fi
    fi
  fi
  if [[ $buildH == 1 ]]; then
    echo -en "${YELLOW}Remove original build file? [y]/n: ${NC}"
    read isRM
    if [[ $isRM != 'n' ]]; then
      eval "rm ${PATH_TO_BUILD_FILE}"
      eval "rm ${PATH_TO_BUILD_FILE}.md5sum"
      echo -e "${GREEN}Original build file (${BLUE}${PATH_TO_BUILD_FILE}${GREEN}) removed${NC}"
      exit 0
    fi
  fi
  # Should only reach here if not handled yet
  if [[ $UNHANDLED_PATH != 'c' ]]; then
    eval "mv ${PATH_TO_BUILD_FILE} ${UNHANDLED_PATH}/"
    eval "rm ${PATH_TO_BUILD_FILE}.md5sum"
    if [[ $FILE_MANAGER_CMD != 'c' ]]; then
      eval "${FILE_MANAGER_CMD} ${UNHANDLED_PATH} &> /dev/null &"
    fi
    disown
  fi
  exit 0
fi
# If build fails:
if [[ $isSilent == 0 ]]; then
  if [[ $TG_SEND_PRIOR_CMD != 'c' ]]; then
    eval $TG_SEND_PRIOR_CMD
  fi
  telegram-send --format html "Build failed after <code>${buildTime}</code>"
fi
exit $?
