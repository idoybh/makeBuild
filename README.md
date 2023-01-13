# makeBuild generic build script
Yet another build script for AOSP ROMs
This script aims to be configurable for use with any ROM / environment, for your liking.  
It currently supports uploading and or pushing the built file to a given path and it is color coded.   
This script uses *[telegram-send](https://github.com/rahiel/telegram-send)* and sends Telegram messages with build status and time.

## Flags
You can start the script with the following flags:
* **-h** to show help and other flags (stands for help)
* **-i** to setup a new / overwrite .config through a CLI (stands for init)
* **-u** to upload the built file (stands for upload / user)
* **-p** to push the built file through adb (stands for push)
* **-f** to flash built image files in $OUT through fastboot (stands for flash)
* **-c** to make a clean build (stands for clean - duh)
* **-s** to disable telegram-send (stands for silent)
* **-d** to run without building (stands for dry)
* **--keep-file | -k** to keep original build file where it is
* **--power _[ARG]_** to power off or reboot if build successful
    * _[ARG]_ should be: `off` or `reboot`
* **--choose _[CMD]_** to change target choose command (see [TARGET_CHOOSE_CMD](#target_choose_cmd)) temporarily
* **--type _[CMD]_** to change build type command (see [BUILD_TYPE_CMD](#build_type_cmd)) temporarily
* **--product _[ARG]_** to change build product name (see [BUILD_PRODUCT_NAME](#build_product_name)) temporarily
* **--config _[FILE]_** to change the config file temporarily
* **--installclean | --i-c** to run make installclean before the build

**Note** `--config`, `--choose` and `--product` should **not** be used together and will **not** affect build.conf - Build will error out if those are used together. Same goes for `-p` and `-f`.

## build.conf
The default configuration file of the script.  
Can be changed per run with the flag `--config`.  
**Note** Must have at least one space before `=` whitespaces after are safely ignored

##### WAS_INIT
Just a flag to show whether the **-i** flag was used before.  
Set this to any other value than 0 to dismiss the warning.  
Set to `0` by default
##### CLEAN_CMD
Set this to whatever command you use to make a clean build.  
Set to `make clobber` by default.
##### TARGET_CHOOSE_CMD
Set this to whatever command you use to "lunch" / select the product to build prior to the build command.  
Set to `lunch yaap_guacamole-user` by default.
##### PRE_BUILD_SCRIPT
Set this to a relative / absolute path to a script that should run before building.  
The script mentioned will be sourced, so note all vars and functions will keep existing in the script's shell.  
Set to blank to disable. Set to blank by default.
##### BUILD_TYPE_CMD
Set this to whatever command you use to select a build type. This will be run after lunch.  
Set to blank to disable. Set to blank by default
##### BUILD_CMD
Set this to whatever command you use to initiate the build process. It will be run inside the source directory.  
Set to `mka yaap` by default
##### FILE_MANAGER_CMD
Set this to whatever command you use to lunch your file manager.  
It is usually just the name of your file manager and depends on your Linux distribution.  
Setting this to blank (no value) will disable launching file manager across the script. Useful for GClod or SSH as an example.  
Set to `dolphin` by default (KDE's default file manager)
##### UPLOAD_CMD
Set this to whatever command you use to upload your file.  
Set to `rclone copy -P` by default.
##### UPLOAD_LINK_CMD
Set this to whatever command you use to get download links for uploaded files.  
Set to nothing to disable.  
Set to `rclone link` by default.
##### TG_SEND_CFG_FILE
Set this to a telegram-send config file path (relative or absolute), blank to use default.  
Set to blank by default
##### UPLOAD_DEST
Set this to the upload destination **remote** folder.  
It will be added at the very end of the upload command, after the local built file path.  
Set to `GDrive:/builds` by default - just to provide an example for rclone.
##### UPLOAD_PATH
Set this to a **local** folder showing your remote files.  
This folder will be opened with your chosen file manager after the built file has been uploaded.  
You can also set this to blank (no value) to disable this function across the script.  
**Please notice:** only set this to an absolute path. It will ***not*** be checked nor converted - to allow you to choose whatever you want.  
Set to `gdrive:/idoybh2/builds/` by default. Again, just to provide an example.
##### SOURCE_PATH
Set this to either a relative or an absolute path that points to your root source directory.
The script will `cd` into this directory for the build process.  
Note that if the first char is `.` it will be replaced by the path of the script - thus allowing you to use a relative path.  
Generally, I would recommend just cloning this repo to your root source folder and keep this as is.  
**Please do not use `..` as the first chars**. Set to `.` by default.
##### UNHANDLED_PATH
Set this to the **local** path you want the script to move the built file to if no handling flags are selected.  
You can either use a relative or an absolute path. The same notes of [SOURCE_PATH](#source_path) apply here.  
You can also set this to blank (no value) to disable this function.
##### ADB_DEST_FOLDER
Set this to the folder you would like to adb push into - **relative to internal storage**  
Please note the script automatically detects if you're booted / in recovery.  
**Please do not start this path with an '/'**. Set to `Flash/YAAP` by default.
##### BUILD_PRODUCT_NAME
This should be set to the product name in `out/target/product/`. Usually, this is your device's codename.  
Set to `guacamole` by default.
##### BUILD_FILE_NAME
Set this to the built file name. Because it usually changes with the date you should use `*.zip` at the end of it and the
constant part of the name at the beginning. See default value `YAAP*.zip` as an example.
##### AUTO_RM_BUILD
Controls whether to automatically remove original build files (after handled)
Possible values are:
* `0` to never remove the original build file (w/o asking).
* `1` to always remove the original build file (w/o asking).
* `2` to always ask whether to remove the original build file (will prompt to change the default).  
Set to `2` by default.
##### AUTO_REBOOT
Set this to `1` to skip waiting for a keypress on each reboot.  
This will make the script automatically reboot from and to recovery.  
Set to `0` by default.
##### AUTO_SLOT
Set this to `1` to automatically switch slots on fastboot flash (see `-f` in [Flags](#Flags)).  
Set to `0` by default.
##### UPLOAD_DONE_MSG
Set this to an extra message you want to send when the upload is done.  
A good option may be a tag list or a link to changelog.  
Set to nothing to disable. Disabled by default.
##### TWRP_PIN
Set this to the decryption pin used to decrypt data in TWRP.  
Other possible values are:
* Blank (no value) - will make the script wait for your manual decryption.  
* `0` - will skip waiting for decryption altogether (for decrypted devices).  
For more information regarding patterns and more refer to the [TWRP documentation](https://twrp.me/faq/openrecoveryscript.html)  
Set to `0` by default.
##### TWRP_SIDELOAD
Set this to `1` to use ADB sideload instead of pushing.  
Will use [UNHANDLED_PATH](#unhandled_path) when done.  
Set to blank (no value) by default.

## Output color coding
* *Red* for errors / warnings
* *Green* and *Blue* for info
* *Yellow* for requested input

Thank you for reading.  
Enjoy the script!
