# configure.in for GNUstep GUI Backend
# Process this file with autoconf to produce a configure script.
#
# Copyright (C) 1996-2002 Free Software Foundation, Inc.
#
# Author:  Adam Fedor <fedor@gnu.org>
#
# This file is part of the GNUstep Backend.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this library; see the file COPYING.LIB.
# If not, write to the Free Software Foundation,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#

AC_INIT
AC_PREREQ(2.57)
AC_CONFIG_SRCDIR([back.make.in])
AC_CONFIG_HEADER(config.h)

if test -z "$GNUSTEP_SYSTEM_ROOT"; then
  AC_MSG_ERROR([You must run the GNUstep.sh script before configuring])
fi

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR($GNUSTEP_MAKEFILES)

#--------------------------------------------------------------------
# Determine the host, build, and target systems
#--------------------------------------------------------------------
AC_PROG_CC
AC_CANONICAL_TARGET([])

#--------------------------------------------------------------------
# The following is so that headers and custom libraries
# in the GNUstep root are used before the standard ones
#--------------------------------------------------------------------
# Set location of GNUstep dirs for later use
GNUSTEP_HDIR=$GNUSTEP_SYSTEM_ROOT/Library/Headers
if test "$GNUSTEP_FLATTENED" = yes; then
  GNUSTEP_LDIR=$GNUSTEP_SYSTEM_ROOT/Library/Libraries
else
  clean_target_os=`$GNUSTEP_MAKEFILES/clean_os.sh $target_os`
  clean_target_cpu=`$GNUSTEP_MAKEFILES/clean_cpu.sh $target_cpu`
  obj_dir=$clean_target_cpu/$clean_target_os
  GNUSTEP_LDIR=$GNUSTEP_SYSTEM_ROOT/Library/Libraries/$obj_dir
fi
CPPFLAGS="$CPPFLAGS -I$GNUSTEP_HDIR"
LDFLAGS="$LDFLAGS -L$GNUSTEP_LDIR/$LIBRARY_COMBO -L$GNUSTEP_LDIR"

#--------------------------------------------------------------------
# Add target OS directories as necessary
#--------------------------------------------------------------------
case "$target_os" in
  freebsd* | openbsd* )   
	      CPPFLAGS="$CPPFLAGS -I/usr/pkg/include"
              LDFLAGS="$LDFLAGS -L/usr/pkg/lib";;
  netbsd*)    CPPFLAGS="$CPPFLAGS -I/usr/pkg/include"
	      LDFLAGS="$LDFLAGS -Wl,-R/usr/pkg/lib -L/usr/pkg/lib";;
esac

#--------------------------------------------------------------------
# Look for WindowMaker's wraster library
#--------------------------------------------------------------------
AC_ARG_WITH(wraster, 
           [  --with-wraster=PREFIX   get-wraster-flags directory prefix])
if test "x$with_wraster" = "x"; then
 wprefix=""
else
 wprefix=${with_wraster}/
fi

if test "x$with_wraster" != "xnone"; then
  GRAPHIC_LIBS=`${wprefix}get-wraster-flags --libs`
  GRAPHIC_CFLAGS=`${wprefix}get-wraster-flags --cflags | sed -e "s|-I/usr/include||"`
  GRAPHIC_LFLAGS=`${wprefix}get-wraster-flags --ldflags`
fi

AC_DEFUN(AC_CHECK_WRASTER,
[dnl
AC_MSG_CHECKING(for current libwraster support)
AC_CACHE_VAL(gs_cv_have_wraster,
[wraster_check_save_header=${CPPFLAGS}
wraster_check_save_libs=${LIBS}
CPPFLAGS="$1 $2 ${CPPFLAGS}"
LIBS="$3 $LIBS"

# Check for RFillImage which is only in version 2.0 of libwraster
AC_CHECK_LIB(wraster, RFillImage, gs_cv_have_wraster=yes, gs_cv_have_wraster=no)if test "x$with_wraster" = "xnone"; then
  gs_cv_have_wraster=no
fi
if test "$gs_cv_have_wraster" = yes; then
  AC_CHECK_HEADERS(wraster.h, gs_cv_have_wraster=yes, gs_cv_have_wraster=no)
fi
CPPFLAGS="${wraster_check_save_header}"
LIBS="${wraster_check_save_libs}"
])
AC_MSG_RESULT($gs_cv_have_wraster)
])

AC_CHECK_WRASTER(${GRAPHIC_CFLAGS}, ${GRAPHIC_LFLAGS}, ${GRAPHIC_LIBS})
if test $gs_cv_have_wraster = no; then
  GRAPHIC_LIBS=
  GRAPHIC_CFLAGS=
  GRAPHIC_LFLAGS=
