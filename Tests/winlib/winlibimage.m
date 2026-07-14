/* Image drawing tests for the winlib graphics backend: a four-colour image
 * keeps its orientation when drawn (the top of the bitmap stays at the top),
 * and a 24-bit RGB image without alpha decodes to its colour.  This exercises
 * WIN32GState's -DPSimage:... path (GSCreateBitmap plus the PlgBlt).
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
  NSUInteger px[5];

  [rep getPixel: px atX: x y: y];
  return (abs((int)px[0] - r) <= 2
	  && abs((int)px[1] - g) <= 2
	  && abs((int)px[2] - b) <= 2);
}

/* Draw SRC scaled over the whole 20x20 canvas with nearest-neighbour sampling,
 * so each source pixel stays a solid block. */
static NSBitmapImageRep *
draw(NSImage *src)
{
  int w = 20, h = 20;
  NSImage *dst = [[NSImage alloc] initWithSize: NSMakeSize(w, h)];
  NSBitmapImageRep *rep;

  [dst lockFocus];
  [[NSGraphicsContext currentContext]
    setImageInterpolation: NSImageInterpolationNone];
  [[NSColor colorWithDeviceRed: 0 green: 0 blue: 0 alpha: 1] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [src drawInRect: NSMakeRect(0, 0, w, h)
	 fromRect: NSZeroRect
	operation: NSCompositeSourceOver
	 fraction: 1.0];
  [[NSGraphicsContext currentContext] flushGraphics];
  rep = [[NSBitmapImageRep alloc]
	  initWithFocusedViewRect: NSMakeRect(0, 0, w, h)];
  [dst unlockFocus];
  [dst release];
  return [rep autorelease];
}

int
main(void)
{
  START_SET("winlib image drawing")
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
      NSBitmapImageRep *rep, *out;
      NSImage          *src;
      unsigned char    *d;
      int               i;

      /* A 2x2 image, bitmap row 0 (top) = red, green; row 1 (bottom) = blue,
       * white.  Drawn over the canvas it must keep that layout. */
      rep = [[NSBitmapImageRep alloc]
	initWithBitmapDataPlanes: NULL pixelsWide: 2 pixelsHigh: 2
		    bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO
		   colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: 8
		     bitsPerPixel: 32];
      d = [rep bitmapData];
      d[0]  = 255; d[1]  = 0;   d[2]  = 0;   d[3]  = 255;  /* top-left  red   */
      d[4]  = 0;   d[5]  = 255; d[6]  = 0;   d[7]  = 255;  /* top-right green */
      d[8]  = 0;   d[9]  = 0;   d[10] = 255; d[11] = 255;  /* bot-left  blue  */
      d[12] = 255; d[13] = 255; d[14] = 255; d[15] = 255;  /* bot-right white */
      src = [[NSImage alloc] initWithSize: NSMakeSize(2, 2)];
      [src addRepresentation: rep];
      [rep release];
      out = draw(src);
      [src release];

      PASS(pixelIs(out, 5, 5, 255, 0, 0)
	&& pixelIs(out, 15, 5, 0, 255, 0)
	&& pixelIs(out, 5, 15, 0, 0, 255)
	&& pixelIs(out, 15, 15, 255, 255, 255),
	"the image keeps its orientation, top of the bitmap at the top")

      /* A 24-bit RGB image without alpha decodes to its colour. */
      rep = [[NSBitmapImageRep alloc]
	initWithBitmapDataPlanes: NULL pixelsWide: 2 pixelsHigh: 2
		    bitsPerSample: 8 samplesPerPixel: 3 hasAlpha: NO isPlanar: NO
		   colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: 6
		     bitsPerPixel: 24];
      d = [rep bitmapData];
      for (i = 0; i < 4; i++)
	{ d[i * 3 + 0] = 0; d[i * 3 + 1] = 255; d[i * 3 + 2] = 255; }
      src = [[NSImage alloc] initWithSize: NSMakeSize(2, 2)];
      [src addRepresentation: rep];
      [rep release];
      out = draw(src);
      [src release];

      PASS(pixelIs(out, 10, 10, 0, 255, 255),
	"a 24-bit rgb image without alpha decodes to its colour")
    }

  LEAVE_POOL
  END_SET("winlib image drawing")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib image drawing")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib image drawing")
  return 0;
}

#endif
