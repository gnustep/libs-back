/* The fonts the art backend enumerates, and whether the user fixed pitch font
 * is fixed pitch (Source/art/FTFontEnumerator.m).
 *
 * A backend that enumerates no fixed pitch face has nothing to answer
 * -userFixedPitchFontOfSize: with, and NSFont falls back to the system font,
 * which is proportional. The font is asked to prove its own pitch here rather
 * than being named, since which face is installed differs by machine.
 *
 * It guards on the art graphics backend, and needs the backend loaded, so it
 * skips where there is no display to reach.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_art) \
  && BUILD_GRAPHICS == GRAPHICS_art

#import <AppKit/AppKit.h>
#include <math.h>

/* Whether the font advances a wide and a narrow character alike, which is
   what being fixed pitch means. */
static BOOL
advancesAlike(NSFont *f)
{
  return fabs([f widthOfString: @"W"] - [f widthOfString: @"i"]) < 0.01;
}

int
main(void)
{
  START_SET("art fixed pitch")

  NSFont *fixed = nil;
  NSFont *variable = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      fixed = [NSFont userFixedPitchFontOfSize: 24.0];
      variable = [NSFont systemFontOfSize: 24.0];
    }
  NS_HANDLER
    {
      fixed = nil;
      variable = nil;
    }
  NS_ENDHANDLER

  if (fixed == nil || variable == nil)
    {
      SKIP("no display to reach the backend with")
    }
  else
    {
      PASS(advancesAlike(fixed),
	"the user fixed pitch font advances W and i alike")
      PASS([fixed isFixedPitch] == YES,
	"the user fixed pitch font reports isFixedPitch")

      /* The system font is proportional wherever a real one was found, so
	 the two answering the same face is the tell that only a fallback was
	 available. */
      PASS([[fixed fontName] isEqualToString: [variable fontName]] == NO,
	"the fixed pitch font is not the system font")
    }

  END_SET("art fixed pitch")
  return 0;
}

#else

int
main(void)
{
  START_SET("art fixed pitch")
    SKIP("back is not built with the art graphics backend")
  END_SET("art fixed pitch")
  return 0;
}

#endif