fi

AC_ARG_WITH(library-flags, 
        [  --with-library-flags=fg Library flags for libraries])
AC_ARG_WITH(dps_include,  
	[  --with-include-flags=fg Include flags])
GRAPHIC_LFLAGS="$GRAPHIC_LFLAGS $with_library_flags"
GRAPHIC_CFLAGS="$GRAPHIC_CFLAGS $with_include_flags"

#--------------------------------------------------------------------
# Find for X windows
#--------------------------------------------------------------------
# If the user specifically set x_include/x_libs, then assume we're
# using a special X system and discard any previous GRAPHIC_flags
set_x_paths=no
if test $gs_cv_have_wraster = no -o $x_includes != NONE; then
  set_x_paths=yes
fi
AC_PATH_XTRA
if test "x$no_x" = xyes; then
  set_x_paths=no
fi

if test $set_x_paths = yes; then
  GRAPHIC_CFLAGS="$X_CFLAGS"
  GRAPHIC_LFLAGS="$X_LIBS"
  GRAPHIC_LIBS="$X_EXTRA_LIBS"

  lib_save_header=${CPPFLAGS}
  lib_save_libs=${LIBS}
  CPPFLAGS="${GRAPHIC_CFLAGS} ${GRAPHIC_LFLAGS} ${CPPFLAGS}"
  LIBS="${GRAPHIC_LIBS} ${LIBS}"
  AC_CHECK_LIB(Xext, main, have_xext=1, have_xext=0)
  if test $have_xext = 1; then
    GRAPHIC_LIBS="-lX11 -lXext ${GRAPHIC_LIBS}"
  else
    GRAPHIC_LIBS="-lX11  ${GRAPHIC_LIBS}"
  fi
  LIBS="${GRAPHIC_LIBS} ${LIBS}"
  AC_CHECK_LIB(Xmu, main, have_xmu=1, have_xmu=0)
  CPPFLAGS="${lib_save_header}"
  LIBS="${lib_save_libs}"
  if test $have_xmu = 1; then
    GRAPHIC_LIBS="-lXmu ${GRAPHIC_LIBS}"
  fi
fi
if test -r $x_includes/X11/DPS; then
  GRAPHIC_CFLAGS="-I$x_includes/X11 $GRAPHIC_CFLAGS"
fi
AC_SUBST(X_PRE_LIBS)

# Old X11 support
AC_MSG_CHECKING([for X11 function prototypes])
AC_EGREP_CPP(yes, 
 [#include <X11/Xlib.h>
  #if NeedFunctionPrototypes
    yes
  #endif
  ], have_funcproto=yes, have_funcproto=no)
