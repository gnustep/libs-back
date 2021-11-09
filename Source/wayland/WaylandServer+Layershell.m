#include "wayland/WaylandServer.h"
#include <AppKit/NSEvent.h>
#include <AppKit/NSApplication.h>

static void layer_surface_configure(void *data,
		struct zwlr_layer_surface_v1 *surface,
		uint32_t serial, uint32_t w, uint32_t h) {

    struct window *window = data;
    NSDebugLog(@"[%d] layer_surface_configure", window->window_id);
    WaylandConfig *wlconfig = window->wlconfig;
	zwlr_layer_surface_v1_ack_configure(surface, serial);
    window->configured = YES;
    if(window->buffer_needs_attach) {
        NSDebugLog(@"attach: win=%d layer", window->window_id);
        wl_surface_attach(window->surface, window->buffer, 0, 0);
        wl_surface_commit(window->surface);
    }

}

static void layer_surface_closed(void *data,
		struct zwlr_layer_surface_v1 *surface) {
    struct window *window = data;
    WaylandConfig *wlconfig = window->wlconfig;
    NSDebugLog(@"layer_surface_closed %d", window->window_id);
	//zwlr_layer_surface_v1_destroy(surface);
	wl_surface_destroy(window->surface);
    window->surface = NULL;
    window->configured = NO;
    window->layer_surface = NULL;
}

const struct zwlr_layer_surface_v1_listener layer_surface_listener = {
	.configure = layer_surface_configure,
	.closed = layer_surface_closed,
};

