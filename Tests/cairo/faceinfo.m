/* Coverage for the fontconfig face descriptor (Source/fontconfig/FCFaceInfo.m)
 * and the character set it exposes (FontconfigCharacterSet in
 * Source/fontconfig/FCFontEnumerator.m).
 *
 * FCFaceInfo carries a family name, weight and traits (each with a getter and a
 * setter), a fixed cache size, and a display name built from the pattern: the
 * family alone when the pattern has no style, or the family and style together.
 * -characterSet resolves the pattern to a font and wraps its coverage as a
 * FontconfigCharacterSet, which reports ASCII characters as members and an
 * unassigned code point as not a member.
 *
 * The classes are private to the backend, so they are reached through
 * NSClassFromString once the backend is loaded, using the pattern generator to
 * build the FcPattern the face needs; the pattern is held opaquely.  It opens
 * the window server named by the environment and skips when there is none, and
 * guards on the cairo graphics backend being the one built.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>

@interface NSObject (FCFaceInfoRoundTrip)
- (void *) createPatternWithAttributes: (NSDictionary *)attributes;
- (id) initWithfamilyName: (NSString *)familyName
		   weight: (int)weight
		   traits: (unsigned int)traits
		  pattern: (void *)pattern;
- (NSString *) familyName;
- (void) setFamilyName: (NSString *)name;
- (int) weight;
- (void) setWeight: (int)weight;
- (unsigned int) traits;
- (void) setTraits: (unsigned int)traits;
- (unsigned int) cacheSize;
- (NSString *) displayName;
- (NSCharacterSet *) characterSet;
@end

int
main(void)
{
  START_SET("fontconfig face info")
  ENTER_POOL

  Class faceClass = Nil;
  id gen = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      faceClass = NSClassFromString(@"FCFaceInfo");
      gen = [[[NSClassFromString(@"FontconfigPatternGenerator") alloc] init]
	      autorelease];
    }
  NS_HANDLER
    {
      faceClass = Nil;
    }
  NS_ENDHANDLER

  if (faceClass == Nil || gen == nil)
    {
      SKIP("no fontconfig backend available")
    }
  else
    {
      NSDictionary *famAttrs = [NSDictionary
	dictionaryWithObject: @"Fam" forKey: NSFontFamilyAttribute];
      NSDictionary *styleAttrs = [NSDictionary
	dictionaryWithObjectsAndKeys:
	  @"Fam", NSFontFamilyAttribute,
	  @"Bold", NSFontFaceAttribute, nil];
      id face = [[[faceClass alloc]
		   initWithfamilyName: @"Fam"
			       weight: 80
			       traits: 0
			      pattern: [gen createPatternWithAttributes: famAttrs]]
		  autorelease];

      /* The family, weight and traits round-trip through the getters and
       * setters. */
      PASS([[face familyName] isEqualToString: @"Fam"],
	"familyName returns the family set at init")
      [face setFamilyName: @"Other"];
      PASS([[face familyName] isEqualToString: @"Other"],
	"setFamilyName updates the family")
      PASS([face weight] == 80, "weight returns the value set at init")
      [face setWeight: 200];
      PASS([face weight] == 200, "setWeight updates the weight")
      PASS([face traits] == 0, "traits returns the value set at init")
      [face setTraits: NSBoldFontMask];
      PASS([face traits] == NSBoldFontMask, "setTraits updates the traits")

      /* The cache size is a fixed value. */
      PASS([face cacheSize] == 257, "cacheSize is 257")

      /* displayName is the family when the pattern has no style... */
      {
	id plain = [[[faceClass alloc]
		      initWithfamilyName: @"Plain"
				  weight: 80
				  traits: 0
				 pattern: [gen createPatternWithAttributes: famAttrs]]
		     autorelease];
	PASS([[plain displayName] isEqualToString: @"Plain"],
	  "displayName is the family when the pattern has no style")
      }

      /* ...and the family and style together when it has one. */
      {
	id styled = [[[faceClass alloc]
		       initWithfamilyName: @"Fam"
				   weight: 80
				   traits: 0
				  pattern: [gen createPatternWithAttributes: styleAttrs]]
		      autorelease];
	PASS([[styled displayName] isEqualToString: @"Fam Bold"],
	  "displayName joins the family and style")
      }

      /* -characterSet wraps a resolved font's coverage. */
      {
	NSDictionary *sansAttrs = [NSDictionary
	  dictionaryWithObject: @"sans-serif" forKey: NSFontFamilyAttribute];
	id sans = [[[faceClass alloc]
		     initWithfamilyName: @"sans-serif"
				 weight: 80
				 traits: 0
				pattern: [gen createPatternWithAttributes: sansAttrs]]
		    autorelease];
	NSCharacterSet *cs = [sans characterSet];

	PASS(cs != nil, "characterSet resolves a font coverage set")
	if (cs != nil)
	  {
	    PASS([cs characterIsMember: (unichar) 'A']
	      && [cs characterIsMember: (unichar) 'z'],
	      "the coverage set contains basic ASCII letters")
	    PASS([cs longCharacterIsMember: (UTF32Char) 'A'],
	      "longCharacterIsMember reports a covered character")
	    PASS(![cs longCharacterIsMember: (UTF32Char) 0x10FFFF],
	      "the coverage set excludes an unassigned code point")
	  }
      }
    }

  LEAVE_POOL
  END_SET("fontconfig face info")
  return 0;
}

#else

int
main(void)
{
  START_SET("fontconfig face info")
    SKIP("back is not built with the cairo graphics backend")
  END_SET("fontconfig face info")
  return 0;
}

#endif
