/* Compositing tests for the winlib graphics backend, driven through the AppKit
 * offscreen path (Source/winlib/WIN32GState.m).
 *
 * A Copy fill replaces the destination, a source-over fill with a
 * half-transparent colour blends towards it, and compositing an opaque image
 * with Copy or source-over paints the image, which exercises WIN32GState's
 * -compositerect: fill path and its -compositeGState: image path (the BitBlt and
 * AlphaBlend routes) together with the GSReadRect read-back.
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

/* A w by h image filled with one opaque colour, for compositing as a source. */
static NSImage *
solidImage(int w, int h, NSColor *color)
{
  NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(w, h)];

  [img lockFocus];
  [color set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [img unlockFocus];
  return [img autorelease];
}

int
main(void)
{
  START_SET("winlib compositing")
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
      NSColor          *red = [NSColor colorWithDeviceRed: 1 green: 0 blue: 0
						    alpha: 1];

      /* A Copy fill replaces the destination. */
      img = beginImage(w, h);
      [red set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      [[NSColor colorWithDeviceRed: 0 green: 0 blue: 1 alpha: 1] set];
      NSRectFillUsingOperation(NSMakeRect(0, 0, w, h), NSCompositeCopy);
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 0, 0, 255),
	"a Copy fill replaces the destination")

      /* A source-over fill with a half-transparent colour blends. */
      img = beginImage(w, h);
      [red set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      [[NSColor colorWithDeviceRed: 1 green: 1 blue: 1 alpha: 0.5] set];
      NSRectFillUsingOperation(NSMakeRect(0, 0, w, h), NSCompositeSourceOver);
      rep = endImage(img, w, h);
      {
	unsigned char *px = [rep bitmapData] + (h / 2) * [rep bytesPerRow]
			      + (w / 2) * [rep samplesPerPixel];
	PASS(px[0] >= 250 && px[1] >= 112 && px[1] <= 143
	  && px[2] >= 112 && px[2] <= 143,
	  "a half-transparent white source-over fill lightens red to about half")
      }

      /* Compositing an opaque image with Copy paints the image. */
      img = beginImage(w, h);
      [red set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      [solidImage(w, h, [NSColor colorWithDeviceRed: 0 green: 1 blue: 0 alpha: 1])
	compositeToPoint: NSZeroPoint operation: NSCompositeCopy];
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 0, 255, 0),
	"compositing an opaque image with Copy paints the image")

      /* Compositing an opaque image with source-over paints the image. */
      img = beginImage(w, h);
      [red set];
      NSRectFill(NSMakeRect(0, 0, w, h));
      [solidImage(w, h, [NSColor colorWithDeviceRed: 0 green: 0 blue: 1 alpha: 1])
	compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];
      rep = endImage(img, w, h);
      PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 0, 0, 255),
	"compositing an opaque image with source-over paints the image")
    }

  LEAVE_POOL
  END_SET("winlib compositing")
  return 0;
}

#else

int
main(void)
{
  START_SET("winlib compositing")
    SKIP("back is not built with the winlib graphics backend")
  END_SET("winlib compositing")
  return 0;
}

#endif
