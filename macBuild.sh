#!/usr/bin/env bash
#
#  macBuild.sh
#  version 1.0.0
#
#  Created by Sergey Balalaev on 23.04.21.
#  Copyright (c) 2021 ByteriX. All rights reserved.
#

SRC_DIR=${PWD}
ROOT_DIR=${SRC_DIR}/build
BUILD_DIR=${SRC_DIR}/.build

NAME=""
BUNDLE_NAME=""

TEAM_ID=""
DEV_ID=""

USERNAME=""
PASSWORD=""

IS_BUILD=false
IS_DEPLOY=false

CMAKE_PARAMS=""


# get parameters of script

POSITIONAL=()

if [ "$#" -le 0 ]; then
    echo -e '\nSomething is missing... Type "sh macBuild.sh -h" without the quotes to find out more...\n'
    exit 0
fi

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -p|--project)
    NAME="$2"
    shift # past argument
    shift # past value
    ;;
    -bu|--bundle)
    BUNDLE_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    -u|--user)
    USERNAME="$2"
    PASSWORD="$3"
    if [ PASSWORD == "" ]; then
        echo "ERROR: $1 need 2 parameters"
        exit
    fi
    shift # past argument
    shift # past value 1
    shift # past value 2
    ;;
    -t|--team)
    TEAM_ID=$2
    shift # past argument
    shift # past value
    ;;
    -de|--developer)
    DEV_ID=$2
    shift # past argument
    shift # past value
    ;;
    -b|--build)
    IS_BUILD=true
    shift # past argument
    ;;
    -d|--deploy)
    IS_DEPLOY=true
    shift # past argument
    ;;
    -a|--all)
    IS_BUILD=true
    IS_DEPLOY=true
    shift # past argument
    ;;
    -c|--cmake)
    CMAKE_PARAMS="$2"
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    echo ""
    echo "Help for call build script with parameters:"
    echo "  -p, --project        : name of project. Requered param."
    echo "  -bu, --bundle        : name of bundle for Application. Requered param."
    echo "  -u, --user           : 2 params: login password. It specialized user, who created in Connection of developer programm. If defined then App will be uploaded to Store."
    echo "  -t, --team           : team identifier of your developer program for a upload IPA to Connection AppSore. If defined -ep doesn't meater and export plist will created automaticle."
    echo "  -de, --developer     : developer identifier: please create 'Developer ID Application' certificate and use this name here"
    echo "  -b, --build          : If selected then will build Application"
    echo "  -d, --deploy         : If selected then will create signed DMG installer"
    echo "  -a, --all            : If selected then will make all features."
    echo "  -c, --cmake          : Params of cmake build"
    echo ""
    echo "Emample: sh build.sh --project ProjectName --bundle ProjectName.Orgaization.com --user UserName Password123 --team 123456 --developer 'Developer ID Application: Ivan Pupkin (123456)' --all --cmake '-DCMAKE_PREFIX_PATH=/usr/local/Cellar/qt'\n\n"
    exit 0
    ;;
    *)
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# Initalize

APP=${NAME}.app
DMG=${NAME}.dmg
TEMP_DMG="temp_${NAME}.dmg"
backgroundPictureName=back.png



checkExit(){
    if [ $? != 0 ]; then
        echo "Building failed\n"
        exit 1
    fi
}

prepareBuild(){
  rm -rf ${ROOT_DIR}
  mkdir -pv ${ROOT_DIR}
  rm -rf ${BUILD_DIR}
  mkdir -pv $BUILD_DIR
}
     
buildRelease(){
  cd ${BUILD_DIR}
  cmake .. -DCMAKE_INSTALL_PREFIX=${ROOT_DIR}\
    -DCMAKE_BUILD_TYPE=Release\
    ${CMAKE_PARAMS}\
    -DNO_SHIBBOLETH=1
    #   -Wno-dev
    # cd ..
  make install
}

