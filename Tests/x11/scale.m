/* Coverage and regression test for the scalers in Source/x11/scale.c.
 *
 * RSmoothScaleImage() allocated its destination and intermediate images with
 * RCreateImage() and its filter-contribution arrays with calloc() but did not
 * check any of them for NULL.  RCreateImage() returns NULL for a request over
 * the maximum image size, so scaling to an over-large size dereferenced the
 * NULL destination (segfault).  It now checks each allocation and returns NULL.
 *
 * The real source is compiled in directly (with raster.c for RCreateImage and
 * friends) so the test does not need the gui-linked back bundle.
 *
 * scale.c is x11 backend code, so this guards on the backend actually being
 * built (config.h names it as BUILD_SERVER), compiling and running only for
 * x11 and skipping cleanly on every other backend.  The GNUmakefile.preamble
 * adds the X11 headers and library under the same condition.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) && BUILD_SERVER == SERVER_x11

#include <X11/Xlib.h>
#include "x11/wraster.h"
#include "x11/raster.c"
#include "x11/scale.c"

int
main(void)
{
  RImage	*src = RCreateImage(4, 4, 0);
  RImage	*up;
  RImage	*sm;
  RImage	*huge;

  memset(src->data, 0x40, (size_t)src->width * src->height * 3);

  up = RScaleImage(src, 8, 8);
  PASS(up != NULL && up->width == 8 && up->height == 8,
    "RScaleImage produces an image of the requested size");
  if (up != NULL)
    RReleaseImage(up);

  sm = RSmoothScaleImage(src, 8, 8);
  PASS(sm != NULL && sm->width == 8 && sm->height == 8,
    "RSmoothScaleImage produces an image of the requested size");
  if (sm != NULL)
    RReleaseImage(sm);

  /* A request larger than the maximum image size makes RCreateImage return
   * NULL; RSmoothScaleImage must propagate that rather than dereference it. */
  huge = RSmoothScaleImage(src, 100000, 4);
  PASS(huge == NULL,
    "RSmoothScaleImage returns NULL for an over-large request");

  RReleaseImage(src);
  return 0;
}

#else

int
main(void)
{
  return 0;
}

#endif
