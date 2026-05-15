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
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSWindow.h>
#include <string.h>
#include <stdlib.h>


/* ── Helpers ─────────────────────────────────────────────────────────────── */

/* Compute the logical (AppKit) dimensions of an output, accounting for its
 * pixel scale factor and any rotation transform reported by the compositor.
 *
 * Physical mode width/height are in hardware pixels.  After dividing by the
 * scale factor we get logical pixels (points).  A 90° or 270° rotation also
 * swaps the two axes.                                                         */
static void
output_compute_effective_size(struct output *output)
{
  int ew = (output->scale > 0) ? output->width  / output->scale : output->width;
  int eh = (output->scale > 0) ? output->height / output->scale : output->height;

  switch (output->transform)
    {
      case WL_OUTPUT_TRANSFORM_90:
      case WL_OUTPUT_TRANSFORM_270:
      case WL_OUTPUT_TRANSFORM_FLIPPED_90:
      case WL_OUTPUT_TRANSFORM_FLIPPED_270:
        /* Swap: the output is rotated 90° or 270° relative to normal. */
        output->effective_width  = eh;
        output->effective_height = ew;
        break;
      default:
        output->effective_width  = ew;
        output->effective_height = eh;
        break;
    }
}

/* Post NSApplicationDidChangeScreenParametersNotification on the main thread
 * so NSScreen reloads its geometry.  Guard against early-init calls that
 * arrive before NSApp is running.                                             */
static void
notify_screen_parameters_changed(void)
{
  if (NSApp == nil)
    return;
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSApplicationDidChangeScreenParametersNotification
                  object: NSApp];
}

/* Clamp all regular (non-layer-shell) windows assigned to an output so that
 * they remain within the output's effective (logical) bounds after a
 * reconfigure.  We update our internal pos_x/y and ask AppKit to move the
 * window; the compositor will honour or adjust the request as it sees fit.   */
static void
reposition_windows_for_output(struct output *output)
{
  WaylandConfig *wlconfig = output->wlconfig;
  struct window *window;

  wl_list_for_each(window, &wlconfig->window_list, link)
  {
    if (window->output != output)
      continue;
    if (window->terminated || window->layer_surface)
      continue;

    int ew = output->effective_width;
    int eh = output->effective_height;
    BOOL moved = NO;

    /* Clamp position so at least the top-left corner is on-screen. */
    if (window->pos_x < 0)               { window->pos_x = 0;       moved = YES; }
    if (window->pos_y < 0)               { window->pos_y = 0;       moved = YES; }
    if (window->pos_x >= (float)ew)      { window->pos_x = MAX(0, ew - (int)window->width);  moved = YES; }
    if (window->pos_y >= (float)eh)      { window->pos_y = MAX(0, eh - (int)window->height); moved = YES; }

    if (moved)
      {
        NSDebugFLLog(@"WaylandOutput",
                     @"reposition_windows_for_output: clamped window %d "
                     @"to (%g,%g) within %dx%d output",
                     window->window_id, window->pos_x, window->pos_y, ew, eh);

        /* Notify AppKit of the new position in GNUstep screen coordinates
         * (Y-flipped: bottom-left origin, as in AppKit).                  */
        NSWindow *nswindow = GSWindowWithNumber(window->window_id);
        if (nswindow)
          {
            float ns_y = eh - window->pos_y - window->height;
            [nswindow setFrameOrigin: NSMakePoint(window->pos_x, ns_y)];
          }
      }
  }
}


/* ── wl_output event handlers ─────────────────────────────────────────────── */

static void
handle_geometry(void *data, struct wl_output *wl_output, int x, int y,
		int physical_width, int physical_height, int subpixel,
		const char *make, const char *model, int transform)
{
  struct output *output = data;

  output->alloc_x   = x;
  output->alloc_y   = y;
  output->transform = transform;

  if (output->make)  free(output->make);
  if (output->model) free(output->model);
  output->make  = strdup(make  ? make  : "");
  output->model = strdup(model ? model : "");

  NSDebugFLLog(@"WaylandOutput",
               @"handle_geometry: output %u @(%d,%d) physical=%dx%dmm "
               @"transform=%d make=%s model=%s",
               output->server_output_id, x, y,
               physical_width, physical_height, transform, make, model);
}

static void
handle_mode(void *data, struct wl_output *wl_output, uint32_t flags,
	    int width, int height, int refresh)
{
  struct output *output = data;

  NSDebugFLLog(@"WaylandOutput",
               @"handle_mode: output %u flags=0x%x size=%dx%d refresh=%dHz",
               output->server_output_id, flags, width, height, refresh / 1000);

  if (flags & WL_OUTPUT_MODE_CURRENT)
    {
      output->width  = width;
      output->height = height;
      NSDebugFLLog(@"WaylandOutput",
                   @"handle_mode: output %u current mode → %dx%d physical",
                   output->server_output_id, width, height);
    }
}

static void
handle_scale(void *data, struct wl_output *wl_output, int32_t scale)
{
  struct output *output = data;
  output->scale = scale;
  NSDebugFLLog(@"WaylandOutput", @"handle_scale: output %u scale=%d",
               output->server_output_id, scale);
}

/* handle_done is called once all output properties for a configuration batch
 * have been sent.  It is the right place to:
 *   1. Compute the effective (logical) output size.
 *   2. Reposition any windows that fell outside the new bounds.
 *   3. Notify AppKit so NSScreen reloads its geometry.                        */
static void
handle_done(void *data, struct wl_output *wl_output)
{
  struct output *output = data;

  int old_ew = output->effective_width;
  int old_eh = output->effective_height;

  output_compute_effective_size(output);

  NSDebugFLLog(@"WaylandOutput",
               @"handle_done: output %u '%s' logical=%dx%d (phys=%dx%d scale=%d "
               @"transform=%d) alloc=(%d,%d)",
               output->server_output_id,
               output->name ? output->name : "unknown",
               output->effective_width, output->effective_height,
               output->width, output->height, output->scale, output->transform,
               output->alloc_x, output->alloc_y);

  BOOL first_configure = !output->configured;
  output->configured = YES;

  /* Only reposition and notify if something actually changed (or first time). */
  if (!first_configure
      && output->effective_width  == old_ew
      && output->effective_height == old_eh)
    return;

  reposition_windows_for_output(output);
  notify_screen_parameters_changed();
}

/* wl_output v4: human-readable connector name (e.g. "HDMI-A-1", "eDP-1"). */
static void
handle_name(void *data, struct wl_output *wl_output, const char *name)
{
  struct output *output = data;
  if (output->name) free(output->name);
  output->name = strdup(name ? name : "");
  NSDebugFLLog(@"WaylandOutput", @"handle_name: output %u name='%s'",
               output->server_output_id, output->name);
}

/* wl_output v4: human-readable description (e.g. "Samsung 27\" monitor"). */
static void
handle_description(void *data, struct wl_output *wl_output,
                   const char *description)
{
  struct output *output = data;
  if (output->description) free(output->description);
  output->description = strdup(description ? description : "");
  NSDebugFLLog(@"WaylandOutput", @"handle_description: output %u desc='%s'",
               output->server_output_id, output->description);
}

const struct wl_output_listener output_listener = {
  handle_geometry,
  handle_mode,
  handle_done,
  handle_scale,
  handle_name,
  handle_description,
};
