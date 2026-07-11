/* Tests the cairo backend's per-glyph metrics through NSFont: the advancement
 * of a glyph, its ink bounding box (which is narrower than the advancement,
 * since the advancement includes the side bearings), that the advancement
 * scales with the point size, and that a fixed-pitch font advances every glyph
 * the same.
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
  NSFont *f, *big, *mono;
  NSSize aW, ai;
  NSRect bW, bi;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping glyph metric tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  f = [NSFont systemFontOfSize: 14];
  big = [NSFont systemFontOfSize: 28];
  mono = [NSFont userFixedPitchFontOfSize: 14];
  PASS(f != nil && big != nil && mono != nil, "the fonts are available");

  aW = [f advancementForGlyph: (NSGlyph)'W'];
  ai = [f advancementForGlyph: (NSGlyph)'i'];
  bW = [f boundingRectForGlyph: (NSGlyph)'W'];
  bi = [f boundingRectForGlyph: (NSGlyph)'i'];

  PASS(aW.width > 0.0 && aW.width > ai.width,
    "a W advances further than an i in a proportional font");

  PASS(near([big advancementForGlyph: (NSGlyph)'W'].width, 2 * aW.width),
    "the glyph advancement scales with the point size");

  PASS(bW.size.width > 0.0 && bW.size.height > 0.0,
    "a glyph has a non-empty ink bounding box");

  PASS(bi.size.width > 0.0 && bi.size.width < ai.width,
    "the ink box of an i is narrower than its advancement");

  PASS([mono advancementForGlyph: (NSGlyph)'i'].width > 0.0
    && near([mono advancementForGlyph: (NSGlyph)'i'].width,
            [mono advancementForGlyph: (NSGlyph)'W'].width),
    "a fixed-pitch font advances i and W the same");

  PASS([f glyphIsEncoded: (NSGlyph)'A'],
    "a common character is an encoded glyph");

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
