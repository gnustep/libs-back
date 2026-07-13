/* Tests the cairo backend's font metrics through NSFont.  The width of a string
 * is its advance (how far the drawing pen moves), so the width of a run of one
 * character is a whole multiple of a single character's width; the ink bounding
 * box, which is narrower, would not add up.  Also check that the metrics scale
 * with the point size and that the ascender and descender have the right signs.
 *
 * It needs a window server (to load the backend font), so it opens the display
 * named by the environment and skips when there is none, and it guards on the
 * cairo graphics backend being the one built.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>
#include <math.h>

static BOOL
near(CGFloat a, CGFloat b)
{
  CGFloat d = a - b;

  return (d < 0.5 && d > -0.5) ? YES : NO;
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSFont *f, *big;
  CGFloat wi, wiiii, wW, wWWWW;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping font metric tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  f = [NSFont systemFontOfSize: 14];
  big = [NSFont systemFontOfSize: 28];
  PASS(f != nil && big != nil, "the system font is available at two sizes");

  PASS(near([f widthOfString: @""], 0.0), "an empty string has zero width");

  /* the width is the advance, so a run of a character is a whole multiple of
   * the single-character width */
  wi = [f widthOfString: @"i"];
  wiiii = [f widthOfString: @"iiii"];
  wW = [f widthOfString: @"W"];
  wWWWW = [f widthOfString: @"WWWW"];
  PASS(wi > 0.0 && near(wiiii, 4 * wi),
    "four i's are four times the width of one i");
  PASS(wW > 0.0 && near(wWWWW, 4 * wW),
    "four W's are four times the width of one W");

  /* metrics scale with the point size */
  PASS(near([big widthOfString: @"Wi"], 2 * [f widthOfString: @"Wi"]),
    "the string width scales with the point size");
  PASS(near([big ascender], 2 * [f ascender]),
    "the ascender scales with the point size");

  /* the ascender is above the baseline, the descender below */
  PASS([f ascender] > 0.0, "the ascender is positive");
  PASS([f descender] < 0.0, "the descender is negative");

  /* no glyph advances more than the maximum advancement */
  PASS([f maximumAdvancement].width >= wW,
    "the maximum advancement is at least the width of a W");

  DESTROY(pool);
  return 0;
}

#else

int
main(int argc, const char **argv)
{
  return 0;
}

#endif
