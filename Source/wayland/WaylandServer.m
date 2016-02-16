/* WaylandServer - Wayland Server Class

   Copyright (C) 2016 Sergio L. Pascual <slp@sinrega.org>
*/

#include "config.h"
#include <AppKit/AppKitExceptions.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/DPSOperators.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSText.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSValue.h>

#include <xkbcommon/xkbcommon.h>
#include <linux/input.h>
#include <sys/mman.h>

#include "wayland/WaylandServer.h"

static void
handle_geometry(void *data,
		struct wl_output *wl_output,
		int x, int y,
		int physical_width,
		int physical_height,
		int subpixel,
		const char *make,
		const char *model,
		int transform)
{
    NSDebugLog(@"handle_geometry");
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
}

static void
handle_done(void *data,
	    struct wl_output *wl_output)
{
    NSDebugLog(@"handle_done");
}

static void
handle_scale(void *data,
	     struct wl_output *wl_output,
	     int32_t scale)
{
    NSDebugLog(@"handle_scale");
    struct output *output = data;

    output->scale = scale;
}

static void
handle_mode(void *data,
	    struct wl_output *wl_output,
	    uint32_t flags,
	    int width,
	    int height,
	    int refresh)
{
    NSDebugLog(@"handle_mode");
    struct output *output = data;

    if (flags & WL_OUTPUT_MODE_CURRENT) {
	output->width = width;
	output->height = height /*- 30*/;
	NSDebugLog(@"handle_mode output=%dx%d", width, height);
	/* XXX - Should we implement this?
	if (display->output_configure_handler)
	    (*display->output_configure_handler)
		(output, display->user_data);
	*/
    }
}

static const struct wl_output_listener output_listener = {
    handle_geometry,
    handle_mode,
    handle_done,
    handle_scale
};

static void
add_output(WaylandConfig *wlconfig, uint32_t id)
{
    NSDebugLog(@"add_output");

    struct output *output;

    output = (struct output *) malloc(sizeof(struct output));
    memset(output, 0, sizeof(struct output));
    output->wlconfig = wlconfig;
    output->scale = 1;
    output->output =
	wl_registry_bind(wlconfig->registry, id, &wl_output_interface, 2);
    output->server_output_id = id;
    wl_list_insert(wlconfig->output_list.prev, &output->link);
    (wlconfig->output_count)++;
    
    wl_output_add_listener(output->output, &output_listener, output);
}

static void
output_destroy(struct output *output)
{
    NSDebugLog(@"output_destroy");

    /* XXX - Should we implement this?
    if (output->destroy_handler)
	(*output->destroy_handler)(output, output->user_data);
    */

    wl_output_destroy(output->output);
    wl_list_remove(&output->link);
    free(output);
}

static void
destroy_output(WaylandConfig *wlconfig, uint32_t id)
{
    struct output *output;

    wl_list_for_each(output, &wlconfig->output_list, link) {
	if (output->server_output_id == id) {
	    output_destroy(output);
	    (wlconfig->output_count)--;
	    break;
	}
    }
}

static void
pointer_handle_enter(void *data, struct wl_pointer *pointer,
		     uint32_t serial, struct wl_surface *surface,
		     wl_fixed_t sx_w, wl_fixed_t sy_w)
{
    NSDebugLog(@"pointer_handle_enter");
    if (!surface) {
	NSDebugLog(@"no surface");
	return;
    }
    
    WaylandConfig *wlconfig = data;
    struct window *window = wl_surface_get_user_data(surface);
    float sx = wl_fixed_to_double(sx_w);
    float sy = wl_fixed_to_double(sy_w);
    
    wlconfig->pointer.x = sx;
    wlconfig->pointer.y = sy;
    wlconfig->pointer.focus = window;
}

static void
pointer_handle_leave(void *data, struct wl_pointer *pointer,
		     uint32_t serial, struct wl_surface *surface)
{
    NSDebugLog(@"pointer_handle_leave");
    if (!surface) {
	NSDebugLog(@"no surface");
	return;
    }

    WaylandConfig *wlconfig = data;
    struct window *window = wl_surface_get_user_data(surface);

    if (wlconfig->pointer.focus->window_id == window->window_id) {
	wlconfig->pointer.focus = NULL;
	wlconfig->pointer.serial = 0;
    }
}

