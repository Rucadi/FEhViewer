#!/bin/bash

mkdir -p FEhViewer.AppDir/syslib
cp -rf ../build/linux/x64/release/bundle/* FEhViewer.AppDir/
ldd FEhViewer.AppDir/fehviewer | cut -d' ' -f3  | xargs -I {} cp {} FEhViewer.AppDir/syslib
unset SOURCE_DATE_EPOCH
wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage && chmod a+x *.AppImage
./appimagetool-x86_64.AppImage FEhViewer.AppDir/