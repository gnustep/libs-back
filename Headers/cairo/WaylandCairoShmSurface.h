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
  int		      poolfd;
  struct wl_shm_pool *pool;
  struct wl_buffer   *buffer;
  cairo_surface_t	  *surface;
  uint32_t	      width, height;
  void	       *data;
  size_t	      size;
  bool		      busy;
};

struct pool_buffer *
createShmBuffer(int width, int height, struct wl_shm *shm);

@interface WaylandCairoShmSurface : CairoSurface
{
}
- (void)destroySurface;
@end

#endif
