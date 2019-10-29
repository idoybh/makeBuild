#!/bin/bash

# handle arguments
isUpload=0
isPush=0
isClean=0
isSilent=0
while getopts ":hiupcs" opt; do
  case $opt in
    h )
    echo 'Arguments available:'
    echo '-h to show this dialog'
    echo '-i for setup'
    echo '-u for upload'
    echo '-p for ADB push'
    echo '-c for a clean build'
    echo '-s to disbale telegram-send bot'
    exit 0
    ;;
    i )
    ;;
    u )
    echo 'User build!'
    isUpload=1
    ;;
    p )
    isPush=1
    ;;
    c )
    isClean=1
    ;;
    s )
    isSilent=1
    ;;
  esac
done

# build
source ./build/envsetup.sh
if [[ $isClean == 1 ]]; then
  echo 'Cleanning build'
  make clobber
fi
lunch aosip_dumpling-userdebug # target
if [[ $isSilent == 0 ]]; then
  telegram-send "Build started"
fi
start_time=$(date +"%s")

mka kronic # build
# no commands allowed in here!
buildRes=$? # save result

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

# handle build file
buildH=0 # build handled?
if [[ $buildRes = '0' ]]; then # if build succeeded
  if [[ $isSilent == 0 ]]; then
    telegram-send "Build done in ${buildTime}"
  fi
  if [[ $isUpload == 1 ]]; then
    if [[ $isSilent == 0 ]]; then
      telegram-send "Uploading build"
    fi
    echo "Uploading..."
    rclone copy -v ~/Android/derp/out/target/product/dumpling/AOSiP*.zip 'GDrive:/builds'
    rclone copy -v ~/Android/derp/out/target/product/dumpling/AOSiP*.zip.md5sum 'GDrive:/builds'
    if [ $? = '0' ]; then
      if [[ $isSilent == 0 ]]; then
        telegram-send "Upload done"
      fi
      dolphin 'gdrive:/idoybh2@gmail.com/builds/' &> /dev/null &
      disown
      buildH=1
    fi
  fi
  if [[ $isPush == 1 ]]; then
    echo "Pushing..."
    isOn='1'
    isRec='1'
    while [ $isOn != '0'] && [ $isRec != '0' ]; do
      adb kill-server
      adb start-server
      adb devices | grep 'device' &> /dev/null
      isOn=$?
      adb devices | grep 'recovery' &> /dev/null
      isRec=$?
      if [ $isRec = '0' ]; then
        adb push ~/Android/derp/out/target/product/dumpling/AOSiP*.zip /sdcard/Flash/Derp/
        buildH=1
      elif [ $isOn = '0' ]; then
        adb push ~/Android/derp/out/target/product/dumpling/AOSiP*.zip /storage/emulated/0/Flash/Derp/
        buildH=1
      else
        echo "Please plug in a device with ADB on and try again"
        echo
      fi
    done
  fi
  if [[ $buildH == 1 ]]; then
    rm ~/Android/derp/out/target/product/dumpling/AOSiP*.zip
    rm ~/Android/derp/out/target/product/dumpling/AOSiP*.zip.md5sum
    exit 0
  fi
  # Should only reach here if not handled yet
  mv ~/Android/derp/out/target/product/dumpling/AOSiP*.zip ~/Desktop/
  rm ~/Android/derp/out/target/product/dumpling/AOSiP*.zip.md5sum
  dolphin ~/Desktop/ &> /dev/null &
  disown
  exit 0
fi
# If build fails:
if [[ $isSilent == 0 ]]; then
  telegram-send "Build failed after ${buildTime}"
fi
exit $?
