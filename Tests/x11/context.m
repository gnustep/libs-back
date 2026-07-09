/* Test for count_offset() in Source/x11/context.c.
 *
 * count_offset() returns the position of the lowest set bit of an X visual's
 * colour mask; RCreateContext() uses it to derive the red/green/blue shifts of
 * a TrueColor or DirectColor visual.  It is a static helper, so the context
 * source is compiled in directly to reach it.  The mask is unsigned and can be
 * zero (a StaticGray or GrayScale visual carries no colour masks), so zero is
 * checked alongside the ordinary channel masks.
 *
 * context.c is x11 backend code, so this guards on the backend actually being
 * built (config.h names it as BUILD_SERVER) and the GNUmakefile.preamble adds
 * the X11 libraries under the same condition.  count_offset() needs no X
 * server, so the test runs without a display.
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

int main(void)
{
  PASS(count_offset(0) == 0,
       "count_offset of a zero mask is 0 and does not loop forever");
  PASS(count_offset(0xffUL) == 0,
       "count_offset of a mask with bit 0 set is 0");
  PASS(count_offset(0xff00UL) == 8,
       "count_offset of 0xff00 is 8");
  PASS(count_offset(0xff0000UL) == 16,
       "count_offset of 0xff0000 is 16");
  PASS(count_offset(0xf800UL) == 11,
       "count_offset of a 16-bit 565 red mask is 11");
  PASS(count_offset(0x07e0UL) == 5,
       "count_offset of a 16-bit 565 green mask is 5");
  PASS(count_offset(0x80000000UL) == 31,
       "count_offset of the top bit of a 32-bit mask is 31");

  return 0;
}

#else
int main(void)
{
  return 0;
}
#endif
