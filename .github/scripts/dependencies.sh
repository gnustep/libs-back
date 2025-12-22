#! /usr/bin/env sh

set -ex
install_gnustep_gui() {
    echo "::group::GNUstep Gui"
    cd $DEPS_PATH
    . $INSTALL_PATH/share/GNUstep/Makefiles/GNUstep.sh
    git clone -q -b ${LIBS_BASE_BRANCH:-master} https://github.com/gnustep/libs-gui.git
    cd libs-gui
    ./configure
    make
    make install
    echo "::endgroup::"
}

mkdir -p $DEPS_PATH

install_gnustep_gui
