#!/bin/bash
CL_RED="\033[31m"
CL_GRN="\033[32m"
CL_YLW="\033[33m"
CL_BLU="\033[34m"
CL_MAG="\033[35m"
CL_CYN="\033[36m"
CL_RST="\033[0m"
if [ -n $AROMA_DEVICE ]; then
AROMA_DEVICE="yes"
fi
DEVICE=${2}
AROMA_VENDOR_CONFIG=${3}
AROMA_VENDOR_SCRIPT=${4}
AROMA_ZIP_OUT_FILE=${5}
AROMA_VENDOR_TWEAKS=${6}
AROMA_DEVICE_CONFIG=${7}
AROMA_DEVICE_SCRIPT=${8}
AROMA_DEVICE_FILES=${9}

echo << EOF "Building zip with the following values:
DEVICE="$DEVICE"
AROMA_VENDOR_CONFIG="$AROMA_VENDOR_CONFIG"
AROMA_VENDOR_SCRIPT="$AROMA_VENDOR_SCRIPT"
AROMA_ZIP_OUT_FILE="$AROMA_ZIP_OUT_FILE"
AROMA_VENDOR_TWEAKS="$AROMA_VENDOR_TWEAKS"
AROMA_DEVICE_CONFIG="$AROMA_DEVICE_CONFIG"
AROMA_DEVICE_SCRIPT="$AROMA_DEVICE_SCRIPT"
AROMA_DEVICE_FILES="$AROMA_DEVICE_FILES" "
EOF

if [ "$AROMA_DEVICE" == "yes" ]
then
echo -e ${CL_GRN}$AROMA_DEVICE${CL_RST}${CL_YLW}" your device is awesome, lets build a full overlay"${CL_RST}
else
AROMA_DEVICE=no
echo -e ${CL_RED}$AROMA_DEVICE${CL_RST}${CL_YLW}" this device doesnt have an aroma overlay"${CL_RST}
fi
SOURCE=$PWD
UPDATER=$OUT/obj/EXECUTABLES/updater_intermediates/updater
AROMADATE=$(date +"%Y-%m-%d")

if [ ! -f "$UPDATER" ]
then
    make updater &>> /dev/null
fi
if [ ! -f "${ANDROID_HOST_OUT}/framework/signapk.jar" ]
then
    make signapk &>> /dev/null
fi

ZIP_DIR=$OUT/Aromazip
mkdir $ZIP_DIR

UPDATER_DIR=$ZIP_DIR/META-INF/com/google/android
mkdir -p $UPDATER_DIR
cp $OUT/obj/EXECUTABLES/updater_intermediates/updater $UPDATER_DIR/update-binary-installer
echo 'if ! is_mounted("/system") then' > $UPDATER_DIR/updater-script
echo 'run_program("/sbin/busybox", "mount", "/system");' >> $UPDATER_DIR/updater-script
echo 'endif;' >> $UPDATER_DIR/updater-script

unzip -q -o $ANDROID_BUILD_TOP/build/tools/releasetools/aroma/aroma.zip -d $ZIP_DIR
cp $ANDROID_BUILD_TOP/$AROMA_VENDOR_TWEAKS $ZIP_DIR/buildproptweaks.sh
cat $ANDROID_BUILD_TOP/$AROMA_VENDOR_SCRIPT >> $UPDATER_DIR/updater-script
cp $ANDROID_BUILD_TOP/$AROMA_VENDOR_CONFIG $UPDATER_DIR/aroma-config

if [ "$AROMA_DEVICE" == "yes" ]
then
cat $ANDROID_BUILD_TOP/$AROMA_DEVICE_SCRIPT >> $UPDATER_DIR/updater-script
awk '/#@AROMA_DEVICE_CONFIG@/{system("cat '$ANDROID_BUILD_TOP/$AROMA_DEVICE_CONFIG'");next}1' $UPDATER_DIR/aroma-config > $UPDATER_DIR/temp
rm $UPDATER_DIR/aroma-config
mv $UPDATER_DIR/temp $UPDATER_DIR/aroma-config
mkdir -p $ZIP_DIR/aroma_device
cp -r $ANDROID_BUILD_TOP/$AROMA_DEVICE_FILES/* $ZIP_DIR/aroma_device/
fi

echo 'unmount("/system");' >> $UPDATER_DIR/updater-script
echo 'ui_print(" ");' >> $UPDATER_DIR/updater-script
echo 'ui_print("Done!");' >> $UPDATER_DIR/updater-script

cd $ZIP_DIR
zip -qr ../$AROMA_ZIP_OUT_FILE.zip ./
cd $OUT
rm -rf $ZIP_DIR

java -jar ${ANDROID_HOST_OUT}/framework/signapk.jar ${SOURCE}/build/target/product/security/testkey.x509.pem ${SOURCE}/build/target/product/security/testkey.pk8 $AROMA_ZIP_OUT_FILE.zip $AROMA_ZIP_OUT_FILE-signed.zip
rm ./$AROMA_ZIP_OUT_FILE.zip
echo -e ${CL_CYN}$(md5sum $AROMA_ZIP_OUT_FILE-signed.zip)${CL_RST}
mkdir -p $OUT/system/addon.d
cp $AROMA_ZIP_OUT_FILE-signed.zip $OUT/system/addon.d/UPDATE-aromainstaller.zip
cd $SOURCE
