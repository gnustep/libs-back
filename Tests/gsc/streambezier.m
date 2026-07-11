/* Tests that GSStreamContext turns an NSBezierPath into PostScript: newpath,
 * the path line attributes, and then the path elements in order.
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

@interface NSObject (GSStreamContextBezier)
- initWithContextInfo: (NSDictionary *)info;
- (void) GSSendBezierPath: (NSBezierPath *)path;
@end

static BOOL
hasLines(NSArray *lines, NSArray *want)
{
  NSEnumerator *e = [want objectEnumerator];
  NSString *w;

  while ((w = [e nextObject]) != nil)
    if (![lines containsObject: w])
      {
        NSLog(@"  missing PostScript line: '%@'", w);
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
  NSString *path;
  NSBezierPath *bp;
  NSArray *lines;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping bezier path test");
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

  bp = [NSBezierPath bezierPath];
  [bp moveToPoint: NSMakePoint(10, 20)];
  [bp lineToPoint: NSMakePoint(30, 40)];
  [bp curveToPoint: NSMakePoint(50, 60)
      controlPoint1: NSMakePoint(11, 12)
      controlPoint2: NSMakePoint(13, 14)];
  [bp closePath];
  [bp setLineWidth: 3.0];
  [bp setLineJoinStyle: NSRoundLineJoinStyle];
  [bp setLineCapStyle: NSSquareLineCapStyle];
  [bp setMiterLimit: 5.0];
  [bp setFlatness: 2.0];

  path = [NSTemporaryDirectory() stringByAppendingPathComponent: @"gsc_bp.ps"];
  x = [[cls alloc] initWithContextInfo:
    [NSDictionary dictionaryWithObject: path forKey: @"NSOutputFile"]];
  [x GSSendBezierPath: bp];
  [x release];        /* dealloc closes and flushes the stream */

  {
    NSString *out = [NSString stringWithContentsOfFile: path
                                             encoding: NSISOLatin1StringEncoding
                                                error: NULL];
    lines = [(out ? out : @"") componentsSeparatedByString: @"\n"];
  }

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"newpath", @"3 setlinewidth", @"1 setlinejoin", @"2 setlinecap",
    @"5 setmiterlimit", @"2 setflat", nil]),
    "GSSendBezierPath emits newpath and the path line attributes");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"10 20 moveto", @"30 40 lineto", @"11 12 13 14 50 60 curveto",
    @"closepath", nil]),
    "GSSendBezierPath emits the path elements in order");

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
