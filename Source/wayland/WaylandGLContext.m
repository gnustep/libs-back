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
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <wayland-egl.h>
#include <wayland-client-protocol.h>
#include <string.h>

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

  return YES;
}

- (void)_computeViewGeometry:(NSRect *)outFrame
{
  NSRect bounds = [_view bounds];
  NSRect frame = [_view convertRect:bounds toView:nil];
  /* AppKit Y-up → Wayland Y-down: flip origin.y relative to window height */
  frame.origin.y = _window->height - NSMaxY(frame);

  static BOOL _loggedOnce = NO;
  if (!_loggedOnce)
    {
      _loggedOnce = YES;
      NSLog(@"WaylandGL: _computeViewGeometry:"
            @" viewBounds=%@ convertedFrame=%@ windowH=%.0f"
            @" → waylandFrame=%@",
            NSStringFromRect(bounds),
            NSStringFromRect([_view convertRect:bounds toView:nil]),
            (double)_window->height,
            NSStringFromRect(frame));
    }

  *outFrame = frame;
}

- (BOOL)_ensureSurface
{
  EGLConfig eglConfig;
  NSRect viewFrame;
  struct wl_surface *renderSurface;
  int subW, subH, subX, subY;

  if (_window == NULL || _window->surface == NULL)
    {
      return NO;
    }

  [self _computeViewGeometry:&viewFrame];
  subX = (int)NSMinX(viewFrame);
  subY = (int)NSMinY(viewFrame);
  subW = (int)NSWidth(viewFrame);
  subH = (int)NSHeight(viewFrame);
  if (subW <= 0 || subH <= 0)
    {
      return NO;
    }

  if (_glSurface == NULL)
    {
      WaylandConfig *wlconfig = _window->wlconfig;

      if (wlconfig->subcompositor == NULL)
        {
          NSLog(@"WaylandGL: _ensureSurface: no subcompositor — using window surface directly");
          renderSurface = _window->surface;
          _window->usesOpenGL = YES;
        }
      else
        {
          _glSurface = wl_compositor_create_surface(wlconfig->compositor);
          if (_glSurface == NULL)
            {
              NSLog(@"WaylandGL: _ensureSurface: wl_compositor_create_surface failed");
              return NO;
            }

          _glSubsurface = wl_subcompositor_get_subsurface(
              wlconfig->subcompositor, _glSurface, _window->surface);
          if (_glSubsurface == NULL)
            {
              NSLog(@"WaylandGL: _ensureSurface: wl_subcompositor_get_subsurface failed");
              wl_surface_destroy(_glSurface);
              _glSurface = NULL;
              return NO;
            }

          wl_subsurface_set_desync(_glSubsurface);
          wl_subsurface_set_position(_glSubsurface, subX, subY);
          wl_surface_set_user_data(_glSurface, _window);
          wl_surface_commit(_window->surface);
          wl_display_flush(wlconfig->display);

          NSLog(@"WaylandGL: _ensureSurface: subsurface created glSurface=%p pos=(%d,%d) size=(%dx%d)",
                _glSurface, subX, subY, subW, subH);
          renderSurface = _glSurface;
        }
    }
  else
    {
      renderSurface = _glSurface;
    }

  if (_eglWindow == NULL)
    {
      _eglWindow = wl_egl_window_create(renderSurface, subW, subH);
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
      NSLog(@"WaylandGL: _ensureSurface: eglCreateWindowSurface failed (0x%x)", eglGetError());
      return NO;
    }

  if (_swapInterval >= 0)
    {
      eglSwapInterval(_eglDisplay, _swapInterval);
    }

  NSLog(@"WaylandGL: _ensureSurface: EGL surface ready eglSurface=%p eglWindow=%p",
        _eglSurface, _eglWindow);
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

  if (_glSubsurface != NULL)
    {
      wl_subsurface_destroy(_glSubsurface);
      _glSubsurface = NULL;
    }

  if (_glSurface != NULL)
    {
      wl_surface_destroy(_glSurface);
      _glSurface = NULL;
    }
}

