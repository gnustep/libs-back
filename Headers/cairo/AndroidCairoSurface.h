/*
   AndroidCairoSurface.h

   Copyright (C) 2026 Free Software Foundation, Inc.

   Author: Todd White <todd.white@thalion.global>
   Date: August 2026

   This file is part of GNUstep.

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

#ifndef AndroidCairoSurface_h
#define AndroidCairoSurface_h

#include "cairo/CairoSurface.h"

#include <android/native_window.h>

@interface AndroidCairoSurface : CairoSurface
{
  /* The window this surface posts to, or NULL while it is offscreen.  It is
   * not retained: the server owns it and outlives the surface. */
  ANativeWindow *_window;
}

- (void) setNativeWindow: (ANativeWindow *)window;
- (ANativeWindow *) nativeWindow;

@end

/* Write one window's pixels into a buffer that is already locked, over the
 * given region of it, leaving alone every pixel the window does not cover.
 *
 * An activity has one surface and an application has as many windows as it
 * likes, so each window is written into that one buffer in turn, back to
 * front.  The caller locks the buffer, clears the region and calls this once
 * per window, so a window below cannot write over the one above it.
 *
 * frame is in screen coordinates, y up from the bottom; the buffer's rows count
 * down from the top, which is what screenHeight turns one into the other.  The
 * region is in the buffer's own coordinates.
 */
extern void
GSAndroidBlitWindow(ANativeWindow_Buffer *buffer, cairo_surface_t *surface,
  NSRect frame, int screenHeight, int x0, int y0, int x1, int y1);

#endif /* AndroidCairoSurface_h */
