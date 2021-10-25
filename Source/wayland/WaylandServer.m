/* -*- mode:ObjC -*-
   WaylandServer - Wayland Server Class

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author: Sergio L. Pascual <slp@sinrega.org>
   Date: February 2016

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

#include "config.h"
#include <AppKit/AppKitExceptions.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/DPSOperators.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSAnimation.h>
#include <GNUstepGUI/GSAnimator.h>
#include <AppKit/NSText.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSValue.h>

#include <unistd.h>
#include <xkbcommon/xkbcommon.h>
#include <linux/input.h>
#include <sys/mman.h>

#include "wayland/WaylandServer.h"


extern const struct wl_output_listener output_listener;

extern const struct wl_seat_listener seat_listener;

static void
shm_format(void *data, struct wl_shm *wl_shm, uint32_t format)
{
}

struct wl_shm_listener shm_listener = {
        shm_format
};


extern const struct xdg_surface_listener xdg_surface_listener;

extern const struct xdg_wm_base_listener wm_base_listener;

extern const struct zwlr_layer_surface_v1_listener layer_surface_listener;

extern const struct xdg_popup_listener xdg_popup_listener;


static void
handle_global(void *data, struct wl_registry *registry,
	      uint32_t name, const char *interface, uint32_t version)
{
    WaylandConfig *wlconfig = data;

    NSDebugLog(@"wayland: registering interface '%s'", interface);
    if (strcmp(interface, xdg_wm_base_interface.name) == 0) {
        wlconfig->wm_base = wl_registry_bind(registry, name,
					     &xdg_wm_base_interface, 1);
        xdg_wm_base_add_listener(wlconfig->wm_base, &wm_base_listener, NULL);
        NSDebugLog(@"wayland: found wm_base interface");
    } else if (strcmp(interface, wl_shell_interface.name) == 0) {
        wlconfig->shell = wl_registry_bind(registry, name,
					   &wl_shell_interface, 1);
        NSDebugLog(@"wayland: found shell interface");
    } else if (strcmp(interface, wl_compositor_interface.name) == 0) {
        wlconfig->compositor = wl_registry_bind(registry, name,
						&wl_compositor_interface, 1);
        NSDebugLog(@"wayland: found compositor interface");
    } else if (strcmp(interface, wl_shm_interface.name) == 0) {
        wlconfig->shm = wl_registry_bind(registry, name,
					 &wl_shm_interface, 1);
        NSDebugLog(@"wayland: found shm interface");
        wl_shm_add_listener(wlconfig->shm, &shm_listener, wlconfig);
    } else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
        wlconfig->layer_shell = wl_registry_bind(registry, name,
			&zwlr_layer_shell_v1_interface, 1);
        NSDebugLog(@"wayland: found wlr-layer_shell interface");
    } else if (strcmp(interface, wl_output_interface.name) == 0) {
	struct output *output = (struct output *)malloc(sizeof(struct output));
	memset(output, 0, sizeof(struct output));
	output->wlconfig = wlconfig;
	output->scale = 1;
	output->output = wl_registry_bind(registry, name, &wl_output_interface, 2);
	output->server_output_id = name;
        NSDebugLog(@"wayland: found output interface");
	wl_list_insert(wlconfig->output_list.prev, &output->link);
	wlconfig->output_count++;
	wl_output_add_listener(output->output, &output_listener, output);
    } else if (strcmp(interface, wl_seat_interface.name) == 0) {
	wlconfig->pointer.wlpointer = NULL;
	wlconfig->seat_version = version;
	wlconfig->seat = wl_registry_bind(wlconfig->registry, name,
					  &wl_seat_interface, 1);
        NSDebugLog(@"wayland: found seat interface");
	wl_seat_add_listener(wlconfig->seat, &seat_listener, wlconfig);
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
    wlconfig->mouse_scroll_multiplier = 1.0f;
    wl_list_init(&wlconfig->output_list);
    wl_list_init(&wlconfig->window_list);

    wlconfig->display = wl_display_connect(NULL);
    if (!wlconfig->display) {
	[NSException raise: NSWindowServerCommunicationException
		    format: @"Unable to connect Wayland Server"];
    }

    wlconfig->registry = wl_display_get_registry(wlconfig->display);
    if (!wlconfig->registry) {
	[NSException raise: NSWindowServerCommunicationException
		    format: @"Unable to get global registry"];
    }
    wl_registry_add_listener(wlconfig->registry,
			     &registry_listener, wlconfig);

    wl_display_dispatch(wlconfig->display);
    wl_display_roundtrip(wlconfig->display);

    if (!wlconfig->compositor) {
	[NSException raise: NSWindowServerCommunicationException
		    format: @"Unable to get compositor"];
    }
    if (!wlconfig->wm_base) {
        /* Note: this was merged into Weston only as of Feb 2019, and is
           probably in Weston only as of 6.0 release, therefore not in Weston
           5.x present in Debian buster (current stable). See Weston merge request
           !103. */
	[NSException raise: NSWindowServerCommunicationException
		    format: @"Unable to get xdg-shell / xdg_wm_base - your Wayland compositor must support the stable XDG Shell protocol"];
    }

    return self;
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
    if (type == ET_RDESC){
//	NSDebugLog(@"receivedEvent ET_RDESC");
	if (wl_display_dispatch(wlconfig->display) == -1) {
	    [NSException raise: NSWindowServerCommunicationException
			format: @"Connection to Wayland Server lost"];
	}
    }
}

