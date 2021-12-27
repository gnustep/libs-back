/* WaylandCairoSurface

   WaylandCairoShmSurface - A cairo surface backed by a wayland
   shared memory buffer.
   After the wayland surface is configured, the buffer needs to be
   attached to the surface. Subsequent changes to the cairo surface
   needs to be notified to the wayland server using wl_surface_damage
   and wl_surface_commit. The buffer is freed after the compositor
   releases it and the cairo surface is not in use.

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


static const enum wl_shm_format wl_fmt = WL_SHM_FORMAT_ARGB8888;
static const cairo_format_t	cairo_fmt = CAIRO_FORMAT_ARGB32;

static void
finishBuffer(struct pool_buffer *buf)
{
  // The buffer can be deleted if it has been released by the compositor
  // and if not used by the cairo surface
  if(buf == NULL || buf->busy || buf->surface != NULL)
  {
    return;
  }
  if (buf->buffer)
    {
      wl_buffer_destroy(buf->buffer);
    }
  if (buf->data)
    {
      munmap(buf->data, buf->size);
    }
  free(buf);
  return;
}

static void
buffer_handle_release(void *data, struct wl_buffer *wl_buffer)
{
  struct pool_buffer *buffer = data;
  buffer->busy = false;
  // If the buffer was not released before dealloc
  finishBuffer(buffer);
}

static const struct wl_buffer_listener buffer_listener = {
  // Sent by the compositor when it's no longer using a buffer
  .release = buffer_handle_release,
};

// Creates a file descriptor for the compositor to share pixel buffers
static int
createPoolFile(off_t size)
{
  static const char template[] = "/gnustep-shared-XXXXXX";
  const char *path;
  char       *name;
  int	      fd;

  path = getenv("XDG_RUNTIME_DIR");
  if (!path)
    {
      errno = ENOENT;
      return -1;
    }

  name = malloc(strlen(path) + sizeof(template));
  if (!name)
    {
      return -1;
    }

  strcpy(name, path);
  strcat(name, template);

  fd = memfd_create(name, MFD_CLOEXEC);

  free(name);

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
  size_t   size = stride * height;

  struct pool_buffer * buf = malloc(sizeof(struct pool_buffer));

  void *data = NULL;
  if (size > 0)
    {
      buf->poolfd = createPoolFile(size);
      if (buf->poolfd == -1)
        {
          return NULL;
        }

      data
	= mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, buf->poolfd, 0);
      if (data == MAP_FAILED)
        {
          return NULL;
        }

      buf->pool = wl_shm_create_pool(shm, buf->poolfd, size);
      buf->buffer = wl_shm_pool_create_buffer(buf->pool, 0, width, height,
					      stride, wl_fmt);
      wl_buffer_add_listener(buf->buffer, &buffer_listener, buf);
    }
  else
  {
    return NULL;
  }

  buf->data = data;
  buf->size = size;
  buf->width = width;
  buf->height = height;
  buf->surface = cairo_image_surface_create_for_data(data, cairo_fmt, width, height, stride);

  if(buf->pool)
  {
    wl_shm_pool_destroy(buf->pool);
  }
  return buf;
}

@implementation WaylandCairoShmSurface
{
    struct pool_buffer *pbuffer;
}
- (id)initWithDevice:(void *)device
{
  struct window *window = (struct window *) device;
  NSDebugLog(@"WaylandCairoShmSurface: initWithDevice win=%d",
	     window->window_id);

  gsDevice = device;

  pbuffer = createShmBuffer(window->width, window->height, window->wlconfig->shm);

  if (pbuffer == NULL)
    {
      NSDebugLog(@"failed to obtain buffer");
      return nil;
    }

  _surface = pbuffer->surface;

  window->buffer_needs_attach = YES;
  if (_surface == NULL)
    {
      NSDebugLog(@"can't create cairo surface");
      return nil;
    }

  if (window->configured)
    {
      // we can attach a buffer to the surface only if the surface is configured
      // this is usually done in the configure event handler
      // in case of resize of an already configured surface
      // we should reattach the new allocated buffer
      NSDebugLog(@"wl_surface_attach: win=%d",
		 window->window_id);
      window->buffer_needs_attach = NO;
      wl_surface_attach(window->surface, pbuffer->buffer, 0, 0);
      wl_surface_commit(window->surface);
    }
  window->wcs = self;

  return self;
}

- (void)dealloc
{
  struct window *window = (struct window *) gsDevice;
  NSDebugLog(@"WaylandCairoSurface: dealloc win=%d", window->window_id);
  cairo_surface_destroy(_surface);
  _surface = NULL;
  pbuffer->surface = NULL;
  // try to free the buffer if already released by the compositor
  finishBuffer(pbuffer);

  [super dealloc];
}

- (NSSize)size
{
  if (_surface == NULL)
    {
      return NSZeroSize;
    }
  return NSMakeSize(cairo_image_surface_get_width(_surface),
		    cairo_image_surface_get_height(_surface));
}

- (void)handleExposeRect:(NSRect)rect
{
  struct window *window = (struct window *) gsDevice;
  NSDebugLog(@"[CairoSurface handleExposeRect] %d", window->window_id);

  window->buffer_needs_attach = YES;

  if (window->configured)
    {
      window->buffer_needs_attach = NO;
      wl_surface_attach(window->surface, pbuffer->buffer, 0, 0);
      NSDebugLog(@"[%d] updating region: %d,%d %fx%f", window->window_id, 0, 0,
		 window->width, window->height);
      // FIXME we should update only the damaged area defined as x,y,width,
      // height at the moment it doesnt work
      wl_surface_damage(window->surface, 0, 0, window->width, window->height);
      wl_surface_commit(window->surface);
      wl_display_dispatch_pending(window->wlconfig->display);
      wl_display_flush(window->wlconfig->display);
    }
}

- (void)destroySurface
{
  // noop this is an offscreen surface
  // no need to destroy it when not visible
}
@end
