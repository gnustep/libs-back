/* WaylandCairoSurface

   WaylandCairoShmSurface - A cairo surface backed by a Wayland shared-memory
   buffer.

   Buffer lifecycle:
   1. createShmBuffer — allocate SHM fd, mmap, create wl_shm_pool + wl_buffer.
      Destroy the pool immediately (safe; the buffer keeps the mapping alive).
   2. initWithDevice — attach the buffer to the wl_surface and commit with a
      full-surface damage region.  Only after xdg_surface_configure (i.e.
      window->configured == YES).
   3. handleExposeRect — re-attach with the actual damage rect on every
      AppKit expose.  If the compositor still holds the buffer (busy == true),
      record needs_repaint and return; the release callback will re-commit.
   4. buffer_handle_release — compositor released the buffer.  If needs_repaint
      is set, immediately re-attach + commit to avoid losing the missed frame.
   5. dealloc / finishBuffer — destroy the wl_buffer, unmap memory, close the
      FD, and free the struct once the compositor has released it.

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author: Sergio L. Pascual <slp@sinrega.org>
   Rewrite: Riccardo Canalicchio <riccardo.canalicchio(at)gmail.com>
   Date: November 2021

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

#define _GNU_SOURCE

#include "wayland/WaylandServer.h"
#include "cairo/WaylandCairoShmSurface.h"
#include <cairo/cairo.h>

#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>


static const enum wl_shm_format wl_fmt    = WL_SHM_FORMAT_ARGB8888;
static const cairo_format_t     cairo_fmt = CAIRO_FORMAT_ARGB32;


/* ── Buffer lifetime ─────────────────────────────────────────────────────── */

/* Free the pool_buffer once both conditions hold:
 *   (a) the compositor has released the wl_buffer (busy == false), and
 *   (b) nobody is rendering into the cairo surface (surface == NULL).
 * Also closes the SHM file descriptor to prevent FD leaks.                  */
static void
finishBuffer(struct pool_buffer *buf)
{
  if (buf == NULL || buf->busy || buf->surface != NULL)
    return;

  if (buf->buffer)
    {
      wl_buffer_destroy(buf->buffer);
      buf->buffer = NULL;
    }
  if (buf->data)
    {
      munmap(buf->data, buf->size);
      buf->data = NULL;
    }
  if (buf->poolfd >= 0)
    {
      close(buf->poolfd);
      buf->poolfd = -1;
    }
  free(buf);
}

/* Compositor released the buffer.  If a repaint was queued while the buffer
 * was busy, re-attach and commit now so the frame is not permanently lost.  */
static void
buffer_handle_release(void *data, struct wl_buffer *wl_buffer)
{
  struct pool_buffer *buffer = data;
  buffer->busy = false;

  if (buffer->needs_repaint && buffer->owner_surface)
    {
      buffer->needs_repaint = false;
      buffer->busy          = true;

      wl_surface_attach(buffer->owner_surface, wl_buffer, 0, 0);
      wl_surface_damage(buffer->owner_surface, 0, 0,
                        (int32_t)buffer->width, (int32_t)buffer->height);
      wl_surface_commit(buffer->owner_surface);

      if (buffer->owner_display)
        wl_display_flush(buffer->owner_display);

      /* Don't call finishBuffer — we just re-submitted the buffer. */
      return;
    }

  finishBuffer(buffer);
}

static const struct wl_buffer_listener buffer_listener = {
  .release = buffer_handle_release,
};


/* ── SHM buffer allocation ───────────────────────────────────────────────── */

/* Creates an anonymous in-memory file suitable for sharing with the
 * compositor via wl_shm.  memfd_create is preferred over mkstemp because
 * it never touches the filesystem and automatically cleans up on close.     */
static int
createPoolFile(off_t size)
{
  int fd = memfd_create("gnustep-wl-shm", MFD_CLOEXEC);
  if (fd < 0)
    return -1;

  if (ftruncate(fd, size) != 0)
    {
      close(fd);
      return -1;
    }

  return fd;
}

