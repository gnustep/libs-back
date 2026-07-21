/* Tests that a shadow set on the graphics context is painted by the backend
 * through the AppKit offscreen path.  A shape is drawn with a coloured shadow
 * at a known offset and the offset region is checked for the shadow colour,
 * the shape is checked to still sit on top of its own shadow, and the shadow
 * state is checked to follow the graphics state stack.  Fill, even-odd fill and
 * stroke are each exercised.
 *
 * It needs a running window server, so it skips cleanly when there is none, and
 * it guards on one of the raster graphics backends that render shadows being
 * the one built.  Colours are checked with a small tolerance to allow for the
 * backend's fixed-point arithmetic.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) \
  && (BUILD_GRAPHICS == GRAPHICS_cairo \
      || BUILD_GRAPHICS == GRAPHICS_art \
      || BUILD_GRAPHICS == GRAPHICS_xlib)

#import <AppKit/AppKit.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSShadow.h>
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

static NSShadow *
redShadow(void)
{
  NSShadow *s = [[[NSShadow alloc] init] autorelease];

  [s setShadowColor: [NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0
                                           alpha: 1.0]];
  [s setShadowOffset: NSMakeSize(8, -8)];
  [s setShadowBlurRadius: 0.0];
  return s;
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  int w = 40, h = 40;
  NSImage *img;
  NSBitmapImageRep *rep;
  NSBezierPath *p;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping shadow tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* A blue rectangle with a red shadow offset to the lower right.  The shape
   * spans device x,y in 10..22 and the shadow 18..30 vertically 12..24. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext saveGraphicsState];
  [redShadow() set];
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  [[NSBezierPath bezierPathWithRect: NSMakeRect(10, 20, 12, 12)] fill];
  [NSGraphicsContext restoreGraphicsState];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 28, h - 1 - 16, 255, 0, 0),
       "a filled shape casts a shadow at the offset location");
  PASS(rep != nil && pixelIs(rep, 12, h - 1 - 30, 0, 0, 255),
       "a filled shape is drawn in its own colour");
  PASS(rep != nil && pixelIs(rep, 20, h - 1 - 22, 0, 0, 255),
       "a filled shape sits on top of its own shadow");
  PASS(rep != nil && pixelIs(rep, 3, h - 1 - 3, 255, 255, 255),
       "the shadow does not extend beyond its offset region");

  /* Even-odd fill casts a shadow through the same path. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext saveGraphicsState];
  [redShadow() set];
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  p = [NSBezierPath bezierPathWithRect: NSMakeRect(10, 20, 12, 12)];
  [p setWindingRule: NSEvenOddWindingRule];
  [p fill];
  [NSGraphicsContext restoreGraphicsState];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 28, h - 1 - 16, 255, 0, 0),
       "an even-odd fill casts a shadow at the offset location");

  /* A stroked shape casts a shadow of its outline. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext saveGraphicsState];
  [redShadow() set];
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  p = [NSBezierPath bezierPathWithRect: NSMakeRect(10, 20, 12, 12)];
  [p setLineWidth: 6];
  [p stroke];
  [NSGraphicsContext restoreGraphicsState];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 30, h - 1 - 18, 255, 0, 0),
       "a stroked shape casts a shadow of its outline");
  PASS(rep != nil && pixelIs(rep, 22, h - 1 - 26, 0, 0, 255),
       "a stroked shape is drawn in its own colour");

  /* The shadow follows the graphics state stack: after the state that set it is
   * restored, a further fill casts no shadow. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext saveGraphicsState];
  [redShadow() set];
  [NSGraphicsContext restoreGraphicsState];
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  [[NSBezierPath bezierPathWithRect: NSMakeRect(10, 20, 12, 12)] fill];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 28, h - 1 - 16, 255, 255, 255),
       "a restored graphics state clears the shadow");

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
