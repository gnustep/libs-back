/* Tests for the CTM and coordinate handling in the base GSGState in
 * Source/gsc/GSGState.m: the matrix operators build the current transform, and
 * a point or delta is mapped through it.
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

@interface NSObject (GSGStateCTM)
- initWithContextInfo: (NSDictionary *)info;
- initWithDrawContext: (id)ctxt;
- (void) GSSetCTM: (NSAffineTransform *)m;
- (NSAffineTransform *) GSCurrentCTM;
- (void) GSConcatCTM: (NSAffineTransform *)m;
- (void) DPStranslate: (CGFloat)x : (CGFloat)y;
- (void) DPSscale: (CGFloat)x : (CGFloat)y;
- (void) DPSrotate: (CGFloat)a;
- (void) DPSconcat: (const CGFloat *)m;
- (void) DPSinitmatrix;
- (NSPoint) pointInMatrixSpace: (NSPoint)p;
- (NSPoint) deltaPointInMatrixSpace: (NSPoint)p;
@end

static BOOL
eqf(CGFloat a, CGFloat b)
{
  CGFloat d = a - b;

  return (d < 0.0001 && d > -0.0001) ? YES : NO;
}

static BOOL
maps(id gs, NSPoint in, CGFloat x, CGFloat y)
{
  NSPoint out = [gs pointInMatrixSpace: in];

  return eqf(out.x, x) && eqf(out.y, y);
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  id ctxt, gs;
  NSAffineTransform *t;
  NSAffineTransformStruct s;
  CGFloat m[6] = {1, 0, 0, 1, 5, 6};

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping GSGState CTM tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];
  ctxt = [[NSClassFromString(@"GSStreamContext") alloc] initWithContextInfo:
    [NSDictionary dictionaryWithObject:
      [NSTemporaryDirectory() stringByAppendingPathComponent: @"gsc_gstate.ps"]
      forKey: @"NSOutputFile"]];
  gs = [[NSClassFromString(@"GSGState") alloc] initWithDrawContext: ctxt];
  PASS(gs != nil, "a GSGState is created for the stream context");
  if (gs == nil)
    {
      DESTROY(pool);
      return 0;
    }

  PASS(maps(gs, NSMakePoint(3, 4), 3, 4),
    "the initial matrix is the identity");

  [gs DPStranslate: 10 : 20];
  PASS(maps(gs, NSMakePoint(0, 0), 10, 20)
    && maps(gs, NSMakePoint(1, 1), 11, 21),
    "translate offsets a mapped point");
  PASS(eqf([gs deltaPointInMatrixSpace: NSMakePoint(1, 1)].x, 1)
    && eqf([gs deltaPointInMatrixSpace: NSMakePoint(1, 1)].y, 1),
    "a delta ignores the translation");

  [gs DPSinitmatrix];
  PASS(maps(gs, NSMakePoint(3, 4), 3, 4), "initmatrix restores the identity");

  [gs DPSscale: 2 : 3];
  PASS(maps(gs, NSMakePoint(5, 5), 10, 15), "scale multiplies a mapped point");

  [gs DPSinitmatrix];
  [gs DPSrotate: 90];
  PASS(maps(gs, NSMakePoint(1, 0), 0, 1),
    "a 90 degree rotation maps the x axis onto the y axis");

  [gs DPSinitmatrix];
  [gs DPSconcat: m];
  PASS(maps(gs, NSMakePoint(0, 0), 5, 6),
    "concat prepends the given matrix");

  /* order matters: translate then scale is not scale then translate */
  [gs DPSinitmatrix];
  [gs DPStranslate: 10 : 0];
  [gs DPSscale: 2 : 2];
  PASS(maps(gs, NSMakePoint(1, 0), 12, 0),
    "translate then scale applies the scale in the translated frame");

  /* GSSetCTM installs a matrix and GSCurrentCTM reads it back */
  t = [NSAffineTransform transform];
  [t scaleXBy: 2 yBy: 4];
  [t translateXBy: 3 yBy: 5];
  [gs GSSetCTM: t];
  s = [[gs GSCurrentCTM] transformStruct];
  PASS(eqf(s.m11, 2) && eqf(s.m22, 4) && eqf(s.tX, 6) && eqf(s.tY, 20),
    "GSSetCTM installs the matrix that GSCurrentCTM reads back");

  {
    NSAffineTransform *t2 = [NSAffineTransform transform];

    [t2 scaleXBy: 2 yBy: 4];
    [t2 translateXBy: 3 yBy: 5];
    [gs DPSinitmatrix];
    [gs GSConcatCTM: t2];
    PASS(maps(gs, NSMakePoint(0, 0), 6, 20),
      "GSConcatCTM prepends the given matrix");
  }

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
