/* The glyph -[NSFont glyphWithName:] answers has to be one the same font can
 * measure, which is what -advancementForGlyph: and -boundingRectForGlyph: do
 * (Source/winlib/WIN32FontInfo.m).
 *
 * AppKit's contract, measured at 14pt on Helvetica, Times-Roman and the system
 * font: the advancement of the glyph named "W" equals the width of the string
 * "W", and the same holds for "i", for "eight" against "8" and for "zero"
 * against "0". A name the font does not carry answers NSNullGlyph.
 *
 * An NSGlyph is a character on this backend, so the number itself cannot match
 * the index AppKit reports; what is checked here is the invariant, that the
 * glyph measures as its character does.
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

static BOOL
advancesLikeTheString(NSFont *f, NSString *name, NSString *string)
{
  NSGlyph g = [f glyphWithName: name];

  if (g == NSNullGlyph)
    {
      return NO;
    }
  return fabs([f advancementForGlyph: g].width - [f widthOfString: string])
    < 0.01;
}

int
main(void)
{
  START_SET("winlib glyphWithName")

  NSFont *font = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      font = [NSFont userFontOfSize: 14];
    }
  NS_HANDLER
    {
      font = nil;
    }
  NS_ENDHANDLER

  if (font == nil)
    {
      SKIP("no win32 gui available")
    }
  else
    {
      /* An NSGlyph is a character on this backend, so the glyph of a name is
	 the character that name stands for. Checked directly because two
	 glyphs can share an advancement and pass the width checks below by
	 coincidence. */
      PASS([font glyphWithName: @"W"] == (NSGlyph)'W',
	"the glyph named W is the character W")
      PASS([font glyphWithName: @"i"] == (NSGlyph)'i',
	"the glyph named i is the character i")

      /* A standard name that is not the character it stands for. */
      PASS([font glyphWithName: @"eight"] == (NSGlyph)'8',
	"the glyph named eight is the character 8")
      PASS([font glyphWithName: @"zero"] == (NSGlyph)'0',
	"the glyph named zero is the character 0")
      PASS([font glyphWithName: @"space"] == (NSGlyph)' ',
	"the glyph named space is the character space")

      PASS(advancesLikeTheString(font, @"W", @"W"),
	"the glyph named W advances as the string W does")
      PASS(advancesLikeTheString(font, @"eight", @"8"),
	"the glyph named eight advances as the string 8 does")

      PASS([font glyphWithName: @"notaglyphname"] == NSNullGlyph,
	"a name the font does not carry answers NSNullGlyph")
    }

  END_SET("winlib glyphWithName")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib glyphWithName")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib glyphWithName")
  return 0;
}

#endif
