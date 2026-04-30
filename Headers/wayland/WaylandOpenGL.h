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
#include <EGL/eglext.h>
#include <stdint.h>

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

  /* EGL/GL extension support */
  BOOL _extensionsLoaded;
  BOOL _hasDmaBufImport;
  BOOL _hasDmaBufImportModifiers;
  BOOL _hasExternalTexture;
  PFNEGLCREATEIMAGEKHRPROC          _pfnCreateImageKHR;
  PFNEGLDESTROYIMAGEKHRPROC         _pfnDestroyImageKHR;
  PFNEGLQUERYDMABUFFORMATSEXTPROC   _pfnQueryDmaBufFormats;
  PFNEGLQUERYDMABUFMODIFIERSEXTPROC _pfnQueryDmaBufModifiers;
  /* GL_OES_EGL_image — stored as void* to avoid pulling in GLES2 headers */
  void *_pfnGLImageTargetTexture2D;
}

/* Returns YES if EGL_EXT_image_dma_buf_import is available. */
- (BOOL)supportsDmaBufImport;

/* Returns YES if GL_OES_EGL_image / GL_OES_EGL_image_external are available. */
- (BOOL)supportsExternalTexture;

/* Returns the EGLDisplay used by this context (EGL_NO_DISPLAY if not yet initialised). */
- (EGLDisplay)eglDisplay;

/*
 * Create an EGLImageKHR backed by a single-plane DMA-BUF.
 * fourcc is a DRM FourCC pixel format code (e.g. DRM_FORMAT_ARGB8888).
 * Returns EGL_NO_IMAGE_KHR on failure.
 */
- (EGLImageKHR)createEGLImageFromDmaBufFd:(int)fd
                                     width:(int)width
                                    height:(int)height
                                    stride:(int)stride
                                    offset:(int)offset
                                    fourcc:(uint32_t)fourcc;

/*
 * Same as above but also passes the 64-bit DRM format modifier.
 * Requires EGL_EXT_image_dma_buf_import_modifiers on the display.
 */
- (EGLImageKHR)createEGLImageFromDmaBufFd:(int)fd
                                     width:(int)width
                                    height:(int)height
                                    stride:(int)stride
                                    offset:(int)offset
                                    fourcc:(uint32_t)fourcc
                                  modifier:(uint64_t)modifier;

/* Destroy an EGLImageKHR previously created by the methods above. */
- (void)destroyEGLImage:(EGLImageKHR)image;

/*
 * Bind image to the GL_TEXTURE_EXTERNAL_OES texture object texId.
 * The caller must bind texId to GL_TEXTURE_EXTERNAL_OES before calling this,
 * or call glBindTexture(GL_TEXTURE_EXTERNAL_OES, texId) themselves.
 * Requires supportsExternalTexture == YES.
 */
- (void)bindEGLImage:(EGLImageKHR)image toExternalTexture:(unsigned int)texId;

@end

@interface WaylandGLPixelFormat : NSOpenGLPixelFormat
{
  NSOpenGLPixelFormatAttribute *_attributes;
  NSUInteger _attributeCount;
}

- (EGLConfig)eglConfigForDisplay:(EGLDisplay)eglDisplay;
@end

#endif
