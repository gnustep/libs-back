#
#  Top level makefile for GNUstep Backend
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
#  You should have received a copy of the GNU Library General Public
#  License along with this library; see the file COPYING.LIB.
#  If not, write to the Free Software Foundation,
#  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

# Install into the system root by default
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

include $(GNUSTEP_MAKEFILES)/common.make

include ../config.make

# The library to be compiled, as a library or as a bundle
ifeq ($(BACKEND_BUNDLE),)
LIBRARY_NAME=libgnustep-$(BACKEND_NAME)
else
BUNDLE_NAME=libgnustep-$(BACKEND_NAME)
endif

#
# The list of subproject directories
#
SUBPROJECTS = gsc
ifneq ($(BUILD_XLIB),)
SUBPROJECTS += xlib
endif
ifneq ($(BUILD_XDPS),)
SUBPROJECTS += xdps
endif
ifneq ($(BUILD_X11),)
SUBPROJECTS += x11
endif
ifneq ($(BUILD_WIN32),)
SUBPROJECTS += win32
endif
ifneq ($(BUILD_WINLIB),)
SUBPROJECTS += winlib
endif
libgnustep-$(BACKEND_NAME)_SUBPROJECTS=$(SUBPROJECTS)

libgnustep-$(BACKEND_NAME)_OBJC_FILES=GSBackend.m

libgnustep-$(BACKEND_NAME)_PRINCIPAL_CLASS=GSBackend

-include GNUmakefile.preamble

ifeq ($(BACKEND_BUNDLE),)
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/bundle.make
endif

-include GNUmakefile.postamble
