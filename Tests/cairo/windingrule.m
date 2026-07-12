/* Tests the fill and clip winding rules of the graphics backend through the
 * AppKit offscreen path.  A path made of an outer rectangle and a smaller inner
 * rectangle wound the same way distinguishes the two rules: the non-zero rule
 * counts the inner region as enclosed twice and fills it, while the even-odd
 * rule counts it as crossed twice and leaves it as a hole.  The same path is
 * used as a clip to exercise the even-odd clip route.
 *
 * It needs a running window server, so it opens the display named by the
 * environment and skips cleanly when there is none, and it guards on the cairo
 * graphics backend being the one built.  Colours are checked with a small
 * tolerance to allow for the backend's fixed-point arithmetic.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <AppKit/NSBezierPath.h>
#include <stdlib.h>

static NSImage *
beginImage(int w, int h)
{
  NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(w, h)];
  [img lockFocus];
  return img;
}

static NSBitmapImageRep *
endImage(NSImage *img, int w, int h)
{
  NSBitmapImageRep *rep;

  [[NSGraphicsContext currentContext] flushGraphics];
  rep = [[NSBitmapImageRep alloc]
          initWithFocusedViewRect: NSMakeRect(0, 0, w, h)];
  [img unlockFocus];
  [img release];
  return [rep autorelease];
}

/* Check the RGB sample at (x, y) with a small tolerance.  The rep row 0 is the
 * top of the image, so callers flip y themselves. */
static BOOL
pixelIs(NSBitmapImageRep *rep, int x, int y, int r, int g, int b)
{
  NSUInteger px[5];

  [rep getPixel: px atX: x y: y];
  return (abs((int)px[0] - r) <= 2
          && abs((int)px[1] - g) <= 2
          && abs((int)px[2] - b) <= 2);
}

/* An outer rectangle with a smaller inner rectangle, both appended as rects so
 * they wind the same way.  The inner hole spans device x,y in 7..13. */
static NSBezierPath *
donutPath(void)
{
  NSBezierPath *p = [NSBezierPath bezierPath];
  [p appendBezierPathWithRect: NSMakeRect(2, 2, 16, 16)];
  [p appendBezierPathWithRect: NSMakeRect(7, 7, 6, 6)];
  return p;
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  int w = 20, h = 20;
  NSImage *img;
  NSBitmapImageRep *rep;
  NSBezierPath *p;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping winding rule tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* Non-zero fill: the inner region is enclosed twice, so it is filled and the
   * hole is painted over. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  p = donutPath();
  [p setWindingRule: NSNonZeroWindingRule];
  [p fill];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 10, h - 1 - 10, 0, 0, 255),
       "a non-zero fill paints the doubly-enclosed inner region");
  PASS(rep != nil && pixelIs(rep, 4, h - 1 - 10, 0, 0, 255),
       "a non-zero fill paints the outer ring");

  /* Even-odd fill: the inner region is crossed twice, so it is left as a hole
   * while the outer ring is still painted. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  p = donutPath();
  [p setWindingRule: NSEvenOddWindingRule];
  [p fill];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 10, h - 1 - 10, 255, 255, 255),
       "an even-odd fill leaves the inner region as a hole");
  PASS(rep != nil && pixelIs(rep, 4, h - 1 - 10, 0, 0, 255),
       "an even-odd fill still paints the outer ring");

  /* Even-odd clip: clipping with the even-odd rule confines a following fill to
   * the outer ring and leaves the inner hole and the outside untouched. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  p = donutPath();
  [p setWindingRule: NSEvenOddWindingRule];
  [p addClip];
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 4, h - 1 - 10, 255, 0, 0),
       "an even-odd clip admits drawing in the outer ring");
  PASS(rep != nil && pixelIs(rep, 10, h - 1 - 10, 255, 255, 255),
       "an even-odd clip excludes the inner hole");
  PASS(rep != nil && pixelIs(rep, 0, h - 1 - 0, 255, 255, 255),
       "an even-odd clip excludes the area outside the path");

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
