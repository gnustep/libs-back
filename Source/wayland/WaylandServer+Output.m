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

//  XXX - Should we implement this?
//        if (display->output_configure_handler)
//            (*display->output_configure_handler)
//            (output, display->user_data);
//
    }

}

/*
static void
destroy_output(WaylandConfig *wlconfig, uint32_t id)
{
    struct output *output;

    wl_list_for_each(output, &wlconfig->output_list, link) {
	if (output->server_output_id == id) {
	    wl_output_destroy(output->output);
	    wl_list_remove(&output->link);
	    free(output);
	    wlconfig->output_count--;
	    break;
	}
    }
}
*/

const struct wl_output_listener output_listener = {
    handle_geometry,
    handle_mode,
    handle_done,
    handle_scale
};
