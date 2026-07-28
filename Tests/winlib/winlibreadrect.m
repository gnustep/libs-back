/* Read back tests for the winlib graphics backend: the rows of a read come
 * back with the top of the drawing first, and reading part of a drawing gives
 * that part rather than whatever is at the top of it.  This exercises
 * WIN32GState's -GSReadRect:, which is what -initWithFocusedViewRect: goes
 * through.
 *
 * It guards on the winlib graphics backend and skips when the backend cannot be
 * reached; colours are checked with a small tolerance.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_winlib) \
  && BUILD_GRAPHICS == GRAPHICS_winlib

#import <AppKit/AppKit.h>
#include <stdlib.h>

static BOOL
pixelIs(NSBitmapImageRep *rep, int x, int y, int r, int g, int b)
{
  unsigned char *d = [rep bitmapData];
  long bpr = [rep bytesPerRow];
  long spp = [rep samplesPerPixel];
  unsigned char *px = d + y * bpr + x * spp;

  return (abs((int)px[0] - r) <= 2
	  && abs((int)px[1] - g) <= 2
	  && abs((int)px[2] - b) <= 2);
}

int
main(void)
{
  START_SET("winlib read back")
  ENTER_POOL

  BOOL haveApp = NO;

  NS_DURING
    {
      [NSApplication sharedApplication];
      haveApp = YES;
    }
  NS_HANDLER
    {
      haveApp = NO;
    }
  NS_ENDHANDLER

  if (haveApp == NO)
    {
      SKIP("no win32 gui available")
    }
  else
    {
      NSImage          *img;
      NSBitmapImageRep *whole;
      NSBitmapImageRep *part;
      int               w = 40, h = 40;

      /* White, with a red band along the bottom and a blue one along the top.
       * A read of the whole drawing starts with its top row, so the blue band
       * comes first and the red one last. */
      img = [[NSImage alloc] initWithSize: NSMakeSize(w, h)];
      [img lockFocus];
      [[NSColor colorWithDeviceRed: 1 green: 1 blue: 1 alpha: 1] set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      [[NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1] set];
      NSRectFill(NSMakeRect(0, 0, w, 10));
      [[NSColor colorWithDeviceRed: 0 green: 0 blue: 1 alpha: 1] set];
      NSRectFill(NSMakeRect(0, h - 10, w, 10));
      [[NSGraphicsContext currentContext] flushGraphics];
      whole = [[NSBitmapImageRep alloc]
		initWithFocusedViewRect: NSMakeRect(0, 0, w, h)];
      part = [[NSBitmapImageRep alloc]
	       initWithFocusedViewRect: NSMakeRect(0, 10, w, 10)];
      [img unlockFocus];
      [img release];
      [whole autorelease];
      [part autorelease];

      PASS(whole != nil && pixelIs(whole, w / 2, 2, 0, 0, 255),
	"a read starts with the top of the drawing")
      PASS(whole != nil && pixelIs(whole, w / 2, h - 3, 255, 0, 0),
	"a read ends with the bottom of the drawing")
      PASS(whole != nil && pixelIs(whole, w / 2, h / 2, 255, 255, 255),
	"what lies between the two comes back between them")
      PASS(part != nil && [part pixelsHigh] == 10,
	"reading part of a drawing gives a bitmap of that size")
      PASS(part != nil && pixelIs(part, w / 2, 5, 255, 255, 255),
	"reading part of a drawing gives that part, not the top of it")
    }

  LEAVE_POOL
  END_SET("winlib read back")

  return 0;
}

#else

int
main(void)
{
  START_SET("winlib read back")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib read back")
  return 0;
}

#endif
