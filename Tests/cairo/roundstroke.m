/* Tests the round line cap and round line join of the backend through the
 * AppKit offscreen path.  A round cap paints a half-disc past the endpoint but
 * rounds off the corner a square cap would fill, and a round join cuts the
 * sharp outer corner a miter join would fill.  The other render tests cover the
 * butt and square caps and the miter and bevel joins, so this covers the round
 * variants.
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

/* Count dark pixels in the square [x0,x1) x [y0,y1) of the rep. */
static long
darkCount(NSBitmapImageRep *rep, int x0, int y0, int x1, int y1)
{
  long n = 0;
  int x, y;

  for (y = y0; y < y1; y++)
    for (x = x0; x < x1; x++)
      {
        NSUInteger px[5];

        [rep getPixel: px atX: x y: y];
        if (px[0] < 100)
          n++;
      }
  return n;
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  int w = 40, h = 40;
  NSImage *img;
  NSBitmapImageRep *rep;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping round stroke tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* A round cap paints a half-disc past the endpoint, so a point on the axis
   * just beyond the endpoint is painted, but rounds off the square corner, so a
   * point out at the corner of where a square cap would reach is left clear.
   * The line runs to x = 24 with width 12 (radius 6). */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  {
    NSBezierPath *p = [NSBezierPath bezierPath];
    [p setLineWidth: 12.0];
    [p setLineCapStyle: NSRoundLineCapStyle];
    [p moveToPoint: NSMakePoint(8, 20)];
    [p lineToPoint: NSMakePoint(24, 20)];
    [p stroke];
  }
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 28, h - 1 - 20, 0, 0, 0),
       "a round cap paints on the axis past the endpoint");
  PASS(rep != nil && pixelIs(rep, 29, h - 1 - 25, 255, 255, 255),
       "a round cap rounds off the corner a square cap would fill");

  /* A round join cuts the sharp outer corner, so it fills fewer pixels in the
   * outer-corner region than a miter join.  The path bends at (12,12) from a
   * vertical to a horizontal segment; the outer corner is the lower-left. */
  {
    long dark[2] = { 0, 0 };
    int style;

    for (style = 0; style < 2; style++)
      {
        img = beginImage(w, h);
        [[NSColor whiteColor] set];
        NSRectFill(NSMakeRect(0, 0, w, h));
        [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
        {
          NSBezierPath *p = [NSBezierPath bezierPath];
          [p setLineWidth: 12.0];
          [p setLineJoinStyle: (style == 0 ? NSMiterLineJoinStyle
                                           : NSRoundLineJoinStyle)];
          [p moveToPoint: NSMakePoint(12, 32)];
          [p lineToPoint: NSMakePoint(12, 12)];
          [p lineToPoint: NSMakePoint(32, 12)];
          [p stroke];
        }
        rep = endImage(img, w, h);
        /* The miter fills the outer wedge out to the sharp corner at device
         * (6,6); the differing region is device x,y in 6..12, which in rep
         * space is cols 6..12, rows h-1-12 .. h-1-6. */
        dark[style] = darkCount(rep, 5, h - 1 - 12, 13, h - 1 - 5);
      }
    PASS(dark[0] > dark[1],
         "a miter join fills the outer corner more than a round join");
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
