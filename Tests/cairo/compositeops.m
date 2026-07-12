/* Tests the cairo backend's compositing operators.  A red destination is
 * filled, then a second fill is made with a given NSCompositingOperation, and
 * the resulting pixel is read back with -initWithFocusedViewRect: and checked.
 * This exercises the operator mapping (NSCompositingOperation to the cairo
 * operator) in the cairo graphics state.
 *
 * It needs a window server (to load the backend), so it opens the display named
 * by the environment and skips when there is none, and it guards on the cairo
 * graphics backend being the one built.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
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

static BOOL
pixelIs(NSBitmapImageRep *rep, int x, int y, int r, int g, int b)
{
  NSUInteger px[5];

  [rep getPixel: px atX: x y: y];
  return (abs((int)px[0] - r) <= 2
          && abs((int)px[1] - g) <= 2
          && abs((int)px[2] - b) <= 2);
}

/* Fill a red destination, then fill it again with FG using OP, and read the
 * centre pixel back. */
static NSBitmapImageRep *
composite(NSColor *fg, NSCompositingOperation op)
{
  int w = 20, h = 20;
  NSImage *img = beginImage(w, h);

  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [fg set];
  NSRectFillUsingOperation(NSMakeRect(0, 0, w, h), op);
  return endImage(img, w, h);
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSColor *blue = [NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0];
  NSColor *green = [NSColor colorWithDeviceRed: 0.0 green: 1.0 blue: 0.0 alpha: 1.0];

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping compositing tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  PASS(pixelIs(composite(blue, NSCompositeCopy), 10, 10, 0, 0, 255),
    "copy replaces the destination with the source");

  PASS(pixelIs(composite(blue, NSCompositeSourceOver), 10, 10, 0, 0, 255),
    "source-over with an opaque source shows the source");

  PASS(pixelIs(composite(blue, NSCompositeDestinationOver), 10, 10, 255, 0, 0),
    "destination-over keeps the opaque destination");

  PASS(pixelIs(composite(green, NSCompositePlusLighter), 10, 10, 255, 255, 0),
    "plus-lighter adds the source to the destination");

  PASS(pixelIs(composite(blue, NSCompositeClear), 10, 10, 0, 0, 0),
    "clear erases the destination");

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
