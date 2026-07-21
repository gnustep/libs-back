/* Tests that a non-rectangular clip survives the graphics state save/restore
 * stack in the cairo backend.  A clip set before -saveGraphicsState is carried
 * onto the copied state, and drawing there must stay inside the real clip
 * shape, not its bounding box.  Rectangular clips always survived; the shapes
 * exercised here (triangle, oval, even-odd ring) are the ones cairo cannot
 * report as a rectangle list, so the state copy has to reproduce them itself.
 *
 * It needs a running window server, so it skips cleanly when there is none, and
 * guards on the cairo graphics backend.  Colours are checked with a small
 * tolerance for the backend's fixed-point arithmetic.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

static NSImage *
beginImage(int w, int h)
{
  NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(w, h)];
  [img lockFocus];
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
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

/* Check the RGB sample at (x, y) with a small tolerance. */
static BOOL
pixelIs(NSBitmapImageRep *rep, int x, int y, int r, int g, int b)
{
  NSUInteger px[5];

  [rep getPixel: px atX: x y: y];
  return (abs((int)px[0] - r) <= 2
          && abs((int)px[1] - g) <= 2
          && abs((int)px[2] - b) <= 2);
}

/* Clip to the given path, save, fill everything red, restore.  The fill runs on
 * the copied state that inherited the clip. */
static NSBitmapImageRep *
clipSaveFill(int w, int h, NSBezierPath *clip)
{
  NSImage *img = beginImage(w, h);

  [clip addClip];
  [NSGraphicsContext saveGraphicsState];
  [[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill(NSMakeRect(0, 0, w, h));
  [NSGraphicsContext restoreGraphicsState];
  return endImage(img, w, h);
}

/* Clip to the given path, then draw a gradient through
 * -[NSGradient drawInRect:angle:], which saves and restores the graphics state
 * itself.  The clip set beforehand has to survive that copy, so this reaches
 * the same code as clipSaveFill but through the path gnustep/libs-gui#228
 * reported.  The gradient runs green to blue, so a painted pixel has a zero red
 * component while the background stays white. */
static NSBitmapImageRep *
clipGradientFill(int w, int h, NSBezierPath *clip)
{
  NSImage *img = beginImage(w, h);
  NSGradient *g = [[NSGradient alloc]
    initWithStartingColor: [NSColor colorWithDeviceRed: 0.0 green: 1.0 blue: 0.0 alpha: 1.0]
              endingColor: [NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 1.0 alpha: 1.0]];

  [clip addClip];
  [g drawInRect: [clip bounds] angle: 90.0];
  [g release];
  return endImage(img, w, h);
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  int w = 24, h = 24;
  NSBitmapImageRep *rep;
  NSBezierPath *p;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping clip save/restore tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* A triangle with the right angle at (3,3) and hypotenuse (21,3)-(3,21).
   * Read back (top-left origin) its interior is the lower-left half: (7,16) is
   * inside, (18,6) is above the hypotenuse, outside the triangle but inside its
   * bounding box.  If the clip were reduced to its bounding box, (18,6) would
   * fill. */
  p = [NSBezierPath bezierPath];
  [p moveToPoint: NSMakePoint(3, 3)];
  [p lineToPoint: NSMakePoint(21, 3)];
  [p lineToPoint: NSMakePoint(3, 21)];
  [p closePath];
  rep = clipSaveFill(w, h, p);
  PASS(rep != nil && pixelIs(rep, 7, 16, 255, 0, 0),
       "a triangle clip still paints its interior after save/restore");
  PASS(rep != nil && pixelIs(rep, 18, 6, 255, 255, 255),
       "a triangle clip is not widened to its bounding box by save/restore");

  /* An oval clip: the centre is inside, a bounding-box corner is outside. */
  p = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(3, 3, 18, 18)];
  rep = clipSaveFill(w, h, p);
  PASS(rep != nil && pixelIs(rep, 12, 12, 255, 0, 0),
       "an oval clip still paints its interior after save/restore");
  PASS(rep != nil && pixelIs(rep, 4, 4, 255, 255, 255),
       "an oval clip corner is not filled after save/restore");

  /* The same oval, filled by a gradient.  -[NSGradient drawInRect:angle:] saves
   * the graphics state internally, so the oval clip has to survive that save;
   * this is the case reported in gnustep/libs-gui#228.  The centre is painted
   * (non-white), a bounding-box corner stays white. */
  p = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(3, 3, 18, 18)];
  rep = clipGradientFill(w, h, p);
  PASS(rep != nil && !pixelIs(rep, 12, 12, 255, 255, 255),
       "a gradient clipped to an oval paints its interior");
  PASS(rep != nil && pixelIs(rep, 4, 4, 255, 255, 255),
       "a gradient clipped to an oval does not spill to its bounding box");

  /* An even-odd ring (outer rect minus inner rect): a point on the ring is
   * inside, the central hole is outside.  Checks that the even-odd rule is
   * carried across the save as well as the geometry. */
  p = [NSBezierPath bezierPath];
  [p appendBezierPathWithRect: NSMakeRect(3, 3, 18, 18)];
  [p appendBezierPathWithRect: NSMakeRect(9, 9, 6, 6)];
  [p setWindingRule: NSEvenOddWindingRule];
  rep = clipSaveFill(w, h, p);
  PASS(rep != nil && pixelIs(rep, 5, 12, 255, 0, 0),
       "an even-odd ring clip still paints the ring after save/restore");
  PASS(rep != nil && pixelIs(rep, 12, 12, 255, 255, 255),
       "an even-odd ring clip keeps its hole after save/restore");

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
