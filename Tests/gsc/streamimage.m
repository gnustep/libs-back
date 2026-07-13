/* Tests that GSStreamContext draws a bitmap image as a well-formed PostScript
 * image: the image dictionary, a colorimage operator, the pixels as hexadecimal
 * data, and the operators that follow on their own lines.
 *
 * GSStreamContext lives in the backend bundle, so the test needs a backend
 * loaded (hence a window server); it opens the display named by the
 * environment and skips when there is none.  The code under test is the same
 * for every backend; it is built for the cairo backend, which is the one that
 * loads on the test display.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

@interface NSObject (GSStreamContextImage)
- initWithContextInfo: (NSDictionary *)info;
- (void) GSDrawImage: (NSRect)r : (void *)imageref;
@end

static BOOL
contains(NSString *s, NSString *needle)
{
  if ([s rangeOfString: needle].location == NSNotFound)
    {
      NSLog(@"  missing PostScript text: '%@'", needle);
      return NO;
    }
  return YES;
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  Class cls;
  id x;
  NSString *path, *ps;
  NSBitmapImageRep *rep;
  unsigned char *d;
  int i;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping image test");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];
  cls = NSClassFromString(@"GSStreamContext");
  PASS(cls != Nil, "the GSStreamContext class is available");
  if (cls == Nil)
    {
      DESTROY(pool);
      return 0;
    }

  rep = [[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes: NULL
                  pixelsWide: 2 pixelsHigh: 2
               bitsPerSample: 8 samplesPerPixel: 3
                    hasAlpha: NO isPlanar: NO
              colorSpaceName: NSDeviceRGBColorSpace
                 bytesPerRow: 6 bitsPerPixel: 24];
  d = [rep bitmapData];
  for (i = 0; i < 12; i++)
    d[i] = (unsigned char)(i * 20);

  path = [NSTemporaryDirectory() stringByAppendingPathComponent: @"gsc_img.ps"];
  x = [[cls alloc] initWithContextInfo:
    [NSDictionary dictionaryWithObject: path forKey: @"NSOutputFile"]];
  [x GSDrawImage: NSMakeRect(0, 0, 2, 2) : rep];
  [x release];        /* dealloc closes and flushes the stream */
  [rep release];

  ps = [NSString stringWithContentsOfFile: path
                                 encoding: NSISOLatin1StringEncoding
                                    error: NULL];
  if (ps == nil)
    ps = @"";

  PASS(contains(ps, @"%% BeginImage") && contains(ps, @"%% EndImage")
    && contains(ps, @"2 2 8 [2 0 0 -2 0 2]")
    && contains(ps, @"currentfile 6 string readhexstring pop")
    && contains(ps, @"false 3 colorimage"),
    "GSDrawImage emits the image dictionary and colorimage operator");

  PASS(contains(ps, @"0014283c5064788ca0b4c8dc"),
    "GSDrawImage writes the pixels as hexadecimal image data");

  /* The hex data has to be terminated so the operator that restores the matrix
   * is a token of its own, not run onto the end of the data. */
  {
    NSArray *lines = [ps componentsSeparatedByString: @"\n"];

    PASS([lines containsObject: @"setmatrix"],
      "the image hex data is terminated before the setmatrix operator");
  }

  DESTROY(pool);
  return 0;
}

#else

int
main(int argc, const char **argv)
{
  return 0;
}

#endif
