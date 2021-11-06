/* -*- mode:ObjC -*-
   WaylandCairoSurface - Draw with Cairo onto Wayland surfaces

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author: Sergio L. Pascual <slp@sinrega.org>
   Date: February 2016

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
#include "cairo/WaylandCairoSurface.h"
#include <cairo/cairo.h>

#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>

#define GSWINDEVICE ((struct window *)gsDevice)

/* Linux specific version */
static int
os_create_anonymous_file(off_t size)
{
    static const char template[] = "/weston-shared-XXXXXX";
    const char *path;
    char *name;
    int fd;

    path = getenv("XDG_RUNTIME_DIR");
    if (!path) {
	errno = ENOENT;
	return -1;
    }

    name = malloc(strlen(path) + sizeof(template));
    if (!name)
	return -1;

    strcpy(name, path);
    strcat(name, template);

    fd = memfd_create(name, MFD_CLOEXEC);

    free(name);

    if (fd < 0)
	return -1;

    if (ftruncate(fd, size) != 0) {
	close(fd);
	return -1;
    }

    return fd;
}

static inline size_t
shm_buffer_stride(struct window *window)
{
  return window->width * 4;
}

static inline size_t
shm_buffer_size(struct window *window)
{
    return shm_buffer_stride(window) * window->height;
}

static cairo_surface_t *
create_shm_buffer(struct window *window)
{
    struct wl_shm_pool *pool;
    cairo_surface_t *surface;
    int fd, size, stride;

    stride = shm_buffer_stride(window);
    size = shm_buffer_size(window);

    NSDebugLog(@"WaylandCairoSurface: creating shm buffer of %d bytes", size);
    fd = os_create_anonymous_file(size);
    if (fd < 0) {
	NSLog(@"creating a buffer file for surface failed");
	return NULL;
    }

    window->data =
	mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (window->data == MAP_FAILED) {
	NSLog(@"error mapping anonymous file");
	close(fd);
	return NULL;
    }

    pool = wl_shm_create_pool(window->wlconfig->shm, fd, size);

    surface = cairo_image_surface_create_for_data(window->data,
						  CAIRO_FORMAT_ARGB32,
						  window->width,
						  window->height,
						  stride);

    window->buffer =
	wl_shm_pool_create_buffer(pool, 0,
				  window->width, window->height, stride,
				  WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);

    close(fd);

    return surface;
}

@implementation WaylandCairoSurface

- (id) initWithDevice: (void*)device
{
    struct window *window = (struct window *) device;
    NSDebugLog(@"WaylandCairoSurface: initWithDevice win=%d", window->window_id);

    gsDevice = device;

    _surface = create_shm_buffer(window);
    window->buffer_needs_attach = YES;
    if (_surface == NULL) {
	NSDebugLog(@"can't create cairo surface");
	return 0;
    }

    if(window->configured) {
        // if the window has a toplevel then it should appear on screen
        // we can attach a buffer only if the xdg surface is configured
        NSDebugLog(@"wl_surface_attach: win=%d toplevel_surface", window->window_id);
        window->buffer_needs_attach = NO;
        wl_surface_attach(window->surface, window->buffer, 0, 0);
        wl_surface_commit(window->surface);
    }
    window->wcs = self;

    return self;
}

- (void) dealloc
{
    struct window *window = (struct window*) gsDevice;
    NSDebugLog(@"WaylandCairoSurface: dealloc win=%d", window->window_id);

    // FIXME: This is leaking memory. We need to *correctly* implement
    // the counterpart to create_shm_buffer.
    //
    // For instance, this is the wrong place to destroy the cairo surface:
    //  cairo_surface_destroy(window->surface);
    //  window->surface = NULL;
    // and likely to unmap the data, and destroy/release the buffer.
    //  "Destroying the wl_buffer after wl_buffer.release does not change
    //  the surface contents. However, if the client destroys the wl_buffer
    //  before receiving the wl_buffer.release event, the surface contents
    //  become undefined immediately."
    // Hence also skipping:
    //  munmap(window->data, shm_buffer_size(window));

    [super dealloc];
}

- (NSSize) size
{
//    NSDebugLog(@"WaylandCairoSurface: size");
    struct window *window = (struct window*) gsDevice;
    return NSMakeSize(window->width, window->height);
}

- (void) setSurface: (cairo_surface_t*)surface
{
//    NSDebugLog(@"WaylandCairoSurface: setSurface");
    _surface = surface;
}

- (void) handleExposeRect: (NSRect)rect
{
    struct window *window = (struct window*) gsDevice;
    NSDebugLog(@"[CairoSurface handleExposeRect] %d", window->window_id);

    int x = NSMinX(rect);
    int y = NSMinY(rect);
    int width = NSWidth(rect);
    int height = NSHeight(rect);

    window->buffer_needs_attach = YES;
    if (window->configured) {
        window->buffer_needs_attach = NO;
        wl_surface_attach(window->surface, window->buffer, 0, 0);
        NSDebugLog(@"[%d] updating region: %d,%d %dx%d", window->window_id, 0, 0, window->width, window->height);
        // FIXME we should update only the damaged area define as x,y,width,height
        // at the moment it doesnt work
        wl_surface_damage(window->surface, 0, 0, window->width, window->height);
        wl_surface_commit(window->surface);
        wl_display_dispatch_pending(window->wlconfig->display);
        wl_display_flush(window->wlconfig->display);
    }

    //NSDebugLog(@"[CairoSurface handleExposeRect end]");
}

@end
