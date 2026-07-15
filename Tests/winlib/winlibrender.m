/* Rendering tests for the winlib graphics backend, driven through the AppKit
 * offscreen path: lock focus on an NSImage, draw with the win32 GDI graphics
 * state, then read the pixels back with -initWithFocusedViewRect: and check
 * them.  This exercises WIN32GState's fill, path and compositing rendering plus
 * the GSReadRect read-back (Source/winlib/WIN32GState.m).
 *
 * It guards on the winlib graphics backend being the one built and skips when
 * the backend cannot be reached; colours are checked with a small tolerance to
 * allow for the backend's arithmetic.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_winlib) \
  && BUILD_GRAPHICS == GRAPHICS_winlib

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

/* Check the pixel at (x, y) in device-RGB byte order with a small tolerance.
 * The rep row 0 is the top of the image. */
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
  START_SET("winlib rendering")
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
      NSBitmapImageRep *rep;
      int               w = 20, h = 20;

      /* A solid fill paints the whole image. */
      img = beginImage(w, h);
      [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 255, 0, 0),
	"a solid fill paints red")

      /* Filling the left half leaves the right half alone (the x axis is not
       * affected by the flipped y origin). */
      img = beginImage(w, h);
      [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      [[NSColor colorWithDeviceRed: 0.0 green: 1.0 blue: 0.0 alpha: 1.0] set];
      NSRectFill(NSMakeRect(0, 0, w / 2, h));
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, w / 4, h / 2, 0, 255, 0),
	"the left half is filled green")
      PASS(rep != nil && pixelIs(rep, 3 * w / 4, h / 2, 255, 0, 0),
	"the right half stays red")

      /* Filling a bezier-path rectangle paints inside and leaves outside. */
      img = beginImage(w, h);
      [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
      {
	NSBezierPath *p = [NSBezierPath bezierPath];
	[p appendBezierPathWithRect: NSMakeRect(2, 2, 6, 6)];
	[p fill];
      }
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, 5, h - 1 - 5, 0, 0, 255),
	"a filled bezier rectangle paints blue inside")
      PASS(rep != nil && pixelIs(rep, w - 3, h / 2, 255, 0, 0),
	"outside the bezier rectangle stays red")
    }

  LEAVE_POOL
  END_SET("winlib rendering")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib rendering")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib rendering")
  return 0;
}

#endif
