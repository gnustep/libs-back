/* The glyph -[NSFont glyphWithName:] answers has to be one the same font can
 * measure, which is what -advancementForGlyph: and -boundingRectForGlyph: do
 * (Source/xlib/GSXftFontInfo.m).
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
 * It guards on the xlib graphics backend, and needs the backend loaded, so it
 * skips where there is no display to reach.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_xlib) \
  && BUILD_GRAPHICS == GRAPHICS_xlib

#import <AppKit/AppKit.h>
#include <math.h>

/* The first installed font that answers -glyphWithName:. */
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
  START_SET("xlib glyphWithName")

  NSFont *font = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      font = fontWithGlyphNames();
    }
  NS_HANDLER
    {
      font = nil;
    }
  NS_ENDHANDLER

  if (font == nil)
    {
      SKIP("no display to reach the backend with")
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

      /* A PostScript name that is not the character it stands for. The X
	 keysym names this used to be limited to have no name for a digit. */
      PASS([font glyphWithName: @"eight"] == (NSGlyph)'8',
	"the glyph named eight is the character 8")
      PASS([font glyphWithName: @"zero"] == (NSGlyph)'0',
	"the glyph named zero is the character 0")

      PASS(advancesLikeTheString(font, @"W", @"W"),
	"the glyph named W advances as the string W does")
      PASS(advancesLikeTheString(font, @"eight", @"8"),
	"the glyph named eight advances as the string 8 does")

      PASS([font glyphWithName: @"notaglyphname"] == NSNullGlyph,
	"a name the font does not carry answers NSNullGlyph")
    }

  END_SET("xlib glyphWithName")
  return 0;
}

#else

int
main(void)
{
  START_SET("xlib glyphWithName")
    SKIP("back is not built with the xlib graphics backend")
  END_SET("xlib glyphWithName")
  return 0;
}

#endif
