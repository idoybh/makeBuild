#!/bin/bash

# Colors
RED="\033[1;31m" # For errors / warnings
GREEN="\033[1;32m" # For info
YELLOW="\033[1;33m" # For input requests
BLUE="\033[1;36m" # For info
NC="\033[0m" # reset color

source build.conf || (echo "Error! no build.config file" && exit 2) # read configs

# handle arguments
isUpload=0
isPush=0
isClean=0
isSilent=0
while getopts ":hiupcs" opt; do
  case $opt in
    h ) # help
    echo -e "${GREEN}Arguments available:${NC}"
    echo '-h to show this dialog'
    echo '-i for setup'
    echo '-u for upload'
    echo '-p for ADB push'
    echo '-c for a clean build'
    echo '-s to disbale telegram-send bot'
    exit 0
    ;;
    i ) # initialize (write a new build.conf)
    echo -e "${GREEN}Initializing settings${NC}"
    echo -e "${GREEN}Default values are inside [] just press enter to apply them${NC}"
    echo -en "${YELLOW}Enter clean command [make clobber]: ${NC}"
    read CLEAN_CMD
    if [[ $CLEAN_CMD = '' ]]; then
      CLEAN_CMD='make clobber'
    fi
    echo -en "${YELLOW}Enter target choose command [lunch aosip_dumpling-userdebug]: ${NC}"
    read TARGET_CHOOSE_CMD
    if [[ $TARGET_CHOOSE_CMD = '' ]]; then
      TARGET_CHOOSE_CMD='lunch aosip_dumpling-userdebug'
    fi
    echo -en "${YELLOW}Enter build command [mka kronic]: ${NC}"
    read BUILD_CMD
    if [[ $BUILD_CMD = '' ]]; then
      BUILD_CMD='mka kronic'
    fi
    echo -en "${YELLOW}Enter file manager command ('c' for none) [dolphin]: ${NC}"
    read FILE_MANAGER_CMD
    if [[ $FILE_MANAGER_CMD = '' ]]; then
      FILE_MANAGER_CMD='dolphin'
    fi
    echo -en "${YELLOW}Enter upload command [rclone copy -v]: ${NC}"
    read UPLOAD_CMD
    if [[ $UPLOAD_CMD = '' ]]; then
      UPLOAD_CMD='rclone copy -v'
    fi
    echo -en "${YELLOW}Enter upload destination [GDrive:/builds]: ${NC}"
    read UPLOAD_DEST
    if [[ $UPLOAD_DEST = '' ]]; then
      UPLOAD_DEST='GDrive:/builds'
    fi
    echo -en "${YELLOW}Enter upload folder path (local - 'c' for none) [gdrive:/idoybh2@gmail.com/builds/]: ${NC}"
    read UPLOAD_PATH
    if [[ $UPLOAD_PATH = '' ]]; then
      UPLOAD_PATH='gdrive:/idoybh2@gmail.com/builds/'
    fi
    echo -en "${YELLOW}Enter source path [.]: ${NC}"
    read SOURCE_PATH
    if [[ $SOURCE_PATH = '' ]]; then
      SOURCE_PATH='.'
    fi
    echo -en "${YELLOW}Enter build product name [dumpling]: ${NC}"
    read BUILD_PRODUCT_NAME
    if [[ $BUILD_PRODUCT_NAME = '' ]]; then
      BUILD_PRODUCT_NAME='dumpling'
    fi
    echo -en "${YELLOW}Enter built zip file name [AOSiP*.zip]: ${NC}"
    read BUILD_FILE_NAME
    if [[ $BUILD_FILE_NAME = '' ]]; then
      BUILD_FILE_NAME='AOSiP*.zip'
    fi
    echo -en "${YELLOW}Enter ADB push destination folder [Flash/Derp]: ${NC}"
    read ADB_DEST_FOLDER
    if [[ $ADB_DEST_FOLDER = '' ]]; then
      ADB_DEST_FOLDER='Flash/Derp'
    fi
    echo -en "${YELLOW}Enter default move path ('c' for none) [~/Desktop]: ${NC}"
    read UNHANDLED_PATH
    if [[ $UNHANDLED_PATH = '' ]]; then
      UNHANDLED_PATH='~/Desktop'
    fi
    echo -e "${RED}Note! if you chose 'n' settings will only persist for current session${NC}"
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
      echo "export UPLOAD_DEST='${UPLOAD_DEST}' # upload command suffix (destiny)" >> build.conf
      echo "export UPLOAD_PATH='${UPLOAD_PATH}' # upload folder path in local ('c' for none)" >> build.conf
      echo "export SOURCE_PATH='${SOURCE_PATH}' # source path" >> build.conf
      echo "export BUILD_PRODUCT_NAME='${BUILD_PRODUCT_NAME}' # product name in out folder" >> build.conf
      echo "export BUILD_FILE_NAME='${BUILD_FILE_NAME}' # built zip file to handle in out folder" >> build.conf
      echo "export ADB_DEST_FOLDER='${ADB_DEST_FOLDER}' # path from internal storage to desired folder" >> build.conf
      echo "export UNHANDLED_PATH='${UNHANDLED_PATH}' # default path to move built zip file ('c' for none)" >> build.conf
      echo "" >> build.conf
    fi
    ;;
    u ) # upload / user build
    echo -e "${GREEN}User build!${NC}"
    isUpload=1
    ;;
    p ) # push
    isPush=1
    ;;
    c ) # clean
    isClean=1
    ;;
    s ) # silent
    isSilent=1
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

