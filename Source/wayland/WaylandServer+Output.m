/* 
   WaylandServer - Output Handling

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
#include <Foundation/NSDebug.h>

static void
handle_geometry(void *data, struct wl_output *wl_output, int x, int y,
		int physical_width, int physical_height, int subpixel,
		const char *make, const char *model, int transform)
{
  struct output *output = data;

  output->alloc_x = x;
  output->alloc_y = y;
  output->transform = transform;

  if (output->make)
    free(output->make);
  output->make = strdup(make);

  if (output->model)
    free(output->model);
  output->model = strdup(model);

  NSDebugFLLog(@"WaylandOutput",
               @"handle_geometry: output @(%d,%d) physical=%dx%dmm "
               @"transform=%d make=%s model=%s",
               x, y, physical_width, physical_height, transform, make, model);
}

static void
handle_done(void *data, struct wl_output *wl_output)
{
  NSDebugFLLog(@"WaylandOutput", @"handle_done: output configuration committed");
}

static void
handle_scale(void *data, struct wl_output *wl_output, int32_t scale)
{
  struct output *output = data;

  output->scale = scale;
  NSDebugFLLog(@"WaylandOutput", @"handle_scale: scale=%d", scale);
}

static void
handle_mode(void *data, struct wl_output *wl_output, uint32_t flags, int width,
	    int height, int refresh)
{
  struct output *output = data;

  NSDebugFLLog(@"WaylandOutput", @"handle_mode: flags=0x%x size=%dx%d refresh=%dHz",
               flags, width, height, refresh / 1000);
  if (flags & WL_OUTPUT_MODE_CURRENT)
    {
      output->width = width;
      output->height = height /*- 30*/;
      NSDebugFLLog(@"WaylandOutput", @"handle_mode: current output size set to %dx%d",
                   width, height);

      //  XXX - Should we implement this?
      //        if (display->output_configure_handler)
      //            (*display->output_configure_handler)
      //            (output, display->user_data);
      //
    }
}

const struct wl_output_listener output_listener
  = {handle_geometry, handle_mode, handle_done, handle_scale};
