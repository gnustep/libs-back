/* NSCompositePlusDarker adds the two premultiplied colours and takes off the
 * amount by which their alphas overlap, so with both opaque it is
 * MAX(0, source + destination - 1).  Grey 0.8 over grey 0.6 is the case that
 * tells it apart from a darken blend: this operator gives 0.4, a darken blend
 * would give 0.6.
 *
 * It needs a window server to draw at all, so it skips cleanly when there is
 * none, and it guards on the cairo graphics backend.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

#define SIDE 20

/* Fill the destination, composite the source over it, read the centre back. */
static NSBitmapImageRep *
composite(NSColor *dest, NSColor *source, NSCompositingOperation op)
{
  NSImage *image;
  NSBitmapImageRep *rep;

  image = AUTORELEASE([[NSImage alloc]
    initWithSize: NSMakeSize(SIDE, SIDE)]);
  [image lockFocus];
  NSRectFillUsingOperation(NSMakeRect(0, 0, SIDE, SIDE), NSCompositeClear);
  if (dest != nil)
    {
      [dest set];
      NSRectFillUsingOperation(NSMakeRect(0, 0, SIDE, SIDE), NSCompositeCopy);
    }
  [source set];
  NSRectFillUsingOperation(NSMakeRect(0, 0, SIDE, SIDE), op);
  rep = AUTORELEASE([[NSBitmapImageRep alloc]
    initWithFocusedViewRect: NSMakeRect(0, 0, SIDE, SIDE)]);
  [image unlockFocus];
  return rep;
}

static NSColor *
grey(CGFloat g, CGFloat a)
{
  return [NSColor colorWithDeviceRed: g green: g blue: g alpha: a];
}

static NSColor *
rgb(CGFloat r, CGFloat g, CGFloat b, CGFloat a)
{
  return [NSColor colorWithDeviceRed: r green: g blue: b alpha: a];
}

/* The bytes come back premultiplied, and a destination fill rounds to the
 * nearest byte, so allow two. */
static BOOL
isPixel(NSBitmapImageRep *rep, int r, int g, int b, int a)
{
  unsigned char *p;

  if (rep == nil || [rep samplesPerPixel] < 4)
    {
      return NO;
    }
  p = [rep bitmapData] + (SIDE / 2) * [rep bytesPerRow]
    + (SIDE / 2) * ([rep bitsPerPixel] / 8);
  return (abs((int)p[0] - r) <= 2 && abs((int)p[1] - g) <= 2
    && abs((int)p[2] - b) <= 2 && abs((int)p[3] - a) <= 2);
}

int
main(int argc, const char **argv)
{
  START_SET("plus darker")

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      SKIP("no window server available")
    }

  NS_DURING
    {
      [NSApplication sharedApplication];
    }
  NS_HANDLER
    {
      NSLog(@"the application did not start: %@", localException);
      SKIP("It looks like the GNUstep backend is not installed")
    }
  NS_ENDHANDLER

  PASS(isPixel(composite(grey(0.6, 1.0), grey(0.8, 1.0), NSCompositePlusDarker),
      102, 102, 102, 255),
    "plus darker of 0.8 over 0.6 is 0.4, not the darker of the two");

  PASS(isPixel(composite(grey(0.6, 1.0), grey(0.4, 1.0), NSCompositePlusDarker),
      0, 0, 0, 255),
    "plus darker takes anything at or below 1 in total down to black");

  PASS(isPixel(composite(rgb(1, 0, 0, 1), rgb(0, 0, 1, 1),
      NSCompositePlusDarker), 0, 0, 0, 255),
    "plus darker of blue over red is black");

  PASS(isPixel(composite(nil, rgb(0, 0, 1, 1), NSCompositePlusDarker),
      0, 0, 255, 255),
    "plus darker over a cleared destination shows the source");

  PASS(isPixel(composite(rgb(1, 0, 0, 1), rgb(0, 0, 1, 0.5),
      NSCompositePlusDarker), 127, 0, 0, 255),
    "a half transparent source takes off half the overlap");

  PASS(isPixel(composite(grey(0.2, 1.0), grey(0.3, 1.0),
      NSCompositePlusLighter), 128, 128, 128, 255),
    "plus lighter adds the two");

  END_SET("plus darker")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("plus darker")
    SKIP("back is not built with the cairo graphics backend")
  END_SET("plus darker")
  return 0;
}

#endif
