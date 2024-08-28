/*
   WaylandServer - Cursor Handling

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
#include "cairo/WaylandCairoShmSurface.h"
#import <AppKit/NSEvent.h>
#import <AppKit/NSView.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSCursor.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSBitmapImageRep.h>
#import <GNUstepGUI/GSWindowDecorationView.h>
#import <GNUstepGUI/GSTheme.h>
#include <linux/input.h>
#include "wayland-cursor.h"

extern void wl_cursor_destroy(struct wl_cursor *cursor);

// XXX should this be configurable by the user?
#define DOUBLECLICK_DELAY 300
#define DOUBLECLICK_MOVE_THREASHOLD 3

static void
pointer_handle_enter(void *data, struct wl_pointer *pointer, uint32_t serial,
		     struct wl_surface *surface, wl_fixed_t sx_w,
		     wl_fixed_t sy_w)
{
  WaylandConfig *wlconfig = data;

  struct window *window = wl_surface_get_user_data(surface);

  if (window->ignoreMouse)
    {
      return;
    }

  wlconfig->pointer.focus = window;

  if (wlconfig->pointer.captured)
    {
      return;
    }

  [(WaylandServer *)GSCurrentServer() initializeMouseIfRequired];


  NSDebugLog(@"[%d] pointer_handle_enter",window->window_id);

  float		 sx = wl_fixed_to_double(sx_w);
  float		 sy = wl_fixed_to_double(sy_w);


  if (window && wlconfig->pointer.serial)
    {
      NSEvent	      *event;
      NSPoint		 eventLocation;
      NSGraphicsContext *gcontext;

      float		 deltaX = sx - wlconfig->pointer.x;
      float		 deltaY = sy - wlconfig->pointer.y;

      gcontext = GSCurrentContext();
      eventLocation = NSMakePoint(sx, window->height - sy);

      event = [NSEvent mouseEventWithType:NSMouseEntered
				 location:eventLocation
			    modifierFlags:wlconfig->modifiers
				timestamp:wlconfig->pointer.last_timestamp
			     windowNumber:window->window_id
				  context:gcontext
			      eventNumber:serial
			       clickCount:0
				 pressure:0.0
			     buttonNumber:0
				   deltaX:deltaX
				   deltaY:deltaY
				   deltaZ:0.];

      [GSCurrentServer() postEvent:event atStart:NO];
    }

  wlconfig->pointer.x = sx;
  wlconfig->pointer.y = sy;
  wlconfig->pointer.serial = serial;
  wlconfig->event_serial = serial;
}

static void
pointer_handle_leave(void *data, struct wl_pointer *pointer, uint32_t serial,
		     struct wl_surface *surface)
{
  WaylandConfig *wlconfig = data;

  struct window *window = wl_surface_get_user_data(surface);

  if (window->ignoreMouse)
    {
      return;
    }

  if (wlconfig->pointer.focus == NULL)
    {
      return;
    }

  [(WaylandServer *)GSCurrentServer() initializeMouseIfRequired];

  if (wlconfig->pointer.focus->window_id == window->window_id
      && wlconfig->pointer.serial)
    {
      if (wlconfig->pointer.captured == NULL)
        {
          window = wlconfig->pointer.focus;
          NSEvent		  *event;
          NSPoint	     eventLocation;
          NSGraphicsContext *gcontext;

          gcontext = GSCurrentContext();

          eventLocation = NSMakePoint(wlconfig->pointer.x, wlconfig->pointer.y);
          event = [NSEvent mouseEventWithType:NSMouseExited
                          location:eventLocation
                      modifierFlags:0
                          timestamp:wlconfig->pointer.last_timestamp
                      windowNumber:window->window_id
                          context:gcontext
                      eventNumber:serial
                      clickCount:0
                          pressure:0.0
                      buttonNumber:0
                          deltaX:0
                          deltaY:0
                          deltaZ:0.];

          [GSCurrentServer() postEvent:event atStart:NO];
        }
      wlconfig->pointer.focus = NULL;
      wlconfig->pointer.serial = serial;
      wlconfig->event_serial = serial;
    }
}

// triggered when the cursor is over a surface
static void
pointer_handle_motion(void *data, struct wl_pointer *pointer, uint32_t time,
		      wl_fixed_t sx_w, wl_fixed_t sy_w)
{
  WaylandConfig *wlconfig = data;
  struct window *focused_window = wlconfig->pointer.focus;

  if (wlconfig->pointer.captured)
    {
      focused_window = wlconfig->pointer.captured;
    }
  if (focused_window == NULL || focused_window->ignoreMouse)
    {
      return;
    }
  float sx = wl_fixed_to_double(sx_w);
  float sy = wl_fixed_to_double(sy_w);

  wlconfig->pointer.last_timestamp = (NSTimeInterval) time / 1000.0;


  [(WaylandServer *)GSCurrentServer() initializeMouseIfRequired];

  if (focused_window && wlconfig->pointer.serial)
    {
      NSEvent	      *event;
      NSEventType	 eventType;
      NSPoint		 eventLocation;
      NSGraphicsContext *gcontext;
      unsigned int	 eventFlags;

      float		 deltaX = sx - wlconfig->pointer.x;
      float		 deltaY = sy - wlconfig->pointer.y;

      gcontext = GSCurrentContext();
      eventLocation = NSMakePoint(sx, focused_window->height - sy);

      eventFlags = wlconfig->modifiers;

      eventType = NSMouseMoved;

      if (wlconfig->pointer.button_state == WL_POINTER_BUTTON_STATE_PRESSED)
        {

          switch (wlconfig->pointer.button)
            {
              case BTN_LEFT:
                eventType = NSLeftMouseDragged;
                break;
              case BTN_RIGHT:
                eventType = NSRightMouseDragged;
                break;
              case BTN_MIDDLE:
                eventType = NSOtherMouseDragged;
                break;
            }
        }

      event = [NSEvent mouseEventWithType:eventType
				 location:eventLocation
			    modifierFlags:eventFlags
				timestamp:wlconfig->pointer.last_timestamp
			     windowNumber:(int) focused_window->window_id
				  context:gcontext
			      eventNumber:time
			       clickCount:0
				 pressure:1.0 // XXX should this be 0 when no button is pressed?
			     buttonNumber:wlconfig->pointer.button
				   deltaX:deltaX
				   deltaY:deltaY
				   deltaZ:0.];

      [GSCurrentServer() postEvent:event atStart:NO];
    }

  wlconfig->pointer.x = sx;
  wlconfig->pointer.y = sy;
}

static void
pointer_handle_button(void *data, struct wl_pointer *pointer, uint32_t serial,
		      uint32_t time, uint32_t button, uint32_t state_w)
{
  WaylandConfig		*wlconfig = data;
  NSEvent			  *event;
  NSEventType		       eventType;
  NSPoint		       eventLocation;
  NSGraphicsContext	    *gcontext;
  unsigned int		       eventFlags;
  float			       deltaX = 0.0;
  float			       deltaY = 0.0;
  int			       clickCount = 1;
  int			       tick;
  int			       buttonNumber;
  enum wl_pointer_button_state state = state_w;

  struct window		*window = wlconfig->pointer.focus;

  if (wlconfig->pointer.captured)
    {
      window = wlconfig->pointer.captured;
    }

  if (window == NULL || window->ignoreMouse)
    {
      return;
    }
  [(WaylandServer *)GSCurrentServer() initializeMouseIfRequired];

  gcontext = GSCurrentContext();
  eventLocation
    = NSMakePoint(wlconfig->pointer.x, window->height - wlconfig->pointer.y);
  eventFlags = wlconfig->modifiers;
  NSTimeInterval timestamp = (NSTimeInterval) time / 1000.0;

  if (state == WL_POINTER_BUTTON_STATE_PRESSED)
    {
      wlconfig->pointer.button = button;
      if (window->toplevel)
        {
          // if the window is a toplevel we check if the event is for resizing or
          // moving the window these actions are delegated to the compositor and
          // therefore we skip forwarding the events to the NSWindow / NSView

          NSWindow *nswindow = GSWindowWithNumber(window->window_id);
          if (nswindow != nil)
            {
              GSStandardWindowDecorationView * wd = [nswindow _windowView];

              if ([wd pointInTitleBarRect:eventLocation])
                {
                  xdg_toplevel_move(window->toplevel, wlconfig->seat, serial);
                  window->moving = YES;
                  return;
                }
              if ([wd pointInResizeBarRect:eventLocation])
                {
                  GSResizeEdgeMode mode = [wd resizeModeForPoint:eventLocation];

                  uint32_t edges = XDG_TOPLEVEL_RESIZE_EDGE_BOTTOM_RIGHT;

                  if (mode == GSResizeEdgeBottomLeftMode)
                    {
                      edges = XDG_TOPLEVEL_RESIZE_EDGE_BOTTOM_LEFT;
                    }
                  else if (mode == GSResizeEdgeBottomRightMode)
                    {
                      edges = XDG_TOPLEVEL_RESIZE_EDGE_BOTTOM_RIGHT;
                    }
                  else if (mode == GSResizeEdgeBottomMode)
                    {
                      edges = XDG_TOPLEVEL_RESIZE_EDGE_BOTTOM;
                    }

                    xdg_toplevel_resize(window->toplevel, wlconfig->seat, serial,
                                edges);
                    window->resizing = YES;
                    return;
                }
            } // endif nswindow != nil
        } // endif window->toplevel

      if (button == wlconfig->pointer.last_click_button
	  && time - wlconfig->pointer.last_click_time < DOUBLECLICK_DELAY
	  && fabsf(wlconfig->pointer.x - wlconfig->pointer.last_click_x)
	       < DOUBLECLICK_MOVE_THREASHOLD
	  && fabsf(wlconfig->pointer.y - wlconfig->pointer.last_click_y)
	       < DOUBLECLICK_MOVE_THREASHOLD)
	{
          wlconfig->pointer.last_click_time = 0;
          clickCount++;
        }
      else
        {
          wlconfig->pointer.last_click_button = button;
          wlconfig->pointer.last_click_time = time;
          wlconfig->pointer.last_click_x = wlconfig->pointer.x;
          wlconfig->pointer.last_click_y = wlconfig->pointer.y;
        }
      wlconfig->pointer.serial = serial;
      switch (button)
        {
          case BTN_LEFT:
            eventType = NSLeftMouseDown;
            break;
          case BTN_RIGHT:
            eventType = NSRightMouseDown;
            break;
          case BTN_MIDDLE:
            eventType = NSOtherMouseDown;
            break;
          // TODO: handle BTN_SIDE, BTN_EXTRA, BTN_FORWARD, BTN_BACK and other
          // constants in libinput.
          // We may just want to send NSOtherMouseDown and populate buttonNumber
          // with the libinput constant?
        }
    }
  else if (state == WL_POINTER_BUTTON_STATE_RELEASED)
    {
      wlconfig->pointer.serial = 0;
      wlconfig->pointer.button = 0;
      if (window->moving)
        {
          window->moving = NO;
          return;
        }
      if (window->resizing)
        {
          window->resizing = NO;
          return;
        }
      switch (button)
        {
          case BTN_LEFT:
            eventType = NSLeftMouseUp;
            break;
          case BTN_RIGHT:
            eventType = NSRightMouseUp;
            break;
          case BTN_MIDDLE:
            eventType = NSOtherMouseUp;
            break;
        }
    }
  else
    {
      return;
    }
  /* FIXME: unlike in _motion and _axis handlers, the argument used in _button
     is the "serial" of the event, not passed and unavailable in _motion and
     _axis handlers. Is it allowed to pass "serial" as the eventNumber: in
     _button handler, but "time" as the eventNumber: in the _motion and _axis
     handlers? */
  tick = serial;

  /* FIXME: X11 backend uses the XGetPointerMapping()-returned values from
     its map_return argument as constants for buttonNumber. As the variant
     with buttonNumber: seems to be a GNUstep extension, and the value
     internal, it might be ok to just provide libinput constant as we're doing
     here. If this is truly correct, please update this comment to document
     the correctness of doing so. */
  buttonNumber = button;

  event = [NSEvent mouseEventWithType:eventType
			     location:eventLocation
			modifierFlags:eventFlags
			    timestamp:timestamp
			 windowNumber:(int) window->window_id
			      context:gcontext
			  eventNumber:tick
			   clickCount:clickCount
			     pressure:1.0
			 buttonNumber:buttonNumber
			       deltaX:deltaX /* FIXME unused */
			       deltaY:deltaY /* FIXME unused */
			       deltaZ:0.];

  [GSCurrentServer() postEvent:event atStart:NO];

  // store button state for mouse move handlers
  wlconfig->pointer.button_state = state;
  wlconfig->pointer.last_timestamp = timestamp;
  wlconfig->pointer.serial = serial;
  wlconfig->event_serial = serial;

}

