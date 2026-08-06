/* The compositing operators, checked by reading the pixels back.  An opaque
 * blue is composited over an opaque red destination and over a cleared one,
 * and each operator keeps the source, the destination, or neither.
 *
 * The colours here are opaque, where the backend's own convention for storing
 * a partly transparent colour does not come into it, and every value below is
 * what AppKit answers for the same drawing.
 *
 * It needs a window server to draw at all, so it skips cleanly when there is
 * none, and it guards on the xlib graphics backend.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_xlib) \
  && BUILD_GRAPHICS == GRAPHICS_xlib

#import <AppKit/AppKit.h>
#include <stdlib.h>

#define SIDE 20

/* Fill the destination if there is one, composite blue over it with OP, and
 * read the centre pixel back. */
static NSBitmapImageRep *
composite(BOOL opaqueDestination, NSCompositingOperation op)
{
  NSImage *image;
  NSBitmapImageRep *rep;

  image = AUTORELEASE([[NSImage alloc]
    initWithSize: NSMakeSize(SIDE, SIDE)]);
  [image lockFocus];
  NSRectFillUsingOperation(NSMakeRect(0, 0, SIDE, SIDE), NSCompositeClear);
  if (opaqueDestination)
    {
      [[NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1] set];
      NSRectFillUsingOperation(NSMakeRect(0, 0, SIDE, SIDE), NSCompositeCopy);
    }
  [[NSColor colorWithDeviceRed: 0 green: 0 blue: 1 alpha: 1] set];
  NSRectFillUsingOperation(NSMakeRect(0, 0, SIDE, SIDE), op);
  rep = AUTORELEASE([[NSBitmapImageRep alloc]
    initWithFocusedViewRect: NSMakeRect(0, 0, SIDE, SIDE)]);
  [image unlockFocus];
  return rep;
}

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
  START_SET("composite operators")

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

  /* Over an opaque destination. */
  PASS(isPixel(composite(YES, NSCompositeCopy), 0, 0, 255, 255),
    "copy replaces the destination");
  PASS(isPixel(composite(YES, NSCompositeSourceOver), 0, 0, 255, 255),
    "source over shows an opaque source");
  PASS(isPixel(composite(YES, NSCompositeSourceIn), 0, 0, 255, 255),
    "source in shows the source where the destination is opaque");
  PASS(isPixel(composite(YES, NSCompositeSourceOut), 0, 0, 0, 0),
    "source out shows nothing where the destination is opaque");
  PASS(isPixel(composite(YES, NSCompositeSourceAtop), 0, 0, 255, 255),
    "source atop shows the source over an opaque destination");
  PASS(isPixel(composite(YES, NSCompositeDestinationOver), 255, 0, 0, 255),
    "destination over keeps an opaque destination");
  PASS(isPixel(composite(YES, NSCompositeDestinationIn), 255, 0, 0, 255),
    "destination in keeps the destination under an opaque source");
  PASS(isPixel(composite(YES, NSCompositeDestinationOut), 0, 0, 0, 0),
    "destination out erases the destination under an opaque source");
  PASS(isPixel(composite(YES, NSCompositeDestinationAtop), 255, 0, 0, 255),
    "destination atop keeps the destination under an opaque source");
  PASS(isPixel(composite(YES, NSCompositeXOR), 0, 0, 0, 0),
    "exclusive or of two opaque pixels leaves nothing");
  PASS(isPixel(composite(YES, NSCompositePlusDarker), 0, 0, 0, 255),
    "plus darker of blue over red is black");
  PASS(isPixel(composite(YES, NSCompositePlusLighter), 255, 0, 255, 255),
    "plus lighter adds the source to the destination");
  PASS(isPixel(composite(YES, NSCompositeClear), 0, 0, 0, 0),
    "clear erases the destination");

  /* Over a cleared destination. */
  PASS(isPixel(composite(NO, NSCompositeSourceOver), 0, 0, 255, 255),
    "source over a cleared destination shows the source");
  PASS(isPixel(composite(NO, NSCompositeSourceIn), 0, 0, 0, 0),
    "source in shows nothing where the destination is transparent");
  PASS(isPixel(composite(NO, NSCompositeSourceOut), 0, 0, 255, 255),
    "source out shows the source where the destination is transparent");
  PASS(isPixel(composite(NO, NSCompositeDestinationOver), 0, 0, 255, 255),
    "destination over a cleared destination shows the source");
  PASS(isPixel(composite(NO, NSCompositeDestinationIn), 0, 0, 0, 0),
    "destination in leaves a cleared destination cleared");
  PASS(isPixel(composite(NO, NSCompositeDestinationAtop), 0, 0, 255, 255),
    "destination atop a cleared destination shows the source");
  PASS(isPixel(composite(NO, NSCompositeXOR), 0, 0, 255, 255),
    "exclusive or over a cleared destination shows the source");

  END_SET("composite operators")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("composite operators")
    SKIP("back is not built with the xlib graphics backend")
  END_SET("composite operators")
  return 0;
}

#endif
