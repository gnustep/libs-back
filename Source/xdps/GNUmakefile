#
#  Main makefile for GNUstep Backend xdps
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

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../../back.make
include $(GNUSTEP_MAKEFILES)/common.make

include ../../config.make

SUBPROJECT_NAME=xdps

# The pswrap source files to be compiled
xdps_PSWRAP_FILES = \
general.psw \
drawingfuncs.psw \
extensions.psw \
fonts.psw

# The C source files to be compiled
xdps_C_FILES = \
parseAFM.c

# The Objective-C source files to be compiled
xdps_OBJC_FILES = \
AFMFileFontInfo.m \
NSDPSContext.m \
NSDPSContextOps.m \
PXKFontManager.m

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/subproject.make

-include GNUmakefile.postamble

