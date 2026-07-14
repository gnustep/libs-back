/* Tests that the cairo backend draws a semi-transparent image correctly.  A
 * straight-alpha bitmap has to be premultiplied before it is handed to cairo,
 * whose ARGB32 format is premultiplied; without that a translucent image comes
 * out too bright.  The test draws a 50% gray over a known background and checks
 * the composited pixel.
 *
 * It needs a window server (to load the backend), so it opens the display named
 * by the environment and skips when there is none, and it guards on the cairo
 * graphics backend being the one built.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

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

/* An n x n bitmap filled with one RGBA colour. */
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
  return AUTORELEASE(img);
}

/* Draw IMG over a solid background of the given gray and read the centre. */
static NSBitmapImageRep *
over(NSImage *img, int bg)
{
  int w = 20, h = 20;
  NSImage *dst = [[NSImage alloc] initWithSize: NSMakeSize(w, h)];
  NSBitmapImageRep *rep;

  [dst lockFocus];
  [[NSColor colorWithDeviceRed: bg / 255.0 green: bg / 255.0 blue: bg / 255.0
                         alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [img drawInRect: NSMakeRect(0, 0, w, h)
         fromRect: NSZeroRect
        operation: NSCompositeSourceOver
         fraction: 1.0];
  [[NSGraphicsContext currentContext] flushGraphics];
  rep = [[NSBitmapImageRep alloc]
          initWithFocusedViewRect: NSMakeRect(0, 0, w, h)];
  [dst unlockFocus];
  [dst release];
  return AUTORELEASE(rep);
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping image alpha tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* a half-transparent gray over black is half of 128 */
  PASS(pixelIs(over(solidImage(4, 128, 128, 128, 128), 0), 10, 10, 64, 64, 64),
    "a half-transparent gray image over black composites to a quarter tone");

  /* a half-transparent gray over white keeps half the background */
  PASS(pixelIs(over(solidImage(4, 128, 128, 128, 128), 255), 10, 10, 191, 191, 191),
    "a half-transparent gray image over white composites to a light tone");

  /* an opaque image still shows its own colour (regression guard) */
  PASS(pixelIs(over(solidImage(4, 128, 128, 128, 255), 0), 10, 10, 128, 128, 128),
    "an opaque gray image over black shows its colour");

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