signBuild(){
  cd ${ROOT_DIR}

  rm -rf ./sign
  mkdir -pv ./sign
  cp -R ./${APP} ./sign

  cd ./sign
  #sign
  codesign --deep --force --verify --verbose --options runtime --timestamp --sign "${DEV_ID}" ${APP}
  #verify
  codesign --verify --verbose=4 ${APP}

  # Prepare installer

  ln -s "/Applications" "${ROOT_DIR}/sign/Applications"
  mkdir "${ROOT_DIR}/sign/.background"
  cp "$SRC_DIR/$backgroundPictureName" "${ROOT_DIR}/sign/.background"

  # Create installer

  cd ${ROOT_DIR}

  rm -f -d -r ./dmg
  mkdir -p ./dmg
  cd ./dmg
}

# depricated easy installer
createInstaller(){
    hdiutil create -volname ${NAME} -srcfolder ${ROOT_DIR}/sign -ov -format UDBZ ${DMG}
}

createInstallerWithBeatyInterface(){

    hdiutil create -volname ${NAME} -srcfolder ${ROOT_DIR}/sign -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" -format UDRW ${DMG}
    mv ${DMG} ${TEMP_DMG}
    title="${NAME}"
    device=$(hdiutil attach -readwrite -noverify -noautoopen ${TEMP_DMG} | \
             egrep '^/dev/' | sed 1q | awk '{print $1}')
    echo '
       tell application "Finder"
         tell disk "'${title}'"
               open
               set current view of container window to icon view
               set toolbar visible of container window to false
               set statusbar visible of container window to false
               set the bounds of container window to {400, 200, 790, 300}
               set theViewOptions to the icon view options of container window
               set arrangement of theViewOptions to not arranged
               set icon size of theViewOptions to 48
               set background picture of theViewOptions to file ".background:'${backgroundPictureName}'"
               set position of item "'${APP}'" of container window to {90, 90}
               set position of item "Applications" of container window to {300, 90}
               set position of item ".background" of container window to {90, 300}
               set position of item ".fseventsd" of container window to {300, 300}
               update without registering applications
               delay 5
               close
         end tell
       end tell
    ' | osascript

    chmod -Rf go-w /Volumes/"${NAME}"
    sync
    sync
    hdiutil detach ${device}
    hdiutil convert "${TEMP_DMG}" -format UDBZ -ov -o "${DMG}"
    rm -f ${TEMP_DMG}
}

signInstallerAndCheckWithApple(){

  # Sign installer and push to Apple

  codesign -s "${DEV_ID}" --timestamp ${DMG}
  REQUEST=$(xcrun altool --notarize-app -f ${DMG} --primary-bundle-id ${BUNDLE_NAME} -u $USERNAME -p $PASSWORD --team-id ${TEAM_ID})

  # Cheching Apple approving

  REQUEST_ID=$(echo "${REQUEST}" | awk -F'RequestUUID = ' '{print $2}' | awk '{print $1}')

  echo "RequestUUID is ${REQUEST_ID}"


  while : ; do
      sleep 10
      INFO=$(xcrun altool --notarization-info $REQUEST_ID -u $USERNAME -p $PASSWORD)
      if [[ $INFO =~ 'Message: Package Approved' && $INFO =~ 'Status: success' ]]; then
          echo "bingo!"
          break
      fi
      echo "waiting information"
  done


  # Finising process and test

  xcrun stapler staple -v ${DMG}

  hdiutil attach ${DMG}
  pushd /Volumes/${NAME}

  spctl -a -v /Volumes/${NAME}/${APP}

  popd
  diskutil eject "/Volumes/${NAME}"
}

# Main code:


if $IS_BUILD ; then

    echo "Prerare build..."
    prepareBuild
    checkExit

    echo "Starting build:"
    buildRelease
    checkExit
    echo ""
    echo "Build success!!!"
    echo ""
fi
     
if $IS_DEPLOY ; then
    echo "Starting sign Application:"
    signBuild
    checkExit

    echo "Creating installer:"
    #createInstaller
    createInstallerWithBeatyInterface
    checkExit

    echo "Sign installer and check it with Apple:"
    signInstallerAndCheckWithApple
    checkExit

    echo ""
    echo "Deploy success!!!"
    echo ""
fi
