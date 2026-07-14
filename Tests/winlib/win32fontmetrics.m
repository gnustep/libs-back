/* Coverage for the win32 GDI font metrics (Source/winlib/WIN32FontInfo.m),
 * reached through NSFont: a proportional font advances a wide glyph further
 * than a narrow one, the advancement scales with the point size, a fixed-pitch
 * font advances every glyph the same, a glyph has a positive-size bounding box,
 * and a common glyph is encoded.
 *
 * It guards on the winlib graphics backend and skips when the backend cannot be
 * reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_winlib) \
  && BUILD_GRAPHICS == GRAPHICS_winlib

#import <AppKit/AppKit.h>
#include <stdlib.h>

/* GDI rounds glyph advances to whole pixels, so allow a couple of pixels.  A
 * plain "near" would clash with the legacy windows.h macro. */
static BOOL
nearly(CGFloat a, CGFloat b)
{
  CGFloat d = a - b;

  return (d < 2.5 && d > -2.5) ? YES : NO;
}

int
main(void)
{
  START_SET("win32 font metrics")
  ENTER_POOL

  BOOL haveApp = NO;

  NS_DURING
    {
      [NSApplication sharedApplication];
      haveApp = YES;
    }
  NS_HANDLER
    {
      haveApp = NO;
    }
  NS_ENDHANDLER

  if (haveApp == NO)
    {
      SKIP("no win32 gui available")
    }
  else
    {
      NSFont *f = [NSFont systemFontOfSize: 14];
      NSFont *big = [NSFont systemFontOfSize: 28];
      NSFont *mono = [NSFont userFixedPitchFontOfSize: 14];
      NSSize  aW, ai, bigW, monoI, monoW;
      NSRect  bW;

      PASS(f != nil && big != nil && mono != nil, "the fonts are available")

      aW = [f advancementForGlyph: (NSGlyph)'W'];
      ai = [f advancementForGlyph: (NSGlyph)'i'];
      bigW = [big advancementForGlyph: (NSGlyph)'W'];
      monoI = [mono advancementForGlyph: (NSGlyph)'i'];
      monoW = [mono advancementForGlyph: (NSGlyph)'W'];
      bW = [f boundingRectForGlyph: (NSGlyph)'W'];

      PASS(aW.width > 0.0 && aW.width > ai.width,
	"a W advances further than an i in a proportional font")

      PASS(nearly(bigW.width, 2 * aW.width),
	"the glyph advancement scales with the point size")

      PASS(monoW.width > 0.0 && nearly(monoI.width, monoW.width),
	"a fixed-pitch font advances every glyph the same")

      PASS(bW.size.width > 0.0 && bW.size.height > 0.0,
	"boundingRectForGlyph reports a positive-size box for a W")

      PASS([f glyphIsEncoded: (NSGlyph)'A'] == YES,
	"a common glyph is encoded")
    }

  LEAVE_POOL
  END_SET("win32 font metrics")
  return 0;
}

#else

int
main(void)
{
  START_SET("win32 font metrics")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("win32 font metrics")
  return 0;
}

#endif
