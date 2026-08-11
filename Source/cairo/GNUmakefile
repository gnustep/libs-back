#  Copyright (C) 2004 Free Software Foundation, Inc.
#
#  Author: Banlu Kemiyatorn <object at gmail dot com>
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
#  Boston, MA 02110-1301, USA.

PACKAGE_NAME = gnustep-back
GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../../back.make
include $(GNUSTEP_MAKEFILES)/common.make

include ../../config.make

SUBPROJECT_NAME=cairo

# The Objective-C source files to be compiled
cairo_OBJC_FILES = CairoSurface.m \
  CairoBitmapSurface.m \
  CairoFontInfo.m \
  CairoGState.m \
  CairoContext.m \
  CairoFontEnumerator.m \
  CairoFontAssetInstaller.m \
  CairoFaceInfo.m \
  CairoPSSurface.m \
  CairoPDFSurface.m \
  ../fontconfig/FCFaceInfo.m \
  ../fontconfig/FCFontEnumerator.m \
  ../fontconfig/FCFontInfo.m \
  ../fontconfig/FCFontAssetInstaller.m \


# The window surface is chosen by the display server, because a surface is that
# server's window seen as something cairo can draw into.  Each server names its
# own, and a server with no branch here compiles no window surface at all --
# which is the right answer for a server that has no window to draw into, and is
# what lets a new server be added without touching the others.
#
# This subproject is reached only when the graphics backend is cairo, since
# Source/GNUmakefile puts $(BUILD_GRAPHICS) in SUBPROJECTS, so the graphics
# backend is not tested again in each branch.

ifeq ($(BUILD_SERVER),x11)
  ifeq ($(WITH_GLITZ),yes)
    cairo_OBJC_FILES += XGCairoGlitzSurface.m
  else
    cairo_OBJC_FILES += XGCairoSurface.m XGCairoXImageSurface.m XGCairoModernSurface.m
  endif
endif

ifeq ($(BUILD_SERVER),wayland)
  cairo_OBJC_FILES += WaylandCairoShmSurface.m
endif

ifeq ($(BUILD_SERVER),android)
  cairo_OBJC_FILES += AndroidCairoSurface.m
endif

ifeq ($(BUILD_SERVER),win32)
  ifeq ($(WITH_GLITZ),yes)
    cairo_OBJC_FILES += Win32CairoGlitzSurface.m
  else
    cairo_OBJC_FILES += Win32CairoSurface.m Win32CairoGState.m
    # Win32CairoXImageSurface.m
  endif
endif

cairo_OBJC_FILES += 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/subproject.make

-include GNUmakefile.postamble

