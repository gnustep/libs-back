/* Regression test: drawing an NSGradient with a non-RGB (pattern) colour
 * must not raise an NSInternalInconsistencyException.  The fix in
 * CairoGState normalizes colours to an RGB-compatible colour space before
 * accessing -redComponent/-greenComponent/-blueComponent.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping gradient test");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  /* Create a small pattern image and make a pattern color (non-RGB). */
  NSImage *pat = [[NSImage alloc] initWithSize: NSMakeSize(4, 4)];
  [pat lockFocus];
  [[NSColor colorWithCalibratedRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] setFill];
  NSRectFill(NSMakeRect(0, 0, 4, 4));
  [pat unlockFocus];
  NSColor *pattern = [NSColor colorWithPatternImage: pat];
  [pat release];

  NSColor *white = [NSColor colorWithCalibratedWhite: 1.0 alpha: 1.0];

  /* Linear gradient: drawInRect:angle: calls drawGradient:fromPoint:toPoint:
   * (linear path).  Without the fix, non-RGB stops are silently skipped. */
  NSGradient *lg = [[NSGradient alloc]
                     initWithStartingColor: pattern
                               endingColor: white];
  NSImage *limg = [[NSImage alloc] initWithSize: NSMakeSize(100, 100)];
  [limg lockFocus];
  PASS_RUNS(([lg drawInRect: NSMakeRect(0, 0, 100, 100) angle: 90.0]),
            "linear gradient with pattern colour draws without exception");
  [limg unlockFocus];
  [limg release];
  [lg release];

  /* Radial gradient: drawFromCenter:radius:toCenter:radius:options: calls
   * drawGradient:fromCenter:radius:toCenter:radius:options: (radial path).
   * Without the fix this raises "Called redComponent on non-RGB colour". */
  NSGradient *rg = [[NSGradient alloc]
                     initWithStartingColor: pattern
                               endingColor: white];
  NSImage *rimg = [[NSImage alloc] initWithSize: NSMakeSize(100, 100)];
  [rimg lockFocus];
  PASS_RUNS(([rg drawFromCenter: NSMakePoint(50, 50) radius: 0
                       toCenter: NSMakePoint(50, 50) radius: 50
                        options: 0]),
            "radial gradient with pattern colour draws without exception");
  [rimg unlockFocus];
  [rimg release];
  [rg release];

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
