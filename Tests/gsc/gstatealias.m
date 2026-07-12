/* Tests that GSGState's GSSetCTM takes its own copy of the matrix, so the
 * gstate and the caller's transform do not alias each other: neither one
 * changing after the call disturbs the other.
 *
 * GSGState lives in the backend bundle, so the test needs a backend loaded
 * (hence a window server); it opens the display named by the environment and
 * skips when there is none.  The code under test is the same for every backend;
 * it is built for the cairo backend, which is the one that loads on the test
 * display.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

@interface NSObject (GSGStateAlias)
- initWithContextInfo: (NSDictionary *)info;
- initWithDrawContext: (id)ctxt;
- (void) GSSetCTM: (NSAffineTransform *)m;
- (void) DPSinitmatrix;
- (NSPoint) pointInMatrixSpace: (NSPoint)p;
@end

static BOOL
eqf(CGFloat a, CGFloat b)
{
  CGFloat d = a - b;

  return (d < 0.0001 && d > -0.0001) ? YES : NO;
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  id ctxt, gs;
  NSAffineTransform *t;
  NSPoint p;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping GSSetCTM alias test");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];
  ctxt = [[NSClassFromString(@"GSStreamContext") alloc] initWithContextInfo:
    [NSDictionary dictionaryWithObject:
      [NSTemporaryDirectory() stringByAppendingPathComponent: @"gsc_alias.ps"]
      forKey: @"NSOutputFile"]];
  gs = [[NSClassFromString(@"GSGState") alloc] initWithDrawContext: ctxt];
  PASS(gs != nil, "a GSGState is created for the stream context");
  if (gs == nil)
    {
      DESTROY(pool);
      return 0;
    }

  /* The caller changing its transform after the call must not reach into the
   * gstate. */
  t = [NSAffineTransform transform];
  [t translateXBy: 7 yBy: 8];
  [gs GSSetCTM: t];
  [t translateXBy: 100 yBy: 100];
  p = [gs pointInMatrixSpace: NSMakePoint(0, 0)];
  PASS(eqf(p.x, 7) && eqf(p.y, 8),
    "changing the caller's transform after GSSetCTM does not change the gstate");

  /* The gstate changing its matrix must not reach back into the caller's
   * transform. */
  t = [NSAffineTransform transform];
  [t translateXBy: 7 yBy: 8];
  [gs GSSetCTM: t];
  [gs DPSinitmatrix];
  p = [t transformPoint: NSMakePoint(0, 0)];
  PASS(eqf(p.x, 7) && eqf(p.y, 8),
    "the gstate resetting its matrix does not change the caller's transform");

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
