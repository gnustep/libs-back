/* Tests the graphics state save and restore stack of the backend through the
 * AppKit offscreen path.  Saving the graphics state, changing the fill colour
 * or the clip, then restoring must return to the earlier state, and the stack
 * must nest so that an inner restore recovers the middle state and an outer
 * restore recovers the first.
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

/* Check the RGB sample at (x, y) with a small tolerance. */
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
      NSLog(@"no window server available; skipping save/restore tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* Restoring the graphics state recovers the earlier fill colour: red is set,
   * the state saved, blue set, then restored, so a fill uses red again. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  [NSGraphicsContext saveGraphicsState];
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  [NSGraphicsContext restoreGraphicsState];
  NSRectFill(NSMakeRect(0, 0, w, h));
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 255, 0, 0),
       "restoring the graphics state recovers the earlier fill colour");

  /* Restoring the graphics state recovers the earlier clip: with no clip set, a
   * clip to the left half is applied inside a saved state, then restored, so a
   * following fill reaches the right half again. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext saveGraphicsState];
  NSRectClip(NSMakeRect(0, 0, w / 2, h));
  [NSGraphicsContext restoreGraphicsState];
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 3 * w / 4, h / 2, 255, 0, 0),
       "restoring the graphics state lifts a clip set inside it");

  /* A clip applied inside a saved state still confines drawing before the
   * restore. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext saveGraphicsState];
  NSRectClip(NSMakeRect(0, 0, w / 2, h));
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext restoreGraphicsState];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 4, h / 2, 255, 0, 0)
       && pixelIs(rep, 3 * w / 4, h / 2, 255, 255, 255),
       "a clip inside a saved state confines drawing before the restore");

  /* The stack nests: red, save, green, save, blue, inner restore back to green,
   * outer restore back to red.  The left strip is filled after the inner
   * restore (green) and the right strip after the outer restore (red). */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  [NSGraphicsContext saveGraphicsState];
  [[NSColor colorWithDeviceRed: 0.0 green: 1.0 blue: 0.0 alpha: 1.0] set];
  [NSGraphicsContext saveGraphicsState];
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  [NSGraphicsContext restoreGraphicsState];
  NSRectFill(NSMakeRect(0, 0, w / 2, h));
  [NSGraphicsContext restoreGraphicsState];
  NSRectFill(NSMakeRect(w / 2, 0, w / 2, h));
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 4, h / 2, 0, 255, 0),
       "an inner restore recovers the middle colour on the stack");
  PASS(rep != nil && pixelIs(rep, 3 * w / 4, h / 2, 255, 0, 0),
       "an outer restore recovers the first colour on the stack");

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
