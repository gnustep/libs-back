#
#  Main makefile for GNUstep WIN32 GUI Backend
#
#  Copyright (C) 2002 Free Software Foundation, Inc.
#
#  Author: Fred Kiefer <FredKiefer@gmx.de>
#
#  This file is part of the GNUstep WIN32 GUI Backend.
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
#  You should have received a copy of the GNU Library General Public
#  License along with this library; see the file COPYING.LIB.
#  If not, write to the Free Software Foundation,
#  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../../back.make
include $(GNUSTEP_MAKEFILES)/common.make

include ../../config.make

SUBPROJECT_NAME=winlib

# The C source files to be compiled
winlib_C_FILES = 

# The Objective-C source files to be compiled
winlib_OBJC_FILES = \
WIN32Context.m \
WIN32GState.m \
WIN32FontEnumerator.m \
WIN32FontInfo.m

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/subproject.make

-include GNUmakefile.postamble
