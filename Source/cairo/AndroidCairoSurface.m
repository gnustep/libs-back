/* AndroidCairoSurface

   A cairo surface for the Android backend.  It is an offscreen image surface:
   the window has real geometry, nothing is on screen, and -flushwindowrect::
   has nothing to post because the image surface is already the destination.
   A surface backed by the buffer ANativeWindow_lock hands out replaces the
   allocation here, behind this same class.

   Copyright (C) 2026 Free Software Foundation, Inc.

   Author: Todd White <todd.white@thalion.global>
   Date: August 2026

   This file is part of the GNU Objective C Backend Library.

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

#include "android/AndroidServer.h"
#include "cairo/AndroidCairoSurface.h"

#include <Foundation/NSDebug.h>

#include <math.h>
#include <stdint.h>

@implementation AndroidCairoSurface

/* device is the struct AndroidWindow the server keeps for this window id. */
- (id) initWithDevice: (void *)device
{
  struct AndroidWindow *window = (struct AndroidWindow *)device;
  int			w, h;

  if (window == NULL)
    {
      NSDebugLLog(@"AndroidCairoSurface", @"no device for the surface");
      DESTROY(self);
      return nil;
    }

  gsDevice = device;

  w = (int)NSWidth(window->frame);
  h = (int)NSHeight(window->frame);
  if (w <= 0 || h <= 0)
    {
      NSDebugLLog(@"AndroidCairoSurface",
		  @"window %d has a %dx%d frame, no surface made",
		  window->window_id, w, h);
      DESTROY(self);
      return nil;
    }

  _surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);

  /* A surface in an error state accepts every drawing call and discards it, so
   * the status is checked while the surface is being created. */
  if (cairo_surface_status(_surface) != CAIRO_STATUS_SUCCESS)
    {
      NSLog(@"AndroidCairoSurface: %dx%d surface: %s", w, h,
	    cairo_status_to_string(cairo_surface_status(_surface)));
      cairo_surface_destroy(_surface);
      _surface = NULL;
      DESTROY(self);
      return nil;
    }

  /* The record carries the window when the activity handed one over before
   * AppKit asked for a surface, which is the order an activity works in: the
   * window arrives with APP_CMD_INIT_WINDOW, and the surface is made later,
   * when something is first drawn. */
  [self setNativeWindow: window->native];

  window->surface = self;
  return self;
}

- (void) dealloc
{
  struct AndroidWindow *window = (struct AndroidWindow *)gsDevice;

  if (window != NULL && window->surface == self)
    {
      window->surface = nil;
    }
  /* _surface is destroyed by CairoSurface -dealloc. */
  [super dealloc];
}

- (NSSize) size
{
  if (_surface == NULL)
    {
      return NSZeroSize;
    }
  return NSMakeSize(cairo_image_surface_get_width(_surface),
		    cairo_image_surface_get_height(_surface));
}

- (void) setSize: (NSSize)newSize
{
  cairo_surface_t *replacement;
  int		   w = (int)newSize.width;
  int		   h = (int)newSize.height;

  if (w <= 0 || h <= 0)
    {
      NSDebugLLog(@"AndroidCairoSurface",
		  @"ignoring a resize to %dx%d", w, h);
      return;
    }
  if (_surface != NULL
      && cairo_image_surface_get_width(_surface) == w
      && cairo_image_surface_get_height(_surface) == h)
    {
      return;
    }

  replacement = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
  if (cairo_surface_status(replacement) != CAIRO_STATUS_SUCCESS)
    {
      NSLog(@"AndroidCairoSurface: resize to %dx%d: %s", w, h,
	    cairo_status_to_string(cairo_surface_status(replacement)));
      cairo_surface_destroy(replacement);
      return;
    }
  if (_surface != NULL)
    {
      cairo_surface_destroy(_surface);
    }
  _surface = replacement;

  /* A bound window keeps handing out buffers of the size it was last told,
   * so a resize that does not reach it clips every later post to the old
   * geometry. */
  /* The format is set; the size is not.  A buffer the size of the window is
   * scaled to the surface by the platform, which stretches a window that is
   * not the shape of the screen.  The window is placed in a buffer of the
   * surface's own size instead, by -_postRect:. */
  if (_window != NULL)
    {
      ANativeWindow_setBuffersGeometry(_window, 0, 0, WINDOW_FORMAT_RGBA_8888);
    }
}

