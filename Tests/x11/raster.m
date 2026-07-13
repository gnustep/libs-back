/* Regression and coverage test for calculateCombineArea() /
 * RCombineArea() in Source/x11/raster.c.
 *
 * calculateCombineArea() clips the source rectangle against the destination.
 * swidth/sheight are unsigned, so when the destination origin is negative it
 * computed "*swidth + *dx" (dx < 0) in unsigned arithmetic: a source placed
 * entirely off the left/top edge underflowed swidth/sheight to a huge value,
 * which was then clamped to the destination size and reported as a non-empty
 * area.  RCombineArea() then read past the source buffer (AddressSanitizer:
 * heap-buffer-overflow at the memcpy).  A symmetric underflow occurred for a
 * source entirely off the right/bottom edge (des->width - *dx, dx > width).
 *
 * The real source is compiled in directly so the test does not need the
 * gui-linked back bundle.  Built with -fsanitize=address (see GNUmakefile) the
 * off-edge combine faults before the fix and is clean after it.
 *
 * raster.c is x11 backend code, so this guards on the backend actually being
 * built (config.h names it as BUILD_SERVER); it compiles the source and runs
 * only for x11, skipping cleanly on every other backend.  The matching
 * GNUmakefile.preamble adds the X11 headers and library under the same
 * condition.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) && BUILD_SERVER == SERVER_x11

#include <X11/Xlib.h>
#include "x11/wraster.h"
#include "x11/raster.c"

/* Build an RImage backed by a heap buffer so AddressSanitizer bounds it. */
static RImage *
makeImage(int w, int h)
{
  RImage *im = malloc(sizeof(RImage));
  im->width = w;
  im->height = h;
  im->format = RRGBFormat;
  im->refCount = 1;
  im->data = calloc((size_t)w * h, 3);
  return im;
}

static void
freeImage(RImage *im)
{
  free(im->data);
  free(im);
}

int
main(void)
{
  RImage	*des = makeImage(8, 8);
  RImage	*src = makeImage(2, 2);
  int		sx, sy, dx, dy;
  unsigned	w, h;

  /* Fully on the destination: nothing is clipped. */
  sx = sy = 0; w = h = 2; dx = dy = 1;
  PASS(calculateCombineArea(des, src, &sx, &sy, &w, &h, &dx, &dy)
    && sx == 0 && sy == 0 && w == 2 && h == 2 && dx == 1 && dy == 1,
    "an in-bounds source is not clipped");

  /* Straddling the left edge: the left column is trimmed. */
  sx = sy = 0; w = h = 2; dx = -1; dy = 3;
  PASS(calculateCombineArea(des, src, &sx, &sy, &w, &h, &dx, &dy)
    && sx == 1 && w == 1 && dx == 0,
    "a source straddling the left edge is trimmed, not wrapped");

  /* Straddling the right edge: the width is clamped to the destination. */
  sx = sy = 0; w = h = 4; dx = 6; dy = 0;
  PASS(calculateCombineArea(des, src, &sx, &sy, &w, &h, &dx, &dy)
    && w == 2 && dx == 6,
    "a source straddling the right edge is clamped to the destination");

  /* Entirely off the left edge: no visible area. */
  sx = sy = 0; w = h = 2; dx = -10; dy = 0;
  PASS(!calculateCombineArea(des, src, &sx, &sy, &w, &h, &dx, &dy),
    "a source entirely off the left edge reports no area");

  /* Entirely off the top edge: no visible area. */
  sx = sy = 0; w = h = 2; dx = 0; dy = -10;
  PASS(!calculateCombineArea(des, src, &sx, &sy, &w, &h, &dx, &dy),
    "a source entirely off the top edge reports no area");

  /* Entirely off the right edge: no visible area (dx > width underflows the
   * clamp des->width - *dx). */
  sx = sy = 0; w = h = 2; dx = 10; dy = 0;
  PASS(!calculateCombineArea(des, src, &sx, &sy, &w, &h, &dx, &dy),
    "a source entirely off the right edge reports no area");

  /* Entirely off the bottom edge: no visible area. */
  sx = sy = 0; w = h = 2; dx = 0; dy = 10;
  PASS(!calculateCombineArea(des, src, &sx, &sy, &w, &h, &dx, &dy),
    "a source entirely off the bottom edge reports no area");

  /* The combine itself must not read past the source when it is off-edge. */
  RCombineArea(des, src, 0, 0, 2, 2, -10, 0);
  RCombineArea(des, src, 0, 0, 2, 2, 0, -10);
  RCombineArea(des, src, 0, 0, 2, 2, 10, 0);
  RCombineArea(des, src, 0, 0, 2, 2, 0, 10);
  PASS(1, "combining an off-edge source does not read past the source buffer");

  freeImage(src);
  freeImage(des);
  return 0;
}

#else

int
main(void)
{
  return 0;
}

#endif
