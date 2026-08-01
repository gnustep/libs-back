/* A font name the win32 GDI backend cannot resolve has to fail, so that
 * -[NSFont fontWithName:size:] returns nil and its callers can fall back.
 * GDI substitutes a face for any name, including an empty one, so the lookup
 * has to be checked against the enumerated families.
 *
 * The checks are font independent: they use the first family the enumerator
 * lists rather than naming a face.
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
#import <GNUstepGUI/GSFontInfo.h>

int
main(void)
{
  START_SET("win32 font lookup")

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

      /* A name that is not a face at all has no font. */
      PASS([NSFont fontWithName: @"ThereIsNoSuchFaceInstalled" size: 12] == nil,
        "an unknown font name has no font")

      /* Nor has an empty one: this is what -[NSFont initWithCoder:] asks for
         when a xib font element carries neither a name nor a metaFont. */
      PASS([NSFont fontWithName: @"" size: 12] == nil,
        "an empty font name has no font")

      /* A font that does exist still resolves, and reports the name asked
         for rather than whatever the device substituted. */
      if ([families count] > 0)
        {
          NSString *family = [families objectAtIndex: 0];
          NSFont *font = [NSFont fontWithName: family size: 12];
          NSFont *bold;

          PASS(font != nil, "a listed family resolves to a font")
          PASS_EQUAL([font fontName], family,
            "the font reports the name it was asked for")

          /* The enumerator advertises "<family> Bold" for every family, so
             that name has to resolve too. */
          bold = [NSFont fontWithName:
            [family stringByAppendingString: @" Bold"] size: 12];
          PASS(bold != nil, "a styled member of a listed family resolves")

          /* NSFont builds hyphenated names of this shape when it replaces
             Helvetica, so they have to keep working. */
          bold = [NSFont fontWithName:
            [family stringByAppendingString: @"-Bold"] size: 12];
          PASS(bold != nil, "a hyphenated style of a listed family resolves")
        }

      /* The standard roles are unaffected. */
      {
        NSFont *system = [NSFont systemFontOfSize: 12];

        PASS(system != nil && [system fontName] != nil,
          "the system font resolves and has a name")
      }
    }

  END_SET("win32 font lookup")
  return 0;
}

#else

int
main(void)
{
  START_SET("win32 font lookup")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("win32 font lookup")
  return 0;
}

#endif
