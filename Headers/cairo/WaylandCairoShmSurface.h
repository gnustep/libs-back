/*
   WaylandCairoShmSurface.h

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author: Sergio L. Pascual <slp@sinrega.org>
   Date: February 2016

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

#ifndef WaylandCairoShmSurface_h
#define WaylandCairoShmSurface_h

#include "cairo/CairoSurface.h"

struct pool_buffer
{
  int		        poolfd;
  struct wl_shm_pool    *pool;
  struct wl_buffer      *buffer;
  cairo_surface_t	*surface;
  uint32_t	        width;
  uint32_t              height;
  void	                *data;
  size_t	        size;
  bool		        busy;

  /* Repaint-on-release: set when handleExposeRect skips attach because
   * the compositor still holds the buffer.  The release callback re-attaches
   * and commits the buffer so the missed frame is not lost.                  */
  bool                  needs_repaint;
  struct wl_surface    *owner_surface; /* the wl_surface this buffer is on   */
  struct wl_display    *owner_display; /* for flushing after re-attach        */
};

struct pool_buffer *
createShmBuffer(int width, int height, struct wl_shm *shm);

@interface WaylandCairoShmSurface : CairoSurface
{
  struct pool_buffer *pbuffer;
}
- (void) destroySurface;
/** Clear the wl_surface back-pointer so the release callback does not
 *  write to a destroyed Wayland proxy after destroySurfaceRole:.           */
- (void) clearOwnerSurface;
@end

#endif
