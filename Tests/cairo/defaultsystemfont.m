/* With no font from the backend's list of system fonts installed, a font is
 * still there to use: the system font is what fontconfig gives for sans-serif
 * instead of a name that nothing has.  A machine with Noto and no DejaVu is
 * like this, and without this no text is drawn.
 *
 * The test gives fontconfig a directory holding one font that isn't on the
 * list, found among those installed, and skips if there isn't one.  It needs
 * a running window server to load the backend at all.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

/* A font file, under the system's font directory, not of the listed families.
 */
static NSString *
findOtherFont(void)
{
  NSFileManager		*fm = [NSFileManager defaultManager];
  NSString		*top = @"/usr/share/fonts";
  NSDirectoryEnumerator	*e = [fm enumeratorAtPath: top];
  NSArray		*listed = [NSArray arrayWithObjects: @"dejavu", @"vera",
    @"freesans", @"freefont", @"tahoma", @"arial", nil];
  NSString		*path;

  while ((path = [e nextObject]) != nil)
    {
      NSString	*extension = [[path pathExtension] lowercaseString];
      NSString	*lower = [path lowercaseString];
      BOOL	skip = NO;
      NSUInteger	i;

      if (NO == [extension isEqual: @"ttf"] && NO == [extension isEqual: @"otf"])
	{
	  continue;
	}
      for (i = 0; i < [listed count]; i++)
	{
	  if ([lower rangeOfString: [listed objectAtIndex: i]].length > 0)
	    {
	      skip = YES;
	    }
	}
      if (NO == skip)
	{
	  return [top stringByAppendingPathComponent: path];
	}
    }
  return nil;
}

int
main(void)
{
  START_SET("the default system font without any listed font")
  NSFileManager	*fm = [NSFileManager defaultManager];
  NSString	*dir;
  NSString	*fonts;
  NSString	*font = findOtherFont();
  NSString	*config;
  NSFont	*f;

  if (nil == font)
    {
      SKIP("no font other than the listed ones is installed")
    }
  dir = [NSTemporaryDirectory() stringByAppendingPathComponent:
    [[NSProcessInfo processInfo] globallyUniqueString]];
  fonts = [dir stringByAppendingPathComponent: @"fonts"];
  [fm createDirectoryAtPath: fonts withIntermediateDirectories: YES
		 attributes: nil error: NULL];
  [fm copyItemAtPath: font
	      toPath: [fonts stringByAppendingPathComponent:
		[font lastPathComponent]]
	       error: NULL];
  config = [dir stringByAppendingPathComponent: @"fonts.conf"];
  [[NSString stringWithFormat:
    @"<?xml version=\"1.0\"?>\n<!DOCTYPE fontconfig SYSTEM \"fonts.dtd\">\n"
    @"<fontconfig><dir>%@</dir><cachedir>%@/cache</cachedir></fontconfig>\n",
    fonts, dir] writeToFile: config atomically: NO
		   encoding: NSUTF8StringEncoding error: NULL];
  setenv("FONTCONFIG_FILE", [config fileSystemRepresentation], 1);

  NS_DURING
    [NSApplication sharedApplication];
  NS_HANDLER
    [fm removeItemAtPath: dir error: NULL];
    SKIP("no display, or the backend isn't installed")
  NS_ENDHANDLER

  f = [NSFont systemFontOfSize: 12];
  PASS(f != nil, "there is a system font (%s)", [[font lastPathComponent] UTF8String])
  PASS(f != nil && [f maximumAdvancement].width > 0, "it has glyphs to draw")
  PASS([NSFont boldSystemFontOfSize: 12] != nil, "there is a bold system font")
  PASS([NSFont userFontOfSize: 12] != nil, "there is a user font")
  [fm removeItemAtPath: dir error: NULL];
  END_SET("the default system font without any listed font")
  return 0;
}

#else

int
main(void)
{
  START_SET("the default system font without any listed font")
    SKIP("back is not built with the cairo graphics backend")
  END_SET("the default system font without any listed font")
  return 0;
}

#endif
