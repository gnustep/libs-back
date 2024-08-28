/* 
   WaylandServer - XdgShell Protocol Handling

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
#include <AppKit/NSGraphics.h>

static void
xdg_surface_on_configure(void *data, struct xdg_surface *xdg_surface,
                         uint32_t serial)
{
  struct window *window = data;

  NSDebugLog(@"xdg_surface_on_configure: win=%d", window->window_id);

  if (window->terminated == YES)
    {
      NSDebugLog(@"deleting window win=%d", window->window_id);
      free(window);
      return;
    }

  NSEvent  *ev = nil;
  NSWindow *nswindow = GSWindowWithNumber(window->window_id);

  // NSDebugLog(@"Acknowledging surface configure %p %d (window_id=%d)",
  // xdg_surface, serial, window->window_id);

  xdg_surface_ack_configure(xdg_surface, serial);
  window->configured = YES;

  if (window->buffer_needs_attach)
    {
      [window->instance flushwindowrect:NSMakeRect(window->pos_x, window->pos_y,
                                                   window->width, window->height)
                                      :window->window_id];
    }

  if (window->wlconfig->pointer.focus
      && window->wlconfig->pointer.focus->window_id == window->window_id)
    {
      ev = [NSEvent otherEventWithType:NSAppKitDefined
                              location:NSZeroPoint
                         modifierFlags:0
                             timestamp:0
                          windowNumber:(int) window->window_id
                               context:GSCurrentContext()
                               subtype:GSAppKitWindowFocusIn
                                 data1:0
                                 data2:0];

      [nswindow sendEvent:ev];
    }
}

static void
xdg_toplevel_configure(void *data, struct xdg_toplevel *xdg_toplevel,
                       int32_t width, int32_t height, struct wl_array *states)
{
  struct window *window = data;

  NSDebugLog(@"[%d] xdg_toplevel_configure %dx%d", window->window_id, width,
             height);

  // The compositor can send 0x0
  if (width == 0 || height == 0)
    {
      return;
    }
  if (window->width != width || window->height != height)
    {
      window->width = width;
      window->height = height;

      xdg_surface_set_window_geometry(window->xdg_surface, 0, 0, window->width,
                                      window->height);

      NSEvent *ev = [NSEvent otherEventWithType:NSAppKitDefined
                                       location:NSMakePoint(0.0, 0.0)
                                  modifierFlags:0
                                      timestamp:0
                                   windowNumber:window->window_id
                                        context:GSCurrentContext()
                                        subtype:GSAppKitWindowResized
                                          data1:window->width
                                          data2:window->height];
      [(GSWindowWithNumber(window->window_id)) sendEvent:ev];
    }
  NSDebugLog(@"[%d] notify resize from backend=%dx%d", window->window_id,
             width, height);
}

static void
xdg_toplevel_close_handler(void *data, struct xdg_toplevel *xdg_toplevel)
{
  NSDebugLog(@"xdg_toplevel_close_handler");
}

static void
xdg_popup_configure(void *data, struct xdg_popup *xdg_popup, int32_t x,
                    int32_t y, int32_t width, int32_t height)
{
  struct window *window = data;

  NSDebugLog(@"[%d] xdg_popup_configure [%d,%d %dx%d]", window->window_id, x, y,
             width, height);
}

static void
xdg_popup_done(void *data, struct xdg_popup *xdg_popup)
{
  struct window *window = data;
  window->terminated = YES;
  xdg_popup_destroy(xdg_popup);
  wl_surface_destroy(window->surface);
}

static void
wm_base_handle_ping(void *data, struct xdg_wm_base *xdg_wm_base,
                    uint32_t serial)
{
  NSDebugLog(@"wm_base_handle_ping");
  xdg_wm_base_pong(xdg_wm_base, serial);
}

const struct xdg_surface_listener xdg_surface_listener = {
  xdg_surface_on_configure,
};

const struct xdg_wm_base_listener wm_base_listener = {
  .ping = wm_base_handle_ping,
};

const struct xdg_popup_listener xdg_popup_listener = {
  .configure = xdg_popup_configure,
  .popup_done = xdg_popup_done,
};

const struct xdg_toplevel_listener xdg_toplevel_listener = {
  .configure = xdg_toplevel_configure,
  .close = xdg_toplevel_close_handler,
};