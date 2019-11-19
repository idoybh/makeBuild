# makeBuild generic build script
Yet another build script for AOSP ROMs
This script's aim is to be configureable for use with any rom / environment, for your liking.
It currently supports uploading and or pushing the built file to a given path and it is color coded.   
This script uses *telegram-send* (see: https://github.com/rahiel/telegram-send) and sends tg messages with build status and time.

## Flags
You can start the script with the following flags:
* **-h** to show help and other flags (stands for help)
* **-i** to setup build.config through a CLI (stands for init)
* **-u** to upload the built file (stands for upload / user)
* **-p** to push the built file through adb (stands for push)
* **-c** to make a clean build (stands for clean - duh)
* **-s** to disable telegram-send (stands for silent)
* **-d** to run without building (stands for dry)
* **--power _[ARG]_** to power off or reboot if build successful
  * _[ARG]_ should be: `off` or `reboot`
* **--choose _[CMD]_** to change target choose command (see [here](#target_choose_cmd)) temporarily
* **--product _[ARG]_** to change build product name (see [here](#build_product_name)) temporarily
* **--config _[FILE]_** to change the config file temporarily

**Note** `--config`, `--choose` and `--product` should **not** be used together and will **not** affect build.conf - Build will error out if those are used together.

## build.conf
The default configuration file of the script.
Can be changed per run with the flag `--config`. 

##### WAS_INIT
Just a flag to show weather the **-i** flag was used before.
Set this to any other value than 0 to dismiss the warning.
Set to `'0'` by default
##### CLEAN_CMD
Set this to whatever command you use to make a clean build.
Set to `'make clobber'` by default.
##### TARGET_CHOOSE_CMD
Set this to whatever command you use to "lunch" / select the product to build prior to the build command.
Set to `'lunch aosip_dumpling-userdebug'` by default.
##### BUILD_CMD
Set this to whatever command you use to initiate the build process. It will be run inside the source directory.
Set to `'mka kronic'` by default
##### FILE_MANAGER_CMD
Set this to whatever command you use to lunch your file manager.
It is usually just the name of your file manager and depends on your linux distribution.
Setting this to `'c'` will disable launching file manager across the script. Usefull for GClod or SSH for example.
Set to `'dolphin'` by default (KDE's default file manager)
##### UPLOAD_CMD
Set this to whatever command you use to upload you file.
Set to `'rclone copy -v'` by default.
##### UPLOAD_LINK_CMD
Set this to whatever command you use to get download links for uploaded files.
Set to `'rclone link'` by default.
##### UPLOAD_DEST
Set this to the upload destination **remote** folder.
It will be added at the very end of the upload command, after the local built file path.
Set to `'GDrive:/builds'` by default - just to provide an example for rclone.
##### UPLOAD_PATH
Set this to a **local** folder showing your remote files.
This folder will be openned with your chosen file manager after the built file has been uploaded.
You can also set this to `'c'` to disable this function across the script.
**Please notice:** only set this to an absolute path. It will not be checked / converted to allow you choosing whatever you want.
Set to `'gdrive:/idoybh2@gmail.com/builds/'` by default. Again, just to provide an example.
##### SOURCE_PATH
Set this to either a relative or an absolute path that points to your root source directory.
The script will CD into this directory for the build process.
Note that if the first char is `.` it will be replaced by the path of the script - thus allowing you to use a relative path.
Generally I would recommend just clonning this repo to your root source folder and keep this as is.
**Please do not use `..` as the first chars**. Set to `'.'` by default.
##### BUILD_PRODUCT_NAME
This should be set to the product name in `out/target/product/`. Usually is your device's codename.
Set to `'dumpling'` by default.
##### BUILD_FILE_NAME
Set this to the built file name. Because it usually changes with the date you should use `'*.zip'` at the end of it and the
constant part of the name at the beginning. See default value `'AOSiP*.zip'` as an example.
##### ADB_DEST_FOLDER
Set this to the folder you would like to adb push into - **relative to internal storage**
Please note the script automatically detects if you're booted / in recovery.
**Please do not start this path with an '/'**. Set to `'Flash/Derp'` by default.
##### UNHANDLED_PATH
Set this to the **local** path you want the script to move the built file to if no handling flags selected.
You can either use a relative or an absolute path. Same notes of *SOURCE_PATH* apply here.
You can also set this to `'c'` to disable this function.
##### AUTO_RM_BUILD
Set this to `1` to skip asking wether to remove original build file.
Set to `0` by default.
##### AUTO_REBOOT
Set this to `1` to skip waiting for a keypress on each reboot.
This will make the script automatically reboot from and to recovery.
Set to `0` by default.

## Output color coding
* *Red* for errors / warnings
* *Green* and *Blue* for info
* *Yellow* for requested input

Thank you for reading.
Enjoy the script!
