/* Test for gs_floor() in Headers/xlib/XGGeometry.h.
 *
 * gs_floor() rounds a float down to the nearest integer as a clamped short; it
 * is used when converting OpenStep coordinates to X device coordinates, where
 * rounding the wrong way for negative values shifts geometry by a pixel.  It
 * must match floorf(): toward negative infinity, not toward zero.
 *
 * XGGeometry.h is part of the xlib graphics backend and pulls in that backend's
 * headers (AppKit, the X GState, Xft), so this guards on the graphics backend
 * actually being xlib (config.h names it as BUILD_GRAPHICS) and the
 * GNUmakefile.preamble adds the matching include paths under the same
 * condition.  gs_floor() itself needs no X server, so the test runs without a
 * display.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_xlib) && BUILD_GRAPHICS == GRAPHICS_xlib

#include <math.h>
#include "xlib/XGGeometry.h"

int main(void)
{
  PASS(gs_floor(-0.5) == -1,
       "gs_floor(-0.5) is -1 (rounds down, not toward zero)");
  PASS(gs_floor(-1.5) == -2,
       "gs_floor(-1.5) is -2");
  PASS(gs_floor(-1.0) == -1,
       "gs_floor of a negative integer is that integer");
  PASS(gs_floor(2.5) == 2,
       "gs_floor(2.5) is 2");
  PASS(gs_floor(3.0) == 3,
       "gs_floor of a positive integer is that integer");
  PASS(gs_floor(0.0) == 0,
       "gs_floor(0) is 0");

  int mismatches = 0;
  float f;
  for (f = -3000.0; f <= 3000.0; f += 0.25)
    {
      short got = gs_floor(f);
      short want = (short)floorf(f);
      if (got != want)
        {
          if (mismatches < 5)
            NSLog(@"gs_floor(%g) = %d, floorf gives %d", f, (int)got, (int)want);
          mismatches++;
        }
    }
  PASS(mismatches == 0,
       "gs_floor matches floorf across [-3000, 3000] in steps of 0.25");

  return 0;
}

#else
int main(void)
{
  return 0;
}
#endif