echo -e "${GREEN}Script dir:${BLUE} ${PWM}${NC}"
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
  telegram-send "Build started"
fi
start_time=$(date +"%s")

eval $BUILD_CMD # build
# no commands allowed in here!
buildRes=$? # save result (exit code)

end_time=$(date +"%s")
tdiff=$(($end_time-$start_time)) # time diff

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

buildTime="" # will store the time to output
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
    telegram-send "Build done in ${buildTime}"
  fi
  if [[ $isUpload == 1 ]]; then
    if [[ $isSilent == 0 ]]; then
      telegram-send "Uploading build"
    fi
    echo -e "${GREEN}Uploading...${NC}"
    eval "${UPLOAD_CMD} ${PATH_TO_BUILD_FILE} ${UPLOAD_DEST}"
    eval "${UPLOAD_CMD} ${PATH_TO_BUILD_FILE}.md5sum ${UPLOAD_DEST}"
    if [[ $? == 0 ]]; then
      if [[ $isSilent == 0 ]]; then
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
    isOn='1'
    isRec='1'
    while [[ $isOn != '0' ]] && [[ $isRec != '0' ]]; do
      adb kill-server
      adb start-server
      adb devices | grep -w 'device' &> /dev/null
      isOn=$?
      adb devices | grep -w 'recovery' &> /dev/null
      isRec=$?
      if [[ $isRec == 0 ]]; then
        eval "adb push ${PATH_TO_BUILD_FILE} /sdcard/${ADB_DEST_FOLDER}/"
        echo -e "${GREEN}Pushed to: ${BLUE}${ADB_DEST_FOLDER}${NC}"
        buildH=1
      elif [[ $isOn == 0 ]]; then
        eval "adb push ${PATH_TO_BUILD_FILE} /storage/emulated/0/${ADB_DEST_FOLDER}/"
        echo -e "${GREEN}Pushed to: ${BLUE}${ADB_DEST_FOLDER}${NC}"
        buildH=1
      else
        echo -en "${RED}Please plug in a device with ADB enabled and press any key${NC}"
        read -n1 temp
        echo
      fi
    done
  fi
  if [[ $buildH == 1 ]]; then
    echo -en "${YELLOW}Remove original build file? [y]/n: ${NC}"
    read isRM
    if [[ $isRM != 'n' ]]; then
      eval "rm ${PATH_TO_BUILD_FILE}"
      eval "rm ${PATH_TO_BUILD_FILE}.md5sum"
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
  telegram-send "Build failed after ${buildTime}"
fi
exit $?
