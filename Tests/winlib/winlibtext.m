/* Text drawing tests for the winlib graphics backend: drawing a string paints
 * some black glyph pixels without covering the whole image, and a larger point
 * size paints more glyph pixels than a smaller one.  This exercises
 * WIN32FontInfo's glyph drawing (the TextOutW path).
 *
 * The glyph shapes are font dependent, so the checks count dark pixels rather
 * than probe fixed positions.  It guards on the winlib graphics backend and
 * skips when the backend cannot be reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_winlib) \
  && BUILD_GRAPHICS == GRAPHICS_winlib

#import <AppKit/AppKit.h>
#include <stdlib.h>

/* Draw "H" at the given point size on a white canvas and count the dark (glyph)
 * pixels. */
static long
darkPixelsForSize(CGFloat size, int w, int h)
{
  NSImage          *img = [[NSImage alloc] initWithSize: NSMakeSize(w, h)];
  NSBitmapImageRep *rep;
  NSDictionary     *attrs;
  unsigned char    *d;
  long              bpr, spp, x, y, dark = 0;

  [img lockFocus];
  [[NSColor colorWithDeviceRed: 1 green: 1 blue: 1 alpha: 1] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  attrs = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSColor blackColor], NSForegroundColorAttributeName,
    [NSFont systemFontOfSize: size], NSFontAttributeName, nil];
  [@"H" drawAtPoint: NSMakePoint(4, 4) withAttributes: attrs];
  [[NSGraphicsContext currentContext] flushGraphics];
  rep = [[NSBitmapImageRep alloc]
	  initWithFocusedViewRect: NSMakeRect(0, 0, w, h)];
  [img unlockFocus];
  [img release];

  d = [rep bitmapData];
  bpr = [rep bytesPerRow];
  spp = [rep samplesPerPixel];
  for (y = 0; y < h; y++)
    for (x = 0; x < w; x++)
      {
	unsigned char *px = d + y * bpr + x * spp;
	if (px[0] < 100 && px[1] < 100 && px[2] < 100)
	  dark++;
      }
  [rep release];
  return dark;
}

int
main(void)
{
  START_SET("winlib text drawing")
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
      int  w = 32, h = 32;
      long small = darkPixelsForSize(12.0, w, h);
      long large = darkPixelsForSize(24.0, w, h);

      PASS(small > 0 && small < (long)w * h,
	"drawing text paints some black glyph pixels but not the whole image")
      PASS(large > small,
	"a larger point size paints more glyph pixels")
    }

  LEAVE_POOL
  END_SET("winlib text drawing")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib text drawing")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib text drawing")
  return 0;
}

#endif