// Discrete step information for scroll and other axes.
static void
pointer_handle_frame(void *data, struct wl_pointer *pointer)
{}

// Source information for scroll and other axes.
static void
pointer_handle_axis_source(void *data, struct wl_pointer *pointer,
			   uint32_t axis_source)
{
  WaylandConfig *wlconfig = data;
  wlconfig->pointer.axis_source = axis_source;
}

// Stop notification for scroll and other axes.
static void
pointer_handle_axis_stop(void *data, struct wl_pointer *pointer, uint32_t time,
			 uint32_t axis)
{}

// Discrete step information for scroll and other axes.
static void
pointer_handle_axis_discrete(void *data, struct wl_pointer *pointer,
			     uint32_t axis, int discrete)
{}

// Scroll and other axis notifications.
static void
pointer_handle_axis(void *data, struct wl_pointer *pointer, uint32_t time,
		    uint32_t axis, wl_fixed_t value)
{
  WaylandConfig	*wlconfig = data;
  NSEvent		  *event;
  NSEventType	     eventType;
  NSPoint	     eventLocation;
  NSGraphicsContext *gcontext;
  unsigned int	     eventFlags;
  float		     deltaX = 0.0;
  float		     deltaY = 0.0;
  int		     clickCount = 1;
  int		     buttonNumber;

  struct window *window = wlconfig->pointer.focus;
  if (window->ignoreMouse)
    {
      return;
    }

  [(WaylandServer *)GSCurrentServer() initializeMouseIfRequired];

  gcontext = GSCurrentContext();
  eventLocation
    = NSMakePoint(wlconfig->pointer.x, window->height - wlconfig->pointer.y);
  eventFlags = wlconfig->modifiers;

  if (wlconfig->pointer.axis_source != WL_POINTER_AXIS_SOURCE_WHEEL)
  {
    //axis_source == WL POINTER AXIS SOURCE FINGER
    //axis_source == WL POINTER AXIS SOURCE CONTINUOUS
    // XXX the scroll is from trackpad we should calculate
    // the momentumPhase
    NSDebugLog(@"touch scroll");
  }

  //float mouse_scroll_multiplier = wlconfig->mouse_scroll_multiplier;
  /* For smooth-scroll events, we're not doing any cross-event or delta
     calculations, as is done in button event handling. */
  switch (axis)
    {
    case WL_POINTER_AXIS_VERTICAL_SCROLL:
      eventType = NSScrollWheel;
      deltaY = wl_fixed_to_double(value) * wlconfig->mouse_scroll_multiplier;
    case WL_POINTER_AXIS_HORIZONTAL_SCROLL:
      eventType = NSScrollWheel;
      deltaX = wl_fixed_to_double(value) * wlconfig->mouse_scroll_multiplier;
    }

  /* FIXME: X11 backend uses the XGetPointerMapping()-returned values from
     its map_return argument as constants for buttonNumber. As the variant
     with buttonNumber: seems to be a GNUstep extension, and the value
     internal, it might be ok to just not provide any value here.
     If this is truly correct, please update this comment to document
     the correctness of doing so. */
  buttonNumber = 0;

  event = [NSEvent mouseEventWithType:eventType
			     location:eventLocation
			modifierFlags:eventFlags
			    timestamp:(NSTimeInterval) time / 1000.0
			 windowNumber:(int) window->window_id
			      context:gcontext
			  eventNumber:time
			   clickCount:clickCount
			     pressure:1.0
			 buttonNumber:buttonNumber
			       deltaX:deltaX
			       deltaY:deltaY
			       deltaZ:0.];

  [GSCurrentServer() postEvent:event atStart:NO];
}

// the Seat category uses this listener
const struct wl_pointer_listener pointer_listener
  = {pointer_handle_enter,	  pointer_handle_leave,
     pointer_handle_motion,	  pointer_handle_button,
     pointer_handle_axis,	  pointer_handle_frame,
     pointer_handle_axis_source,  pointer_handle_axis_stop,
     pointer_handle_axis_discrete};

@implementation
WaylandServer (Cursor)
- (NSPoint)mouselocation
{
  int aScreen = -1;

  if (wl_list_length(&wlconfig->output_list) == 0)
    {
      return NSZeroPoint;
    }
  struct output *output = (struct output *)wlconfig->output_list.next;
  aScreen = output->server_output_id;

  if (aScreen < 0)
    {
      // No outputs in the wl_list.
      return NSZeroPoint;
    }

  return [self mouseLocationOnScreen:aScreen window:NULL];
}

- (NSPoint)mouseLocationOnScreen:(int)aScreen window:(int *)win
{
  struct window *window = wlconfig->pointer.focus;
  struct output *output;
  float		 x;
  float		 y;

  x = wlconfig->pointer.x;
  y = wlconfig->pointer.y;

  if (window)
    {
      x += window->pos_x;
      y += window->pos_y;
      if (win)
        {
          *win = window->window_id;
        }
    }

  wl_list_for_each(output, &wlconfig->output_list, link)
  {
    if (output->server_output_id == aScreen)
      {
        y = output->height - y;
        break;
      }
  }

  return NSMakePoint(x, y);
}

- (BOOL)capturemouse:(int)win
{
  struct window *window = get_window_with_id(wlconfig, win);
  wlconfig->pointer.captured = window;
  return YES;
}

- (void)releasemouse
{
  wlconfig->pointer.captured = NULL;
}

- (void)setMouseLocation:(NSPoint)mouseLocation onScreen:(int)aScreen
{
  NSDebugLog(@"setMouseLocation: not supported");
}

- (void)hidecursor
{
  // to hide the cursor we set a NULL surface
  wl_pointer_set_cursor(wlconfig->pointer.wlpointer, wlconfig->pointer.serial,
			NULL, 0, 0);
}

- (void)showcursor
{
  // restore  the previous surface
  wl_pointer_set_cursor(wlconfig->pointer.wlpointer, wlconfig->pointer.serial,
			wlconfig->cursor->surface,
			wlconfig->cursor->image->hotspot_x,
			wlconfig->cursor->image->hotspot_y);
}

- (void)standardcursor:(int)style :(void **)cid
{

  [self initializeMouseIfRequired];

  char * cursor_name = "";

  switch (style)
    {
    case GSArrowCursor:
      cursor_name = "left_ptr";
      break;
    case GSIBeamCursor:
      cursor_name = "xterm";
      break;
    case GSDragLinkCursor:
      cursor_name = "dnd-link";
      break;
    case GSOperationNotAllowedCursor:
      cursor_name = "X_cursor";
      break;
    case GSDragCopyCursor:
      cursor_name = "dnd-copy";
      break;
    case GSPointingHandCursor:
      cursor_name = "hand";
      break;
    case GSResizeLeftCursor:
      cursor_name = "left_side";
      break;
    case GSResizeRightCursor:
      cursor_name = "right_side";
      break;
    case GSResizeLeftRightCursor:
      cursor_name = "sb_h_double_arrow";
      break;
    case GSCrosshairCursor:
      cursor_name = "crosshair";
      break;
    case GSResizeUpCursor:
      cursor_name = "top_side";
      break;
    case GSResizeDownCursor:
      cursor_name = "bottom_side";
      break;
    case GSResizeUpDownCursor:
      cursor_name = "sb_v_double_arrow";
      break;
    case GSDisappearingItemCursor:
      cursor_name = "pirate";
      break;
    case GSContextualMenuCursor:
      break;
    case GSGreenArrowCursor:
      break;
    case GSClosedHandCursor:
      break;
    case GSOpenHandCursor:
      break;
    }
  if (strlen(cursor_name) != 0)
    {
      NSDebugLog(@"load cursor from theme for style %d: %s", style,
		 cursor_name);
      struct cursor *wayland_cursor = malloc(sizeof(struct cursor));

      wayland_cursor->cursor
	= wl_cursor_theme_get_cursor(wlconfig->cursor_theme, cursor_name);

      wayland_cursor->image = wayland_cursor->cursor->images[0];
      wayland_cursor->buffer
	= wl_cursor_image_get_buffer(wayland_cursor->image);

      *cid = wayland_cursor;
    }
  else
    {
      NSDebugLog(@"unable to load cursor from theme for style %d", style);
    }
}

- (void)imagecursor:(NSPoint)hotp :(NSImage *)image :(void **)cid
{
  NSBitmapImageRep* raw_img = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
  unsigned char *data = [raw_img bitmapData];
  NSSize imageSize = NSMakeSize(raw_img.pixelsWide, raw_img.pixelsHigh);
  int width = imageSize.width;
  int height = imageSize.height;

  struct pool_buffer *pbuffer
    = createShmBuffer(width, height, wlconfig->shm);

  // TODO should check if the bitmaprep format is compatible
  memcpy(pbuffer->data, data, [raw_img bytesPerPlane]);

  struct cursor * wayland_cursor = malloc(sizeof(struct cursor));

  struct wl_cursor * cursor = malloc(sizeof(struct wl_cursor));
  cursor->image_count = 1;
  cursor->name = "custom";
  struct wl_cursor_image * cursor_image = malloc(sizeof(struct wl_cursor_image));
  cursor->images = malloc(sizeof *cursor->images);
  cursor->images[0] = cursor_image;
  cursor_image->width = width;
  cursor_image->height = height;
  cursor_image->hotspot_x = hotp.x;
  cursor_image->hotspot_y = hotp.y;

  wayland_cursor->cursor = cursor;
  wayland_cursor->image = cursor_image;
  wayland_cursor->buffer = pbuffer->buffer;
  *cid = wayland_cursor;
}

- (void)setcursorcolor:(NSColor *)fg :(NSColor *)bg :(void *)cid
{
  NSLog(@"Call to obsolete method -setcursorcolor:::");
  [self recolorcursor:fg:bg:cid];
  [self setcursor:cid];
}

- (void) recolorcursor:(NSColor *)fg :(NSColor *)bg :(void*) cid
{
  // TODO recolorcursor
  NSDebugLog(@"recolorcursor");
}

- (void)setcursor:(void *)cid
{
  struct cursor *wayland_cursor = cid;
  if (wayland_cursor == NULL)
    {
      return;
    }
  if (wayland_cursor->cursor == NULL)
    {
      return;
    }
  if (wayland_cursor->image == NULL)
    {
      return;
    }
  if (wayland_cursor->buffer == NULL)
    {
      return;
    }

  if (wayland_cursor->surface)
    {
      wl_surface_destroy(wayland_cursor->surface);
    }
  wl_pointer_set_cursor(wlconfig->pointer.wlpointer, wlconfig->event_serial,
            wlconfig->cursor_surface,
            wayland_cursor->image->hotspot_x,
            wayland_cursor->image->hotspot_y);

  wl_surface_attach(wlconfig->cursor_surface, wayland_cursor->buffer, 0, 0);
  wl_surface_damage(wlconfig->cursor_surface, 0, 0,
                  wayland_cursor->image->width, wayland_cursor->image->height);
  wl_surface_commit(wlconfig->cursor_surface);


  wlconfig->cursor = wayland_cursor;
}

- (void)freecursor:(void *)cid
{
  // the cursor should be deallocated
  struct cursor * c = cid;
  wl_cursor_destroy(c->cursor);
  wl_buffer_destroy(c->buffer);
  free(cid);
}

- (void)setIgnoreMouse:(BOOL)ignoreMouse :(int)win
{
  struct window *window = get_window_with_id(wlconfig, win);
  if (window)
    {
      window->ignoreMouse = ignoreMouse;
    }
}

- (void)initializeMouseIfRequired
{
  if (!_mouseInitialized)
    {
      [self initializeMouse];
    }
}

- (void)initializeMouse
{
  _mouseInitialized = YES;

  wlconfig->cursor_theme =
    wl_cursor_theme_load(NULL, 24, wlconfig->shm);

  wlconfig->cursor_surface
    = wl_compositor_create_surface(wlconfig->compositor);

  // default cursor used for show/hide
  struct cursor *wayland_cursor;
  [self standardcursor:GSArrowCursor :(void **)&wayland_cursor];
  [self setcursor:wayland_cursor];

  [self mouseOptionsChanged:nil];
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(mouseOptionsChanged:)
	   name:NSUserDefaultsDidChangeNotification
	 object:nil];
}

- (void)mouseOptionsChanged:(NSNotification *)aNotif
{
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

  wlconfig->mouse_scroll_multiplier =
    [defs integerForKey:@"GSMouseScrollMultiplier"];
  if (wlconfig->mouse_scroll_multiplier < 0.0001f)
    {
      wlconfig->mouse_scroll_multiplier = 1.0f;
    }
}
@end