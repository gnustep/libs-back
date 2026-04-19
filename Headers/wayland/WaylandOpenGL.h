/* 	-*-ObjC-*- */
/* WaylandOpenGL - NSOpenGL management for Wayland backend

   Copyright (C) 2026 Free Software Foundation, Inc.

   This file is part of the GNUstep Backend.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#ifndef _GNUstep_H_WaylandOpenGL_
#define _GNUstep_H_WaylandOpenGL_

#include <AppKit/NSOpenGL.h>
#include <EGL/egl.h>

@class NSView;
struct wl_egl_window;
struct window;

@interface WaylandGLContext : NSOpenGLContext
{
  NSOpenGLPixelFormat *_pixelFormat;
  NSView *_view;
  NSOpenGLContext *_shareContext;
  struct window *_window;
  struct wl_surface *_glSurface;
  struct wl_subsurface *_glSubsurface;
  struct wl_egl_window *_eglWindow;
  EGLDisplay _eglDisplay;
  EGLContext _eglContext;
  EGLSurface _eglSurface;
  int _swapInterval;
}
@end

@interface WaylandGLPixelFormat : NSOpenGLPixelFormat
{
  NSOpenGLPixelFormatAttribute *_attributes;
  NSUInteger _attributeCount;
}

- (EGLConfig)eglConfigForDisplay:(EGLDisplay)eglDisplay;
@end

#endif
