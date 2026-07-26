/* xlibimage.c - plain-Xlib implementation of the wraster subset used by the
 * GNUstep X11 backend. See Headers/x11/xlibimage.h. No MIT-SHM and no
 * PseudoColor StandardColormap machinery: images use XCreateImage/XGetImage/
 * XPutImage, and non-TrueColor colour is resolved by the X server through
 * XAllocColor.
 */
#ifndef SKIP_CONFIG_H
#include <config.h>
#endif

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdlib.h>
#include <string.h>

#include "x11/xlibimage.h"

/* Number of low zero bits in mask == bit offset of the channel field. */
static int
count_offset(unsigned long mask)
{
    int i = 0;
    while (mask != 0 && (mask & 1) == 0) {
        i++;
        mask >>= 1;
    }
    return i;
}

/* Scale an 8-bit component (0..255) into a field whose maximum value is
 * maxval (== mask >> offset), rounding to nearest. */
static unsigned long
scale_component(unsigned int v8, unsigned long maxval)
{
    if (maxval == 0)
        return 0;
    if (maxval == 255)
        return v8;
    return (unsigned long)((v8 * maxval + 127) / 255);
}

RContext *
RCreateContext(Display *dpy, int screen_number, RContextAttributes *attribs)
{
    RContext *context;
    XGCValues gcv;

    context = malloc(sizeof(RContext));
    if (!context)
        return NULL;
    memset(context, 0, sizeof(RContext));

    context->attribs = malloc(sizeof(RContextAttributes));
    if (!context->attribs) {
        free(context);
        return NULL;
    }
    if (attribs) {
        *context->attribs = *attribs;
    } else {
        memset(context->attribs, 0, sizeof(RContextAttributes));
        context->attribs->render_mode = RDitheredRendering;
        context->attribs->colors_per_channel = 4;
        context->attribs->standard_colormap_mode = RUseStdColormap;
    }
    /* This build never uses shared memory. */
    context->attribs->use_shared_memory = False;
    context->attribs->flags &= ~RC_UseSharedMemory;

    context->dpy = dpy;
    context->screen_number = screen_number;
    context->visual = DefaultVisual(dpy, screen_number);
    context->depth = DefaultDepth(dpy, screen_number);
    context->cmap = DefaultColormap(dpy, screen_number);
    context->drawable = RootWindow(dpy, screen_number);
    context->black = BlackPixel(dpy, screen_number);
    context->white = WhitePixel(dpy, screen_number);
    context->vclass = context->visual->class;

    gcv.function = GXcopy;
    gcv.graphics_exposures = False;
    context->copy_gc = XCreateGC(dpy, context->drawable,
                                 GCFunction | GCGraphicsExposures, &gcv);

    if (context->vclass == TrueColor) {
        context->red_offset = count_offset(context->visual->red_mask);
        context->green_offset = count_offset(context->visual->green_mask);
        context->blue_offset = count_offset(context->visual->blue_mask);
    }

    context->std_rgb_map = NULL;
    context->std_gray_map = NULL;
    context->ncolors = 0;
    context->colors = NULL;
    context->pixels = NULL;
    context->flags.use_shared_pixmap = 0;
    context->flags.optimize_for_speed = 0;
    context->hermes_data = NULL;

    return context;
}

void
RDestroyContext(RContext *context)
{
    if (!context)
        return;
    if (context->copy_gc)
        XFreeGC(context->dpy, context->copy_gc);
    if (context->attribs)
        free(context->attribs);
    free(context);
}

Bool
RGetClosestXColor(RContext *context, RColor *color, XColor *retColor)
{
    retColor->red   = (unsigned short)color->red   << 8;
    retColor->green = (unsigned short)color->green << 8;
    retColor->blue  = (unsigned short)color->blue  << 8;
    retColor->flags = DoRed | DoGreen | DoBlue;

    if (context->vclass == TrueColor) {
        Visual *v = context->visual;
        unsigned long rmax = v->red_mask   >> context->red_offset;
        unsigned long gmax = v->green_mask >> context->green_offset;
        unsigned long bmax = v->blue_mask  >> context->blue_offset;

        retColor->pixel =
            ((scale_component(color->red,   rmax) << context->red_offset)
                 & v->red_mask) |
            ((scale_component(color->green, gmax) << context->green_offset)
                 & v->green_mask) |
            ((scale_component(color->blue,  bmax) << context->blue_offset)
                 & v->blue_mask);
        return True;
    }

    /* PseudoColor / StaticColor / GrayScale / StaticGray: let the server
     * pick the closest allocatable pixel. */
    if (XAllocColor(context->dpy, context->cmap, retColor))
        return True;

    retColor->pixel = context->black;
    return False;
}

RXImage *
RCreateXImage(RContext *context, int depth,
              unsigned int width, unsigned int height)
{
    RXImage *rximg = malloc(sizeof(RXImage));
    if (!rximg)
        return NULL;

    rximg->image = XCreateImage(context->dpy, context->visual, depth,
                                ZPixmap, 0, NULL, width, height, 8, 0);
    if (!rximg->image) {
        free(rximg);
        return NULL;
    }
    rximg->image->data = malloc(rximg->image->bytes_per_line * height);
    if (!rximg->image->data) {
        XDestroyImage(rximg->image);
        free(rximg);
        return NULL;
    }
    return rximg;
}

RXImage *
RGetXImage(RContext *context, Drawable d, int x, int y,
           unsigned int width, unsigned int height)
{
    RXImage *ximg = malloc(sizeof(RXImage));
    if (!ximg)
        return NULL;
    ximg->image = XGetImage(context->dpy, d, x, y, width, height,
                            AllPlanes, ZPixmap);
    if (!ximg->image) {
        free(ximg);
        return NULL;
    }
    return ximg;
}

void
RPutXImage(RContext *context, Drawable d, GC gc, RXImage *ximage,
           int src_x, int src_y, int dest_x, int dest_y,
           unsigned int width, unsigned int height)
{
    XPutImage(context->dpy, d, gc, ximage->image, src_x, src_y,
              dest_x, dest_y, width, height);
}

void
RDestroyXImage(RContext *context, RXImage *ximage)
{
    (void)context;
    if (!ximage)
        return;
    if (ximage->image)
        XDestroyImage(ximage->image);
    free(ximage);
}
