#
#  Tools level makefile for GNUstep Backend Library
#
#  Copyright (C) 1997,1999 Free Software Foundation, Inc.
#
#  Author: Scott Christley <scottc@net-community.com>
#
#  This file is part of the GNUstep GUI Library.
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

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../back.make
include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.make

# The applications to be compiled
TOOL_NAME = gpbs

# The source files to be compiled
gpbs_OBJC_FILES = gpbs.m
font_cacher_OBJC_FILES = font_cacher.m

ifeq ($(BUILD_GRAPHICS),xlib)
TOOL_NAME += font_cacher
endif

ifeq ($(BUILD_SERVER),x11)
gpbs_OBJC_FILES += xpbs.m 
ifeq ($(BACKEND_BUNDLE),yes)
font_cacher_OBJC_FILES += XGCommonFont.m
gpbs_C_FILES += xdnd.c
endif
endif

MAN1_PAGES = gpbs.1

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble
