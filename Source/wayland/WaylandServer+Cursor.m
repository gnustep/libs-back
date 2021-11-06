#include "wayland/WaylandServer.h"
#include <AppKit/NSEvent.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>
#include <AppKit/GSWindowDecorationView.h>
#include <AppKit/GSTheme.h>
#include <AppKit/NSApplication.h>
#include <linux/input.h>

static void
pointer_handle_enter(void *data, struct wl_pointer *pointer,
		     uint32_t serial, struct wl_surface *surface,
		     wl_fixed_t sx_w, wl_fixed_t sy_w)
{
    if (!surface) {
	NSDebugLog(@"no surface");
	return;
    }

    WaylandConfig *wlconfig = data;
    struct window *window = wl_surface_get_user_data(surface);
    float sx = wl_fixed_to_double(sx_w);
    float sy = wl_fixed_to_double(sy_w);
    [GSCurrentServer() initializeMouseIfRequired];

    wlconfig->pointer.x = sx;
    wlconfig->pointer.y = sy;
    wlconfig->pointer.focus = window;

    // FIXME: Send NSMouseEntered event.
}

static void
pointer_handle_leave(void *data, struct wl_pointer *pointer,
		     uint32_t serial, struct wl_surface *surface)
{
    if (!surface) {
	NSDebugLog(@"no surface");
	return;
    }

    WaylandConfig *wlconfig = data;
    struct window *window = wl_surface_get_user_data(surface);
    [GSCurrentServer() initializeMouseIfRequired];

    if (wlconfig->pointer.focus->window_id == window->window_id) {
	wlconfig->pointer.focus = NULL;
	wlconfig->pointer.serial = 0;
    }

    // FIXME: Send NSMouseExited event.
}

// triggered when the cursor is over a surface
static void
pointer_handle_motion(void *data, struct wl_pointer *pointer,
		      uint32_t time, wl_fixed_t sx_w, wl_fixed_t sy_w)
{
    WaylandConfig *wlconfig = data;
    struct window *window;
    if(window->moving || window->resizing) {
        return;
    }
    float sx = wl_fixed_to_double(sx_w);
    float sy = wl_fixed_to_double(sy_w);

    [GSCurrentServer() initializeMouseIfRequired];

    if (wlconfig->pointer.focus && wlconfig->pointer.serial) {
	window = wlconfig->pointer.focus;
	NSEvent *event;
	NSEventType eventType;
	NSPoint eventLocation;
	NSGraphicsContext *gcontext;
	unsigned int eventFlags;
	float deltaX = sx - window->wlconfig->pointer.x;
	float deltaY = sy - window->wlconfig->pointer.y;

//	NSDebugLog(@"obtaining locations: wayland=%fx%f pointer=%fx%f",
//		   sx, sy, window->wlconfig->pointer.x, window->wlconfig->pointer.y);

	gcontext = GSCurrentContext();
	eventLocation = NSMakePoint(sx,
				    window->height - sy);

	eventFlags = 0;
	eventType = NSLeftMouseDragged;

//	NSDebugLog(@"sending pointer delta: %fx%f, window=%d", deltaX, deltaY, window->window_id);

	event = [NSEvent mouseEventWithType: eventType
				   location: eventLocation
			      modifierFlags: eventFlags
				  timestamp: (NSTimeInterval) time / 1000.0
			       windowNumber: (int)window->window_id
				    context: gcontext
				eventNumber: time
				 clickCount: 1
				   pressure: 1.0
			       buttonNumber: 0 /* FIXME */
				     deltaX: deltaX
				     deltaY: deltaY
				     deltaZ: 0.];

	[GSCurrentServer() postEvent: event atStart: NO];
    }

    wlconfig->pointer.x = sx;
    wlconfig->pointer.y = sy;
}

static void
pointer_handle_button(void *data, struct wl_pointer *pointer, uint32_t serial,
		      uint32_t time, uint32_t button, uint32_t state_w)
{
    WaylandConfig *wlconfig = data;
    NSEvent *event;
    NSEventType eventType;
    NSPoint eventLocation;
    NSGraphicsContext *gcontext;
    unsigned int eventFlags;
    float deltaX = 0.0;
    float deltaY = 0.0;
    int clickCount = 1;
    int tick;
    int buttonNumber;
    enum wl_pointer_button_state state = state_w;
    struct window *window = wlconfig->pointer.focus;

    [GSCurrentServer() initializeMouseIfRequired];

    gcontext = GSCurrentContext();
    eventLocation = NSMakePoint(wlconfig->pointer.x,
				window->height - wlconfig->pointer.y);
    eventFlags = 0;

    if(window->toplevel) {
        // if the window is a toplevel we check if the event is for resizing or moving the window
        // these actions are delegated to the compositor and therefore we skip forwarding the events
        // to the NSWindow / NSView

        NSWindow * nswindow = GSWindowWithNumber(window->window_id);
        if(nswindow != nil) {
            GSWindowDecorationView * wd = [GSWindowDecorationView windowDecorator];
//            NSPoint p = [[nswindow contentView] convertPoint: eventLocation fromView: nil];
            GSTheme *theme = [GSTheme theme];
            CGFloat titleHeight = [theme titlebarHeight];
            CGFloat resizebarHeight = [theme resizebarHeight];
            NSRect windowframe = [nswindow frame];
            NSDebugLog(@"[%d] titleHeight: %f", window->window_id, titleHeight);
            NSDebugLog(@"[%d] resizebarHeight: %f", window->window_id, resizebarHeight);
            NSDebugLog(@"[%d] windowframe: %f,%f %fx%f", windowframe.origin.x, windowframe.origin.y,
                    windowframe.size.width, windowframe.size.height);
            NSDebugLog(@"[%d] eventLocation: %f,%f", window->window_id, eventLocation.x, eventLocation.y);

            NSRect titleBarRect = NSZeroRect;
            NSRect resizeBarRect = NSZeroRect;
            NSRect closeButtonRect = NSZeroRect;
            NSRect miniaturizeButtonRect = NSZeroRect;
            NSUInteger styleMask = [nswindow styleMask];
            bool hasTitleBar = NO;
            bool hasResizeBar = NO;
            bool hasCloseButton = NO;
            bool hasMiniaturizeButton = NO;

            // wayland controls the window move / resize

            if (styleMask
                & (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask)) {
                hasTitleBar = YES;
                titleBarRect = NSMakeRect(0.0, windowframe.size.height - titleHeight,
                windowframe.size.width, titleHeight);

                NSDebugLog(@"[%d] titleBarRect: %f,%f %fx%f", titleBarRect.origin.x, titleBarRect.origin.y,
                        titleBarRect.size.width, titleBarRect.size.height);
            }

            if (styleMask & NSResizableWindowMask) {
                hasResizeBar = YES;
                float padding = 10.0;
                resizeBarRect = NSMakeRect(-padding, -padding, windowframe.size.width + padding * 2, resizebarHeight + padding * 2);

                NSDebugLog(@"[%d] resizeBarRect: %f,%f %fx%f", resizeBarRect.origin.x, resizeBarRect.origin.y,
                        resizeBarRect.size.width, resizeBarRect.size.height);
            }

            if (styleMask & NSClosableWindowMask) {
                hasCloseButton = YES;

                closeButtonRect = NSMakeRect(windowframe.size.width - [theme titlebarButtonSize] -
				   [theme titlebarPaddingRight], windowframe.size.height -
				   [theme titlebarButtonSize] - [theme titlebarPaddingTop],
				   [theme titlebarButtonSize], [theme titlebarButtonSize]);

            }

            if (styleMask & NSMiniaturizableWindowMask) {
                hasMiniaturizeButton = YES;
                miniaturizeButtonRect = NSMakeRect([theme titlebarPaddingLeft], windowframe.size.height -
                                [theme titlebarButtonSize] - [theme titlebarPaddingTop],
                                [theme titlebarButtonSize], [theme titlebarButtonSize]);
            }

            if (hasTitleBar &&
                !NSPointInRect(eventLocation, closeButtonRect) &&
                !NSPointInRect(eventLocation, miniaturizeButtonRect) &&
                NSPointInRect(eventLocation, titleBarRect)) {
                NSDebugLog(@"[%d] point in titleBarRect [%f,%f] [%f,%f %fx%f]",
                        window->window_id,
                        eventLocation.x, eventLocation.y,
                        titleBarRect.origin.x, titleBarRect.origin.y,
                        titleBarRect.size.width, titleBarRect.size.height);

                if(state == WL_POINTER_BUTTON_STATE_PRESSED) {
                    xdg_toplevel_move(window->toplevel, wlconfig->seat, serial);
                    window->moving = YES;
                    return;
                } else {
                    window->moving = NO;

                }
            }
            if (hasResizeBar && NSPointInRect(eventLocation, resizeBarRect)) {
                uint32_t edges = XDG_TOPLEVEL_RESIZE_EDGE_BOTTOM_RIGHT;
                NSDebugLog(@"[%d] point in resizeBarRect [%f,%f] [%f,%f %fx%f]",
                        window->window_id,
                        eventLocation.x, eventLocation.y,
                        resizeBarRect.origin.x, resizeBarRect.origin.y,
                        resizeBarRect.size.width, resizeBarRect.size.height);

                if (resizeBarRect.size.width < 30 * 2
                    && eventLocation.x < resizeBarRect.size.width / 2) {
                    edges = XDG_TOPLEVEL_RESIZE_EDGE_BOTTOM_LEFT;
                } else if (eventLocation.x > resizeBarRect.size.width - 30) {
                    edges = XDG_TOPLEVEL_RESIZE_EDGE_BOTTOM_RIGHT;
                } else if (eventLocation.x < 29) {
                    edges = XDG_TOPLEVEL_RESIZE_EDGE_BOTTOM_LEFT;
                } else {
                    edges = XDG_TOPLEVEL_RESIZE_EDGE_BOTTOM;
                }

                if(state == WL_POINTER_BUTTON_STATE_PRESSED) {
                    xdg_toplevel_resize(window->toplevel, wlconfig->seat, serial, edges);
                    window->resizing = YES;
                    return;
                } else {
                    window->resizing = NO;
                }
            }
        }
    } // endif window->toplevel


    if (state == WL_POINTER_BUTTON_STATE_PRESSED) {
	if (button == wlconfig->pointer.last_click_button &&
	    time - wlconfig->pointer.last_click_time < 300 &&
	    abs(wlconfig->pointer.x - wlconfig->pointer.last_click_x) < 3 &&
	    abs(wlconfig->pointer.y - wlconfig->pointer.last_click_y) < 3) {
	    wlconfig->pointer.last_click_time = 0;
	    clickCount++;
	} else {
	    NSDebugLog(@"handle_button MISS: b=%d t=%d x=%f y=%f", button, time, wlconfig->pointer.x, wlconfig->pointer.y);
	    wlconfig->pointer.last_click_button = button;
	    wlconfig->pointer.last_click_time = time;
	    wlconfig->pointer.last_click_x = wlconfig->pointer.x;
	    wlconfig->pointer.last_click_y = wlconfig->pointer.y;
	}

	switch (button) {
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
	wlconfig->pointer.serial = serial;
    } else if (state == WL_POINTER_BUTTON_STATE_RELEASED) {
	switch (button) {
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
	wlconfig->pointer.serial = 0;
    } else {
      return;
    }

    /* FIXME: unlike in _motion and _axis handlers, the argument used in _button
       is the "serial" of the event, not passed and unavailable in _motion and
       _axis handlers. Is it allowed to pass "serial" as the eventNumber: in
       _button handler, but "time" as the eventNumber: in the _motion and _axis
       handlers? */
    tick = serial;

    NSDebugLog(@"sending pointer event at: %fx%f, window=%d", wlconfig->pointer.x, wlconfig->pointer.y, window->window_id);

    /* FIXME: X11 backend uses the XGetPointerMapping()-returned values from
       its map_return argument as constants for buttonNumber. As the variant
       with buttonNumber: seems to be a GNUstep extension, and the value
       internal, it might be ok to just provide libinput constant as we're doing
       here. If this is truly correct, please update this comment to document
       the correctness of doing so. */
    buttonNumber = button;

    event = [NSEvent mouseEventWithType: eventType
			       location: eventLocation
			  modifierFlags: eventFlags
			      timestamp: (NSTimeInterval) time / 1000.0
			   windowNumber: (int)window->window_id
				context: gcontext
			    eventNumber: tick
			     clickCount: clickCount
			       pressure: 1.0
			   buttonNumber: buttonNumber
				 deltaX: deltaX /* FIXME unused */
				 deltaY: deltaY /* FIXME unused */
				 deltaZ: 0.];

    [GSCurrentServer() postEvent: event atStart: NO];
}

static void
pointer_handle_axis(void *data, struct wl_pointer *pointer,
		    uint32_t time, uint32_t axis, wl_fixed_t value)
{
  NSDebugLog(@"pointer_handle_axis: axis=%d value=%g", axis, wl_fixed_to_double(value));
  WaylandConfig *wlconfig = data;
  NSEvent *event;
  NSEventType eventType;
  NSPoint eventLocation;
  NSGraphicsContext *gcontext;
  unsigned int eventFlags;
  float deltaX = 0.0;
  float deltaY = 0.0;
  int clickCount = 1;
  int buttonNumber;

  struct window *window = wlconfig->pointer.focus;

  [GSCurrentServer() initializeMouseIfRequired];

  gcontext = GSCurrentContext();
  eventLocation = NSMakePoint(wlconfig->pointer.x,
                              window->height - wlconfig->pointer.y);
  eventFlags = 0;

  /* FIXME: we should get axis_source out of wl_pointer; however, the wl_pointer
     is not defined in wayland-client.h. How does one get the axis_source out of
     it to confirm the source is the physical mouse wheel? */
#if 0
  if (pointer->axis_source != WL_POINTER_AXIS_SOURCE_WHEEL)
    return;
#endif

  float mouse_scroll_multiplier = wlconfig->mouse_scroll_multiplier;
  /* For smooth-scroll events, we're not doing any cross-event or delta
     calculations, as is done in button event handling. */
  switch(axis)
    {
    case WL_POINTER_AXIS_VERTICAL_SCROLL:
      eventType = NSScrollWheel;
      deltaY = wl_fixed_to_double(value) * wlconfig->mouse_scroll_multiplier;
    case WL_POINTER_AXIS_HORIZONTAL_SCROLL:
      eventType = NSScrollWheel;
      deltaX = wl_fixed_to_double(value) * wlconfig->mouse_scroll_multiplier;
    }

  NSDebugLog(@"sending pointer scroll at: %fx%f, value %fx%f, window=%d", wlconfig->pointer.x, wlconfig->pointer.y, deltaX, deltaY, window->window_id);

  /* FIXME: X11 backend uses the XGetPointerMapping()-returned values from
     its map_return argument as constants for buttonNumber. As the variant
     with buttonNumber: seems to be a GNUstep extension, and the value
     internal, it might be ok to just not provide any value here.
     If this is truly correct, please update this comment to document
     the correctness of doing so. */
  buttonNumber = 0;

  event = [NSEvent mouseEventWithType: eventType
                             location: eventLocation
                        modifierFlags: eventFlags
                            timestamp: (NSTimeInterval) time / 1000.0
                         windowNumber: (int)window->window_id
                              context: gcontext
                          eventNumber: time
                           clickCount: clickCount
                             pressure: 1.0
                         buttonNumber: buttonNumber
                               deltaX: deltaX
                               deltaY: deltaY
                               deltaZ: 0.];

  [GSCurrentServer() postEvent: event atStart: NO];
}

const struct wl_pointer_listener pointer_listener = {
	pointer_handle_enter,
	pointer_handle_leave,
	pointer_handle_motion,
	pointer_handle_button,
	pointer_handle_axis,
};

@implementation WaylandServer(Cursor)
- (NSPoint) mouselocation
{
  int aScreen = -1;
  struct output *output;

  NSDebugLog(@"mouselocation");

  // FIXME: find a cleaner way to get the first element of a wl_list
  wl_list_for_each(output, &wlconfig->output_list, link) {
    aScreen = output->server_output_id;
    break;
  }
  if (aScreen < 0)
    // No outputs in the wl_list.
    return NSZeroPoint;

  return [self mouseLocationOnScreen: aScreen window: NULL];
}

- (NSPoint) mouseLocationOnScreen: (int)aScreen window: (int *)win
{
//    NSDebugLog(@"mouseLocationOnScreen: %d %fx%f", win,
//	       wlconfig->pointer.x, wlconfig->pointer.y);
    struct window *window = wlconfig->pointer.focus;
    struct output *output;
    float x;
    float y;

    /*if (wlconfig->pointer.serial) {
	NSDebugLog(@"captured");
	x = wlconfig->pointer.captured_x;
	y = wlconfig->pointer.captured_y;
	} else*/ {
	//NSDebugLog(@"NOT captured");
	x = wlconfig->pointer.x;
	y = wlconfig->pointer.y;

	if (window) {
	    x += window->pos_x;
	    y += window->pos_y;
	    if (win) {
              *win = &window->window_id;
            }
	}
    }

    wl_list_for_each(output, &wlconfig->output_list, link) {
	if (output->server_output_id == aScreen) {
	    y = output->height - y;
	    break;
	}
    }

//    NSDebugLog(@"mouseLocationOnScreen: returning %fx%f", x, y);

    return NSMakePoint(x, y);
}

- (BOOL) capturemouse: (int) win
{
    NSDebugLog(@"capturemouse: %d", win);
    return NO;
}

- (void) releasemouse
{
    NSDebugLog(@"releasemouse");
}

- (void) setMouseLocation: (NSPoint)mouseLocation onScreen: (int)aScreen
{
    NSDebugLog(@"setMouseLocation");
}

- (void) hidecursor
{
    NSDebugLog(@"hidecursor");
}

- (void) showcursor
{
    NSDebugLog(@"showcursor");
}

- (void) standardcursor: (int) style : (void**) cid
{
    NSDebugLog(@"standardcursor");
}

- (void) imagecursor: (NSPoint)hotp : (NSImage *) image : (void**) cid
{
    NSDebugLog(@"imagecursor");
}

- (void) setcursorcolor: (NSColor *)fg : (NSColor *)bg : (void*) cid
{
    NSLog(@"Call to obsolete method -setcursorcolor:::");
    [self recolorcursor: fg : bg : cid];
    [self setcursor: cid];
}

- (void) recolorcursor: (NSColor *)fg : (NSColor *)bg : (void*) cid
{
    NSDebugLog(@"recolorcursor");
}

- (void) setcursor: (void*) cid
{
    NSDebugLog(@"setcursor");
}

- (void) freecursor: (void*) cid
{
    NSDebugLog(@"freecursor");
}
- (void) setIgnoreMouse: (BOOL)ignoreMouse : (int)win
{
    NSDebugLog(@"setIgnoreMouse");
}

- (void) initializeMouseIfRequired
{
  if (!_mouseInitialized)
    [self initializeMouse];
}

- (void) initializeMouse
{
  _mouseInitialized = YES;

  [self mouseOptionsChanged: nil];
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver: self
       selector: @selector(mouseOptionsChanged:)
           name: NSUserDefaultsDidChangeNotification
         object: nil];
}

- (void) mouseOptionsChanged: (NSNotification *)aNotif
{
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

  wlconfig->mouse_scroll_multiplier = [defs integerForKey:@"GSMouseScrollMultiplier"];
  if (wlconfig->mouse_scroll_multiplier < 0.0001f)
    wlconfig->mouse_scroll_multiplier = 1.0f;
}
@end
