/* What is drawn into an offscreen image has to be recorded in the alpha plane
 * the window keeps, so that reading the pixels back reports the alpha that was
 * drawn: an opaque fill reads back opaque, and a cleared rectangle reads back
 * transparent.
 *
 * The plane is created the first time something needs it, which for an image
 * cache is the clear the drawing starts with, so a graphics state set up
 * before that has to take the plane before it draws.
 *
 * It needs a window server to draw at all, so it skips cleanly when there is
 * none, and it guards on the xlib graphics backend being the one built.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_xlib) \
  && BUILD_GRAPHICS == GRAPHICS_xlib

#import <AppKit/AppKit.h>
#include <stdlib.h>

#define SIDE 20

enum
{
  OpaqueFill,
  Cleared,
  FillThenClear,
  ClearThenFill,
  HalfFill
};

static void
fill(CGFloat alpha)
{
  [[NSColor colorWithDeviceRed: 1.0
                         green: 0.0
                          blue: 0.0
                         alpha: alpha] set];
  NSRectFill(NSMakeRect(0, 0, SIDE, SIDE));
}

static void
clear(void)
{
  NSRectFillUsingOperation(NSMakeRect(0, 0, SIDE, SIDE), NSCompositeClear);
}

/* Draw one of the cases into an offscreen image and read the pixels back. */
static NSBitmapImageRep *
drawn(int which)
{
  NSImage *image;
  NSBitmapImageRep *rep;

  image = AUTORELEASE([[NSImage alloc]
    initWithSize: NSMakeSize(SIDE, SIDE)]);
  [image lockFocus];
  switch (which)
    {
      case OpaqueFill:
        fill(1.0);
        break;
      case Cleared:
        clear();
        break;
      case FillThenClear:
        fill(1.0);
        clear();
        break;
      case ClearThenFill:
        clear();
        fill(1.0);
        break;
      case HalfFill:
        fill(0.5);
        break;
    }
  rep = AUTORELEASE([[NSBitmapImageRep alloc]
    initWithFocusedViewRect: NSMakeRect(0, 0, SIDE, SIDE)]);
  [image unlockFocus];
  return rep;
}

static int
sample(NSBitmapImageRep *rep, int index)
{
  unsigned char *p;

  if (rep == nil || [rep samplesPerPixel] < 4)
    {
      return -1;
    }
  p = [rep bitmapData] + (SIDE / 2) * [rep bytesPerRow]
    + (SIDE / 2) * ([rep bitsPerPixel] / 8);
  return (int)p[index];
}

int
main(int argc, const char **argv)
{
  START_SET("alpha recording")

  NSBitmapImageRep *rep;

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

  rep = drawn(OpaqueFill);
  PASS(rep != nil, "an offscreen image reads back");
  PASS(sample(rep, 0) == 255 && sample(rep, 1) == 0 && sample(rep, 2) == 0,
    "an opaque fill reads back as the colour that was drawn");
  PASS(sample(rep, 3) == 255,
    "an opaque fill reads back opaque");

  PASS(sample(drawn(Cleared), 3) == 0,
    "a cleared rectangle reads back transparent");

  PASS(sample(drawn(FillThenClear), 3) == 0,
    "clearing over an opaque fill reads back transparent");

  PASS(sample(drawn(ClearThenFill), 3) == 255,
    "an opaque fill over a cleared rectangle reads back opaque");

  rep = drawn(HalfFill);
  PASS(sample(rep, 3) > 100 && sample(rep, 3) < 160,
    "a half transparent fill reads back half transparent");

  END_SET("alpha recording")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("alpha recording")
    SKIP("back is not built with the xlib graphics backend")
  END_SET("alpha recording")
  return 0;
}

#endif