- (void)_loadExtensions
{
  const char *eglExts;
  const char *glExts;

  if (_eglDisplay == EGL_NO_DISPLAY || _eglContext == EGL_NO_CONTEXT)
    return;

  _extensionsLoaded = YES;

  eglExts = eglQueryString(_eglDisplay, EGL_EXTENSIONS);
  if (eglExts == NULL)
    eglExts = "";

  if (strstr(eglExts, "EGL_EXT_image_dma_buf_import") != NULL)
    {
      _pfnCreateImageKHR = (PFNEGLCREATEIMAGEKHRPROC)
          eglGetProcAddress("eglCreateImageKHR");
      _pfnDestroyImageKHR = (PFNEGLDESTROYIMAGEKHRPROC)
          eglGetProcAddress("eglDestroyImageKHR");
      if (_pfnCreateImageKHR != NULL && _pfnDestroyImageKHR != NULL)
        {
          _hasDmaBufImport = YES;
          NSDebugMLLog(@"OpenGL", @"WaylandGL: EGL_EXT_image_dma_buf_import available");
        }
    }

  if (_hasDmaBufImport
      && strstr(eglExts, "EGL_EXT_image_dma_buf_import_modifiers") != NULL)
    {
      _pfnQueryDmaBufFormats = (PFNEGLQUERYDMABUFFORMATSEXTPROC)
          eglGetProcAddress("eglQueryDmaBufFormatsEXT");
      _pfnQueryDmaBufModifiers = (PFNEGLQUERYDMABUFMODIFIERSEXTPROC)
          eglGetProcAddress("eglQueryDmaBufModifiersEXT");
      if (_pfnQueryDmaBufFormats != NULL && _pfnQueryDmaBufModifiers != NULL)
        {
          _hasDmaBufImportModifiers = YES;
          NSDebugMLLog(@"OpenGL", @"WaylandGL: EGL_EXT_image_dma_buf_import_modifiers available");
        }
    }

  /* GL_OES_EGL_image + GL_OES_EGL_image_external — needs a current context */
  glExts = (const char *)glGetString(GL_EXTENSIONS);
  if (glExts == NULL)
    glExts = "";

  if (strstr(glExts, "GL_OES_EGL_image") != NULL)
    {
      void *pfn = (void *)eglGetProcAddress("glEGLImageTargetTexture2DOES");
      if (pfn != NULL)
        {
          _pfnGLImageTargetTexture2D = pfn;
          _hasExternalTexture = YES;
          NSDebugMLLog(@"OpenGL", @"WaylandGL: GL_OES_EGL_image_external available");
        }
    }
}

- (BOOL)supportsDmaBufImport
{
  return _hasDmaBufImport;
}

- (BOOL)supportsExternalTexture
{
  return _hasExternalTexture;
}

- (EGLDisplay)eglDisplay
{
  return _eglDisplay;
}

- (EGLImageKHR)createEGLImageFromDmaBufFd:(int)fd
                                     width:(int)width
                                    height:(int)height
                                    stride:(int)stride
                                    offset:(int)offset
                                    fourcc:(uint32_t)fourcc
{
  EGLint attrs[] = {
    EGL_WIDTH,                     (EGLint)width,
    EGL_HEIGHT,                    (EGLint)height,
    EGL_LINUX_DRM_FOURCC_EXT,      (EGLint)fourcc,
    EGL_DMA_BUF_PLANE0_FD_EXT,     (EGLint)fd,
    EGL_DMA_BUF_PLANE0_OFFSET_EXT, (EGLint)offset,
    EGL_DMA_BUF_PLANE0_PITCH_EXT,  (EGLint)stride,
    EGL_NONE
  };
  EGLImageKHR image;

  if (!_hasDmaBufImport || _pfnCreateImageKHR == NULL
      || _eglDisplay == EGL_NO_DISPLAY)
    return EGL_NO_IMAGE_KHR;

  image = _pfnCreateImageKHR(_eglDisplay, EGL_NO_CONTEXT,
                              EGL_LINUX_DMA_BUF_EXT,
                              (EGLClientBuffer)NULL, attrs);
  if (image == EGL_NO_IMAGE_KHR)
    NSDebugMLLog(@"OpenGL", @"WaylandGL: eglCreateImageKHR(dma-buf) failed: 0x%x",
                 eglGetError());
  return image;
}

