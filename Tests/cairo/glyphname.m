/* The glyph -[NSFont glyphWithName:] answers has to be one the same font can
 * measure, which is what -advancementForGlyph: and -boundingRectForGlyph: do
 * (Source/cairo/CairoFontInfo.m).
 *
 * AppKit's contract, measured at 14pt on Helvetica, Times-Roman and the system
 * font: the advancement of the glyph named "W" equals the width of the string
 * "W", and the same holds for "i", "eight" against "8" and "zero" against "0".
 * A name the font does not carry answers NSNullGlyph.
 *
 * An NSGlyph is a character on this backend, so the number itself cannot match
 * the index AppKit reports; what is checked here is the invariant, that the
 * glyph measures as its character does.
 *
 * It guards on the cairo graphics backend and needs a font whose face carries
 * PostScript glyph names, so it skips when no installed font has them.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <math.h>

/* The first installed font that answers -glyphWithName:, since not every face
 * carries PostScript glyph names. */
static NSFont *
fontWithGlyphNames(void)
{
  NSArray *names = [[NSFontManager sharedFontManager] availableFonts];
  NSUInteger i;

  for (i = 0; i < [names count]; i++)
    {
      NSFont *f = [NSFont fontWithName: [names objectAtIndex: i] size: 14];

      if (f != nil && [f glyphWithName: @"W"] != NSNullGlyph)
	{
	  return f;
	}
    }
  return nil;
}

/* Whether the glyph of that name advances as the string does. */
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
  START_SET("cairo glyphWithName")

  NSFont *anyFont = nil;
  NSFont *font = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      anyFont = [NSFont userFontOfSize: 14];
      font = fontWithGlyphNames();
    }
  NS_HANDLER
    {
      anyFont = nil;
      font = nil;
    }
  NS_ENDHANDLER

  if (anyFont == nil)
    {
      SKIP("no backend to reach a font with")
    }
  else
    {
      /* Holds whether or not the face carries glyph names, so it runs
	 wherever there is a backend at all. */
      PASS([anyFont glyphWithName: @"notaglyphname"] == NSNullGlyph,
	"a name no font carries answers NSNullGlyph")
    }

  if (font == nil)
    {
      SKIP("no installed font carries PostScript glyph names")
    }
  else
    {
      NSGlyph w = [font glyphWithName: @"W"];

      /* An NSGlyph is a character on this backend, so the glyph of a name is
	 the character that name stands for. Checked directly because two
	 glyphs can share an advancement and pass the width checks below by
	 coincidence. */
      PASS(w == (NSGlyph)'W', "the glyph named W is the character W")
      PASS([font glyphWithName: @"i"] == (NSGlyph)'i',
	"the glyph named i is the character i")
      PASS([font glyphWithName: @"eight"] == (NSGlyph)'8',
	"the glyph named eight is the character 8")
      PASS([font glyphWithName: @"zero"] == (NSGlyph)'0',
	"the glyph named zero is the character 0")

      PASS(advancesLikeTheString(font, @"W", @"W"),
	"the glyph named W advances as the string W does")

      PASS(advancesLikeTheString(font, @"i", @"i"),
	"the glyph named i advances as the string i does")

      /* A name that is not the character it stands for. */
      PASS(advancesLikeTheString(font, @"eight", @"8"),
	"the glyph named eight advances as the string 8 does")

      PASS(advancesLikeTheString(font, @"zero", @"0"),
	"the glyph named zero advances as the string 0 does")

      /* The bounding box follows the same convention as the advancement. */
      PASS(NSEqualRects([font boundingRectForGlyph: w],
			[font boundingRectForGlyph:
			  (NSGlyph)[@"W" characterAtIndex: 0]]),
	"the glyph named W has the bounding rect of the character W")

    }

  END_SET("cairo glyphWithName")
  return 0;
}

#else

int
main(void)
{
  START_SET("cairo glyphWithName")
    SKIP("back is not built with the cairo graphics backend")
  END_SET("cairo glyphWithName")
  return 0;
}

#endif
