#
#  Main makefile for GNUstep Haiku Backend
#
#  Copyright (C) 2025 Free Software Foundation, Inc.
#
#  This file is part of the GNUstep Backend.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; see the file COPYING.LIB.
#  If not, see <http://www.gnu.org/licenses/> or write to the 
#  Free Software Foundation, 51 Franklin Street, Fifth Floor, 

PACKAGE_NAME = gnustep-back
GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../../back.make

include $(GNUSTEP_MAKEFILES)/common.make

include ../../config.make

# The library to be compiled, as a library or as a bundle
SUBPROJECT_NAME=haiku

# The Objective-C source files to be compiled
haiku_OBJC_FILES = \
HaikuContext.m \
HaikuServer.m \
HaikuFontInfo.m \
HaikuFontEnumerator.m \
HaikuFaceInfo.m \
HaikuGState.m

# Additional C++ flags for Haiku
haiku_CPPFLAGS += -I/system/develop/headers/be
haiku_CPPFLAGS += -I/system/develop/headers/cpp
haiku_CPPFLAGS += -I/system/develop/headers/posix

# Haiku libraries to link against
haiku_LDFLAGS += -lbe -lroot -ltranslation

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/subproject.make

-include GNUmakefile.postamble