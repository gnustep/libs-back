/* -*- mode:ObjC -*-
   WaylandGLContext - backend implementation of NSOpenGLContext using EGL

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

#include "config.h"

#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <GNUstepGUI/GSDisplayServer.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>

#include <EGL/egl.h>
#include <wayland-egl.h>

#include "wayland/WaylandServer.h"
#include "wayland/WaylandOpenGL.h"

static WaylandGLContext *currentGLContext;

@implementation WaylandGLContext

+ (void)clearCurrentContext
{
  if (currentGLContext != nil && currentGLContext->_eglDisplay != EGL_NO_DISPLAY)
    {
      eglMakeCurrent(currentGLContext->_eglDisplay,
                     EGL_NO_SURFACE,
                     EGL_NO_SURFACE,
                     EGL_NO_CONTEXT);
    }
  currentGLContext = nil;
}

+ (NSOpenGLContext *)currentContext
{
  return currentGLContext;
}

- (void *)CGLContextObj
{
  return (void *)_eglContext;
}

- (void)copyAttributesFromContext:(NSOpenGLContext *)context
                         withMask:(unsigned long)mask
{
  (void)context;
  (void)mask;
}

- (id)initWithCGLContextObj:(void *)context
{
  NSDebugMLLog(@"OpenGL", @"initWithCGLContextObj is not supported on Wayland (%p)", context);
  [self release];
  return nil;
}

- (BOOL)_ensureDisplayAndContextWithShare:(NSOpenGLContext *)share
{
  EGLint major;
  EGLint minor;
  EGLConfig eglConfig;
  EGLContext shareContext = EGL_NO_CONTEXT;
  EGLint glesContextAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
  EGLint *contextAttrs = NULL;
  struct wl_display *wlDisplay;

  if (_eglDisplay != EGL_NO_DISPLAY && _eglContext != EGL_NO_CONTEXT)
    {
      return YES;
    }

  if (_window == NULL && [self _attachToWindowIfNeeded] == NO)
    {
      return NO;
    }

  wlDisplay = NULL;
  if (_window != NULL && _window->wlconfig != NULL)
    {
      wlDisplay = _window->wlconfig->display;
    }

  if (wlDisplay == NULL)
    {
      NSDebugMLLog(@"OpenGL", @"Cannot create EGL display without an attached Wayland window");
      return NO;
    }

  _eglDisplay = eglGetDisplay((EGLNativeDisplayType)wlDisplay);
  if (_eglDisplay == EGL_NO_DISPLAY)
    {
      NSDebugMLLog(@"OpenGL", @"eglGetDisplay failed");
      return NO;
    }

  if (eglInitialize(_eglDisplay, &major, &minor) == EGL_FALSE)
    {
      NSDebugMLLog(@"OpenGL", @"eglInitialize failed");
      return NO;
    }

  if (eglBindAPI(EGL_OPENGL_API) == EGL_FALSE)
    {
      NSDebugMLLog(@"OpenGL", @"eglBindAPI(EGL_OPENGL_API) failed, trying GLES2");
      if (eglBindAPI(EGL_OPENGL_ES_API) == EGL_FALSE)
        {
          NSDebugMLLog(@"OpenGL", @"eglBindAPI failed for OpenGL and GLES");
          return NO;
        }
      contextAttrs = glesContextAttrs;
    }

  eglConfig = [(WaylandGLPixelFormat *)_pixelFormat eglConfigForDisplay:_eglDisplay];
  if (eglConfig == NULL)
    {
      return NO;
    }

  if (share != nil && [share isKindOfClass:[WaylandGLContext class]])
    {
      shareContext = ((WaylandGLContext *)share)->_eglContext;
    }

  _eglContext = eglCreateContext(_eglDisplay, eglConfig, shareContext, contextAttrs);
  if (_eglContext == EGL_NO_CONTEXT)
    {
      NSDebugMLLog(@"OpenGL", @"eglCreateContext failed");
      return NO;
    }

  return YES;
}

- (BOOL)_attachToWindowIfNeeded
{
  GSDisplayServer *server;
  NSWindow *window;
  struct window *newWindow;

  if (_view == nil)
    {
      return NO;
    }

  window = [_view window];
  if (window == nil)
    {
      return NO;
    }

  server = GSCurrentServer();
  newWindow = (struct window *)[server windowDevice:[window windowNumber]];
  if (newWindow == NULL)
    {
      return NO;
    }

  if (_window != newWindow)
    {
      if (_window != NULL)
        {
          _window->usesOpenGL = NO;
        }
      _window = newWindow;
      [self _destroySurface];
    }

  _window->usesOpenGL = YES;
  return YES;
}

- (BOOL)_ensureSurface
{
  EGLConfig eglConfig;

  if (_window == NULL || _window->surface == NULL)
    {
      return NO;
    }

  if (_eglWindow == NULL)
    {
      _eglWindow = wl_egl_window_create(_window->surface,
                                        (int)_window->width,
                                        (int)_window->height);
      if (_eglWindow == NULL)
        {
          NSDebugMLLog(@"OpenGL", @"wl_egl_window_create failed");
          return NO;
        }
    }

  if (_eglSurface != EGL_NO_SURFACE)
    {
      return YES;
    }

  eglConfig = [(WaylandGLPixelFormat *)_pixelFormat eglConfigForDisplay:_eglDisplay];
  _eglSurface = eglCreateWindowSurface(_eglDisplay,
                                       eglConfig,
                                       (EGLNativeWindowType)_eglWindow,
                                       NULL);

  if (_eglSurface == EGL_NO_SURFACE)
    {
      NSDebugMLLog(@"OpenGL", @"eglCreateWindowSurface failed");
      return NO;
    }

  if (_swapInterval >= 0)
    {
      eglSwapInterval(_eglDisplay, _swapInterval);
    }

  return YES;
}

- (void)_destroySurface
{
  if (_eglDisplay != EGL_NO_DISPLAY && _eglSurface != EGL_NO_SURFACE)
    {
      eglDestroySurface(_eglDisplay, _eglSurface);
      _eglSurface = EGL_NO_SURFACE;
    }

  if (_eglWindow != NULL)
    {
      wl_egl_window_destroy(_eglWindow);
      _eglWindow = NULL;
    }
}

- (id)initWithFormat:(NSOpenGLPixelFormat *)format
        shareContext:(NSOpenGLContext *)share
{
  self = [super init];

  if (!self)
    {
      return nil;
    }

  if (format == nil || [format isKindOfClass:[WaylandGLPixelFormat class]] == NO)
    {
      NSDebugMLLog(@"OpenGL", @"Invalid pixel format %@", format);
      [self release];
      return nil;
    }

  _eglDisplay = EGL_NO_DISPLAY;
  _eglContext = EGL_NO_CONTEXT;
  _eglSurface = EGL_NO_SURFACE;
  _eglWindow = NULL;
  _window = NULL;
  _swapInterval = 1;

  _pixelFormat = RETAIN(format);
  _shareContext = RETAIN(share);

  if (share != nil && [share isKindOfClass:[WaylandGLContext class]])
    {
      _eglDisplay = ((WaylandGLContext *)share)->_eglDisplay;
    }

  return self;
}

- (NSOpenGLPixelFormat *)pixelFormat
{
  return _pixelFormat;
}

- (void)setView:(NSView *)view
{
  if (view == nil)
    {
      [NSException raise:NSInvalidArgumentException
                  format:@"setView called with nil"];
    }

  ASSIGN(_view, view);

  if ([self _attachToWindowIfNeeded] == NO)
    {
      return;
    }

  if ([self _ensureDisplayAndContextWithShare:_shareContext] == NO)
    {
      return;
    }

  [self _ensureSurface];
}

- (NSView *)view
{
  return _view;
}

- (void)clearDrawable
{
  if (_window != NULL)
    {
      _window->usesOpenGL = NO;
    }
  [self _destroySurface];
}

- (void)makeCurrentContext
{
  if (_view == nil)
    {
      [NSException raise:NSGenericException
                  format:@"GL Context has no view attached, cannot be made current"];
    }

  if ([self _attachToWindowIfNeeded] == NO)
    {
      return;
    }

  if ([self _ensureDisplayAndContextWithShare:_shareContext] == NO)
    {
      return;
    }

  if ([self _ensureSurface] == NO)
    {
      return;
    }

  if (eglMakeCurrent(_eglDisplay, _eglSurface, _eglSurface, _eglContext) == EGL_FALSE)
    {
      NSDebugMLLog(@"OpenGL", @"eglMakeCurrent failed");
      return;
    }

  currentGLContext = self;
}

- (void)flushBuffer
{
  if (_eglDisplay == EGL_NO_DISPLAY || _eglSurface == EGL_NO_SURFACE)
    {
      return;
    }

  eglSwapBuffers(_eglDisplay, _eglSurface);
  if (_window != NULL && _window->wlconfig != NULL)
    {
      wl_display_flush(_window->wlconfig->display);
    }
}

- (void)update
{
  [self _attachToWindowIfNeeded];

  if (_eglWindow != NULL && _window != NULL)
    {
      wl_egl_window_resize(_eglWindow,
                           (int)_window->width,
                           (int)_window->height,
                           0,
                           0);
    }
}

- (void)getValues:(long *)vals forParameter:(NSOpenGLContextParameter)param
{
  if (vals == NULL)
    {
      return;
    }

  switch (param)
    {
      case NSOpenGLCPSwapInterval:
        *vals = _swapInterval;
        break;
      default:
        *vals = 0;
        break;
    }
}

- (void)setValues:(const long *)vals forParameter:(NSOpenGLContextParameter)param
{
  if (vals == NULL)
    {
      return;
    }

  if (param == NSOpenGLCPSwapInterval)
    {
      _swapInterval = (int)*vals;
      if (_eglDisplay != EGL_NO_DISPLAY)
        {
          eglSwapInterval(_eglDisplay, _swapInterval);
        }
    }
}

- (void)dealloc
{
  if (currentGLContext == self)
    {
      [WaylandGLContext clearCurrentContext];
    }

  if (_window != NULL)
    {
      _window->usesOpenGL = NO;
    }

  [self _destroySurface];

  if (_eglDisplay != EGL_NO_DISPLAY && _eglContext != EGL_NO_CONTEXT)
    {
      eglDestroyContext(_eglDisplay, _eglContext);
      _eglContext = EGL_NO_CONTEXT;
    }

  RELEASE(_view);
  RELEASE(_shareContext);
  RELEASE(_pixelFormat);

  [super dealloc];
}

@end
