/* Coverage for the fontconfig pattern generator and parser
 * (FontconfigPatternGenerator / FontconfigPatternParser in
 * Source/fontconfig/FCFontEnumerator.m), the mapping between NSFontDescriptor
 * attributes and a fontconfig pattern.
 *
 * The two are inverses: -createPatternWithAttributes: builds a pattern from an
 * attribute dictionary and -attributesFromPattern: reads one back.  The test
 * runs attributes through both and checks that the family name, style name,
 * size, visible name and the symbolic traits (bold, italic, monospace,
 * condensed, expanded) survive the round trip.  The continuous weight and width
 * scales are not checked, since they are quantised to fontconfig's integer
 * range and do not return the same value.
 *
 * The two classes are private to the backend, so they are reached through
 * NSClassFromString once the backend is loaded, and the pattern is passed
 * between them opaquely.  It needs the backend loaded, so it opens the window
 * server named by the environment and skips when there is none, and guards on
 * the cairo graphics backend being the one built.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>

/* The generator returns an FcPattern* and the parser reads one; the test only
 * passes it between them, so it is held opaquely to avoid a fontconfig
 * dependency in the test. */
@interface NSObject (FontconfigPatternRoundTrip)
- (void *) createPatternWithAttributes: (NSDictionary *)attributes;
- (NSDictionary *) attributesFromPattern: (void *)pattern;
@end

static NSDictionary *
roundTrip(id generator, id parser, NSDictionary *attributes)
{
  void *pattern = [generator createPatternWithAttributes: attributes];

  return [parser attributesFromPattern: pattern];
}

static NSDictionary *
attributesWithTraits(NSDictionary *traits)
{
  return [NSDictionary dictionaryWithObject: traits
				     forKey: NSFontTraitsAttribute];
}

static BOOL
symbolicTraitRoundTrips(id generator, id parser, NSFontSymbolicTraits trait)
{
  NSDictionary *traits = [NSDictionary
    dictionaryWithObject: [NSNumber numberWithUnsignedInt: trait]
		  forKey: NSFontSymbolicTrait];
  NSDictionary *out = roundTrip(generator, parser,
    attributesWithTraits(traits));
  NSDictionary *outTraits = [out objectForKey: NSFontTraitsAttribute];
  NSFontSymbolicTraits outSym
    = [[outTraits objectForKey: NSFontSymbolicTrait] unsignedIntValue];

  return (outSym & trait) == trait;
}

int
main(void)
{
  START_SET("fontconfig pattern round trip")
  ENTER_POOL

  Class genClass = Nil;
  Class parserClass = Nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      genClass = NSClassFromString(@"FontconfigPatternGenerator");
      parserClass = NSClassFromString(@"FontconfigPatternParser");
    }
  NS_HANDLER
    {
      genClass = Nil;
      parserClass = Nil;
    }
  NS_ENDHANDLER

  if (genClass == Nil || parserClass == Nil)
    {
      SKIP("no fontconfig backend available")
    }
  else
    {
      id gen = [[[genClass alloc] init] autorelease];
      id parser = [[[parserClass alloc] init] autorelease];

      /* The family name is carried through unchanged. */
      {
	NSDictionary *out = roundTrip(gen, parser,
	  [NSDictionary dictionaryWithObject: @"DejaVu Sans"
				      forKey: NSFontFamilyAttribute]);
	PASS([[out objectForKey: NSFontFamilyAttribute]
	       isEqualToString: @"DejaVu Sans"],
	  "the family name round-trips")
      }

      /* The style name is carried through unchanged. */
      {
	NSDictionary *out = roundTrip(gen, parser,
	  [NSDictionary dictionaryWithObject: @"Bold Italic"
				      forKey: NSFontFaceAttribute]);
	PASS([[out objectForKey: NSFontFaceAttribute]
	       isEqualToString: @"Bold Italic"],
	  "the style name round-trips")
      }

      /* The visible name is carried through unchanged. */
      {
	NSDictionary *out = roundTrip(gen, parser,
	  [NSDictionary dictionaryWithObject: @"DejaVu Sans Bold"
				      forKey: NSFontVisibleNameAttribute]);
	PASS([[out objectForKey: NSFontVisibleNameAttribute]
	       isEqualToString: @"DejaVu Sans Bold"],
	  "the visible name round-trips")
      }

      /* The size is carried through unchanged. */
      {
	NSDictionary *out = roundTrip(gen, parser,
	  [NSDictionary dictionaryWithObject: [NSNumber numberWithDouble: 12.5]
				      forKey: NSFontSizeAttribute]);
	PASS([[out objectForKey: NSFontSizeAttribute] doubleValue] == 12.5,
	  "the size round-trips")
      }

      /* The symbolic traits survive the round trip. */
      PASS(symbolicTraitRoundTrips(gen, parser, NSFontBoldTrait),
	"the bold trait round-trips")
      PASS(symbolicTraitRoundTrips(gen, parser, NSFontItalicTrait),
	"the italic trait round-trips")
      PASS(symbolicTraitRoundTrips(gen, parser, NSFontMonoSpaceTrait),
	"the monospace trait round-trips")
      PASS(symbolicTraitRoundTrips(gen, parser, NSFontCondensedTrait),
	"the condensed trait round-trips")
      PASS(symbolicTraitRoundTrips(gen, parser, NSFontExpandedTrait),
	"the expanded trait round-trips")
    }

  LEAVE_POOL
  END_SET("fontconfig pattern round trip")
  return 0;
}

#else

int
main(void)
{
  START_SET("fontconfig pattern round trip")
    SKIP("back is not built with the cairo graphics backend")
  END_SET("fontconfig pattern round trip")
  return 0;
}

#endif
