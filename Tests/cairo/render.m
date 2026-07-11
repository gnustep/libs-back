/* Rendering tests for the graphics backend, driven through the AppKit
 * offscreen path: lock focus on an NSImage, draw, then read the pixels back
 * with -initWithFocusedViewRect: and check them.  This exercises the backend's
 * fill, path and compositing rendering plus the GSReadRect read-back, whichever
 * backend (cairo, xlib, ...) is installed.
 *
 * It needs a running window server, so it opens the display named by the
 * environment and skips cleanly when there is none; the harness runs it under a
 * headless server (Xvfb) where one is available.  Colours are checked with a
 * small tolerance to allow for the backend's fixed-point arithmetic.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

/* This drives the AppKit drawing path against the installed backend; the
 * offscreen rendering it relies on is exercised here for the cairo graphics
 * backend, so guard on that being the one built. */
#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

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
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  int w = 20, h = 20;
  NSImage *img;
  NSBitmapImageRep *rep;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping rendering tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* A solid fill covers the whole image with one colour. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 255, 0, 0),
       "a solid red fill reads back red");

  /* A second fill over the left half leaves the right half untouched.  The x
   * axis is not affected by the flipped y origin, so left stays left. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 1.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w / 2, h));
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 4, h / 2, 0, 255, 0),
       "the left half is filled green");
  PASS(rep != nil && pixelIs(rep, 3 * w / 4, h / 2, 255, 0, 0),
       "the right half stays red");

  /* Filling a bezier-path rectangle paints inside and leaves outside alone. */
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
       "a filled bezier rectangle paints blue inside");
  PASS(rep != nil && pixelIs(rep, w - 3, h / 2, 255, 0, 0),
       "outside the bezier rectangle stays red");

  /* Compositing a half-transparent white over red lightens it (source-over):
   * out = 255*0.5 + 255*0.5 for red, 0*0.5 + 255*0.5 for green/blue ~= 127. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 0.5] set];
  NSRectFillUsingOperation(NSMakeRect(0, 0, w, h), NSCompositeSourceOver);
  rep = endImage(img, w, h);
  {
    unsigned char *d = [rep bitmapData];
    unsigned char *px = d + (h / 2) * [rep bytesPerRow]
                          + (w / 2) * [rep samplesPerPixel];
    PASS(px[0] >= 250 && px[1] >= 110 && px[1] <= 145
         && px[2] >= 110 && px[2] <= 145,
         "half-transparent white over red lightens green and blue to ~127");
  }

  /* A stroked line paints along its width and leaves clear pixels alone. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  {
    NSBezierPath *p = [NSBezierPath bezierPath];
    [p setLineWidth: 4.0];
    [p moveToPoint: NSMakePoint(0, h / 2)];
    [p lineToPoint: NSMakePoint(w, h / 2)];
    [p stroke];
  }
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 2, h / 2, 0, 0, 0),
       "a stroked line paints black along its centre");
  PASS(rep != nil && pixelIs(rep, w / 2, h / 2 - 7, 255, 255, 255),
       "pixels clear of the stroked line stay white");

  /* A horizontal gradient runs dark on the left to light on the right. */
  img = beginImage(w, h);
  {
    NSGradient *grad = [[NSGradient alloc]
        initWithStartingColor: [NSColor colorWithDeviceRed: 0.0 green: 0.0
                                                      blue: 0.0 alpha: 1.0]
                  endingColor: [NSColor colorWithDeviceRed: 1.0 green: 1.0
                                                      blue: 1.0 alpha: 1.0]];
    [grad drawInRect: NSMakeRect(0, 0, w, h) angle: 0.0];
    [grad release];
  }
  rep = endImage(img, w, h);
  {
    unsigned char *d = [rep bitmapData];
    long bpr = [rep bytesPerRow], spp = [rep samplesPerPixel];
    int left = d[(h / 2) * bpr + 2 * spp];
    int mid = d[(h / 2) * bpr + (w / 2) * spp];
    int right = d[(h / 2) * bpr + (w - 3) * spp];
    PASS(rep != nil && left < 70 && right > 185 && mid > left && mid < right,
         "a horizontal gradient runs dark-left to light-right");
  }

  /* A clip rectangle confines drawing to the left half of the image. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  NSRectClip(NSMakeRect(0, 0, w / 2, h));
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 4, h / 2, 255, 0, 0),
       "drawing inside the clip rectangle is painted");
  PASS(rep != nil && pixelIs(rep, 3 * w / 4, h / 2, 255, 255, 255),
       "drawing outside the clip rectangle is suppressed");

  /* Drawing an image paints its pixels into the destination. */
  {
    NSBitmapImageRep *srcRep;
    NSImage *src;
    unsigned char *sd;
    int i;

    srcRep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes: NULL
                      pixelsWide: 8
                      pixelsHigh: 8
                   bitsPerSample: 8
                 samplesPerPixel: 4
                        hasAlpha: YES
                        isPlanar: NO
                  colorSpaceName: NSDeviceRGBColorSpace
                     bytesPerRow: 0
                    bitsPerPixel: 0];
    sd = [srcRep bitmapData];
    for (i = 0; i < 8 * 8; i++)
      {
        sd[i * 4 + 0] = 0;
        sd[i * 4 + 1] = 255;
        sd[i * 4 + 2] = 0;
        sd[i * 4 + 3] = 255;
      }
    src = [[NSImage alloc] initWithSize: NSMakeSize(8, 8)];
    [src addRepresentation: srcRep];
    [srcRep release];

    img = beginImage(w, h);
    [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
    NSRectFill(NSMakeRect(0, 0, w, h));
    [src drawInRect: NSMakeRect(0, 0, w / 2, h)
           fromRect: NSZeroRect
          operation: NSCompositeSourceOver
           fraction: 1.0];
    rep = endImage(img, w, h);
    [src release];

    PASS(rep != nil && pixelIs(rep, w / 4, h / 2, 0, 255, 0),
         "a drawn image paints its pixels (green) where it is drawn");
    PASS(rep != nil && pixelIs(rep, 3 * w / 4, h / 2, 255, 255, 255),
         "the area where no image was drawn stays white");
  }

  /* Drawing text paints glyph pixels.  The shapes are font-dependent, so just
   * check that some black glyphs were painted and the whole image was not
   * covered. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  {
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor blackColor], NSForegroundColorAttributeName,
        [NSFont systemFontOfSize: 14], NSFontAttributeName, nil];
    [@"H" drawAtPoint: NSMakePoint(4, 2) withAttributes: attrs];
  }
  rep = endImage(img, w, h);
  {
    unsigned char *d = [rep bitmapData];
    long bpr = [rep bytesPerRow], spp = [rep samplesPerPixel];
    long x, y, dark = 0;

    for (y = 0; y < h; y++)
      for (x = 0; x < w; x++)
        {
          unsigned char *px = d + y * bpr + x * spp;
          if (px[0] < 100 && px[1] < 100 && px[2] < 100)
            dark++;
        }
    PASS(rep != nil && dark > 0 && dark < (long)w * h,
         "drawing text paints some black glyph pixels but not the whole image");
  }

  /* Line caps: a butt cap ends at the endpoint, a square cap extends past it by
   * half the line width.  The line runs to x = 12 with width 6, so x = 14 is
   * inside a square cap but clear of a butt cap. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
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
       "a butt line cap does not paint past the endpoint");

  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
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
       "a square line cap paints past the endpoint");

  /* A dash pattern paints some segments of the line and leaves gaps. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  {
    NSBezierPath *p = [NSBezierPath bezierPath];
    CGFloat pattern[2] = { 4.0, 4.0 };
    [p setLineWidth: 4.0];
    [p setLineDash: pattern count: 2 phase: 0.0];
    [p moveToPoint: NSMakePoint(0, h / 2)];
    [p lineToPoint: NSMakePoint(w, h / 2)];
    [p stroke];
  }
  rep = endImage(img, w, h);
  {
    unsigned char *d = [rep bitmapData];
    long bpr = [rep bytesPerRow], spp = [rep samplesPerPixel];
    long x, on = 0, off = 0;
    for (x = 0; x < w; x++)
      {
        unsigned char *px = d + (h / 2) * bpr + x * spp;
        if (px[0] < 100) on++;
        else if (px[0] > 200) off++;
      }
    PASS(rep != nil && on > 0 && off > 0,
         "a dashed line paints some segments and leaves gaps");
  }

  /* Line joins: a miter join fills the sharp outer corner, a bevel cuts it off,
   * so a miter paints more of the outer-corner region than a bevel. */
  {
    long dark[2] = { 0, 0 };
    int style;

    for (style = 0; style < 2; style++)
      {
        unsigned char *d;
        long bpr, spp, cx, cy;

        img = beginImage(w, h);
        [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
        NSRectFill(NSMakeRect(0, 0, w, h));
        [[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
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
         "a miter join fills the outer corner more than a bevel join");
  }

  /* A translate transform offsets subsequent drawing.  The transform is applied
   * inside a saved graphics state and restored before the pixels are read back,
   * so the read-back uses the identity transform. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext saveGraphicsState];
  {
    NSAffineTransform *t = [NSAffineTransform transform];
    [t translateXBy: w / 2 yBy: 0.0];
    [t concat];
    [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
    NSRectFill(NSMakeRect(0, 0, 4, h));
  }
  [NSGraphicsContext restoreGraphicsState];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 2 + 2, h / 2, 255, 0, 0),
       "a translate transform moves the fill to the offset position");
  PASS(rep != nil && pixelIs(rep, 2, h / 2, 255, 255, 255),
       "the untranslated origin is left unpainted");

  /* A non-rectangular (triangular) clip path confines drawing to the path.  The
   * triangle has corners (0,0), (w,0), (0,h), so the lower-left corner is inside
   * and the upper-right corner is outside. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  {
    NSBezierPath *tri = [NSBezierPath bezierPath];
    [tri moveToPoint: NSMakePoint(0, 0)];
    [tri lineToPoint: NSMakePoint(w, 0)];
    [tri lineToPoint: NSMakePoint(0, h)];
    [tri closePath];
    [tri addClip];
    [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
    NSRectFill(NSMakeRect(0, 0, w, h));
  }
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 2, h - 3, 255, 0, 0),
       "drawing inside a triangular clip path is painted");
  PASS(rep != nil && pixelIs(rep, w - 3, 2, 255, 255, 255),
       "drawing outside the triangular clip path is suppressed");

  /* A scale transform enlarges subsequent drawing.  A 4-wide strip scaled 2x in
   * x reaches to x = 8, so x = 6 is inside it and x = 10 is beyond. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext saveGraphicsState];
  {
    NSAffineTransform *t = [NSAffineTransform transform];
    [t scaleXBy: 2.0 yBy: 1.0];
    [t concat];
    [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
    NSRectFill(NSMakeRect(0, 0, 4, h));
  }
  [NSGraphicsContext restoreGraphicsState];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, 6, h / 2, 255, 0, 0),
       "a scale transform enlarges the fill in x");
  PASS(rep != nil && pixelIs(rep, 10, h / 2, 255, 255, 255),
       "the area beyond the scaled fill stays white");

  /* A 90-degree rotation about the centre moves a right-middle mark to the top.
   * A point (x,y) about centre (w/2,h/2) rotates to (w/2 + (h/2 - y),
   * h/2 + (x - w/2)); the mark at (~18,~10) lands at (~10,~18) = top-middle. */
  img = beginImage(w, h);
  [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext saveGraphicsState];
  {
    NSAffineTransform *t = [NSAffineTransform transform];
    [t translateXBy: w / 2.0 yBy: h / 2.0];
    [t rotateByDegrees: 90.0];
    [t translateXBy: -w / 2.0 yBy: -h / 2.0];
    [t concat];
    [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
    NSRectFill(NSMakeRect(w - 4, h / 2 - 2, 4, 4));
  }
  [NSGraphicsContext restoreGraphicsState];
  rep = endImage(img, w, h);
  PASS(rep != nil && pixelIs(rep, w / 2, 2, 255, 0, 0),
       "a 90-degree rotation moves the right-middle mark to the top");
  PASS(rep != nil && pixelIs(rep, w - 2, h / 2, 255, 255, 255),
       "the mark's original position is left unpainted after rotation");

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
