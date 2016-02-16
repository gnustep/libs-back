/* <title>WaylandServer</title>

   <abstract>Backend server using Wayland.</abstract>

   Copyright (C) 2016 Sergio L. Pascual <slp@sinrega.org>
*/

#ifndef _WaylandServer_h_INCLUDE
#define _WaylandServer_h_INCLUDE

#include "config.h"

#include <GNUstepGUI/GSDisplayServer.h>
#include <wayland-client.h>
#include <cairo/cairo.h>
#include <xkbcommon/xkbcommon.h>

#include "cairo/WaylandCairoSurface.h"
#include "wayland/xdg-shell-unstable-v5-client-protocol.h"

struct pointer {
    struct wl_pointer *wlpointer;
    float x;
    float y;
    uint32_t last_click_button;
    uint32_t last_click_time;
    float last_click_x;
    float last_click_y;

    uint32_t serial;
    struct window *focus;
};

typedef struct _WaylandConfig {
    struct wl_display *display;
    struct wl_registry *registry;
    struct wl_compositor *compositor;
    struct wl_shell *shell;
    struct xdg_shell *xdg_shell;
    struct wl_shm *shm;
    struct wl_seat *seat;
    struct wl_keyboard *keyboard;
    struct wl_surface *surface;
    struct wl_shell_surface *shell_surface;
    struct wl_buffer *buffer;
    
    struct wl_list output_list;
    int output_count;
    struct wl_list window_list;
    int window_count;
    int last_window_id;

    struct pointer pointer;
    struct xkb_context *xkb_context;
    struct {
        struct xkb_keymap *keymap;
        struct xkb_state *state;
        xkb_mod_mask_t control_mask;
        xkb_mod_mask_t alt_mask;
        xkb_mod_mask_t shift_mask;
    } xkb;
    int modifiers;

    int seat_version;
} WaylandConfig;

struct output {
    WaylandConfig *wlconfig;
    struct wl_output *output;
    uint32_t server_output_id;
    struct wl_list link;
    int alloc_x;
    int alloc_y;
    int width;
    int height;
    int transform;
    int scale;
    char *make;
    char *model;

    //display_output_handler_t destroy_handler;
    void *user_data;
};

struct window {
    WaylandConfig *wlconfig;
    id instance;
    int window_id;
    struct wl_list link;

    float pos_x;
    float pos_y;
    float width;
    float height;
    float saved_pos_x;
    float saved_pos_y;
    int is_out;

    unsigned char *data;
    struct wl_surface *surface;
    struct wl_buffer *buffer;
    struct wl_shell_surface *shell_surface;
    struct xdg_surface *xdg_surface;
    struct output *output;
    WaylandCairoSurface *wcs;
};


cairo_surface_t *
create_shm_buffer(struct window *window);

@interface WaylandServer : GSDisplayServer
{
    WaylandConfig *wlconfig;
}
@end

#endif /* _XGServer_h_INCLUDE */
