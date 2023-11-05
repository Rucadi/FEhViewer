#!/bin/bash

function copy_deps {
    local dep=$1
    local target_dir=$2

    # Copy the dependency
    cp $dep $target_dir

    # Get the dependencies of the dependency
    local deps=$(ldd $dep | cut -d' ' -f3)


    # For each dependency of the dependency, call this function recursively
    for dep in $deps; do
        if [ ! -f $target_dir/$(basename $dep) ]; then
            copy_deps $dep $target_dir
        fi
    done
}


cp -rf ../build/linux/x64/release/bundle/* FEhViewer.AppDir/
deps=$(ldd FEhViewer.AppDir/fehviewer | cut -d' ' -f3)
# | xargs -I {} copy_deps {} FEhViewer.AppDir/lib

for dep in $deps; do
    copy_deps $dep FEhViewer.AppDir/lib
done

unset SOURCE_DATE_EPOCH

if [ ! -f appimagetool-x86_64.AppImage ]; then
    wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage && chmod a+x *.AppImage
fi
./appimagetool-x86_64.AppImage FEhViewer.AppDir/