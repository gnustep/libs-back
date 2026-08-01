/* xlibimage.h - plain-Xlib replacement for the subset of the Window Maker
 * raster (wraster) API used by the GNUstep X11 server and xlib graphics
 * backend. Compiled in place of wraster when the backend is configured
 * without wraster (USE_WRASTER == 0). Field and function names match
 * wraster.h so the backend call sites are identical under either build.
 */
#ifndef _xlibimage_h_INCLUDE
#define _xlibimage_h_INCLUDE

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#ifdef XSHM
#include <X11/extensions/XShm.h>
#endif

/* RContextAttributes flag bits (values match wraster.h). */
#define RC_RenderMode        (1<<0)
#define RC_ColorsPerChannel  (1<<1)
#define RC_GammaCorrection   (1<<2)
#define RC_VisualID          (1<<3)
#define RC_UseSharedMemory   (1<<4)
#define RC_DefaultVisual     (1<<5)
#define RC_ScalingFilter     (1<<6)
#define RC_StandardColormap  (1<<7)

/* render_mode values (match wraster.h). */
enum { RDitheredRendering = 0, RBestMatchRendering = 1 };

/* standard_colormap_mode values (match wraster.h). */
enum { RUseStdColormap = 0, RCreateStdColormap, RIgnoreStdColormap };

typedef struct RContextAttributes {
    int flags;
    int render_mode;
    int colors_per_channel;
    float rgamma;
    float ggamma;
    float bgamma;
    VisualID visualid;
    int use_shared_memory;
    int scaling_filter;
    int standard_colormap_mode;
} RContextAttributes;

typedef struct RContext {
    Display *dpy;
    int screen_number;
    Colormap cmap;
    RContextAttributes *attribs;
    GC copy_gc;
    Visual *visual;
    int depth;
    Window drawable;                 /* root window */
    int vclass;
    unsigned long black;
    unsigned long white;
    int red_offset;
    int green_offset;
    int blue_offset;
    XStandardColormap *std_rgb_map;  /* unused here; kept for field-compat */
    XStandardColormap *std_gray_map; /* unused here; kept for field-compat */
    int ncolors;                     /* 0 here */
    XColor *colors;                  /* NULL here */
    unsigned long *pixels;           /* NULL here */
    struct {
        unsigned int use_shared_pixmap:1;
        unsigned int optimize_for_speed:1;
    } flags;
    void *hermes_data;               /* NULL here */
} RContext;

typedef struct RColor {
    unsigned char red;
    unsigned char green;
    unsigned char blue;
    unsigned char alpha;
} RColor;

typedef struct RXImage {
    XImage *image;
} RXImage;

RContext *RCreateContext(Display *dpy, int screen_number,
                         RContextAttributes *attribs);
void RDestroyContext(RContext *context);
Bool RGetClosestXColor(RContext *context, RColor *color, XColor *retColor);
RXImage *RCreateXImage(RContext *context, int depth,
                       unsigned int width, unsigned int height);
RXImage *RGetXImage(RContext *context, Drawable d, int x, int y,
                    unsigned int width, unsigned int height);
void RPutXImage(RContext *context, Drawable d, GC gc, RXImage *ximage,
                int src_x, int src_y, int dest_x, int dest_y,
                unsigned int width, unsigned int height);
void RDestroyXImage(RContext *context, RXImage *ximage);

#endif /* _xlibimage_h_INCLUDE */
