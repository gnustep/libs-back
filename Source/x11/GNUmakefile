#
#  Main makefile for GNUstep Backend x11
#
#  Copyright (C) 2002 Free Software Foundation, Inc.
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

# The library to be compiled, as a library or as a bundle
SUBPROJECT_NAME=x11

# The C source files to be compiled
ifeq ($(WITH_WRASTER),yes)
x11_C_FILES = \
xdnd.c
else
x11_C_FILES = \
StdCmap.c \
context.c \
convert.c \
raster.c \
scale.c \
xdnd.c \
xutil.c
endif

# The Objective-C source files to be compiled
x11_OBJC_FILES = \
XGServer.m \
XGServerEvent.m \
XGServerWindow.m \
XGDragView.m \
XGSlideView.m \
XIMInputServer.m \
XGBitmapImageRep.m

x11_HEADER_FILES_DIR = ../../Headers/x11
x11_HEADER_FILES_INSTALL_DIR = gnustep/x11

x11_HEADER_FILES = \
XGServer.h \
XGServerWindow.h

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/subproject.make

-include GNUmakefile.postamble

