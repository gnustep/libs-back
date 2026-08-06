/* The alpha channel of a winlib drawable, driven through the AppKit offscreen
 * path (Source/winlib/WIN32GState.m and Source/win32/WIN32Server.m).
 *
 * GDI writes zero into the alpha byte of every pixel it draws, so a drawable
 * only has an alpha channel if the drawing paths maintain that byte. These
 * check what -GSReadRect: reports for an opaque fill and for a cleared area,
 * and what an image with an alpha channel composites to, which is the part
 * that needs the source's own alpha rather than the constant one.
 *
 * It guards on the winlib graphics backend and skips when the backend cannot
 * be reached; colours are checked with a small tolerance.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_winlib) \
  && BUILD_GRAPHICS == GRAPHICS_winlib

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

static unsigned char *
pixelAt(NSBitmapImageRep *rep, int x, int y)
{
  return [rep bitmapData] + y * [rep bytesPerRow] + x * [rep samplesPerPixel];
}

static BOOL
pixelIs(NSBitmapImageRep *rep, int x, int y, int r, int g, int b)
{
  unsigned char *px = pixelAt(rep, x, y);

  return (abs((int)px[0] - r) <= 2
	  && abs((int)px[1] - g) <= 2
	  && abs((int)px[2] - b) <= 2);
}

/* An n by n image of one colour, its samples not premultiplied. */
static NSImage *
solidImage(int n, int r, int g, int b, int a)
{
  NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes: NULL pixelsWide: n pixelsHigh: n
		bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO
	       colorSpaceName: NSDeviceRGBColorSpace
		 bitmapFormat: NSAlphaNonpremultipliedBitmapFormat
		  bytesPerRow: n * 4 bitsPerPixel: 32];
  unsigned char *d = [rep bitmapData];
  NSImage *img;
  int i;

  for (i = 0; i < n * n; i++)
    {
      d[i * 4 + 0] = r;
      d[i * 4 + 1] = g;
      d[i * 4 + 2] = b;
      d[i * 4 + 3] = a;
    }
  img = [[NSImage alloc] initWithSize: NSMakeSize(n, n)];
  [img addRepresentation: rep];
  [rep release];
  return [img autorelease];
}

/* Draw IMG over a background of one grey and read the result back. */
static NSBitmapImageRep *
over(NSImage *img, int background, int w, int h)
{
  NSImage *dst = beginImage(w, h);

  [[NSColor colorWithDeviceRed: background / 255.0
			 green: background / 255.0
			  blue: background / 255.0
			 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [img drawInRect: NSMakeRect(0, 0, w, h)
	 fromRect: NSZeroRect
	operation: NSCompositeSourceOver
	 fraction: 1.0];
  return endImage(dst, w, h);
}

int
main(void)
{
  START_SET("winlib alpha")

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

      /* An opaque fill reads back opaque. */
      img = beginImage(w, h);
      [[NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1] set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      rep = endImage(img, w, h);
      PASS(rep != nil && [rep samplesPerPixel] == 4
	&& pixelAt(rep, w / 2, h / 2)[3] == 255,
	"an opaque fill reads back with an alpha of 255")

      /* A cleared area reads back transparent. */
      img = beginImage(w, h);
      [[NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1] set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      NSRectFillUsingOperation(NSMakeRect(0, 0, w, h), NSCompositeClear);
      rep = endImage(img, w, h);
      PASS(rep != nil && [rep samplesPerPixel] == 4
	&& pixelAt(rep, w / 2, h / 2)[3] == 0,
	"a cleared area reads back with an alpha of 0")

      /* A half transparent image takes half of what is under it. */
      rep = over(solidImage(4, 128, 128, 128, 128), 255, w, h);
      PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 191, 191, 191),
	"a half transparent grey image over white composites to a light tone")

      rep = over(solidImage(4, 128, 128, 128, 128), 0, w, h);
      PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 64, 64, 64),
	"a half transparent grey image over black composites to a quarter tone")

      /* An opaque image still shows its own colour. */
      rep = over(solidImage(4, 128, 128, 128, 255), 255, w, h);
      PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 128, 128, 128),
	"an opaque grey image over white shows its colour")
    }

  END_SET("winlib alpha")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib alpha")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib alpha")
  return 0;
}

#endif
