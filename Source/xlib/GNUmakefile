#
#  Main makefile for GNUstep Backend xlib
#
#  Copyright (C) 1997 Free Software Foundation, Inc.
#
#  Author: Adam Fedor <fedor@gnu.org>
#
#  This file is part of the GNUstep Backend.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Library General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  Library General Public License for more details.
#
#  If you are interested in a warranty or support for this source code,
#  contact Scott Christley at scottc@net-community.com
#
#  You should have received a copy of the GNU Library General Public
#  License along with this library; see the file COPYING.LIB.
#  If not, write to the Free Software Foundation,
#  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../../back.make
include $(GNUSTEP_MAKEFILES)/common.make

include ../../config.make

SUBPROJECT_NAME=xlib

# The Objective-C source files to be compiled
xlib_OBJC_FILES = \
XGBitmap.m \
XGCommonFont.m \
XGFont.m \
XGFontManager.m \
XGContext.m \
XGGState.m \
XGGeometry.m \
linking.m

ifeq ($(WITH_XFT),yes)
xlib_OBJC_FILES += GSXftFontInfo.m
endif

xlib_HEADER_FILES_DIR = ../../Headers/xlib
xlib_HEADER_FILES_INSTALL_DIR = gnustep/xlib

xlib_HEADER_FILES = \
XGContext.h \
XGPrivate.h \
XGGeometry.h \
XGGState.h 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/subproject.make

-include GNUmakefile.postamble

