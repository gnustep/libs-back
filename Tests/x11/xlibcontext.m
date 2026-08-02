/* Test for RCreateContext() and RDestroyContext() in Source/x11/xlibimage.c.
 *
 * xlibimage.c is the plain-Xlib implementation of the wraster subset the X11
 * backend uses, and it is what a default build compiles: --enable-wraster is
 * off unless asked for, so USE_WRASTER is 0 and context.c is not built.  This
 * checks the context it produces: the fields taken from the screen, the
 * attributes copy (including the two the implementation overrides), and the
 * channel offsets derived from a TrueColor visual's masks.
 *
 * It needs a running X server: it opens the display named by $DISPLAY and
 * skips cleanly when there is none, so the harness can run it under a headless
 * server (Xvfb) where one is available.
 *
 * The guard is the mirror of the one the wraster tests carry: this builds only
 * where xlibimage.c is the implementation in use.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) \
  && BUILD_SERVER == SERVER_x11 && (!defined(USE_WRASTER) || !USE_WRASTER)

#include <X11/Xlib.h>
#include "x11/xlibimage.h"
#include "x11/xlibimage.c"

/* Independent oracle for the lowest-set-bit position, so the offset check does
 * not merely restate the count_offset() it is meant to verify. */
static int
low_bit(unsigned long m)
{
  int s = 0;

  if (m == 0)
    return 0;
  while ((m & 1) == 0)
    {
      s++;
      m >>= 1;
    }
  return s;
}

int
main(void)
{
  START_SET("xlibcontext")
  Display		*dpy;
  int			screen;
  RContext		*ctx;
  RContextAttributes	attribs;

  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      SKIP("no X display available")
    }
  screen = DefaultScreen(dpy);

  /* No attributes: the implementation supplies its own defaults. */
  ctx = RCreateContext(dpy, screen, NULL);
  PASS(ctx != NULL, "RCreateContext succeeds with no attributes");
  if (ctx == NULL)
    {
      XCloseDisplay(dpy);
      SKIP("no render context could be created")
    }

  PASS(ctx->attribs != NULL, "the context has its own attributes");
  PASS(ctx->attribs != NULL
    && ctx->attribs->render_mode == RDitheredRendering,
    "the default render mode is dithered");
  PASS(ctx->attribs != NULL && ctx->attribs->colors_per_channel == 4,
    "the default is four colours per channel");
  PASS(ctx->attribs != NULL
    && ctx->attribs->standard_colormap_mode == RUseStdColormap,
    "the default is to use the standard colormap");

  /* The fields taken straight from the screen. */
  PASS(ctx->dpy == dpy, "the context keeps the display it was created for");
  PASS(ctx->screen_number == screen, "the context keeps its screen number");
  PASS(ctx->visual == DefaultVisual(dpy, screen),
    "the context uses the screen's default visual");
  PASS(ctx->depth == DefaultDepth(dpy, screen),
    "the context uses the screen's default depth");
  PASS(ctx->cmap == DefaultColormap(dpy, screen),
    "the context uses the screen's default colormap");
  PASS(ctx->drawable == RootWindow(dpy, screen),
    "the context drawable is the root window");
  PASS(ctx->black == BlackPixel(dpy, screen),
    "the context records the screen's black pixel");
  PASS(ctx->white == WhitePixel(dpy, screen),
    "the context records the screen's white pixel");
  PASS(ctx->vclass == ctx->visual->class,
    "the context visual class is the visual's own class");
  PASS(ctx->copy_gc != NULL, "the context has a copy graphics context");

  /* Fields this implementation does not use are left empty rather than
   * uninitialised. */
  PASS(ctx->std_rgb_map == NULL && ctx->std_gray_map == NULL,
    "no standard colormaps are built");
  PASS(ctx->ncolors == 0 && ctx->colors == NULL && ctx->pixels == NULL,
    "no colour table is built");
  PASS(ctx->hermes_data == NULL, "no Hermes data is attached");

  if (ctx->vclass == TrueColor)
    {
      PASS(ctx->red_offset == low_bit(ctx->visual->red_mask),
        "the red offset is the lowest set bit of the visual's red mask");
      PASS(ctx->green_offset == low_bit(ctx->visual->green_mask),
        "the green offset is the lowest set bit of the visual's green mask");
      PASS(ctx->blue_offset == low_bit(ctx->visual->blue_mask),
        "the blue offset is the lowest set bit of the visual's blue mask");
    }
  else
    {
      /* The offsets are derived for a TrueColor visual only, and a context
       * starts zeroed, so they stay at zero for any other class. */
      PASS(ctx->red_offset == 0 && ctx->green_offset == 0
        && ctx->blue_offset == 0,
        "no channel offsets are derived for a non-TrueColor visual");
    }

  RDestroyContext(ctx);

  /* Supplied attributes are copied, and the copy is the context's own. */
  memset(&attribs, 0, sizeof(attribs));
  attribs.flags = RC_RenderMode | RC_ColorsPerChannel;
  attribs.render_mode = RBestMatchRendering;
  attribs.colors_per_channel = 6;
  ctx = RCreateContext(dpy, screen, &attribs);
  PASS(ctx != NULL, "RCreateContext succeeds with attributes supplied");
  if (ctx != NULL)
    {
      PASS(ctx->attribs != &attribs,
        "the context takes a copy rather than keeping the caller's struct");
      PASS(ctx->attribs->render_mode == RBestMatchRendering,
        "the supplied render mode is kept");
      PASS(ctx->attribs->colors_per_channel == 6,
        "the supplied colours per channel is kept");

      attribs.colors_per_channel = 2;
      PASS(ctx->attribs->colors_per_channel == 6,
        "changing the caller's struct afterwards does not change the context");

      RDestroyContext(ctx);
    }

  /* Shared memory is never used by this implementation, whatever is asked
   * for, and it says so in the copy it keeps. */
  memset(&attribs, 0, sizeof(attribs));
  attribs.flags = RC_UseSharedMemory;
  attribs.use_shared_memory = True;
  ctx = RCreateContext(dpy, screen, &attribs);
  PASS(ctx != NULL, "RCreateContext succeeds when shared memory is asked for");
  if (ctx != NULL)
    {
      PASS(ctx->attribs->use_shared_memory == False,
        "shared memory is refused however it was asked for");
      PASS((ctx->attribs->flags & RC_UseSharedMemory) == 0,
        "the shared memory flag is cleared as well as the value");
      RDestroyContext(ctx);
    }

  /* Releasing nothing is allowed. */
  PASS_RUNS(({ RDestroyContext(NULL); }),
    "RDestroyContext tolerates a null context");

  XCloseDisplay(dpy);

  END_SET("xlibcontext")
  return 0;
}

#else

int
main(void)
{
  START_SET("xlibcontext")
  SKIP("back is built with the wraster image code, not the plain Xlib layer")
  END_SET("xlibcontext")
  return 0;
}

#endif
