#!/bin/bash
source build.conf || (echo "Error! no build.config file" && exit 2) # read configs
# handle arguments
isUpload=0
isPush=0
isClean=0
isSilent=0
while getopts ":hiupcs" opt; do
  case $opt in
    h ) # help
    echo 'Arguments available:'
    echo '-h to show this dialog'
    echo '-i for setup'
    echo '-u for upload'
    echo '-p for ADB push'
    echo '-c for a clean build'
    echo '-s to disbale telegram-send bot'
    exit 0
    ;;
    i ) # initialize (write a new build.conf)
    echo 'Initializing settings'
    echo 'Default values are inside [] just press enter to apply them'
    read -p "Enter clean command [make clobber]: " CLEAN_CMD
    if [[ $CLEAN_CMD = '' ]]; then
      CLEAN_CMD='make clobber'
    fi
    read -p "Enter target choose command [lunch aosip_dumpling-userdebug]: " TARGET_CHOOSE_CMD
    if [[ $TARGET_CHOOSE_CMD = '' ]]; then
      TARGET_CHOOSE_CMD='lunch aosip_dumpling-userdebug'
    fi
    read -p "Enter build command [mka kronic]: " BUILD_CMD
    if [[ $BUILD_CMD = '' ]]; then
      BUILD_CMD='mka kronic'
    fi
    read -p "Enter file manager command ('c' for none) [dolphin]: " FILE_MANAGER_CMD
    if [[ $FILE_MANAGER_CMD = '' ]]; then
      FILE_MANAGER_CMD='dolphin'
    fi
    read -p "Enter upload command [rclone copy -v]: " UPLOAD_CMD
    if [[ $UPLOAD_CMD = '' ]]; then
      UPLOAD_CMD='rclone copy -v'
    fi
    read -p "Enter upload destination [GDrive:/builds]: " UPLOAD_DEST
    if [[ $UPLOAD_DEST = '' ]]; then
      UPLOAD_DEST='GDrive:/builds'
    fi
    read -p "Enter upload folder path (local - 'c' for none) [gdrive:/idoybh2@gmail.com/builds/]: " UPLOAD_PATH
    if [[ $UPLOAD_PATH = '' ]]; then
      UPLOAD_PATH='gdrive:/idoybh2@gmail.com/builds/'
    fi
    read -p "Enter source path [.]: " SOURCE_PATH
    if [[ $SOURCE_PATH = '' ]]; then
      SOURCE_PATH='.'
    fi
    read -p "Enter build product name [dumpling]: " BUILD_PRODUCT_NAME
    if [[ $BUILD_PRODUCT_NAME = '' ]]; then
      BUILD_PRODUCT_NAME='dumpling'
    fi
    read -p "Enter built zip file name [AOSiP*.zip]: " BUILD_FILE_NAME
    if [[ $BUILD_FILE_NAME = '' ]]; then
      BUILD_FILE_NAME='AOSiP*.zip'
    fi
    read -p "Enter ADB push destination folder [Flash/Derp]: " ADB_DEST_FOLDER
    if [[ $ADB_DEST_FOLDER = '' ]]; then
      ADB_DEST_FOLDER='Flash/Derp'
    fi
    read -p "Enter default move path ('c' for none) [~/Desktop]: " UNHANDLED_PATH
    if [[ $UNHANDLED_PATH = '' ]]; then
      UNHANDLED_PATH='~/Desktop'
    fi
    echo "Note! if you chose no settings will only persist for current session"
    read -p "Write current config to file? [y]/n: " isWriteConf
    if [[ $isWriteConf != 'n' ]]; then
      echo "Rewriting file"
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
    echo 'User build!'
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
  echo "ERROR! Invalid source path in config. Must start with '.' or '/' or '~'"
  exit 2
fi
if [[ $UNHANDLED_PATH = '.' ]]; then # converting UNHANDLED_PATH
  UNHANDLED_PATH=$PWD
elif [[ ${UNHANDLED_PATH:0:1} = '.' ]]; then
  UNHANDLED_PATH=${UNHANDLED_PATH#"."}
  UNHANDLED_PATH="${PWD}/${UNHANDLED_PATH}"
elif [[ ${UNHANDLED_PATH:0:1} != '/' ]] && [[ ${UNHANDLED_PATH:0:1} != '~' ]] && [[ $UNHANDLED_PATH != 'c' ]]; then
  echo "ERROR! Invalid default path in config. Must start with '.' or '/' or '~' or be exactly 'c'"
  exit 2
fi

echo "Script dir: ${PWM}"
echo "Source dir: ${SOURCE_PATH}"
cd $SOURCE_PATH # changing dir to source path
PATH_TO_BUILD_FILE="${SOURCE_PATH}/out/target/product/${BUILD_PRODUCT_NAME}/${BUILD_FILE_NAME}"

# build
source "${SOURCE_PATH}/build/envsetup.sh"
if [[ $isClean == 1 ]]; then
  echo 'Cleanning build'
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
    echo "Uploading..."
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
    echo "Pushing..."
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
        buildH=1
      elif [[ $isOn == 0 ]]; then
        echo $CD
        eval "adb push ${PATH_TO_BUILD_FILE} /storage/emulated/0/${ADB_DEST_FOLDER}/"
        buildH=1
      else
        read -n1 -p "Please plug in a device with ADB enabled and press any key"
        echo
      fi
    done
  fi
  if [[ $buildH == 1 ]]; then
    read -p "Remove original build file? [y]/n: " isRM
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
#exit $?
