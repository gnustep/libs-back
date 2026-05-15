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
#include "wayland/xdg-decoration-unstable-v1-client-protocol.h"
#include "wayland/text-input-unstable-v3-client-protocol.h"

/* User data stored on every wl_surface owned by GNUstep.
 * For main window surfaces offset_x/y are 0.0.
 * For GL subsurfaces they hold the subsurface position within the parent window
 * (Wayland Y-down coordinates), so pointer event coordinates can be translated
 * to parent-window space.  Each WaylandGLContext malloc's its own binding so
 * multiple GL views in the same window each have independent offsets. */
struct wl_surface_binding
{
  struct window *window;
  float          offset_x;
  float          offset_y;
};

/* Retrieve the window from any GNUstep-owned wl_surface. */
static inline struct window *
surface_get_window(struct wl_surface *surface)
{
  struct wl_surface_binding *b
    = (struct wl_surface_binding *)wl_surface_get_user_data(surface);
  return b ? b->window : NULL;
}

/* Retrieve the subsurface-to-window offset; returns (0,0) for main surfaces. */
static inline void
surface_get_offset(struct wl_surface *surface, float *ox, float *oy)
{
  struct wl_surface_binding *b
    = (struct wl_surface_binding *)wl_surface_get_user_data(surface);
  *ox = b ? b->offset_x : 0.0f;
  *oy = b ? b->offset_y : 0.0f;
}

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

  uint32_t	     serial;
  struct window     *focus;
  struct window     *captured;
  /* Subsurface-to-window offset captured at pointer-enter time.
   * Zero for main window surfaces; non-zero when the pointer entered a GL
   * subsurface.  Applied to sx/sy in motion/button handlers so all AppKit
   * coordinates are expressed in parent-window space. */
  float              focus_offset_x;
  float              focus_offset_y;

  /* Per-frame axis accumulation (cleared after each wl_pointer.frame event).
   * Populated by axis/axis_discrete; dispatched as one NSScrollWheel in frame. */
  BOOL     frame_has_axis;
  float    frame_deltaX;
  float    frame_deltaY;
  int      frame_discrete_x;   /* discrete scroll steps this frame, horizontal */
  int      frame_discrete_y;   /* discrete scroll steps this frame, vertical   */
  uint32_t frame_time;         /* timestamp of the last axis event in this frame */

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
  struct wl_display                 *display;
  struct wl_registry                *registry;
  struct wl_compositor              *compositor;
  struct wl_shell                   *shell;
  struct wl_shm	                    *shm;
  struct wl_seat                    *seat;
  struct wl_keyboard                *keyboard;
  struct xdg_wm_base                *wm_base;
  struct zwlr_layer_shell_v1        *layer_shell;
  struct wl_subcompositor           *subcompositor;
  struct zxdg_decoration_manager_v1 *decoration_manager;
  int seat_version;

  struct wl_list output_list;
  int		 output_count;
  struct wl_list window_list;
  int		 window_count;
  int		 last_window_id;

// last event serial from pointer or keyboard
  uint32_t	 event_serial;

// cursor global position tracking (output-relative, Wayland Y-down)
  BOOL   cursor_global_valid;
  float  cursor_global_x;
  float  cursor_global_y;


// cursor
  struct wl_cursor_theme *cursor_theme;
  struct cursor *cursor;
  struct wl_surface *cursor_surface;

// pointer
  struct pointer      pointer;
  float mouse_scroll_multiplier;

