/* Line cap and join tests for the winlib graphics backend: a butt cap ends at
 * the endpoint while a square cap extends past it, and a miter join fills the
 * sharp outer corner more than a bevel join.  This exercises WIN32GState's pen
 * end-cap and join setup (the PS_ENDCAP_* and PS_JOIN_* pen styles).
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
  [[NSColor colorWithDeviceRed: 1 green: 1 blue: 1 alpha: 1] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0 green: 0 blue: 0 alpha: 1] set];
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
  START_SET("winlib line caps and joins")
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

      /* A butt cap ends at the endpoint: the line runs to x = 12 with width 6,
       * so x = 14 is clear of the cap. */
      img = beginImage(w, h);
      {
	NSBezierPath *p = [NSBezierPath bezierPath];
	[p setLineWidth: 6.0];
	[p setLineCapStyle: NSButtLineCapStyle];
	[p moveToPoint: NSMakePoint(4, h / 2)];
	[p lineToPoint: NSMakePoint(12, h / 2)];
	[p stroke];
      }
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, 14, h / 2, 255, 255, 255),
	"a butt line cap does not paint past the endpoint")

      /* A square cap extends past the endpoint by half the width, so x = 14 is
       * inside the cap. */
      img = beginImage(w, h);
      {
	NSBezierPath *p = [NSBezierPath bezierPath];
	[p setLineWidth: 6.0];
	[p setLineCapStyle: NSSquareLineCapStyle];
	[p moveToPoint: NSMakePoint(4, h / 2)];
	[p lineToPoint: NSMakePoint(12, h / 2)];
	[p stroke];
      }
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, 14, h / 2, 0, 0, 0),
	"a square line cap paints past the endpoint")

      /* A miter join fills the sharp outer corner more than a bevel join. */
      {
	long dark[2] = { 0, 0 };
	int  style;

	for (style = 0; style < 2; style++)
	  {
	    unsigned char *d;
	    long           bpr, spp, cx, cy;

	    img = beginImage(w, h);
	    {
	      NSBezierPath *p = [NSBezierPath bezierPath];
	      [p setLineWidth: 6.0];
	      [p setLineJoinStyle: (style == 0 ? NSMiterLineJoinStyle
						: NSBevelLineJoinStyle)];
	      [p moveToPoint: NSMakePoint(5, 4)];
	      [p lineToPoint: NSMakePoint(5, 14)];
	      [p lineToPoint: NSMakePoint(15, 14)];
	      [p stroke];
	    }
	    rep = endImage(img, w, h);
	    d = [rep bitmapData];
	    bpr = [rep bytesPerRow];
	    spp = [rep samplesPerPixel];
	    for (cy = 1; cy <= 5; cy++)
	      for (cx = 0; cx <= 4; cx++)
		{
		  unsigned char *px = d + cy * bpr + cx * spp;
		  if (px[0] < 100)
		    dark[style]++;
		}
	  }
	PASS(dark[0] > dark[1],
	  "a miter join fills the outer corner more than a bevel join")
      }
    }

  LEAVE_POOL
  END_SET("winlib line caps and joins")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib line caps and joins")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib line caps and joins")
  return 0;
}

#endif