- (void) setNativeWindow: (ANativeWindow *)window
{
  _window = window;
  if (_window != NULL && _surface != NULL)
    {
      ANativeWindow_setBuffersGeometry(_window, 0, 0, WINDOW_FORMAT_RGBA_8888);
    }
}

- (ANativeWindow *) nativeWindow
{
  return _window;
}

/* Copy rect out of the image surface and post it.
 *
 * rect is in cairo coordinates: y counts down from the top, which is what the
 * callers convert to.  The destination stride comes from the buffer and is
 * never computed from the width, since a window is entitled to hand out a
 * wider row than it shows.  cairo's ARGB32 is a native-endian 32-bit word, so
 * its bytes are B, G, R, A, where RGBA_8888 is R, G, B, A: every pixel is
 * swizzled rather than copied.
 */
void
GSAndroidBlitWindow(ANativeWindow_Buffer *buffer, cairo_surface_t *surface,
  NSRect frame, int screenHeight, int x0, int y0, int x1, int y1)
{
  int		 sw, sh, srcStride, x, y, offsetX, offsetY;
  unsigned char	*src;

  if (buffer == NULL || surface == NULL || screenHeight <= 0)
    {
      return;
    }

  cairo_surface_flush(surface);
  sw = cairo_image_surface_get_width(surface);
  sh = cairo_image_surface_get_height(surface);
  srcStride = cairo_image_surface_get_stride(surface);
  src = cairo_image_surface_get_data(surface);
  if (src == NULL)
    {
      return;
    }

  /* cairo's own idea of the stride for this width, against the one the surface
   * reports.  A mismatch means the surface is not the format the loop below
   * assumes, and writing garbage silently is worse than saying so once. */
  if (srcStride != cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, sw))
    {
      NSLog(@"AndroidCairoSurface: stride %d is not the %d ARGB32 needs for"
	    @" width %d, not posting", srcStride,
	    cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, sw), sw);
      return;
    }

  offsetX = (int)NSMinX(frame);
  offsetY = screenHeight - (int)NSMaxY(frame);

  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > buffer->width) x1 = buffer->width;
  if (y1 > buffer->height) y1 = buffer->height;

  for (y = y0; y < y1; y++)
    {
      int	 sy = y - offsetY;
      uint32_t	*s;
      uint32_t	*d;

      if (sy < 0 || sy >= sh)
	{
	  continue;
	}
      s = (uint32_t *)(src + (size_t)sy * srcStride);
      d = (uint32_t *)((unsigned char *)buffer->bits
	+ (size_t)y * buffer->stride * 4);

      for (x = x0; x < x1; x++)
	{
	  int sx = x - offsetX;

	  if (sx >= 0 && sx < sw)
	    {
	      uint32_t p = s[sx];
	      uint32_t a = (p >> 24) & 0xff;
	      uint32_t r = (p >> 16) & 0xff;
	      uint32_t g = (p >> 8) & 0xff;
	      uint32_t b = p & 0xff;

	      d[x] = (a << 24) | (b << 16) | (g << 8) | r;
	    }
	}
    }
}