AC_MSG_RESULT([$have_funcproto])
if test "$have_funcproto" = no; then
  AC_DEFINE(FUNCPROTO,1,[Define if X11 doesn't automatically use prototypes])
fi


#--------------------------------------------------------------------
# Find for DPS
#--------------------------------------------------------------------
save_CPPFLAGS=${CPPFLAGS}
CPPFLAGS="${CPPFLAGS} ${GRAPHIC_CFLAGS}"
AC_CHECK_HEADERS([DPS/dpsclient.h DPS/dpsNXargs.h])
CPPFLAGS="${save_CPPFLAGS}"

#--------------------------------------------------------------------
# freetype libraries
#--------------------------------------------------------------------
save_header=${CPPFLAGS}
save_libs=${LIBS}
CPPFLAGS="${GRAPHIC_CFLAGS} ${GRAPHIC_LFLAGS} ${CPPFLAGS}"
LIBS="${GRAPHIC_LIBS} ${LIBS}"

FREETYPE_LIBS="`freetype-config --libs`"
FREETYPE_CFLAGS="`freetype-config --cflags`"

CPPFLAGS="${CPPFLAGS} ${FREETYPE_CFLAGS}"
LIBS="${LIBS} ${FREETYPE_LIBS}"

AC_CHECK_LIB(freetype, main, have_freetype=yes, have_freetype=no)
if test "$have_freetype" = yes; then
  AC_CHECK_HEADER(ft2build.h,have_freetype=yes, have_freetype=no)
fi
if test "$have_freetype" = yes; then
  GRAPHIC_CFLAGS="$GRAPHIC_CFLAGS $FREETYPE_CFLAGS"
  GRAPHIC_LIBS="$FREETYPE_LIBS $GRAPHIC_LIBS"
fi
CPPFLAGS="${save_header}"
LIBS="${save_libs}"

#--------------------------------------------------------------------
# Extended font support & UTF8 support
#--------------------------------------------------------------------
WITH_XFT=no
save_header=${CPPFLAGS}
save_libs=${LIBS}
CPPFLAGS="${GRAPHIC_CFLAGS} ${GRAPHIC_LFLAGS} ${CPPFLAGS}"
LIBS="${GRAPHIC_LIBS} ${LIBS}"
AC_CHECK_LIB(Xft, XftFontOpen, have_xft=yes, have_xft=no)
AC_CHECK_HEADER(X11/Xft/Xft.h)
if test "$have_xft" = yes -a "$ac_cv_header_X11_Xft_Xft_h" = yes; then
  GRAPHIC_LIBS="-lXft ${GRAPHIC_LIBS}"
  WITH_XFT=yes
  AC_DEFINE(HAVE_XFT,1,[Define if you have the Xft library])
  AC_CHECK_LIB(Xft, XftDrawStringUtf8, have_utf8=yes, have_utf8=no)
  if test "$have_utf8" = yes; then
    AC_DEFINE(HAVE_UTF8,1,[Define if you have XftDrawStringUtf8])
  fi
  AC_CHECK_LIB(fontconfig, FcPatternCreate, have_fc=yes, have_fc=no)
  AC_CHECK_HEADER(fontconfig/fontconfig.h)
  if test "$have_fc" = yes -a "$ac_cv_header_fontconfig_fontconfig_h" = yes; then
    GRAPHIC_LIBS="-lfontconfig ${GRAPHIC_LIBS}"
    AC_DEFINE(HAVE_FC,1,[Define if you have FcPatternCreate])
  fi
fi
CPPFLAGS="${save_header}"
LIBS="${save_libs}"
AC_SUBST(WITH_XFT)

#--------------------------------------------------------------------
# GLX support
#--------------------------------------------------------------------
WITH_GLX=no
AC_ARG_ENABLE(glx, 
  [  --disable-glx           Disable GLX support],,
  enable_glx=yes)
if test "x$enable_glx" = "xyes"; then
   save_header=${CPPFLAGS}
   save_libs=${LIBS}
   CPPFLAGS="${GRAPHIC_CFLAGS} ${GRAPHIC_LFLAGS} ${CPPFLAGS}"
   LIBS="${GRAPHIC_LIBS} ${LIBS}"
   AC_CHECK_LIB(GL, glXMakeContextCurrent, have_glx=yes, have_glx=no)
   AC_CHECK_HEADER(GL/glx.h)
   AC_MSG_CHECKING([for GLX_RGBA_TYPE])
   AC_EGREP_CPP(yes, 
     [#include <GL/glx.h>
      #ifdef GLX_RGBA_TYPE
        yes
      #endif
      ], have_glx_rgba=yes, have_glx_rgba=no)
   AC_MSG_RESULT([$have_glx_rgba])
   if test "$have_glx" = yes -a "$ac_cv_header_GL_glx_h" = yes -a "$have_glx_rgba" = yes; then
     GRAPHIC_LIBS="-lGL ${GRAPHIC_LIBS}"
     WITH_GLX=yes
     AC_DEFINE(HAVE_GLX,1,[Define if you have the glx library])
   fi
   CPPFLAGS="${save_header}"
   LIBS="${save_libs}"
   AC_SUBST(WITH_GLX)
fi


#--------------------------------------------------------------------
# XIM support
#--------------------------------------------------------------------
AC_ARG_ENABLE(xim, 
  [  --disable-xim           Disable XIM support],,
  enable_xim=yes)
if test "x$enable_xim" = "xyes"; then
 AC_DEFINE(USE_XIM,1,[Define to enable XIM support])
fi

#--------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------
AC_HAVE_FUNCS(usleep)

save_CPPFLAGS=${CPPFLAGS}
CPPFLAGS="$CPPFLAGS $GRAPHIC_CFLAGS"
have_xshm=no
AC_CHECK_HEADERS(X11/extensions/XShm.h,
	have_xshm=yes,,
	[#include <X11/Xlib.h>])
AC_CHECK_FUNCS(shmctl)
if test "$ac_cv_header_X11_extensions_XShm_h" = yes -a "$ac_cv_func_shmctl" = yes; then
  AC_DEFINE(XSHM,1,[Define if you have X11 XShm extensions])
fi
CPPFLAGS="$save_CPPFLAGS"

#--------------------------------------------------------------------
# Window's graphics library
#--------------------------------------------------------------------
save_header=${CPPFLAGS}
save_libs=${LIBS}
CPPFLAGS="${GRAPHIC_CFLAGS} ${GRAPHIC_LFLAGS} ${CPPFLAGS}"
LIBS="${GRAPHIC_LIBS} ${LIBS}"
AC_CHECK_LIB(gdi32, main, have_gdi32=yes, have_gdi32=no)
if test "$have_gdi32" = yes; then
  WIN32_LIBS="-lgdi32"
fi
CPPFLAGS="${save_header}"
LIBS="${save_libs}"

#--------------------------------------------------------------------
# libart graphics libraries
#--------------------------------------------------------------------
save_header=${CPPFLAGS}
save_libs=${LIBS}
CPPFLAGS="${GRAPHIC_CFLAGS} ${GRAPHIC_LFLAGS} ${CPPFLAGS}"
LIBS="${GRAPHIC_LIBS} ${LIBS}"

LIBART_LIBS="`libart2-config --libs`"
LIBART_CFLAGS="`libart2-config --cflags`"

CPPFLAGS="${CPPFLAGS} ${LIBART_CFLAGS}"
LIBS="${LIBS} ${LIBART_LIBS}"

AC_CHECK_LIB(art_lgpl_2, main, have_libart_lgpl_2=yes, have_libart_lgpl_2=no)
if test "$have_libart_lgpl_2" = yes; then
  AC_CHECK_HEADER(libart_lgpl/libart.h,have_libart_lgpl_2=yes, have_libart_lgpl_2=no)
fi
if test "$have_libart_lgpl_2" = yes; then
  GRAPHIC_LIBS="$LIBART_LIBS $GRAPHIC_LIBS"
  GRAPHIC_CFLAGS="$LIBART_CFLAGS $GRAPHIC_CFLAGS"
fi
CPPFLAGS="${save_header}"
LIBS="${save_libs}"

#--------------------------------------------------------------------
# Set definitions
#--------------------------------------------------------------------
WITH_WRASTER=no
if test $gs_cv_have_wraster = yes -a $set_x_paths = no; then
  AC_DEFINE(WITH_WRASTER,1,[Define if you have libwraster])
  WITH_WRASTER=yes
fi
AC_SUBST(WITH_WRASTER)
AC_SUBST(GRAPHIC_LIBS)
AC_SUBST(GRAPHIC_CFLAGS)
AC_SUBST(GRAPHIC_LFLAGS)

#--------------------------------------------------------------------
# Which projects should we build?
#--------------------------------------------------------------------
BUILD_SERVER=x11
BUILD_GRAPHICS=xlib
case $target_os in
  *mingw32* ) BUILD_SERVER=win32
              BUILD_GRAPHICS=winlib;;
esac

AC_ARG_ENABLE(server, 
  [  --enable-server=SRV     Build server type: x11, win32],,
  enable_server=$BUILD_SERVER)
AC_ARG_ENABLE(graphics, 
  [  --enable-graphics=GPH   Build graphics: xlib, xdps, winlib, art],,
  enable_graphics="$BUILD_GRAPHICS")

BUILD_SERVER=$enable_server
BUILD_GRAPHICS="$enable_graphics"
AC_MSG_CHECKING(Backend Server)
AC_SUBST(BUILD_SERVER)
AC_DEFINE_UNQUOTED(BUILD_SERVER,SERVER_$BUILD_SERVER,
	[Define to type of window server to build])
AC_MSG_RESULT($BUILD_SERVER)

AC_MSG_CHECKING(Backend Graphics)
AC_SUBST(BUILD_GRAPHICS)
AC_DEFINE_UNQUOTED(BUILD_GRAPHICS,$BUILD_GRAPHICS,
	[Define to type of graphics context to build])
AC_MSG_RESULT($BUILD_GRAPHICS)

if test x"$BUILD_GRAPHICS" = "xxdps"; then
  GRAPHIC_LIBS="-ldpstk -ldps -lpsres -lXt $X_PRE_LIBS $GRAPHIC_LIBS"
elif test x"$BUILD_GRAPHICS" = "xart"; then
  if test "$have_freetype" = no; then
    AC_MSG_ERROR([can't find freetype, required for graphics=art!])
  fi
  if test "$have_libart_lgpl_2" = no; then
    AC_MSG_ERROR([can't find libart, required for graphics=art!])
  fi
elif test x"$BUILD_GRAPHICS" = "xwinlib"; then
  GRAPHIC_LIBS="$WIN32_LIBS $GRAPHIC_LIBS"
fi

AH_TOP([
#define SERVER_x11   1
#define SERVER_win32 2
])

#--------------------------------------------------------------------
# Set the name of the backend
#--------------------------------------------------------------------
AC_ARG_WITH(name, 
           [  --with-name=PREFIX      Set the name of the backend (def=back)])
AC_MSG_CHECKING(Backend name)
if test "x$with_name" = "x"; then
 BACKEND_NAME=back
else
 BACKEND_NAME=${with_name}
fi
AC_MSG_RESULT($BACKEND_NAME)
AC_SUBST(BACKEND_NAME)

AC_CONFIG_FILES([back.make config.make])
AC_OUTPUT
