/* Tests that successive clips intersect in the backend, through the AppKit
 * offscreen path.  Setting a second clip does not replace the first: drawing is
 * confined to the intersection of the two, and two disjoint clips leave nothing
 * to draw.  The other render tests only set a single clip, so this covers the
 * accumulation of the clip stack.
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
      NSLog(@"no window server available; skipping clip stack tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* Two clips intersect: a clip to the left half and then to the top half
   * confine a fill to the top-left quadrant only. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  NSRectClip(NSMakeRect(0, 0, w / 2, h));
  NSRectClip(NSMakeRect(0, h / 2, w, h / 2));
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 4, h - 1 - (3 * h / 4), 255, 0, 0),
       "two clips admit drawing in their intersecting quadrant");
  PASS(rep != nil && pixelIs(rep, 3 * w / 4, h - 1 - (3 * h / 4), 255, 255, 255),
       "the quadrant outside the first clip stays clear");
  PASS(rep != nil && pixelIs(rep, w / 4, h - 1 - (h / 4), 255, 255, 255),
       "the quadrant outside the second clip stays clear");

  /* Two disjoint clips leave an empty region: a clip to the left half and then
   * to the right half admit no drawing at all. */
  img = beginImage(w, h);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  NSRectClip(NSMakeRect(0, 0, w / 2, h));
  NSRectClip(NSMakeRect(w / 2, 0, w / 2, h));
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 4, h / 2, 255, 255, 255)
       && pixelIs(rep, 3 * w / 4, h / 2, 255, 255, 255),
       "two disjoint clips leave nothing to draw");

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