struct pool_buffer *
createShmBuffer(int width, int height, struct wl_shm *shm)
{
  uint32_t stride = cairo_format_stride_for_width(cairo_fmt, width);
  size_t   size   = stride * height;

  if (size == 0)
    return NULL;

  struct pool_buffer *buf = calloc(1, sizeof(struct pool_buffer));
  if (!buf)
    return NULL;

  buf->poolfd = -1;

  buf->poolfd = createPoolFile(size);
  if (buf->poolfd < 0)
    {
      free(buf);
      return NULL;
    }

  buf->data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, buf->poolfd, 0);
  if (buf->data == MAP_FAILED)
    {
      close(buf->poolfd);
      free(buf);
      return NULL;
    }

  /* Create the pool and immediately the buffer.  The pool can be destroyed
   * right after — the buffer retains the memory mapping independently.      */
  struct wl_shm_pool *pool = wl_shm_create_pool(shm, buf->poolfd, size);
  buf->buffer = wl_shm_pool_create_buffer(pool, 0, width, height, stride, wl_fmt);
  wl_shm_pool_destroy(pool);
  /* buf->pool is left NULL — pool is gone, nothing to free later. */

  if (!buf->buffer)
    {
      munmap(buf->data, size);
      close(buf->poolfd);
      free(buf);
      return NULL;
    }

  wl_buffer_add_listener(buf->buffer, &buffer_listener, buf);

  buf->size    = size;
  buf->width   = width;
  buf->height  = height;
  buf->surface = cairo_image_surface_create_for_data(
      buf->data, cairo_fmt, width, height, stride);

  return buf;
}


/* ── WaylandCairoShmSurface ──────────────────────────────────────────────── */

@implementation WaylandCairoShmSurface

- (id)initWithDevice:(void *)device
{
  struct window *window = (struct window *)device;
  NSDebugLog(@"WaylandCairoShmSurface: initWithDevice win=%d", window->window_id);

  gsDevice = device;

  pbuffer = createShmBuffer((int)window->width, (int)window->height,
                             window->wlconfig->shm);
  if (pbuffer == NULL)
    {
      NSDebugLog(@"WaylandCairoShmSurface: failed to allocate SHM buffer");
      return nil;
    }

  _surface = pbuffer->surface;
  if (_surface == NULL)
    {
      NSDebugLog(@"WaylandCairoShmSurface: failed to create cairo surface");
      finishBuffer(pbuffer);
      pbuffer = NULL;
      return nil;
    }

  /* Wire back-pointers so the release callback can re-commit missed frames. */
  pbuffer->owner_surface = window->surface;
  pbuffer->owner_display = window->wlconfig->display;

  window->wcs = self;

  if (window->configured)
    {
      /* Attach the fresh buffer with a full-surface damage region.
       * wl_surface_damage is mandatory before commit — without it the
       * compositor treats the commit as a no-op for rendering purposes.     */
      window->buffer_needs_attach = NO;
      pbuffer->busy = true;
      wl_surface_attach(window->surface, pbuffer->buffer, 0, 0);
      wl_surface_damage(window->surface, 0, 0,
                        (int32_t)window->width, (int32_t)window->height);
      wl_surface_commit(window->surface);
    }
  else
    {
      window->buffer_needs_attach = YES;
    }

  return self;
}

- (void)dealloc
{
  struct window *window = (struct window *)gsDevice;
  NSDebugLog(@"WaylandCairoShmSurface: dealloc win=%d", window->window_id);

  /* Detach this surface from the window so it won't be used again. */
  if (window->wcs == self)
    window->wcs = nil;

  /* Sever the Cairo→buffer link; the buffer may still be compositor-held. */
  cairo_surface_destroy(_surface);
  _surface         = NULL;
  pbuffer->surface = NULL;

  /* Clear back-pointers so the release callback doesn't touch freed data.  */
  pbuffer->owner_surface = NULL;
  pbuffer->owner_display = NULL;
  pbuffer->needs_repaint = false;

  /* Free immediately if the compositor has already released the buffer;
   * otherwise finishBuffer defers until the release callback fires.         */
  finishBuffer(pbuffer);
  pbuffer = NULL;

  [super dealloc];
}

