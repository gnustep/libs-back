#include "wayland/WaylandServer.h"
#include <AppKit/NSEvent.h>
#include <AppKit/NSApplication.h>

static void
xdg_surface_on_configure(void *data, struct xdg_surface *xdg_surface,
			 uint32_t serial)
{
    struct window *window = data;

    NSDebugLog(@"xdg_surface_on_configure: win=%d", window->window_id);

    if(window->terminated == YES) {
        NSDebugLog(@"deleting window win=%d", window->window_id);
        free(window);
        return;
    }
    WaylandConfig *wlconfig = window->wlconfig;

    NSEvent *ev = nil;
    NSWindow *nswindow = GSWindowWithNumber(window->window_id);

    NSDebugLog(@"Acknowledging surface configure %p %d (window_id=%d)", xdg_surface, serial, window->window_id);
    xdg_surface_ack_configure(xdg_surface, serial);
    window->configured = YES;


    if(window->buffer_needs_attach) {
        NSDebugLog(@"attach: win=%d toplevel", window->window_id);
        wl_surface_attach(window->surface, window->buffer, 0, 0);
        wl_surface_commit(window->surface);
    }


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

static void xdg_popup_configure(void *data, struct xdg_popup *xdg_popup,
		int32_t x, int32_t y, int32_t width, int32_t height) {
    struct window *window = data;
    WaylandConfig *wlconfig = window->wlconfig;

    window->width = width;
    window->height = height;


}

static void xdg_popup_done(void *data, struct xdg_popup *xdg_popup) {
    struct window *window = data;
    WaylandConfig *wlconfig = window->wlconfig;
	xdg_popup_destroy(xdg_popup);

	wl_surface_destroy(window->surface);
}

static void wm_base_handle_ping(void *data, struct xdg_wm_base *xdg_wm_base,
		uint32_t serial)
{
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