- (void) _postRect: (NSRect)rect
{
  ANativeWindow_Buffer	 buffer;
  ARect			 dirty;
  int			 sw, sh, x0, y0, x1, y1, x, y, srcStride;
  int			 offsetX, offsetY;
  unsigned char		*src;

  if (_window == NULL || _surface == NULL)
    {
      return;
    }

  cairo_surface_flush(_surface);
  sw = cairo_image_surface_get_width(_surface);
  sh = cairo_image_surface_get_height(_surface);
  srcStride = cairo_image_surface_get_stride(_surface);
  src = cairo_image_surface_get_data(_surface);
  if (src == NULL)
    {
      return;
    }

  /* cairo's own idea of the stride for this width, against the one the surface
   * reports.  A mismatch means the surface is not the format the loop below
   * assumes, and posting garbage silently is worse than saying so once. */
  if (srcStride != cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, sw))
    {
      NSLog(@"AndroidCairoSurface: stride %d is not the %d ARGB32 needs for"
	    @" width %d, not posting", srcStride,
	    cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, sw), sw);
      return;
    }

  /* Where this window sits in the surface.  The frame is in screen
   * coordinates, y up from the bottom; the buffer's rows count down from the
   * top, so the window's top edge is the screen height less its maximum y. */
  {
    struct AndroidWindow *record = (struct AndroidWindow *)gsDevice;
    int			  screenHeight = ANativeWindow_getHeight(_window);

    if (record == NULL || screenHeight <= 0)
      {
	return;
      }
    offsetX = (int)NSMinX(record->frame);
    offsetY = screenHeight - (int)NSMaxY(record->frame);
  }

  x0 = (int)floor(NSMinX(rect));
  y0 = (int)floor(NSMinY(rect));
  x1 = (int)ceil(NSMaxX(rect));
  y1 = (int)ceil(NSMaxY(rect));
  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > sw) x1 = sw;
  if (y1 > sh) y1 = sh;
  if (x1 <= x0 || y1 <= y0)
    {
      return;
    }

  /* The region to redraw is asked for rather than assumed.  A window locks one
   * of several buffers in turn, so the one it hands out holds whatever was
   * drawn into it some frames ago rather than what was posted last; the area
   * that has to be written is therefore wider than the area that changed, and
   * the window is the only thing that knows how much wider.  It reports that
   * through the same argument, which is why the argument is not NULL.
   */
  /* The damage is named to the window in the buffer's own coordinates. */
  dirty.left = x0 + offsetX;
  dirty.top = y0 + offsetY;
  dirty.right = x1 + offsetX;
  dirty.bottom = y1 + offsetY;
  if (ANativeWindow_lock(_window, &buffer, &dirty) != 0)
    {
      NSDebugLLog(@"AndroidCairoSurface", @"the window would not lock");
      return;
    }

  x0 = dirty.left;
  y0 = dirty.top;
  x1 = dirty.right;
  y1 = dirty.bottom;
  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > buffer.width) x1 = buffer.width;
  if (y1 > buffer.height) y1 = buffer.height;
  if (x1 <= x0 || y1 <= y0)
    {
      ANativeWindow_unlockAndPost(_window);
      return;
    }

  /* Everything the window says has to be written is written: the window's own
   * pixels where it covers, and black where it does not.  Leaving the rest
   * alone would show whichever frame this buffer last held. */
  for (y = y0; y < y1; y++)
    {
      int	 sy = y - offsetY;
      uint32_t	*s = (sy >= 0 && sy < sh)
	? (uint32_t *)(src + (size_t)sy * srcStride) : NULL;
      uint32_t	*d = (uint32_t *)((unsigned char *)buffer.bits
				  + (size_t)y * buffer.stride * 4);

      for (x = x0; x < x1; x++)
	{
	  int sx = x - offsetX;

	  if (s != NULL && sx >= 0 && sx < sw)
	    {
	      uint32_t p = s[sx];
	      uint32_t a = (p >> 24) & 0xff;
	      uint32_t r = (p >> 16) & 0xff;
	      uint32_t g = (p >> 8) & 0xff;
	      uint32_t b = p & 0xff;

	      d[x] = (a << 24) | (b << 16) | (g << 8) | r;
	    }
	  else
	    {
	      d[x] = 0xff000000;
	    }
	}
    }

  ANativeWindow_unlockAndPost(_window);
}

/* An expose asks for what is already drawn to be shown again, so it posts the
 * rect it names.  With no window there is nothing to post: the image surface
 * is already the destination. */
- (void) handleExposeRect: (NSRect)rect
{
  [self _postRect: rect];
}

/* A flush is a request for everything held back to reach the destination, so
 * it posts the whole surface.  A caller that knows the damaged rectangle calls
 * -handleExposeRect: instead and must not call both, or the window is posted
 * twice for one drawing operation. */
- (void) flush
{
  NSSize size = [self size];

  [super flush];
  [self _postRect: NSMakeRect(0, 0, size.width, size.height)];
}

- (BOOL) isDrawingToScreen
{
  return (_window != NULL) ? YES : NO;
}

@end