// keyboard focus (set by keyboard_handle_enter/leave)
  struct window      *keyboard_focus;

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

  /* zwp_text_input_v3 — input method / preedit support */
  struct zwp_text_input_manager_v3 *text_input_manager;
  struct zwp_text_input_v3         *text_input;
  BOOL                              text_input_active;  /* enabled for current surface */

  /* Preedit geometry (set by AppKit via WaylandInputServer setters) */
  NSPoint ime_preedit_spot;    /* cursor position for IM popup, in screen coords */
  NSRect  ime_preedit_rect;    /* preedit bounding rect                           */

  /* Pending IM events, applied together in the done callback */
  char   *ime_pending_preedit;       /* NULL when no active preedit */
  int32_t ime_preedit_cursor_begin;
  int32_t ime_preedit_cursor_end;
  char   *ime_pending_commit;        /* NULL when no pending commit */
  uint32_t ime_serial;               /* most recent done serial     */

  /* wl_data_device — selection and drag-and-drop */
  struct wl_data_device_manager *data_device_manager;
  struct wl_data_device         *data_device;
  int                            data_device_manager_version;

  /* DnD outbound: we are the drag source */
  struct wl_data_source *dnd_source;    /* NULL when no outbound drag is active */

  /* DnD inbound: pending/current offer from an external app */
  struct wl_data_offer  *dnd_offer;
  char                 **dnd_offer_mimes;     /* strdup'd, NULL when empty */
  int                    dnd_offer_mime_count;
  int                    dnd_offer_mime_cap;
  uint32_t               dnd_offer_source_actions;
  uint32_t               dnd_current_action;
  float                  dnd_x;               /* surface-local cursor pos */
  float                  dnd_y;
  struct window         *dnd_target;          /* GNUstep window under cursor */
  BOOL                   dnd_incoming;        /* YES between enter and leave/drop */

} WaylandConfig;

struct output
{
  WaylandConfig	*wlconfig;
  struct wl_output *output;
  uint32_t	    server_output_id;
  struct wl_list    link;
  int		    alloc_x;        /* compositor layout origin X (physical pixels) */
  int		    alloc_y;        /* compositor layout origin Y (physical pixels) */
  int		    width;          /* current mode width  (physical pixels)        */
  int		    height;         /* current mode height (physical pixels)        */
  int		    effective_width;  /* logical width  = width  / scale, swap for rot */
  int		    effective_height; /* logical height = height / scale, swap for rot */
  int		    transform;
  int		    scale;
  char	       *make;
  char	       *model;
  char	       *name;           /* human-readable connector name (wl_output v4) */
  char	       *description;    /* human-readable description    (wl_output v4) */
  BOOL          configured;     /* YES after the first handle_done has fired    */

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
  BOOL usesOpenGL;
  BOOL global_pos_known;   // saved_pos_x/y hold a reliable output-relative origin

  /* Binding embedded in the struct for this window's own wl_surface.
   * Set once at surface-creation time; offset_x/y are always 0,0. */
  struct wl_surface_binding surface_binding;

  float pos_x;
  float pos_y;
  float width;
  float height;
  float saved_pos_x;
  float saved_pos_y;
  int	is_out;
  int	level;

  int   parent_id;

  struct wl_surface            *surface;
  struct xdg_surface           *xdg_surface;
  struct xdg_toplevel          *toplevel;
  struct xdg_popup             *popup;
  struct xdg_positioner	       *positioner;
  struct zwlr_layer_surface_v1 *layer_surface;
  struct zxdg_toplevel_decoration_v1    *decoration;
  struct output		       *output;
  CairoSurface		       *wcs;
};

/* get_window_with_id returns the known window with the passed ID, or NULL.
 *
 * NULL is returned when the passed window is not known; for example, the
 * window has been '->terminated' and was removed from the window_list already,
 * but something has referred to its ID. It is the responsibility of the caller
 * to handle the case where NULL is used.
 */
struct window *get_window_with_id(WaylandConfig *wlconfig, int winid);
float WaylandToNS(struct window *window, float wl_y);

@interface WaylandServer : GSDisplayServer
{
  WaylandConfig *wlconfig;

  BOOL _mouseInitialized;
  id   inputServer;
}
@end

@interface WaylandServer (Cursor)
- (void) initializeMouseIfRequired;
@end

@interface WaylandServer (DragAndDrop)
- (id <NSDraggingInfo>) dragInfo;
- (BOOL) addDragTypes: (NSArray *)types toWindow: (NSWindow *)win;
- (BOOL) removeDragTypes: (NSArray *)types fromWindow: (NSWindow *)win;
@end

@interface WaylandServer (InputMethod)
- (NSString *) inputMethodStyle;
- (NSString *) fontSize: (int *)size;
- (BOOL) clientWindowRect: (NSRect *)rect;
- (BOOL) statusArea: (NSRect *)rect;
- (BOOL) preeditArea: (NSRect *)rect;
- (BOOL) preeditSpot: (NSPoint *)p;
- (BOOL) setStatusArea: (NSRect *)rect;
- (BOOL) setPreeditArea: (NSRect *)rect;
- (BOOL) setPreeditSpot: (NSPoint *)p;
@end

#endif /* _WaylandServer_h_INCLUDE */
