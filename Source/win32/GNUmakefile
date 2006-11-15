#
#  Main makefile for GNUstep Backend win32
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
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../../back.make

include $(GNUSTEP_MAKEFILES)/common.make

include ../../config.make

# The library to be compiled, as a library or as a bundle
SUBPROJECT_NAME=win32

win32_LOCALIZED_RESOURCE_FILES = \

# The C source files to be compiled
win32_C_FILES = \

# The Objective-C source files to be compiled
win32_OBJC_FILES = \
WIN32Server.m  \
w32_debug.m \
w32_notifications.m \
w32_activate.m \
w32_create.m \
w32_general.m \
w32_movesize.m \
w32_text_focus.m \
w32_windowdisplay.m \
GSDisplayServer_details.m \

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/subproject.make

-include GNUmakefile.postamble
