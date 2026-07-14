/* Stroke tests for the winlib graphics backend: a solid stroked line paints
 * along its width and leaves clear pixels alone, and a dashed stroke paints its
 * dashes and leaves gaps between them.  This exercises WIN32GState's stroke path
 * and the ExtCreatePen pen setup, including the dash pattern.
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
  START_SET("winlib stroke")
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
      int               w = 40, h = 40;

      /* A solid stroked line paints along its centre and leaves clear pixels. */
      img = beginImage(w, h);
      [[NSColor colorWithDeviceRed: 1 green: 1 blue: 1 alpha: 1] set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      [[NSColor colorWithDeviceRed: 0 green: 0 blue: 0 alpha: 1] set];
      {
	NSBezierPath *p = [NSBezierPath bezierPath];
	[p setLineWidth: 4.0];
	[p moveToPoint: NSMakePoint(0, h / 2)];
	[p lineToPoint: NSMakePoint(w, h / 2)];
	[p stroke];
      }
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 0, 0, 0),
	"a stroked line paints black along its centre")
      PASS(rep != nil && pixelIs(rep, w / 2, h / 2 - 7, 255, 255, 255),
	"pixels clear of the stroked line stay white")

      /* A dashed stroke paints its dashes and leaves gaps between them. */
      img = beginImage(w, h);
      [[NSColor colorWithDeviceRed: 1 green: 1 blue: 1 alpha: 1] set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      [[NSColor colorWithDeviceRed: 0 green: 0 blue: 0 alpha: 1] set];
      {
	NSBezierPath *p = [NSBezierPath bezierPath];
	CGFloat       pattern[2] = { 8.0, 8.0 };

	[p setLineWidth: 4.0];
	[p setLineDash: pattern count: 2 phase: 0.0];
	[p moveToPoint: NSMakePoint(0, h / 2)];
	[p lineToPoint: NSMakePoint(w, h / 2)];
	[p stroke];
      }
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, 4, h / 2, 0, 0, 0),
	"the first dash of a dashed stroke paints black")
      PASS(rep != nil && pixelIs(rep, 12, h / 2, 255, 255, 255),
	"the gap after the first dash stays white")
    }

  LEAVE_POOL
  END_SET("winlib stroke")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib stroke")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib stroke")
  return 0;
}

#endif
