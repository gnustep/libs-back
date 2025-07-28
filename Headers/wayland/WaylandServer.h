/* <title>WaylandServer</title>

   <abstract>Backend server using Wayland.</abstract>

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author: Sergio L. Pascual <slp@sinrega.org>
   Rewrite: Riccardo Canalicchio <riccardo.canalicchio(at)gmail.com>
   Date: February 2016

   This file is part of the GNUstep Backend.

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

#ifndef _WaylandServer_h_INCLUDE
#define _WaylandServer_h_INCLUDE

#include "config.h"

#include <GNUstepGUI/GSDisplayServer.h>
#include <wayland-client.h>
#include <wayland-cursor.h>
#include <cairo/cairo.h>
#include <xkbcommon/xkbcommon.h>

#include "cairo/CairoSurface.h"

#include "wayland/xdg-shell-client-protocol.h"
#include "wayland/wlr-layer-shell-client-protocol.h"

struct pointer
{
  struct wl_pointer *wlpointer;
  float		     x;
  float		     y;
  uint32_t	     last_click_button;
  uint32_t	     last_click_time;
  float		     last_click_x;
  float		     last_click_y;

  uint32_t		       button;
  NSTimeInterval	   last_timestamp;
  enum wl_pointer_button_state button_state;

  uint32_t axis_source;

  uint32_t	 serial;
  struct window *focus;
  struct window *captured;

};

struct cursor
{
  struct wl_cursor *cursor;
  struct wl_surface *surface;
  struct wl_cursor_image *image;
  struct wl_buffer *buffer;
};

typedef struct _WaylandConfig
{
  struct wl_display	    *display;
  struct wl_registry	     *registry;
  struct wl_compositor       *compositor;
  struct wl_shell		  *shell;
  struct wl_shm		*shm;
  struct wl_seat		 *seat;
  struct wl_keyboard	     *keyboard;
  struct xdg_wm_base	     *wm_base;
  struct zwlr_layer_shell_v1 *layer_shell;
  int seat_version;

  struct wl_list output_list;
  int		 output_count;
  struct wl_list window_list;
  int		 window_count;
  int		 last_window_id;

// last event serial from pointer or keyboard
  uint32_t	 event_serial;


// cursor
  struct wl_cursor_theme *cursor_theme;
  struct cursor *cursor;
  struct wl_surface *cursor_surface;

// pointer
  struct pointer      pointer;
  float mouse_scroll_multiplier;

// keyboard
  struct xkb_context *xkb_context;
  struct
  {
    struct xkb_keymap *keymap;
    struct xkb_state  *state;
    xkb_mod_mask_t     control_mask;
    xkb_mod_mask_t     alt_mask;
    xkb_mod_mask_t     shift_mask;
  } xkb;
  int modifiers;

} WaylandConfig;

struct output
{
  WaylandConfig	*wlconfig;
  struct wl_output *output;
  uint32_t	    server_output_id;
  struct wl_list    link;
  int		    alloc_x;
  int		    alloc_y;
  int		    width;
  int		    height;
  int		    transform;
  int		    scale;
  char	       *make;
  char	       *model;

  void *user_data;
};

struct window
{
  WaylandConfig *wlconfig;
  id		 instance;
  int		 window_id;
  struct wl_list link;
  BOOL		 configured; // surface has been configured once
  BOOL buffer_needs_attach;  // there is a new buffer avaialble for the surface
  BOOL terminated;
  BOOL moving;
  BOOL resizing;
  BOOL ignoreMouse;

  float pos_x;
  float pos_y;
  float width;
  float height;
  float saved_pos_x;
  float saved_pos_y;
  int	is_out;
  int	level;

  struct wl_surface	    *surface;
  struct xdg_surface	     *xdg_surface;
  struct xdg_toplevel	      *toplevel;
  struct xdg_popup		   *popup;
  struct xdg_positioner	*positioner;
  struct zwlr_layer_surface_v1 *layer_surface;
  struct output		*output;
  CairoSurface		       *wcs;
};

struct window *get_window_with_id(WaylandConfig *wlconfig, int winid);

@interface WaylandServer : GSDisplayServer
{
  WaylandConfig *wlconfig;

  BOOL _mouseInitialized;
}
@end

@interface
WaylandServer (Cursor)
- (void)initializeMouseIfRequired;
@end

#endif /* _WaylandServer_h_INCLUDE */