- (void) setupRunLoopInputSourcesForMode: (NSString*)mode
{
    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
    long fdWaylandHandle = wl_display_get_fd(wlconfig->display);

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
    int width;
    int height;
    int altered = 0;

    /* We're not allowed to create a zero rect window */
    if (NSWidth(frame) <= 0 || NSHeight(frame) <= 0) {
	NSDebugLog(@"trying to create a zero rect window");
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
    window->window_id = wlconfig->last_window_id;
    window->xdg_surface = NULL;
    window->toplevel = NULL;
    window->configured = NO;
    window->buffer_needs_attach = NO;
    window->terminated = NO;

#if 0
    if (style & NSMiniWindowMask) {
	NSDebugLog(@"----> window id=%d will be a NSMiniWindowMask", window->window_id);
    } else if (style & NSIconWindowMask) {
	NSDebugLog(@"----> window id=%d will be a NSIconWindowMask", window->window_id);
    } else if (style & NSBorderlessWindowMask) {
	NSDebugLog(@"----> window id=%d will be a NSBorderlessWindowMask", window->window_id);
    } else {
	NSDebugLog(@"----> window id=%d will be ordinary", window->window_id);
    }
#endif

    // FIXME is this needed?
    if (window->pos_x < 0) {
	window->pos_x = 0;
	altered = 1;
    }


    NSDebugLog(@"creating new window with id=%d: pos=%fx%f, size=%fx%f",
	       window->window_id, window->pos_x, window->pos_y,
	       window->width, window->height);

    wl_list_insert(wlconfig->window_list.prev, &window->link);
    wlconfig->last_window_id++;
    wlconfig->window_count++;


    // creates a buffer for the window
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
- (void) makeWindowTopLevelIfNeeded: (int) win
{
	NSDebugLog(@"makeWindowTopLevelIfNeeded %d", win);
    struct window *window = get_window_with_id(wlconfig, win);

    if(window->toplevel != NULL || window->layer_surface != NULL) {
        return;
    }

    if(window->surface == NULL) {
        window->surface = wl_compositor_create_surface(wlconfig->compositor);
        if (!window->surface) {
        NSDebugLog(@"can't create wayland surface");
        free(window);
        return;
        }
        wl_surface_set_user_data(window->surface, window);
    }
    if(window->xdg_surface == NULL) {
        window->xdg_surface =
        xdg_wm_base_get_xdg_surface(wlconfig->wm_base, window->surface);
        window->toplevel = xdg_surface_get_toplevel(window->xdg_surface);

        xdg_surface_add_listener(window->xdg_surface,
                    &xdg_surface_listener, window);

        xdg_surface_set_window_geometry(window->xdg_surface,
                        window->pos_x,
                        window->pos_y,
                        window->width,
                        window->height);
    }
    //NSDebugLog(@"wl_surface_commit: win=%d toplevel", window->window_id);
    wl_surface_commit(window->surface);
	wl_display_dispatch_pending(window->wlconfig->display);
	wl_display_flush(window->wlconfig->display);
}
- (void) termwindow: (int) win
{
    NSDebugLog(@"termwindow: win=%d", win);
    struct window *window = get_window_with_id(wlconfig, win);

    if(window->xdg_surface) {
        //destroy_xdg_surface(window->xdg_surface);
    }
    wl_surface_destroy(window->surface);
    wl_buffer_destroy(window->buffer);
    wl_list_remove(&window->link);
    window->terminated = YES;
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

    if(window->toplevel) {
        xdg_toplevel_set_title(window->toplevel, cString);
    }
}

- (void) miniwindow: (int) win
{
    NSDebugLog(@"miniwindow");
//	xdg_toplevel_set_minimized(window->toplevel);
//    [self orderwindow: NSWindowOut :0 :win];
}

- (void) setWindowdevice: (int) winId forContext: (NSGraphicsContext *)ctxt
{
    // creates a new shm buffer
    NSDebugLog(@"creating a new shm buffer: %d", winId);
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
        if(window->layer_surface) {
            zwlr_layer_surface_v1_destroy(window->layer_surface);
            wl_surface_destroy(window->surface);
            window->surface = NULL;
            window->layer_surface = NULL;
            window->configured = NO;
            window->is_out = 1;
        }
        if(window->xdg_surface) {
        xdg_surface_set_window_geometry(window->xdg_surface,
                        window->pos_x + 32000,
                        window->pos_y + 32000,
                        window->width,
                        window->height);
        }
        NSRect rect = NSMakeRect(0, 0,
                    window->width, window->height);
        [window->instance flushwindowrect:rect :window->window_id];
        if(window->toplevel != NULL) {
            xdg_toplevel_set_minimized(window->toplevel);
        }

        wl_display_dispatch_pending(window->wlconfig->display);
        wl_display_flush(window->wlconfig->display);
    } else /*if (window->is_out)*/ {
        NSDebugLog(@"orderwindow: %d restoring to %fx%f", win, window->pos_x, window->pos_y);
        [self makeWindowShell: win];
	NSRect rect = NSMakeRect(0, 0,
				 window->width, window->height);
	[window->instance flushwindowrect:rect :window->window_id];

//	xdg_toplevel_set_minimized(window->toplevel);
//	xdg_toplevel_set_fullscreen(window->toplevel, window->output);

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
    WaylandConfig *config = window->wlconfig;

    if(window->toplevel == NULL && !window->layer_surface) {
        [self makeWindowShell: win];
    }
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

	if (config->pointer.focus &&
	    config->pointer.focus->window_id == window->window_id) {
	    config->pointer.y -= (wframe.origin.y - window->pos_y);
	    config->pointer.x -= (wframe.origin.x - window->pos_x);
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
    wl_surface_commit(window->surface);
/*
	NSRect flushRect = NSMakeRect(0, 0,
				      window->width, window->height);
*/
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
	    NSDebugLog(@"notify resize=%fx%f", rect.size.width, rect.size.height);
	    [(GSWindowWithNumber(window->window_id)) sendEvent: ev];
	    NSDebugLog(@"notified resize=%fx%f", rect.size.width, rect.size.height);
        // we have a new buffer
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

- (NSRect) windowbounds: (int) win
{
    struct window *window = get_window_with_id(wlconfig, win);
    NSDebugLog(@"windowbounds: win=%d, pos=%dx%d size=%dx%d",
	       window->window_id, window->pos_x, window->pos_y,
	       window->width, window->height);

    return NSMakeRect(window->pos_x, window->output->height - window->pos_y,
		      window->width, window->height);
}

- (void) makeMainMenu: (int) win
{
    struct window *window = get_window_with_id(wlconfig, win);
	char *namespace = "wlroots";
    if(!wlconfig->layer_shell) {
        return;
    }
    if(window->surface == NULL) {
        window->surface = wl_compositor_create_surface(wlconfig->compositor);
        wl_surface_set_user_data(window->surface, window);
    }

    if(window->layer_surface == NULL) {
        window->layer_surface = zwlr_layer_shell_v1_get_layer_surface(
                wlconfig->layer_shell,
                window->surface,
                window->output->output,
                ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY,
                namespace);
        assert(window->layer_surface);
        zwlr_layer_surface_v1_set_size(window->layer_surface,
                window->width, window->height);
        zwlr_layer_surface_v1_set_anchor(window->layer_surface,
                ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP);
        zwlr_layer_surface_v1_set_exclusive_zone(window->layer_surface, 1);
        zwlr_layer_surface_v1_set_margin(window->layer_surface,
                0, 0, 0, 0);
        zwlr_layer_surface_v1_add_listener(window->layer_surface,
                &layer_surface_listener, window);
    }
	wl_surface_commit(window->surface);
	wl_display_roundtrip(wlconfig->display);
}
- (void) makeSubMenu: (int) win
{
    struct window *window = get_window_with_id(wlconfig, win);
    if(!wlconfig->layer_shell) {
        return;
    }
	char *namespace = "wlroots";
    if(window->surface == NULL) {
        window->surface = wl_compositor_create_surface(wlconfig->compositor);
        wl_surface_set_user_data(window->surface, window);
    }
    if(window->layer_surface == NULL) {
        window->layer_surface = zwlr_layer_shell_v1_get_layer_surface(
                wlconfig->layer_shell,
                window->surface,
                window->output->output,
                ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY,
                namespace);

        zwlr_layer_surface_v1_set_size(window->layer_surface,
                window->width, window->height);
        zwlr_layer_surface_v1_set_anchor(window->layer_surface,
                ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT);
        zwlr_layer_surface_v1_set_exclusive_zone(window->layer_surface, 1);
        zwlr_layer_surface_v1_set_margin(window->layer_surface,
                window->pos_y, 0, 0, window->pos_x);

        zwlr_layer_surface_v1_add_listener(window->layer_surface,
                &layer_surface_listener, window);
    }

	wl_surface_commit(window->surface);
	wl_display_roundtrip(wlconfig->display);
}

- (void) makeWindowShell: (int) win
{
    NSLog(@"makeWindowShell %d", win);
    struct window *window = get_window_with_id(wlconfig, win);
    switch(window->level) {
        case NSMainMenuWindowLevel:
            NSDebugLog(@"NSMainMenuWindowLevel win=%d", win);
            [self makeMainMenu: win];
        break;
        case NSSubmenuWindowLevel:
            NSDebugLog(@"NSSubmenuWindowLevel win=%d", win);
            [self makeSubMenu: win];
        break;
        case NSDesktopWindowLevel:
            NSDebugLog(@"NSDesktopWindowLevel win=%d", win);
        break;
        case NSStatusWindowLevel:
            NSDebugLog(@"NSStatusWindowLevel win=%d", win);
        break;
        case NSPopUpMenuWindowLevel:
            NSDebugLog(@"NSPopUpMenuWindowLevel win=%d", win);
        break;
        case NSScreenSaverWindowLevel:
            NSDebugLog(@"NSScreenSaverWindowLevel win=%d", win);
        break;
        case NSFloatingWindowLevel:
            NSDebugLog(@"NSFloatingWindowLevel win=%d", win);
        case NSModalPanelWindowLevel:
            NSDebugLog(@"NSModalPanelWindowLevel win=%d", win);
        case NSNormalWindowLevel:
            NSDebugLog(@"NSNormalWindowLevel win=%d", win);
            [self makeWindowTopLevelIfNeeded: win];

        break;
    }
}

- (void) setwindowlevel: (int) level : (int) win
{
    struct window *window = get_window_with_id(wlconfig, win);
    window->level = level;

    NSDebugLog(@"setwindowlevel: level=%d win=%d", level, win);
    [self makeWindowShell: win];
}

- (int) windowlevel: (int) win
{
    NSDebugLog(@"windowlevel: %d", win);
    struct window *window = get_window_with_id(wlconfig, win);
    return window->level;
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
//    NSDebugLog(@"flushwindowrect: %d %fx%f", win, NSWidth(rect), NSHeight(rect));
    struct window *window = get_window_with_id(wlconfig, win);

    [[GSCurrentContext() class] handleExposeRect: rect forDriver: window->wcs];
    // [(CairoSurface *)driver handleExposeRect: rect];
}

- (void) styleoffsets: (float*) l : (float*) r : (float*) t : (float*) b
		     : (unsigned int) style
{
    NSDebugLog(@"styleoffsets");
    /* XXX - Assume we don't decorate */
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

- (void) setParentWindow: (int)parentWin
          forChildWindow: (int)childWin
{
    NSDebugLog(@"setParentWindow: parent=%d child=%d", parentWin, childWin);
    struct window *parent = get_window_with_id(wlconfig, parentWin);
    struct window *child = get_window_with_id(wlconfig, childWin);

    if(!child->toplevel) {
        return;
    }
    if (parent) {
        if(!parent->toplevel) {
            return;
        }
        xdg_toplevel_set_parent(child->toplevel, parent->toplevel);
    } else {
        xdg_toplevel_set_parent(child->toplevel, NULL);
    }
    xdg_toplevel_set_minimized(child->toplevel);
    wl_display_dispatch_pending(wlconfig->display);
    wl_display_flush(wlconfig->display);
}




@end