- (NSSize)size
{
  if (_surface == NULL)
    return NSZeroSize;
  return NSMakeSize(cairo_image_surface_get_width(_surface),
                    cairo_image_surface_get_height(_surface));
}

- (void)handleExposeRect:(NSRect)rect
{
  struct window *window = (struct window *)gsDevice;

  if (!window->configured)
    {
      window->buffer_needs_attach = YES;
      return;
    }

  /* If the buffer dimensions no longer match the window (e.g. after a
   * compositor-driven resize), the old buffer is stale.  Mark it for
   * repaint-on-release so no frame is lost, then bail out — AppKit will
   * allocate a correctly-sized WaylandCairoShmSurface via the next
   * setWindowdevice:forContext: call.                                        */
  if (pbuffer->width != (uint32_t)window->width
      || pbuffer->height != (uint32_t)window->height)
    {
      NSDebugLog(@"[%d] handleExposeRect: size mismatch buf=%dx%d win=%dx%d — "
                 @"deferring until resize completes",
                 window->window_id,
                 pbuffer->width, pbuffer->height,
                 (int)window->width, (int)window->height);
      pbuffer->needs_repaint = true;
      return;
    }

  /* If the compositor still owns the buffer, queue a repaint for the moment
   * it returns it.  Attaching a busy buffer causes a protocol error.        */
  if (pbuffer->busy)
    {
      NSDebugLog(@"[%d] handleExposeRect: buffer busy — queuing repaint",
                 window->window_id);
      pbuffer->needs_repaint = true;
      return;
    }

  /* Attach, mark the actual damaged region, and commit.
   * Using the precise rect (converted to integer coordinates) reduces the
   * compositor's repaint area for partial-surface updates.                  */
  int dx = (int)NSMinX(rect);
  int dy = (int)(window->height - NSMaxY(rect));  /* flip Y: AppKit → Wayland */
  int dw = (int)NSWidth(rect)  + 1;               /* +1: cover sub-pixel edges */
  int dh = (int)NSHeight(rect) + 1;

  /* Clamp to buffer dimensions. */
  if (dx < 0) dx = 0;
  if (dy < 0) dy = 0;
  if (dx + dw > (int)pbuffer->width)  dw = (int)pbuffer->width  - dx;
  if (dy + dh > (int)pbuffer->height) dh = (int)pbuffer->height - dy;

  NSDebugLog(@"[%d] handleExposeRect: attach+damage (%d,%d %dx%d)",
             window->window_id, dx, dy, dw, dh);

  pbuffer->needs_repaint = false;
  pbuffer->busy          = true;
  window->buffer_needs_attach = NO;

  wl_surface_attach(window->surface, pbuffer->buffer, 0, 0);
  wl_surface_damage(window->surface, dx, dy, dw, dh);
  wl_surface_commit(window->surface);
  wl_display_dispatch_pending(window->wlconfig->display);
  wl_display_flush(window->wlconfig->display);
}

- (void)destroySurface
{
  /* Offscreen surface — no-op.  Destruction is handled in dealloc. */
}

- (void)clearOwnerSurface
{
  /* Called from destroySurfaceRole: just before wl_surface_destroy.
   * Prevents the buffer_handle_release callback from writing to the
   * about-to-be-freed proxy.                                              */
  if (pbuffer)
    {
      pbuffer->owner_surface = NULL;
      pbuffer->owner_display = NULL;
      pbuffer->needs_repaint = false;
    }
}

@end
