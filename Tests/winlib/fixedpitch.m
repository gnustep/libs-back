/* Whether a font reports the pitch it actually has
 * (Source/winlib/WIN32FontInfo.m).
 *
 * GDI reports the pitch in TEXTMETRIC.tmPitchAndFamily, where the bit named
 * TMPF_FIXED_PITCH is set for a font of VARIABLE pitch, the opposite of what
 * the name says. Measured at 14pt: Courier New and Consolas report the bit
 * clear and advance W and i alike, Tahoma and Arial report it set and advance
 * them differently.
 *
 * A font that advances every glyph by the same amount is fixed pitch, which is
 * what -isFixedPitch answers, so the two are checked against each other rather
 * than against a face name.
 *
 * It guards on the winlib graphics backend and skips when the backend cannot
 * be reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_winlib) \
  && BUILD_GRAPHICS == GRAPHICS_winlib

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
  START_SET("winlib fixed pitch")

  NSFont *fixed = nil;
  NSFont *variable = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      fixed = [NSFont userFixedPitchFontOfSize: 14.0];
      variable = [NSFont systemFontOfSize: 14.0];
    }
  NS_HANDLER
    {
      fixed = nil;
      variable = nil;
    }
  NS_ENDHANDLER

  if (fixed == nil || variable == nil)
    {
      SKIP("no win32 gui available")
    }
  else
    {
      /* The two fonts are what they are meant to be, so that the checks below
	 mean something. */
      PASS(advancesAlike(fixed),
	"the user fixed pitch font advances W and i alike")
      PASS(advancesAlike(variable) == NO,
	"the system font advances W and i differently")

      PASS([fixed isFixedPitch] == YES,
	"a font that advances every glyph alike reports isFixedPitch")
      PASS([variable isFixedPitch] == NO,
	"a font that does not reports isFixedPitch NO")
    }

  END_SET("winlib fixed pitch")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib fixed pitch")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib fixed pitch")
  return 0;
}

#endif
