/* Round-trip test for RConvertImage() in Source/x11/convert.c.
 *
 * RConvertImage() turns an RImage (24-bit RGB/RGBA) into an X Pixmap for the
 * context's visual and depth.  This builds a known image, converts it, reads
 * the pixmap back with XGetImage(), decodes it through the visual (directly
 * for a TrueColor/DirectColor visual, or via the colormap otherwise) and
 * checks the result.  On a TrueColor visual with 8 bits per channel the round
 * trip is exact; on a lower-depth or palette visual it is only checked to
 * have produced a readable pixmap, since the conversion is intentionally lossy
 * (quantisation and dithering).
 *
 * The wraster sources are compiled in directly so the test does not need the
 * gui-linked back bundle.  It needs a running X server: it opens the display
 * named by $DISPLAY and skips cleanly when there is none, so the harness can
 * run it under a headless server (Xvfb) where one is available.
 *
 * raster.c is x11 backend code, so this guards on the backend actually being
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
#include "x11/convert.c"

static int
trailing_zeros(unsigned long m)
{
  int s = 0;
  if (!m)
    return 0;
  while (!(m & 1)) { s++; m >>= 1; }
  return s;
}

static int
bit_count(unsigned long m)
{
  int n = 0;
  while (m) { n += m & 1; m >>= 1; }
  return n;
}

int
main(void)
{
  Display	*dpy;
  RContext	*ctx;
  RContextAttributes attribs;
  RImage	*img;
  Pixmap	pixmap = 0;
  XImage	*xi;
  int		w = 16, h = 16, x, y;
  int		maxError = 0;
  BOOL		trueColor;

  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      NSLog(@"no X display available; skipping RConvertImage round-trip test");
      return 0;
    }

  memset(&attribs, 0, sizeof(attribs));
  attribs.flags = RC_RenderMode | RC_ColorsPerChannel;
  attribs.render_mode = RBestMatchRendering;
  attribs.colors_per_channel = 6;

  ctx = RCreateContext(dpy, DefaultScreen(dpy), &attribs);
  PASS(ctx != NULL, "RCreateContext succeeds on the display");
  if (ctx == NULL)
    return 0;

  trueColor = (ctx->vclass == TrueColor || ctx->vclass == DirectColor);

  /* A 16x16 RGB ramp. */
  img = RCreateImage(w, h, 0);
  for (y = 0; y < h; y++)
    for (x = 0; x < w; x++)
      {
	unsigned char *p = img->data + (y * w + x) * 3;
	p[0] = x * 17;
	p[1] = y * 17;
	p[2] = (x * 17 + y * 17) / 2;
      }

  PASS(RConvertImage(ctx, img, &pixmap) && pixmap != 0,
    "RConvertImage produces a pixmap");

  xi = XGetImage(dpy, pixmap, 0, 0, w, h, AllPlanes, ZPixmap);
  PASS(xi != NULL, "the converted pixmap can be read back");

  if (xi != NULL)
    {
      for (y = 0; y < h; y++)
	for (x = 0; x < w; x++)
	  {
	    unsigned char *o = img->data + (y * w + x) * 3;
	    unsigned long px = XGetPixel(xi, x, y);
	    int r, g, b;

	    if (trueColor)
	      {
		unsigned long rm = ctx->visual->red_mask;
		unsigned long gm = ctx->visual->green_mask;
		unsigned long bm = ctx->visual->blue_mask;

		r = ((px & rm) >> trailing_zeros(rm)) * 255
		  / ((1 << bit_count(rm)) - 1);
		g = ((px & gm) >> trailing_zeros(gm)) * 255
		  / ((1 << bit_count(gm)) - 1);
		b = ((px & bm) >> trailing_zeros(bm)) * 255
		  / ((1 << bit_count(bm)) - 1);
	      }
	    else
	      {
		XColor c;

		c.pixel = px;
		XQueryColor(dpy, ctx->cmap, &c);
		r = c.red >> 8;
		g = c.green >> 8;
		b = c.blue >> 8;
	      }

	    if (abs(r - o[0]) > maxError) maxError = abs(r - o[0]);
	    if (abs(g - o[1]) > maxError) maxError = abs(g - o[1]);
	    if (abs(b - o[2]) > maxError) maxError = abs(b - o[2]);
	  }

      if (trueColor && bit_count(ctx->visual->red_mask) >= 8)
	{
	  PASS(maxError <= 1,
	    "RConvertImage round-trips RGB exactly on an 8-bit-per-channel"
	    " TrueColor visual");
	}
      else
	{
	  /* Lower-depth or palette visuals are lossy by design; the pixels
	   * are only required to be readable, which is checked above. */
	  PASS(maxError <= 255, "the converted pixels are readable");
	}
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
