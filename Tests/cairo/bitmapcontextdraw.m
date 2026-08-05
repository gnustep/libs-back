/* Drawing into a graphics context made for an NSBitmapImageRep has to reach
 * the bytes of that representation.  The bitmap is a 32 bit device RGB one
 * with premultiplied alpha last, which is the layout the cairo backend can
 * carry directly.
 *
 * The context takes the same coordinates as any other: the origin is at the
 * bottom left, so the first row of the bitmap is the top of the drawing.
 *
 * It needs a running window server to load the backend at all, so it skips
 * cleanly when there is none, and it guards on the cairo graphics backend.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>
#include <string.h>

#define WIDE 8
#define HIGH 8

static NSBitmapImageRep *
makeRep(void)
{
  return AUTORELEASE([[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes: NULL
                  pixelsWide: WIDE
                  pixelsHigh: HIGH
               bitsPerSample: 8
             samplesPerPixel: 4
                    hasAlpha: YES
                    isPlanar: NO
              colorSpaceName: NSDeviceRGBColorSpace
                 bytesPerRow: 0
                bitsPerPixel: 0]);
}

static unsigned char *
pixel(NSBitmapImageRep *rep, int x, int y)
{
  return [rep bitmapData] + y * [rep bytesPerRow] + x * 4;
}

static void
clearRep(NSBitmapImageRep *rep)
{
  memset([rep bitmapData], 0, [rep bytesPerRow] * [rep pixelsHigh]);
}

static void
fillRect(NSBitmapImageRep *rep, NSColor *colour, NSRect rect)
{
  NSGraphicsContext *ctxt;

  ctxt = [NSGraphicsContext graphicsContextWithBitmapImageRep: rep];
  [NSGraphicsContext saveGraphicsState];
  [NSGraphicsContext setCurrentContext: ctxt];
  [colour set];
  NSRectFill(rect);
  [ctxt flushGraphics];
  [NSGraphicsContext restoreGraphicsState];
}

static BOOL
isColour(unsigned char *p, int r, int g, int b, int a)
{
  return (abs((int)p[0] - r) <= 1 && abs((int)p[1] - g) <= 1
    && abs((int)p[2] - b) <= 1 && abs((int)p[3] - a) <= 1);
}

int
main(int argc, const char **argv)
{
  START_SET("bitmap context drawing")

  NSBitmapImageRep *rep;
  NSGraphicsContext *ctxt;
  BOOL allRed;
  BOOL topClear;
  BOOL bottomRed;
  int x;
  int y;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      SKIP("no window server available")
    }

  NS_DURING
    {
      [NSApplication sharedApplication];
    }
  NS_HANDLER
    {
      SKIP("It looks like the GNUstep backend is not installed")
    }
  NS_ENDHANDLER

  rep = makeRep();
  ctxt = [NSGraphicsContext graphicsContextWithBitmapImageRep: rep];
  PASS(ctxt != nil, "a graphics context can be made for a bitmap");

  /* An opaque fill over the whole representation. */
  clearRep(rep);
  fillRect(rep, [NSColor redColor], NSMakeRect(0, 0, WIDE, HIGH));
  allRed = YES;
  for (y = 0; y < HIGH; y++)
    {
      for (x = 0; x < WIDE; x++)
        {
          if (!isColour(pixel(rep, x, y), 255, 0, 0, 255))
            {
              allRed = NO;
            }
        }
    }
  PASS(allRed, "an opaque fill reaches every pixel of the bitmap");

  /* The bottom half in context coordinates is the last rows of the bitmap. */
  clearRep(rep);
  fillRect(rep, [NSColor redColor], NSMakeRect(0, 0, WIDE, HIGH / 2));
  topClear = YES;
  bottomRed = YES;
  for (y = 0; y < HIGH / 2; y++)
    {
      if (!isColour(pixel(rep, 0, y), 0, 0, 0, 0))
        {
          topClear = NO;
        }
    }
  for (y = HIGH / 2; y < HIGH; y++)
    {
      if (!isColour(pixel(rep, 0, y), 255, 0, 0, 255))
        {
          bottomRed = NO;
        }
    }
  PASS(topClear, "the first rows of the bitmap are above the drawing");
  PASS(bottomRed, "a fill at the origin lands in the last rows of the bitmap");

  /* And the left half is the first columns. */
  clearRep(rep);
  fillRect(rep, [NSColor redColor], NSMakeRect(0, 0, WIDE / 2, HIGH));
  PASS(isColour(pixel(rep, 0, 0), 255, 0, 0, 255),
    "a fill at the origin lands in the first columns of the bitmap");
  PASS(isColour(pixel(rep, WIDE - 1, 0), 0, 0, 0, 0),
    "the last columns of the bitmap are beyond the drawing");

  /* What lands in the bitmap is premultiplied, as the format says. */
  clearRep(rep);
  fillRect(rep, [NSColor colorWithDeviceRed: 1.0
                                      green: 0.0
                                       blue: 0.0
                                      alpha: 0.5],
           NSMakeRect(0, 0, WIDE, HIGH));
  PASS(isColour(pixel(rep, 0, 0), 128, 0, 0, 128),
    "a half transparent fill is stored premultiplied");

  /* A second context for the same bitmap draws over what is already there. */
  clearRep(rep);
  fillRect(rep, [NSColor redColor], NSMakeRect(0, 0, WIDE, HIGH));
  fillRect(rep, [NSColor greenColor], NSMakeRect(0, 0, WIDE / 2, HIGH / 2));
  PASS(isColour(pixel(rep, 0, HIGH - 1), 0, 255, 0, 255),
    "a second context draws into the same bitmap");
  PASS(isColour(pixel(rep, WIDE - 1, 0), 255, 0, 0, 255),
    "a second context keeps what the first one drew");

  /* The representation reads back the colour it was given. */
  clearRep(rep);
  fillRect(rep, [NSColor redColor], NSMakeRect(0, 0, WIDE, HIGH));
  PASS([[[rep colorAtX: 0 y: 0] colorUsingColorSpaceName: NSDeviceRGBColorSpace]
    isEqual: [NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0]],
    "the representation reads back the colour that was drawn");

  END_SET("bitmap context drawing")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("bitmap context drawing")
    SKIP("back is not built with the cairo graphics backend")
  END_SET("bitmap context drawing")
  return 0;
}

#endif
