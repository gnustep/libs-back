/* 
   WaylandServer - LayerShell Protocol Handling

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author: Riccardo Canalicchio <riccardo.canalicchio(at)gmail.com>
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

#include "wayland/WaylandServer.h"
#include <AppKit/NSEvent.h>
#include <AppKit/NSApplication.h>

static void
layer_surface_configure(void *data, struct zwlr_layer_surface_v1 *surface,
			uint32_t serial, uint32_t w, uint32_t h)
{
  struct window *window = data;
  NSDebugLog(@"[%d] layer_surface_configure", window->window_id);
  WaylandConfig *wlconfig = window->wlconfig;
  zwlr_layer_surface_v1_ack_configure(surface, serial);
  window->configured = YES;
  if (window->buffer_needs_attach)
    {
      [window->instance flushwindowrect:NSMakeRect(window->pos_x, window->pos_y,
						   window->width, window->height
						   ):window->window_id];
    }
}

static void
layer_surface_closed(void *data, struct zwlr_layer_surface_v1 *surface)
{
  struct window *window = data;
  WaylandConfig *wlconfig = window->wlconfig;
  NSDebugLog(@"layer_surface_closed %d", window->window_id);
  // zwlr_layer_surface_v1_destroy(surface);
  wl_surface_destroy(window->surface);
  window->surface = NULL;
  window->configured = NO;
  window->layer_surface = NULL;
}

const struct zwlr_layer_surface_v1_listener layer_surface_listener = {
  .configure = layer_surface_configure,
  .closed = layer_surface_closed,
};