- (EGLImageKHR)createEGLImageFromDmaBufFd:(int)fd
                                     width:(int)width
                                    height:(int)height
                                    stride:(int)stride
                                    offset:(int)offset
                                    fourcc:(uint32_t)fourcc
                                  modifier:(uint64_t)modifier
{
  EGLint modLo = (EGLint)(modifier & 0xFFFFFFFFu);
  EGLint modHi = (EGLint)(modifier >> 32);
  EGLint attrs[] = {
    EGL_WIDTH,                          (EGLint)width,
    EGL_HEIGHT,                         (EGLint)height,
    EGL_LINUX_DRM_FOURCC_EXT,           (EGLint)fourcc,
    EGL_DMA_BUF_PLANE0_FD_EXT,          (EGLint)fd,
    EGL_DMA_BUF_PLANE0_OFFSET_EXT,      (EGLint)offset,
    EGL_DMA_BUF_PLANE0_PITCH_EXT,       (EGLint)stride,
    EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, modLo,
    EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, modHi,
    EGL_NONE
  };
  EGLImageKHR image;

  if (!_hasDmaBufImport || _pfnCreateImageKHR == NULL
      || _eglDisplay == EGL_NO_DISPLAY)
    return EGL_NO_IMAGE_KHR;

  if (!_hasDmaBufImportModifiers)
    {
      NSDebugMLLog(@"OpenGL",
                   @"WaylandGL: modifier requested but EGL_EXT_image_dma_buf_import_modifiers unavailable");
      return EGL_NO_IMAGE_KHR;
    }

  image = _pfnCreateImageKHR(_eglDisplay, EGL_NO_CONTEXT,
                              EGL_LINUX_DMA_BUF_EXT,
                              (EGLClientBuffer)NULL, attrs);
  if (image == EGL_NO_IMAGE_KHR)
    NSDebugMLLog(@"OpenGL",
                 @"WaylandGL: eglCreateImageKHR(dma-buf+modifier) failed: 0x%x",
                 eglGetError());
  return image;
}

- (void)destroyEGLImage:(EGLImageKHR)image
{
  if (image == EGL_NO_IMAGE_KHR || _pfnDestroyImageKHR == NULL
      || _eglDisplay == EGL_NO_DISPLAY)
    return;
  _pfnDestroyImageKHR(_eglDisplay, image);
}

- (void)bindEGLImage:(EGLImageKHR)image toExternalTexture:(unsigned int)texId
{
  typedef void (*TargetTex2DOES)(GLenum, GLeglImageOES);
  TargetTex2DOES fn = (TargetTex2DOES)_pfnGLImageTargetTexture2D;

  if (image == EGL_NO_IMAGE_KHR || fn == NULL)
    return;
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, texId);
  fn(GL_TEXTURE_EXTERNAL_OES, (GLeglImageOES)image);
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
  _glSurface = NULL;
  _glSubsurface = NULL;
  _window = NULL;
  _extensionsLoaded = NO;
  _hasDmaBufImport = NO;
  _hasDmaBufImportModifiers = NO;
  _hasExternalTexture = NO;
  _pfnCreateImageKHR = NULL;
  _pfnDestroyImageKHR = NULL;
  _pfnQueryDmaBufFormats = NULL;
  _pfnQueryDmaBufModifiers = NULL;
  _pfnGLImageTargetTexture2D = NULL;
  /* Default to unthrottled swaps.  With vsync=1 eglSwapBuffers blocks on the
     compositor frame callback, which starves the main run loop when called
     from a timer.  Apps that want vsync can set NSOpenGLCPSwapInterval = 1. */
  _swapInterval = 0;

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

  if (!_extensionsLoaded)
    [self _loadExtensions];

  currentGLContext = self;
}

- (void)flushBuffer
{
  if (_eglDisplay == EGL_NO_DISPLAY || _eglSurface == EGL_NO_SURFACE)
    {
      NSLog(@"WaylandGL: flushBuffer: skipped — no EGL display/surface");
      return;
    }

  static NSUInteger _swapCount = 0;
  EGLBoolean ok = eglSwapBuffers(_eglDisplay, _eglSurface);
  if (++_swapCount <= 5 || _swapCount % 90 == 0)
    NSLog(@"WaylandGL: flushBuffer: eglSwapBuffers #%lu result=%d err=0x%x",
          (unsigned long)_swapCount, (int)ok, ok ? 0 : eglGetError());

  if (_window != NULL && _window->wlconfig != NULL)
    {
      wl_display_flush(_window->wlconfig->display);
    }
}

- (void)update
{
  NSRect viewFrame;

  [self _attachToWindowIfNeeded];

  if (_eglWindow == NULL || _window == NULL)
    {
      return;
    }

  [self _computeViewGeometry:&viewFrame];

  wl_egl_window_resize(_eglWindow,
                       (int)NSWidth(viewFrame),
                       (int)NSHeight(viewFrame),
                       0,
                       0);

  if (_glSubsurface != NULL)
    {
      wl_subsurface_set_position(_glSubsurface,
                                 (int)NSMinX(viewFrame),
                                 (int)NSMinY(viewFrame));
      wl_surface_commit(_window->surface);
      wl_display_flush(_window->wlconfig->display);
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
