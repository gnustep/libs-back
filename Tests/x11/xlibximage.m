/* Test for the image and colour calls in Source/x11/xlibimage.c.
 *
 * xlibimage.c is what a default build compiles for the X11 backend, since
 * --enable-wraster is off unless asked for.  This covers the calls the backend
 * makes on it: RCreateXImage builds an image to draw into, RGetXImage reads a
 * drawable back, RPutXImage writes one out again and RDestroyXImage releases
 * it, while RGetClosestXColor turns an RColor into a pixel for the visual.
 *
 * The round trip is the point: a known colour is put into a pixmap, read back,
 * written into a second pixmap and read again, and the pixels must survive.
 *
 * It needs a running X server: it opens the display named by $DISPLAY and
 * skips cleanly when there is none, so the harness can run it under a headless
 * server (Xvfb) where one is available.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) \
  && BUILD_SERVER == SERVER_x11 && (!defined(USE_WRASTER) || !USE_WRASTER)

#include <X11/Xlib.h>
#include "x11/xlibimage.h"
#include "x11/xlibimage.c"

int
main(void)
{
  START_SET("xlibximage")
  Display	*dpy;
  int		screen;
  RContext	*ctx;
  RXImage	*img;
  RXImage	*readBack;
  Pixmap	src = 0;
  Pixmap	dst = 0;
  XColor	xc;
  RColor	colour;
  unsigned int	w = 8, h = 8;

  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      SKIP("no X display available")
    }
  screen = DefaultScreen(dpy);

  ctx = RCreateContext(dpy, screen, NULL);
  PASS(ctx != NULL, "a context can be created");
  if (ctx == NULL)
    {
      XCloseDisplay(dpy);
      SKIP("no render context could be created")
    }

  /* A colour for the visual. */
  colour.red = 255;
  colour.green = 0;
  colour.blue = 0;
  colour.alpha = 255;
  memset(&xc, 0, sizeof(xc));
  PASS(RGetClosestXColor(ctx, &colour, &xc) == True,
    "a colour can be resolved for the visual");
  PASS(xc.red == (255 << 8) && xc.green == 0 && xc.blue == 0,
    "the returned XColor carries the components it was asked for");
  PASS((xc.flags & (DoRed | DoGreen | DoBlue)) == (DoRed | DoGreen | DoBlue),
    "the returned XColor asks for all three components");

  /* An image to draw into. */
  img = RCreateXImage(ctx, ctx->depth, w, h);
  PASS(img != NULL && img->image != NULL, "an image can be created");
  if (img != NULL && img->image != NULL)
    {
      PASS(img->image->width == (int)w && img->image->height == (int)h,
        "the image has the size it was asked for");
      PASS(img->image->depth == ctx->depth,
        "the image has the depth it was asked for");
      PASS(img->image->data != NULL, "the image has somewhere to put pixels");
    }

  /* Fill a pixmap with the colour, read it back, and check the pixels. */
  src = XCreatePixmap(dpy, ctx->drawable, w, h, ctx->depth);
  PASS(src != 0, "a pixmap can be created to draw into");
  if (src != 0)
    {
      XSetForeground(dpy, ctx->copy_gc, xc.pixel);
      XFillRectangle(dpy, src, ctx->copy_gc, 0, 0, w, h);
      XSync(dpy, False);

      readBack = RGetXImage(ctx, src, 0, 0, w, h);
      PASS(readBack != NULL && readBack->image != NULL,
        "the pixmap can be read back into an image");
      if (readBack != NULL && readBack->image != NULL)
        {
          PASS(readBack->image->width == (int)w
            && readBack->image->height == (int)h,
            "the image read back has the size that was asked for");
          PASS(XGetPixel(readBack->image, w / 2, h / 2) == xc.pixel,
            "the pixel read back is the one that was drawn");

          /* Write it into a second pixmap and read that, so the put is
           * covered as well as the get. */
          dst = XCreatePixmap(dpy, ctx->drawable, w, h, ctx->depth);
          if (dst != 0)
            {
              RXImage *again;

              RPutXImage(ctx, dst, ctx->copy_gc, readBack, 0, 0, 0, 0, w, h);
              XSync(dpy, False);
              again = RGetXImage(ctx, dst, 0, 0, w, h);
              PASS(again != NULL && again->image != NULL
                && XGetPixel(again->image, w / 2, h / 2) == xc.pixel,
                "a written image reads back with the same pixel");
              RDestroyXImage(ctx, again);
              XFreePixmap(dpy, dst);
            }
          RDestroyXImage(ctx, readBack);
        }
      XFreePixmap(dpy, src);
    }

  RDestroyXImage(ctx, img);

  /* Releasing nothing is allowed. */
  PASS_RUNS(({ RDestroyXImage(ctx, NULL); }),
    "RDestroyXImage tolerates a null image");

  RDestroyContext(ctx);
  XCloseDisplay(dpy);

  END_SET("xlibximage")
  return 0;
}

#else

int
main(void)
{
  START_SET("xlibximage")
  SKIP("back is built with the wraster image code, not the plain Xlib layer")
  END_SET("xlibximage")
  return 0;
}

#endif
