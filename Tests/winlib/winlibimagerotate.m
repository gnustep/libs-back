/* Image rotation test for the winlib graphics backend: an image drawn through
 * -drawInRect: under a rotated transform is rotated, which exercises the
 * WIN32GState -DPSimage: PlgBlt path with a rotating CTM (unlike the axis-aligned
 * compositeGState blit).
 *
 * A four-colour image (top-left red, top-right green, bottom-left blue,
 * bottom-right white) drawn with a 90 degree rotation about the centre lands
 * with the colours rotated a quarter turn.  It guards on the winlib graphics
 * backend and skips when the backend cannot be reached.
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

static NSImage *
fourColorImage(void)
{
  NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes: NULL pixelsWide: 2 pixelsHigh: 2
		bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO
	       colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: 8
		 bitsPerPixel: 32];
  unsigned char *d = [rep bitmapData];
  NSImage       *img;

  d[0]  = 255; d[1]  = 0;   d[2]  = 0;   d[3]  = 255;  /* top-left  red   */
  d[4]  = 0;   d[5]  = 255; d[6]  = 0;   d[7]  = 255;  /* top-right green */
  d[8]  = 0;   d[9]  = 0;   d[10] = 255; d[11] = 255;  /* bot-left  blue  */
  d[12] = 255; d[13] = 255; d[14] = 255; d[15] = 255;  /* bot-right white */
  img = [[NSImage alloc] initWithSize: NSMakeSize(2, 2)];
  [img addRepresentation: rep];
  [rep release];
  return [img autorelease];
}

int
main(void)
{
  START_SET("winlib image rotation")
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
      int                w = 40, h = 40;
      NSImage           *dst = [[NSImage alloc] initWithSize: NSMakeSize(w, h)];
      NSBitmapImageRep  *rep;
      NSAffineTransform *t = [NSAffineTransform transform];

      [dst lockFocus];
      [[NSGraphicsContext currentContext]
	setImageInterpolation: NSImageInterpolationNone];
      [[NSColor blackColor] set];
      NSRectFill(NSMakeRect(0, 0, w, h));

      /* Rotate a quarter turn about the centre of the canvas. */
      [t translateXBy: w / 2 yBy: h / 2];
      [t rotateByDegrees: 90];
      [t translateXBy: -w / 2 yBy: -h / 2];
      [t concat];

      [fourColorImage() drawInRect: NSMakeRect(0, 0, w, h)
			   fromRect: NSZeroRect
			  operation: NSCompositeSourceOver
			   fraction: 1.0];
      [[NSGraphicsContext currentContext] flushGraphics];
      rep = [[[NSBitmapImageRep alloc]
	       initWithFocusedViewRect: NSMakeRect(0, 0, w, h)] autorelease];
      [dst unlockFocus];
      [dst release];

      /* A 90 degree rotation moves top-left red to bottom-left, top-right green
       * to top-left, bottom-right white to top-right, bottom-left blue to
       * bottom-right. */
      PASS(pixelIs(rep, 10, 10, 0, 255, 0)
	&& pixelIs(rep, 30, 10, 255, 255, 255)
	&& pixelIs(rep, 10, 30, 255, 0, 0)
	&& pixelIs(rep, 30, 30, 0, 0, 255),
	"an image drawn under a rotated transform is rotated a quarter turn")
    }

  LEAVE_POOL
  END_SET("winlib image rotation")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib image rotation")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib image rotation")
  return 0;
}

#endif
