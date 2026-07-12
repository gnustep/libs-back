/* Tests curved path rendering in the backend through the AppKit offscreen path.
 * Filling an oval paints inside the ellipse and leaves the corners of its
 * bounding box clear, and stroking a cubic curve follows the curve away from
 * the straight chord between its endpoints.  This exercises the curve segments
 * of the path (cairo_curve_to) rather than the straight lines the other render
 * tests use.
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

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  int w = 20, h = 20;
  NSImage *img;
  NSBitmapImageRep *rep;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping curve tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* A filled oval paints its centre and leaves the corners of the bounding box
   * clear, because the ellipse does not reach the corners. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  {
    NSBezierPath *p = [NSBezierPath bezierPath];
    [p appendBezierPathWithOvalInRect: NSMakeRect(2, 2, 16, 16)];
    [p fill];
  }
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 10, h - 1 - 10, 0, 0, 255),
       "a filled oval paints its centre");
  PASS(rep != nil && pixelIs(rep, 3, h - 1 - 3, 255, 255, 255),
       "a filled oval leaves the corner of its bounding box clear");

  /* Stroking a cubic curve follows the curve, not the straight chord.  The
   * curve runs from (2,4) to (18,4) with both control points high, so it peaks
   * near y = 12 at the middle and stays clear of the chord at y = 4. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  {
    NSBezierPath *p = [NSBezierPath bezierPath];
    [p setLineWidth: 2.0];
    [p moveToPoint: NSMakePoint(2, 4)];
    [p curveToPoint: NSMakePoint(18, 4)
       controlPoint1: NSMakePoint(2, 16)
       controlPoint2: NSMakePoint(18, 16)];
    [p stroke];
  }
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 10, h - 1 - 12, 0, 0, 0),
       "a stroked cubic curve paints along its raised middle");
  PASS(rep != nil && pixelIs(rep, 10, h - 1 - 4, 255, 255, 255),
       "a stroked cubic curve leaves the straight chord clear");

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
