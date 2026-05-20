#! /usr/bin/env sh

set -ex

install_gnustep_make() {
    echo "::group::GNUstep Make"
    cd $DEPS_PATH
    git clone -q -b ${TOOLS_MAKE_BRANCH:-master} https://github.com/gnustep/tools-make.git
    cd tools-make
    ./configure --prefix=$INSTALL_PATH || cat config.log
    make install

    echo "::endgroup::"
}

install_gnustep_base() {
    echo "::group::GNUstep Base"
    cd $DEPS_PATH
    . $INSTALL_PATH/share/GNUstep/Makefiles/GNUstep.sh
    git clone -q -b ${LIBS_BASE_BRANCH:-master} https://github.com/gnustep/libs-base.git
    cd libs-base
    ./configure
    make
    make install
    echo "::endgroup::"
}


install_gnustep_gui() {
    echo "::group::GNUstep Gui"
    cd $DEPS_PATH
    . $INSTALL_PATH/share/GNUstep/Makefiles/GNUstep.sh
    git clone -q -b ${LIBS_GUI_BRANCH:-master} https://github.com/gnustep/libs-gui.git
    cd libs-gui
    ./configure
    make
    make install
    echo "::endgroup::"
}

mkdir -p $DEPS_PATH

install_gnustep_make
install_gnustep_base
install_gnustep_gui
