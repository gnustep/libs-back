/* Coverage for the fontconfig font enumerator (Source/fontconfig/
 * FCFontEnumerator.m), the shared font discovery layer the graphics backends
 * use through GSFontEnumerator.
 *
 * The checks are font independent: the enumerator lists at least one family and
 * one font, a listed family has at least one member, the default system, bold
 * and fixed-pitch names are set and the three roles differ, and matching a
 * family returns font descriptors.
 *
 * It needs the font backend loaded, so it opens the window server named by the
 * environment (X or wayland) and skips when there is none, and it guards on the
 * cairo graphics backend being the one built, as the other font tests do.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSFontInfo.h>

int
main(void)
{
  START_SET("fontconfig font enumeration")
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

      /* Matching a family returns font descriptors. */
      if ([families count] > 0)
	{
	  NSDictionary *attrs = [NSDictionary
	    dictionaryWithObject: [families lastObject]
			  forKey: NSFontFamilyAttribute];
	  NSArray *matches = [e matchingFontDescriptorsFor: attrs];

	  PASS([matches count] > 0,
	    "matchingFontDescriptorsFor: returns descriptors")
	  PASS([[matches objectAtIndex: 0]
		 isKindOfClass: [NSFontDescriptor class]],
	    "matchingFontDescriptorsFor: returns NSFontDescriptor objects")
	}
    }

  LEAVE_POOL
  END_SET("fontconfig font enumeration")
  return 0;
}

#else

int
main(void)
{
  START_SET("fontconfig font enumeration")
    SKIP("back is not built with the cairo graphics backend")
  END_SET("fontconfig font enumeration")
  return 0;
}

#endif