static void
pointer_handle_motion(void *data, struct wl_pointer *pointer,
		      uint32_t time, wl_fixed_t sx_w, wl_fixed_t sy_w)
{
    WaylandConfig *wlconfig = data;
    struct window *window;
    float sx = wl_fixed_to_double(sx_w);
    float sy = wl_fixed_to_double(sy_w);
    NSDebugLog(@"pointer_handle_motion: %fx%f", sx, sy);

    if (wlconfig->pointer.focus && wlconfig->pointer.serial) {
	window = wlconfig->pointer.focus;
	NSEvent *event;
	NSEventType eventType;
	NSPoint eventLocation;
	NSGraphicsContext *gcontext;
	unsigned int eventFlags;
	int tick;
	float deltaX = sx - window->wlconfig->pointer.x;
	float deltaY = sy - window->wlconfig->pointer.y;

	NSDebugLog(@"obtaining locations: wayland=%fx%f pointer=%fx%f",
		   sx, sy, window->wlconfig->pointer.x, window->wlconfig->pointer.y);
    
	gcontext = GSCurrentContext();
	eventLocation = NSMakePoint(sx,
				    window->height - sy);

	eventFlags = 0;
	eventType = NSLeftMouseDragged;
	
	tick = 0;


	NSDebugLog(@"sending pointer delta: %fx%f, window=%d", deltaX, deltaY, window->window_id);

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
    NSDebugLog(@"pointer_handle_button: button=%d", button);
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
    enum wl_pointer_button_state state = state_w;
    struct window *window = wlconfig->pointer.focus;

    gcontext = GSCurrentContext();
    eventLocation = NSMakePoint(wlconfig->pointer.x,
				window->height - wlconfig->pointer.y);
    eventFlags = 0;
    if (state == WL_POINTER_BUTTON_STATE_PRESSED) {
	if (button == wlconfig->pointer.last_click_button &&
	    time - wlconfig->pointer.last_click_time < 300 &&
	    abs(wlconfig->pointer.x - wlconfig->pointer.last_click_x) < 3 &&
	    abs(wlconfig->pointer.y - wlconfig->pointer.last_click_y) < 3) {
	    NSDebugLog(@"handle_button HIT: b=%d t=%d x=%f y=%f", button, time, wlconfig->pointer.x, wlconfig->pointer.y);
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
	}
	wlconfig->pointer.serial = serial;
    } else {
	switch (button) {
	case BTN_LEFT:
	    eventType = NSLeftMouseUp;
	    break;
	case BTN_RIGHT:
	    eventType = NSRightMouseUp;
	    break;
	}
	wlconfig->pointer.serial = 0;
    }

    tick = serial;

    NSDebugLog(@"sending pointer event at: %fx%f, window=%d", wlconfig->pointer.x, wlconfig->pointer.y, window->window_id);
    
    event = [NSEvent mouseEventWithType: eventType
			       location: eventLocation
			  modifierFlags: eventFlags
			      timestamp: (NSTimeInterval) time / 1000.0
			   windowNumber: (int)window->window_id
				context: gcontext
			    eventNumber: tick
			     clickCount: clickCount
			       pressure: 1.0
			 buttonNumber: 0 /* FIXME */
				 deltaX: deltaX
				 deltaY: deltaY
				 deltaZ: 0.];

    [GSCurrentServer() postEvent: event atStart: NO];
}

static void
pointer_handle_axis(void *data, struct wl_pointer *pointer,
		    uint32_t time, uint32_t axis, wl_fixed_t value)
{
}

static const struct wl_pointer_listener pointer_listener = {
	pointer_handle_enter,
	pointer_handle_leave,
	pointer_handle_motion,
	pointer_handle_button,
	pointer_handle_axis,
};

static void
keyboard_handle_keymap(void *data, struct wl_keyboard *keyboard,
		       uint32_t format, int fd, uint32_t size)
{
    NSDebugLog(@"keyboard_handle_keymap");
    WaylandConfig *wlconfig = data;
    struct xkb_keymap *keymap;
    struct xkb_state *state;
    char *map_str;

    if (!data) {
	close(fd);
	return;
    }

    if (format != WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1) {
	close(fd);
	return;
    }

    map_str = mmap(NULL, size, PROT_READ, MAP_SHARED, fd, 0);
    if (map_str == MAP_FAILED) {
	close(fd);
	return;
    }

    wlconfig->xkb_context = xkb_context_new(0);
    if (wlconfig->xkb_context == NULL) {
	fprintf(stderr, "Failed to create XKB context\n");
	return;
    }

    keymap = xkb_keymap_new_from_string(wlconfig->xkb_context,
					map_str,
					XKB_KEYMAP_FORMAT_TEXT_V1,
					0);
    munmap(map_str, size);
    close(fd);

    if (!keymap) {
	fprintf(stderr, "failed to compile keymap\n");
	return;
    }

    state = xkb_state_new(keymap);
    if (!state) {
	fprintf(stderr, "failed to create XKB state\n");
	xkb_keymap_unref(keymap);
	return;
    }
    
    xkb_keymap_unref(wlconfig->xkb.keymap);
    xkb_state_unref(wlconfig->xkb.state);
    wlconfig->xkb.keymap = keymap;
    wlconfig->xkb.state = state;

    wlconfig->xkb.control_mask =
	1 << xkb_keymap_mod_get_index(wlconfig->xkb.keymap, "Control");
    wlconfig->xkb.alt_mask =
	1 << xkb_keymap_mod_get_index(wlconfig->xkb.keymap, "Mod1");
    wlconfig->xkb.shift_mask =
	1 << xkb_keymap_mod_get_index(wlconfig->xkb.keymap, "Shift");
		
}

static void
keyboard_handle_enter(void *data, struct wl_keyboard *keyboard,
		      uint32_t serial, struct wl_surface *surface,
		      struct wl_array *keys)
{
    NSDebugLog(@"keyboard_handle_enter");
}

static void
keyboard_handle_leave(void *data, struct wl_keyboard *keyboard,
		      uint32_t serial, struct wl_surface *surface)
{
    NSDebugLog(@"keyboard_handle_leave");
}

static void
keyboard_handle_modifiers(void *data, struct wl_keyboard *keyboard,
			  uint32_t serial, uint32_t mods_depressed,
			  uint32_t mods_latched, uint32_t mods_locked,
			  uint32_t group)
{
    NSDebugLog(@"keyboard_handle_modifiers");
    WaylandConfig *wlconfig = data;
    struct input *input = data;
    xkb_mod_mask_t mask;

    /* If we're not using a keymap, then we don't handle PC-style modifiers */
    if (!wlconfig->xkb.keymap)
	return;

    xkb_state_update_mask(wlconfig->xkb.state, mods_depressed, mods_latched,
			  mods_locked, 0, 0, group);
    mask = xkb_state_serialize_mods(wlconfig->xkb.state,
				    XKB_STATE_MODS_DEPRESSED |
				    XKB_STATE_MODS_LATCHED);
    wlconfig->modifiers = 0;
    if (mask & wlconfig->xkb.control_mask)
	wlconfig->modifiers |= NSCommandKeyMask;
    if (mask & wlconfig->xkb.alt_mask)
	wlconfig->modifiers |= NSAlternateKeyMask;
    if (mask & wlconfig->xkb.shift_mask)
	wlconfig->modifiers |= NSShiftKeyMask;
    
}

static void
keyboard_handle_key(void *data, struct wl_keyboard *keyboard,
		    uint32_t serial, uint32_t time, uint32_t key,
		    uint32_t state_w)
{
    NSDebugLog(@"keyboard_handle_key: %d", key);
    WaylandConfig *wlconfig = data;
    uint32_t code, num_syms;
    enum wl_keyboard_key_state state = state_w;
    const xkb_keysym_t *syms;
    xkb_keysym_t sym;
    struct itimerspec its;
    struct window *window = wlconfig->pointer.focus;

    if (!window) {
	return;
    }

    if (key == 28) {
	sym = NSCarriageReturnCharacter;
    } else if (key == 14) {
	sym = NSDeleteCharacter;
    } else {
	code = key + 8;
	
	num_syms = xkb_state_key_get_syms(wlconfig->xkb.state, code, &syms);
	
	sym = XKB_KEY_NoSymbol;
	if (num_syms == 1)
	    sym = syms[0];
    }

    NSString *s = [NSString stringWithUTF8String: &sym];
    NSEventType eventType;
	
    if (state == WL_KEYBOARD_KEY_STATE_PRESSED) {
	eventType = NSKeyDown;
    } else {
	eventType = NSKeyUp;
    }

    NSEvent *ev = [NSEvent keyEventWithType: eventType
				   location: NSZeroPoint
			      modifierFlags: wlconfig->modifiers
				  timestamp: time / 1000.0
			       windowNumber: window->window_id
				    context: GSCurrentContext()
				 characters: s
			   charactersIgnoringModifiers: s
				  isARepeat: NO
				    keyCode: code];
  
    [GSCurrentServer() postEvent: ev atStart: NO];

    NSDebugLog(@"keyboard_handle_key: %@", s);
}

static void
keyboard_handle_repeat_info(void *data, struct wl_keyboard *keyboard,
			    int32_t rate, int32_t delay)
{
    NSDebugLog(@"keyboard_handle_repeat_info");
}

static const struct wl_keyboard_listener keyboard_listener = {
    keyboard_handle_keymap,
    keyboard_handle_enter,
    keyboard_handle_leave,
    keyboard_handle_key,
    keyboard_handle_modifiers,
    keyboard_handle_repeat_info
};

static void
seat_handle_capabilities(void *data, struct wl_seat *seat,
			 enum wl_seat_capability caps)
{
    WaylandConfig *wlconfig = data;

    if ((caps & WL_SEAT_CAPABILITY_POINTER) && !wlconfig->pointer.wlpointer) {
	wlconfig->pointer.wlpointer = wl_seat_get_pointer(seat);
	wl_pointer_set_user_data(wlconfig->pointer.wlpointer, wlconfig);
	wl_pointer_add_listener(wlconfig->pointer.wlpointer, &pointer_listener,
				wlconfig);
    } else if (!(caps & WL_SEAT_CAPABILITY_POINTER) && wlconfig->pointer.wlpointer) {
	if (wlconfig->seat_version >= WL_POINTER_RELEASE_SINCE_VERSION)
	    wl_pointer_release(wlconfig->pointer.wlpointer);
	else
	    wl_pointer_destroy(wlconfig->pointer.wlpointer);
	wlconfig->pointer.wlpointer = NULL;
    }

    wl_display_dispatch_pending(wlconfig->display);
    wl_display_flush(wlconfig->display);

    if ((caps & WL_SEAT_CAPABILITY_KEYBOARD) && !wlconfig->keyboard) {
	wlconfig->keyboard = wl_seat_get_keyboard(seat);
	wl_keyboard_set_user_data(wlconfig->keyboard, wlconfig);
	wl_keyboard_add_listener(wlconfig->keyboard, &keyboard_listener,
				 wlconfig);
    } else if (!(caps & WL_SEAT_CAPABILITY_KEYBOARD) && wlconfig->keyboard) {
	if (wlconfig->seat_version >= WL_KEYBOARD_RELEASE_SINCE_VERSION)
	    wl_keyboard_release(wlconfig->keyboard);
	else
	    wl_keyboard_destroy(wlconfig->keyboard);
	wlconfig->keyboard = NULL;
    }

#if 0
    if ((caps & WL_SEAT_CAPABILITY_TOUCH) && !input->touch) {
	input->touch = wl_seat_get_touch(seat);
	wl_touch_set_user_data(input->touch, input);
	wl_touch_add_listener(input->touch, &touch_listener, input);
    } else if (!(caps & WL_SEAT_CAPABILITY_TOUCH) && input->touch) {
	if (input->seat_version >= WL_TOUCH_RELEASE_SINCE_VERSION)
	    wl_touch_release(input->touch);
	else
	    wl_touch_destroy(input->touch);
	input->touch = NULL;
    }
#endif
}

static const struct wl_seat_listener seat_listener = {
    seat_handle_capabilities,
};

static void
add_seat(WaylandConfig *wlconfig, uint32_t name, uint32_t version)
{
    wlconfig->pointer.wlpointer = NULL;
    wlconfig->seat_version = version;
    wlconfig->seat = wl_registry_bind(wlconfig->registry, name,
				      &wl_seat_interface, 1);
    wl_seat_add_listener(wlconfig->seat, &seat_listener, wlconfig);
}

static void
shm_format(void *data, struct wl_shm *wl_shm, uint32_t format)
{
}

struct wl_shm_listener shm_listener = {
        shm_format
};

static void
handle_ping(void *data, struct wl_shell_surface *shell_surface,
	    uint32_t serial)
{
    NSDebugLog(@"handle_ping");
    struct window *window = (struct window *) data;
    wl_shell_surface_pong(shell_surface, serial);
    wl_display_dispatch_pending(window->wlconfig->display);
    wl_display_flush(window->wlconfig->display);
}

static void
handle_configure(void *data, struct wl_shell_surface *shell_surface,
		 uint32_t edges, int32_t width, int32_t height)
{
}

static void
handle_popup_done(void *data, struct wl_shell_surface *shell_surface)
{
}

static const struct wl_shell_surface_listener shell_surface_listener = {
    handle_ping,
    handle_configure,
    handle_popup_done
};

static void
xdg_shell_ping(void *data, struct xdg_shell *shell, uint32_t serial)
{
    WaylandConfig *wlconfig = data;
    xdg_shell_pong(shell, serial);
    wl_display_dispatch_pending(wlconfig->display);
    wl_display_flush(wlconfig->display);

}

static const struct xdg_shell_listener xdg_shell_listener = {
    xdg_shell_ping,
};

static void
handle_surface_configure(void *data, struct xdg_surface *xdg_surface,
			 int32_t x, int32_t y,
			 int32_t width, int32_t height,
			 struct wl_array *states, uint32_t serial)
{
    struct window *window = data;
    WaylandConfig *wlconfig = window->wlconfig;
    NSDebugLog(@"handle_surface_configure: win=%d", window->window_id);
    
    NSEvent *ev = nil;
    NSWindow *nswindow = GSWindowWithNumber(window->window_id);

    if (wlconfig->pointer.focus &&
	wlconfig->pointer.focus->window_id == window->window_id) {
	ev = [NSEvent otherEventWithType: NSAppKitDefined
				location: NSZeroPoint
			   modifierFlags: 0
			       timestamp: 0
			windowNumber: (int)window->window_id
				 context: GSCurrentContext()
				 subtype: GSAppKitWindowFocusIn
				   data1: 0
			       data2: 0];
	
	[nswindow sendEvent: ev];
    }

#if 0
    struct window *window = data;
    int moved = 0;
    NSDebugLog(@"configure window=%d pos=%dx%d size=%dx%d",
	       window->window_id, x, y, width, height);
    NSDebugLog(@"current values pos=%dx%d size=%dx%d",
	       window->pos_x, window->pos_y, window->width, window->height);

    if (!window->is_out && (window->pos_x != x || window->pos_y != y)) {
	window->pos_x = x;
	window->pos_y = y;
	moved = 1;
    }
	       
    xdg_surface_ack_configure(window->xdg_surface, serial);
    NSRect rect = NSMakeRect(0, 0,
			     window->width, window->height);
    [window->instance flushwindowrect:rect :window->window_id];

    wl_display_dispatch_pending(window->wlconfig->display);
    wl_display_flush(window->wlconfig->display);

    if (moved) {
	NSDebugLog(@"window moved, notifying AppKit");
	NSEvent *ev = nil;
	NSWindow *nswindow = GSWindowWithNumber(window->window_id);
    
	ev = [NSEvent otherEventWithType: NSAppKitDefined
				location: NSZeroPoint
			   modifierFlags: 0
			       timestamp: 0
			    windowNumber: (int)window->window_id
				 context: GSCurrentContext()
				 subtype: GSAppKitWindowMoved
				   data1: window->pos_x
				   data2: WaylandToNS(window, window->pos_y)];

	[nswindow sendEvent: ev];
    }
#endif
}

static void
handle_surface_delete(void *data, struct xdg_surface *xdg_surface)
{
    NSDebugLog(@"handle_surface_delete");
}

static const struct xdg_surface_listener xdg_surface_listener = {
    handle_surface_configure,
    handle_surface_delete,
};

static void
handle_global(void *data, struct wl_registry *registry,
	      uint32_t name, const char *interface, uint32_t version)
{
    WaylandConfig *wlconfig = data;

    if (strcmp(interface, "wl_compositor") == 0) {
	wlconfig->compositor =
	    wl_registry_bind(wlconfig->registry, name,
			     &wl_compositor_interface, 1);
	/*	
    } else if (strcmp(interface, "wl_shell") == 0) {
	wlconfig->shell =
	    wl_registry_bind(registry, name,
			     &wl_shell_interface, 1);
	*/
    } else if (strcmp(interface, "xdg_shell") == 0) {
	wlconfig->xdg_shell = wl_registry_bind(registry, name,
					       &xdg_shell_interface, 1);
	xdg_shell_use_unstable_version(wlconfig->xdg_shell, 5);
	xdg_shell_add_listener(wlconfig->xdg_shell,
			       &xdg_shell_listener, wlconfig);
    } else if (strcmp(interface, "wl_shm") == 0) {
	wlconfig->shm = wl_registry_bind(wlconfig->registry, name,
					 &wl_shm_interface, 1);
	wl_shm_add_listener(wlconfig->shm, &shm_listener, wlconfig);
    } else if (strcmp(interface, "wl_output") == 0) {
        add_output(wlconfig, name);
    } else if (strcmp(interface, "wl_seat") == 0) {
	add_seat(wlconfig, name, version);
    }
}

static void
handle_global_remove(void *data, struct wl_registry *registry,
		     uint32_t name)
{
}

static const struct wl_registry_listener registry_listener = {
    handle_global,
    handle_global_remove
};

struct window *
get_window_with_id(WaylandConfig *wlconfig, int winid)
{
    struct window *window;

    wl_list_for_each(window, &wlconfig->window_list, link) {
	if (window->window_id == winid) {
	    return window;
	}
    }

    return NULL;
}

float WaylandToNS(struct window *window, float wl_y)
{
    return (window->output->height - wl_y - window->height);
}

int NSToWayland(struct window *window, int ns_y)
{
    return (window->output->height - ns_y - window->height);
}

@implementation WaylandServer

/* Initialize AppKit backend */
+ (void) initializeBackend
{
    NSDebugLog(@"Initializing GNUstep Wayland backend");
    [GSDisplayServer setDefaultServerClass: [WaylandServer class]];
}

- (id) _initWaylandContext
{
    wlconfig = (WaylandConfig *) malloc(sizeof(WaylandConfig));
    memset(wlconfig, 0, sizeof(WaylandConfig));
    wlconfig->last_window_id = 1;
    wl_list_init(&wlconfig->output_list);
    wl_list_init(&wlconfig->window_list);
    
    wlconfig->display = wl_display_connect(NULL);
    if (!wlconfig->display) {
	[NSException raise: NSWindowServerCommunicationException
		    format: @"Unable to connect Wayland Server"];
    }

    wlconfig->registry = wl_display_get_registry(wlconfig->display);
    wl_registry_add_listener(wlconfig->registry,
			     &registry_listener, wlconfig);
    wl_display_dispatch(wlconfig->display);
    wl_display_roundtrip(wlconfig->display);
   
    return self;
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
    NSDebugLog(@"receivedEvent");
    if (type == ET_RDESC){
	if (wl_display_dispatch(wlconfig->display) == -1) {
	    [NSException raise: NSWindowServerCommunicationException
			format: @"Connection to Wayland Server lost"];
	}
    }
}

- (void) setupRunLoopInputSourcesForMode: (NSString*)mode
{
    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
    int fdWaylandHandle = wl_display_get_fd(wlconfig->display);
    
    [currentRunLoop addEvent: (void*)fdWaylandHandle
			type: ET_RDESC
		     watcher: (id<RunLoopEvents>)self
		     forMode: mode];
}

- (id) initWithAttributes: (NSDictionary *)info
{
    NSDebugLog(@"WaylandServer initWithAttributes");
    [super initWithAttributes: info];
    [self _initWaylandContext];

    [self setupRunLoopInputSourcesForMode: NSDefaultRunLoopMode]; 
    [self setupRunLoopInputSourcesForMode: NSConnectionReplyMode]; 
    [self setupRunLoopInputSourcesForMode: NSModalPanelRunLoopMode]; 
    [self setupRunLoopInputSourcesForMode: NSEventTrackingRunLoopMode]; 

    return self;
}

- (void) dealloc
{
    NSDebugLog(@"Destroying Wayland Server");
    [super dealloc];
}

- (BOOL) handlesWindowDecorations
{
  return NO;
}

- (void) restrictWindow: (int)win toImage: (NSImage*)image
{
    NSDebugLog(@"restrictWindow");
}

- (NSRect) boundsForScreen: (int)screen
{
    NSDebugLog(@"boundsForScreen: %d", screen);
    struct output *output;

    wl_list_for_each(output, &wlconfig->output_list, link) {
	NSDebugLog(@"screen found: %dx%d", output->width, output->height);
	return NSMakeRect(0, 0, output->width, output->height);
    }

    NSDebugLog(@"can't find screen");
    return NSZeroRect;
}

- (NSWindowDepth) windowDepthForScreen: (int)screen
{
    NSDebugLog(@"windowDepthForScreen: %d", screen);
    return (_GSRGBBitValue | 8);
}

- (const NSWindowDepth *) availableDepthsForScreen: (int)screen
{
    NSDebugLog(@"availableDepthsForScreen");
    return NULL;
}

- (NSArray *) screenList
{
    NSDebugLog(@"screenList");
    NSMutableArray *screens =
	[NSMutableArray arrayWithCapacity: wlconfig->output_count];
    struct output *output;

    wl_list_for_each(output, &wlconfig->output_list, link) {
	[screens addObject: [NSNumber numberWithInt: output->server_output_id]];
	NSDebugLog(@"adding screen with output_id=%d", output->server_output_id);
	NSDebugLog(@"output dimensions: %dx%d %dx%d",
		   output->alloc_x, output->alloc_y,
		   output->width, output->height);
    }
    
    return screens;
}

- (void *) serverDevice
{
    NSDebugLog(@"serverDevice");
    return NULL;
}

- (void *) windowDevice: (int)win
{
    NSDebugLog(@"windowDevice");
    return NULL;
}

- (void) beep
{
    NSDebugLog(@"beep");
}

@end


@implementation WaylandServer (WindowOps)

- (int) window: (NSRect)frame : (NSBackingStoreType)type : (unsigned int)style
	      : (int)screen
{
    NSDebugLog(@"window: screen=%d frame=%@", screen, NSStringFromRect(frame));
    struct window *window;
    struct output *output;
    struct wl_surface *wlsurface;
    cairo_surface_t *cairo_surface;
    cairo_t *cr;
    int width;
    int height;
    int altered = 0;
    int window_type = 0;

    /* We're not allowed to create a zero rect window */
    if (NSWidth(frame) <= 0 || NSHeight(frame) <= 0) {
	NSDebugLog(@"trying try create a zero rect window");
	frame.size.width = 2;
	frame.size.height = 2;
    }

    window = malloc(sizeof(struct window));
    memset(window, 0, sizeof(struct window));

    wl_list_for_each(output, &wlconfig->output_list, link) {
	if (output->server_output_id == screen) {
	    window->output = output;
	    break;
	}
    }

    if (!window->output) {
	NSDebugLog(@"can't find screen %d", screen);
	free(window);
	return 0;
    }

    window->wlconfig = wlconfig;
    window->instance = self;
    window->is_out = 0;
    window->width = width = NSWidth(frame);
    window->height = height = NSHeight(frame);
    window->pos_x = frame.origin.x;
    window->pos_y = NSToWayland(window, frame.origin.y);

    wlsurface = wl_compositor_create_surface(wlconfig->compositor);
    if (wlsurface == NULL) {
	NSDebugLog(@"can't create wayland surface");
	return 0;
    }
    /*
    window->shell_surface = wl_shell_get_shell_surface(wlconfig->shell,
						       wlsurface);
    if (window->shell_surface) {
	NSDebugLog(@"shell surface is present");
	wl_shell_surface_add_listener(window->shell_surface,
				      &shell_surface_listener, window);
	wl_shell_surface_set_toplevel(window->shell_surface);
    } else {
	NSDebugLog(@"shell surface is missing");
    }
    */

    if (style & NSMainMenuWindowMask) {
	window->xdg_surface =
	    xdg_shell_get_xdg_surface_special(wlconfig->xdg_shell, wlsurface, 2);
	NSDebugLog(@"window id=%d will be a panel", wlconfig->last_window_id);
    }
    else if (style & NSBackgroundWindowMask)
	window->xdg_surface =
	    xdg_shell_get_xdg_surface_special(wlconfig->xdg_shell, wlsurface, 1);
    else
	window->xdg_surface =
	    xdg_shell_get_xdg_surface_special(wlconfig->xdg_shell, wlsurface, 0);


    xdg_surface_set_user_data(window->xdg_surface, window);
    xdg_surface_add_listener(window->xdg_surface,
			     &xdg_surface_listener, window);

    if (window->pos_x < 0) {
	window->pos_x = 0;
	altered = 1;
    }

#if 0
    if (window->pos_y < 31) {
	window->pos_y = 31;
	altered = 1;
    }
#endif

    NSDebugLog(@"creating new window with id=%d: pos=%fx%f, size=%fx%f",
	       window->window_id, window->pos_x, window->pos_y,
	       window->width, window->height);
    xdg_surface_set_window_geometry(window->xdg_surface,
				    window->pos_x,
				    window->pos_y,
				    window->width,
				    window->height);
    wl_surface_commit(wlsurface);

    wl_surface_set_user_data(wlsurface, window);
    window->surface = wlsurface;

    window->window_id = wlconfig->last_window_id;
    wl_list_insert(wlconfig->window_list.prev, &window->link);
    (wlconfig->last_window_id)++;
    (wlconfig->window_count)++;

    wl_display_dispatch_pending(wlconfig->display);
    wl_display_flush(wlconfig->display);

    [self _setWindowOwnedByServer: (int)window->window_id];

    if (altered) {
	NSEvent *ev = [NSEvent otherEventWithType: NSAppKitDefined
					 location: NSZeroPoint
				    modifierFlags: 0
					timestamp: 0
				     windowNumber: (int)window->window_id
					  context: GSCurrentContext()
					  subtype: GSAppKitWindowMoved
					    data1: window->pos_x
					    data2: WaylandToNS(window, window->pos_y)];
	[(GSWindowWithNumber(window->window_id)) sendEvent: ev];
	NSDebugLog(@"window: notifying of move=%fx%f", window->pos_x, WaylandToNS(window, window->pos_y));
    }


    return window->window_id;
}

- (void) termwindow: (int) win
{
    NSDebugLog(@"termwindow: win=%d", win);
    struct window *window = get_window_with_id(wlconfig, win);

    if (window->xdg_surface) {
	xdg_surface_destroy(window->xdg_surface);
    }

    wl_surface_destroy(window->surface);
    wl_buffer_destroy(window->buffer);
    wl_list_remove(&window->link);

    free(window);
}

- (int) nativeWindow: (void *)winref
		    : (NSRect*)frame
		    : (NSBackingStoreType*)type 
		    : (unsigned int*)style
		    : (int*)screen
{
    NSDebugLog(@"nativeWindow");
    return 0;
}

- (void) stylewindow: (unsigned int) style : (int) win
{
    NSDebugLog(@"stylewindow");
}

- (void) windowbacking: (NSBackingStoreType)type : (int) win
{
    NSDebugLog(@"windowbacking");
}

- (void) titlewindow: (NSString *) window_title : (int) win
{
    NSDebugLog(@"titlewindow: win=%d title=%@", win, window_title);
    if (window_title == @"Window") {
	return;
    }

    struct window *window = get_window_with_id(wlconfig, win);
    const char *cString = [window_title UTF8String];

    xdg_surface_set_title(window->xdg_surface, cString);
}

- (void) miniwindow: (int) win
{
    NSDebugLog(@"miniwindow");
    [self orderwindow: NSWindowOut :0 :win];
}

- (void) setWindowdevice: (int) winId forContext: (NSGraphicsContext *)ctxt
{
    NSDebugLog(@"setWindowdevice: %d", winId);
    struct window *window;

    window = get_window_with_id(wlconfig, winId);

    GSSetDevice(ctxt, window, 0.0, window->height);
    DPSinitmatrix(ctxt);
    DPSinitclip(ctxt);
}

- (void) orderwindow: (int) op : (int) otherWin : (int) win
{
    NSDebugLog(@"orderwindow: %d", win);
    struct window *window = get_window_with_id(wlconfig, win);

    if (op == NSWindowOut) {
	NSDebugLog(@"orderwindow: NSWindowOut");
	//window->pos_x += 32000;
	//window->pos_y += 32000;
	window->is_out = 1;
	xdg_surface_set_window_geometry(window->xdg_surface,
					window->pos_x + 32000,
					window->pos_y + 32000,
					window->width,
					window->height);
	NSRect rect = NSMakeRect(0, 0,
				 window->width, window->height);
	[window->instance flushwindowrect:rect :window->window_id];

	wl_display_dispatch_pending(window->wlconfig->display);
	wl_display_flush(window->wlconfig->display);


	//xdg_surface_set_minimized(window->xdg_surface);
    } else /*if (window->is_out)*/ {
	NSDebugLog(@"orderwindow: restoring to %dx%d", window->pos_x, window->pos_y);
	xdg_surface_set_window_geometry(window->xdg_surface,
					window->pos_x,
					window->pos_y,
					window->width,
					window->height);
	NSRect rect = NSMakeRect(0, 0,
				 window->width, window->height);
	[window->instance flushwindowrect:rect :window->window_id];

	xdg_surface_set_minimized(window->xdg_surface);

	wl_display_dispatch_pending(window->wlconfig->display);
	wl_display_flush(window->wlconfig->display);

	window->is_out = 0;
    }
}

- (void) movewindow: (NSPoint)loc : (int) win
{
    NSDebugLog(@"movewindow");
}


- (NSRect) _OSFrameToWFrame: (NSRect)o for: (void*)win
{
  struct window *window = (struct window *)win;
  NSRect x;

  x.size.width = o.size.width;
  x.size.height = o.size.height;
  x.origin.x = o.origin.x;
  x.origin.y = o.origin.y + o.size.height;
  x.origin.y = window->output->height - x.origin.y;
  return x;
}

- (void) placewindow: (NSRect)rect : (int) win
{
    NSDebugLog(@"placewindow: %d %@", win, NSStringFromRect(rect));
    struct window *window = get_window_with_id(wlconfig, win);
    WaylandConfig *wlconfig = window->wlconfig;

    if (0 && wlconfig->pointer.serial && wlconfig->pointer.focus &&
	wlconfig->pointer.focus->window_id == win) {
	NSEvent *event;
	NSEventType eventType;
	NSPoint eventLocation;
	NSGraphicsContext *gcontext;
	unsigned int eventFlags;
	float deltaX = 0.0;
	float deltaY = 0.0;
	int tick;
	
	gcontext = GSCurrentContext();
	eventLocation = NSMakePoint(wlconfig->pointer.x,
				    window->height - wlconfig->pointer.y);
	eventFlags = 0;
	eventType = NSLeftMouseUp;
	
	tick = 0;
	
	NSDebugLog(@"sending pointer event at: %fx%f, window=%d", wlconfig->pointer.x, wlconfig->pointer.y, window->window_id);
	
	event = [NSEvent mouseEventWithType: eventType
				   location: eventLocation
			      modifierFlags: eventFlags
				  timestamp: (NSTimeInterval) 0
			       windowNumber: (int)window->window_id
				    context: gcontext
				eventNumber: tick
				 clickCount: 1
				   pressure: 1.0
			       buttonNumber: 0 /* FIXME */
				     deltaX: deltaX
				     deltaY: deltaY
				     deltaZ: 0.];

	[GSCurrentServer() postEvent: event atStart: NO];

	xdg_surface_move(window->xdg_surface,
			 wlconfig->seat,
			 wlconfig->pointer.serial);
    } else {
	NSDebugLog(@"placewindow: oldpos=%fx%f", window->pos_x, window->pos_y);
	NSDebugLog(@"placewindow: oldsize=%fx%f", window->width, window->height);
	NSRect frame;
	NSRect wframe;
	BOOL resize = NO;
	BOOL move = NO;

	frame = [(GSWindowWithNumber(window->window_id)) frame];
	if (NSEqualRects(rect, frame) == YES)
	    return;
	if (NSEqualSizes(rect.size, frame.size) == NO) {
	    resize = YES;
	    move = YES;
	}
	if (NSEqualPoints(rect.origin, frame.origin) == NO) {
	    move = YES;
	}

	wframe = [self _OSFrameToWFrame: rect for: window];

	if (wlconfig->pointer.focus &&
	    wlconfig->pointer.focus->window_id == window->window_id) {
	    wlconfig->pointer.y -= (wframe.origin.y - window->pos_y);
	    wlconfig->pointer.x -= (wframe.origin.x - window->pos_x);
	}
	
	window->width = wframe.size.width;
	window->height = wframe.size.height;       
	window->pos_x = wframe.origin.x;
	window->pos_y = wframe.origin.y;

	xdg_surface_set_window_geometry(window->xdg_surface,
					window->pos_x,
					window->pos_y,
					window->width,
					window->height);

	NSRect flushRect = NSMakeRect(0, 0,
				      window->width, window->height);
	[window->instance flushwindowrect:rect :window->window_id];
	
	wl_display_dispatch_pending(window->wlconfig->display);
	wl_display_flush(window->wlconfig->display);

	if (resize == YES) {
	    NSEvent *ev = [NSEvent otherEventWithType: NSAppKitDefined
					     location: rect.origin
					modifierFlags: 0
					    timestamp: 0
					 windowNumber: win
					      context: GSCurrentContext()
					      subtype: GSAppKitWindowResized
						data1: rect.size.width
						data2: rect.size.height];
	    [(GSWindowWithNumber(window->window_id)) sendEvent: ev];
	    NSDebugLog(@"placewindow notify resized=%fx%f", rect.size.width, rect.size.height);
	} else if (move == YES) {
	    NSEvent *ev = [NSEvent otherEventWithType: NSAppKitDefined
					     location: NSZeroPoint
					modifierFlags: 0
					    timestamp: 0
					 windowNumber: (int)window->window_id
					      context: GSCurrentContext()
					      subtype: GSAppKitWindowMoved
						data1: rect.origin.x
						data2: rect.origin.y];
	    [(GSWindowWithNumber(window->window_id)) sendEvent: ev];
	    NSDebugLog(@"placewindow notify moved=%fx%f", rect.origin.x, rect.origin.y);
	}
	    
	NSDebugLog(@"placewindow: newpos=%fx%f", window->pos_x, window->pos_y);
	NSDebugLog(@"placewindow: newsize=%fx%f", window->width, window->height);
    }
}

- (NSRect) windowbounds: (int) win
{
    struct window *window = get_window_with_id(wlconfig, win);
    NSDebugLog(@"windowbounds: win=%d, pos=%dx%d size=%dx%d",
	       window->window_id, window->pos_x, window->pos_y,
	       window->width, window->height);
    
    return NSMakeRect(window->pos_x, window->output->height - window->pos_y,
		      window->width, window->height);
}

- (void) setwindowlevel: (int) level : (int) win
{
    NSDebugLog(@"setwindowlevel: level=%d win=%d", level, win);
}

- (int) windowlevel: (int) win
{
    NSDebugLog(@"windowlevel: %d", win);
    return 0;
}

/** Backends can override this method to return an array of window numbers 
    ordered front to back.  The front most window being the first object
    in the array.  
    The default implementation returns the visible windows in an
    unspecified order.
 */
- (NSArray *) windowlist
{
  NSMutableArray *list = [NSMutableArray arrayWithArray:[NSApp windows]];
  int c = [list count];

  while (c-- > 0)
    {
       if (![[list objectAtIndex:c] isVisible])
         {
	   [list removeObjectAtIndex:c];
         }
    }
  return [list valueForKey:@"windowNumber"];
}

- (int) windowdepth: (int) win
{
    NSDebugLog(@"windowdepth");
    return 0;
}

- (void) setmaxsize: (NSSize)size : (int) win
{
    NSDebugLog(@"setmaxsize");
}

- (void) setminsize: (NSSize)size : (int) win
{
    NSDebugLog(@"setminsize");
}

- (void) setresizeincrements: (NSSize)size : (int) win
{
    NSDebugLog(@"setresizeincrements");
}

- (void) flushwindowrect: (NSRect)rect : (int) win
{
    NSDebugLog(@"flushwindowrect: %d %fx%f", win, NSWidth(rect), NSHeight(rect));
    struct window *window = get_window_with_id(wlconfig, win);

    [[GSCurrentContext() class] handleExposeRect: rect forDriver: window->wcs];
}

- (void) styleoffsets: (float*) l : (float*) r : (float*) t : (float*) b 
		     : (unsigned int) style
{
    NSDebugLog(@"styleoffsets");
    /* XXX - Assume we don't decorations */
    *l = *r = *t = *b = 0.0;
}

- (void) docedited: (int) edited : (int) win
{
    NSDebugLog(@"docedited");
}

- (void) setinputstate: (int)state : (int)win
{
    NSDebugLog(@"setinputstate");
}

- (void) setinputfocus: (int) win
{
    NSDebugLog(@"setinputfocus");
}

- (void) setalpha: (float)alpha : (int) win
{
    NSDebugLog(@"setalpha");
}

- (void) setShadow: (BOOL)hasShadow : (int)win
{
    NSDebugLog(@"setshadow");
}

- (NSPoint) mouselocation
{
    NSDebugLog(@"mouselocation");
    return NSZeroPoint;
}

- (NSPoint) mouseLocationOnScreen: (int)aScreen window: (int *)win
{
    NSDebugLog(@"mouseLocationOnScreen: %d %fx%f", win,
	       wlconfig->pointer.x, wlconfig->pointer.y);
    struct window *window = wlconfig->pointer.focus;
    struct output *output;
    float x;
    float y;

    /*if (wlconfig->pointer.serial) {
	NSDebugLog(@"captured");
	x = wlconfig->pointer.captured_x;
	y = wlconfig->pointer.captured_y;
	} else*/ {
	NSDebugLog(@"NOT captured");
	x = wlconfig->pointer.x;
	y = wlconfig->pointer.y;
	
	if (window) {
	    x += window->pos_x;
	    y += window->pos_y;
	    win = &window->window_id;
	}	
    }

    wl_list_for_each(output, &wlconfig->output_list, link) {
	if (output->server_output_id == aScreen) {
	    y = output->height - y;
	    break;
	}
    }

    NSDebugLog(@"mouseLocationOnScreen: returning %fx%f", x, y);
    
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

- (void) setParentWindow: (int)parentWin 
          forChildWindow: (int)childWin
{
    NSDebugLog(@"setParentWindow: parent=%d child=%d", parentWin, childWin);
    struct window *parent = get_window_with_id(wlconfig, parentWin);
    struct window *child = get_window_with_id(wlconfig, childWin);

    if (parent) {
	xdg_surface_set_parent(child->xdg_surface, parent->xdg_surface);
    } else {
	xdg_surface_set_parent(child->xdg_surface, NULL);
    }
    xdg_surface_set_minimized(child->xdg_surface);
    wl_display_dispatch_pending(wlconfig->display);
    wl_display_flush(wlconfig->display);
}

- (void) setIgnoreMouse: (BOOL)ignoreMouse : (int)win
{
    NSDebugLog(@"setIgnoreMouse");
}

@end
