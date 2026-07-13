/* Coverage for the win32 GDI font enumerator (Source/winlib/
 * WIN32FontEnumerator.m), the font discovery layer the winlib backend uses
 * through GSFontEnumerator.
 *
 * The checks are font independent: the enumerator lists at least one family and
 * one font, a listed family has at least one member, and the default system,
 * bold and fixed-pitch names are set with the three roles differing.
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
#import <GNUstepGUI/GSFontInfo.h>

int
main(void)
{
  START_SET("win32 font enumeration")
  ENTER_POOL

  GSFontEnumerator *e = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      e = [GSFontEnumerator sharedEnumerator];
    }
  NS_HANDLER
    {
      e = nil;
    }
  NS_ENDHANDLER

  if (e == nil)
    {
      SKIP("no font backend available")
    }
  else
    {
      NSArray *families = [e availableFontFamilies];
      NSArray *fonts = [e availableFonts];

      /* The enumerator lists families and fonts. */
      PASS([families count] > 0, "availableFontFamilies is not empty")
      PASS([fonts count] > 0, "availableFonts is not empty")

      /* A listed family has at least one member. */
      if ([families count] > 0)
	{
	  NSString *family = [families lastObject];

	  PASS([[e availableMembersOfFontFamily: family] count] > 0,
	    "a listed family has at least one member")
	}

      /* The default names are set, and the three roles differ. */
      {
	NSString *sys = [e defaultSystemFontName];
	NSString *bold = [e defaultBoldSystemFontName];
	NSString *fixed = [e defaultFixedPitchFontName];

	PASS(sys != nil && bold != nil && fixed != nil,
	  "the default system, bold and fixed-pitch names are set")
	PASS(![bold isEqualToString: sys],
	  "the default bold name differs from the default system name")
	PASS(![fixed isEqualToString: sys],
	  "the default fixed-pitch name differs from the default system name")
      }
    }

  LEAVE_POOL
  END_SET("win32 font enumeration")
  return 0;
}

#else

int
main(void)
{
  START_SET("win32 font enumeration")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("win32 font enumeration")
  return 0;
}

#endif
