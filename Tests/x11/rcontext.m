/* Test for RCreateContext() in Source/x11/context.c.
 *
 * RCreateContext() builds an RContext for a screen: it selects a visual (the
 * best available, or the screen's default when RC_DefaultVisual is set),
 * creates a colormap, a drawable and a graphics context, and for a TrueColor
 * or DirectColor visual derives the red/green/blue shifts from the visual's
 * colour masks.  This checks the context fields are populated consistently and
 * that the derived channel offsets match the masks of the chosen visual.
 *
 * The wraster sources are compiled in directly so the test does not need the
 * gui-linked back bundle.  It needs a running X server: it opens the display
 * named by $DISPLAY and skips cleanly when there is none, so the harness can
 * run it under a headless server (Xvfb) where one is available.
 *
 * context.c is x11 backend code, so this guards on the backend actually being
 * built (config.h names it as BUILD_SERVER) and the GNUmakefile.preamble adds
 * the X11 libraries under the same condition.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) && BUILD_SERVER == SERVER_x11

#include <X11/Xlib.h>
#include "x11/wraster.h"
#include "x11/raster.c"
#include "x11/scale.c"
#include "x11/context.c"
#include "x11/xutil.c"

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
  Display		*dpy;
  int			screen;
  RContext		*ctx;
  RContextAttributes	attribs;

  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      NSLog(@"no X display available; skipping RCreateContext test");
      return 0;
    }
  screen = DefaultScreen(dpy);

  /* Default attributes: RCreateContext picks the best visual for the screen. */
  ctx = RCreateContext(dpy, screen, NULL);
  PASS(ctx != NULL, "RCreateContext succeeds with default attributes");
  if (ctx == NULL)
    return 0;

  PASS(ctx->dpy == dpy, "the context keeps the display it was created for");
  PASS(ctx->screen_number == screen, "the context keeps its screen number");
  PASS(ctx->attribs != NULL, "the context has its own attributes copy");
  PASS(ctx->visual != NULL, "the context has a visual");
  PASS(ctx->depth > 0, "the context has a positive depth");
  PASS(ctx->cmap != 0, "the context has a colormap");
  PASS(ctx->drawable != 0, "the context has a drawable");
  PASS(ctx->copy_gc != NULL, "the context has a copy graphics context");
  PASS(ctx->vclass >= StaticGray && ctx->vclass <= DirectColor,
       "the context visual class is a valid X visual class");

  if (ctx->vclass == TrueColor || ctx->vclass == DirectColor)
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
      /* A palette or grayscale visual carries no channel masks, so the
       * red/green/blue offsets are not used for it. */
      PASS(1, "no channel offsets to check for a non-TrueColor visual");
    }

  /* Explicit default visual: RCreateContext must use the screen's default
   * visual and record its black and white pixels. */
  memset(&attribs, 0, sizeof(attribs));
  attribs.flags = RC_DefaultVisual;
  ctx = RCreateContext(dpy, screen, &attribs);
  PASS(ctx != NULL, "RCreateContext succeeds for the default visual");
  if (ctx != NULL)
    {
      PASS(ctx->visual == DefaultVisual(dpy, screen),
	   "the default-visual context uses the screen's default visual");
      PASS(ctx->depth == DefaultDepth(dpy, screen),
	   "the default-visual context uses the screen's default depth");
      PASS(ctx->black == BlackPixel(dpy, screen),
	   "the default-visual context records the screen's black pixel");
      PASS(ctx->white == WhitePixel(dpy, screen),
	   "the default-visual context records the screen's white pixel");
    }

  return 0;
}

#else

int
main(void)
{
  return 0;
}

#endif
