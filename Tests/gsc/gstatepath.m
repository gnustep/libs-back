/* Tests for the path construction and query in the base GSGState in
 * Source/gsc/GSGState.m (inherited by the concrete backends): a path is built
 * in device space with the current transform applied, and the current point
 * and bounding box are read back in user space, so both round-trip through the
 * transform.
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

@interface NSObject (GSGStatePath)
- initWithContextInfo: (NSDictionary *)info;
- initWithDrawContext: (id)ctxt;
- (void) DPSmoveto: (CGFloat)x : (CGFloat)y;
- (void) DPSlineto: (CGFloat)x : (CGFloat)y;
- (void) DPSrmoveto: (CGFloat)x : (CGFloat)y;
- (void) DPSrlineto: (CGFloat)x : (CGFloat)y;
- (void) DPScurveto: (CGFloat)x1 : (CGFloat)y1 : (CGFloat)x2 : (CGFloat)y2 : (CGFloat)x3 : (CGFloat)y3;
- (void) DPSnewpath;
- (void) DPSclosepath;
- (void) DPScurrentpoint: (CGFloat *)x : (CGFloat *)y;
- (void) DPSpathbbox: (CGFloat *)llx : (CGFloat *)lly : (CGFloat *)urx : (CGFloat *)ury;
- (void) DPStranslate: (CGFloat)x : (CGFloat)y;
- (void) DPSscale: (CGFloat)x : (CGFloat)y;
@end

static BOOL
eqf(CGFloat a, CGFloat b)
{
  CGFloat d = a - b;

  return (d < 0.0001 && d > -0.0001) ? YES : NO;
}

static BOOL
atPoint(id gs, CGFloat x, CGFloat y)
{
  CGFloat cx, cy;

  [gs DPScurrentpoint: &cx : &cy];
  return eqf(cx, x) && eqf(cy, y);
}

static BOOL
hasBBox(id gs, CGFloat llx, CGFloat lly, CGFloat urx, CGFloat ury)
{
  CGFloat a, b, c, d;

  [gs DPSpathbbox: &a : &b : &c : &d];
  return eqf(a, llx) && eqf(b, lly) && eqf(c, urx) && eqf(d, ury);
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  id ctxt, gs;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping GSGState path tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];
  ctxt = [[NSClassFromString(@"GSStreamContext") alloc] initWithContextInfo:
    [NSDictionary dictionaryWithObject:
      [NSTemporaryDirectory() stringByAppendingPathComponent: @"gsc_path.ps"]
      forKey: @"NSOutputFile"]];
  gs = [[NSClassFromString(@"GSGState") alloc] initWithDrawContext: ctxt];
  PASS(gs != nil, "a GSGState is created for the stream context");
  if (gs == nil)
    {
      DESTROY(pool);
      return 0;
    }

  [gs DPSmoveto: 10 : 20];
  PASS(atPoint(gs, 10, 20), "moveto sets the current point");
  [gs DPSlineto: 30 : 40];
  PASS(atPoint(gs, 30, 40), "lineto moves the current point to its end");
  [gs DPSrmoveto: 5 : 5];
  PASS(atPoint(gs, 35, 45), "rmoveto moves the current point relatively");
  [gs DPSrlineto: 10 : 0];
  PASS(atPoint(gs, 45, 45), "rlineto extends the path relatively");

  /* current point after a curve is the curve's end point */
  [gs DPSnewpath];
  [gs DPSmoveto: 0 : 0];
  [gs DPScurveto: 10 : 10 : 20 : 10 : 30 : 0];
  PASS(atPoint(gs, 30, 0), "curveto ends at its final point");
  PASS(hasBBox(gs, 0, 0, 30, 10),
    "the path bounding box spans the curve control points");

  /* closepath returns the current point to the start of the subpath */
  [gs DPSnewpath];
  [gs DPSmoveto: 10 : 20];
  [gs DPSlineto: 30 : 40];
  [gs DPSclosepath];
  PASS(atPoint(gs, 10, 20), "closepath returns to the start of the subpath");

  /* a triangle's bounding box */
  [gs DPSnewpath];
  [gs DPSmoveto: 10 : 20];
  [gs DPSlineto: 30 : 40];
  [gs DPSlineto: 5 : 50];
  PASS(hasBBox(gs, 5, 20, 30, 50), "the bounding box spans the path points");

  /* the path is built with the transform applied, and read back in user space,
   * so the current point and box round-trip through the transform */
  [gs DPSnewpath];
  [gs DPStranslate: 100 : 200];
  [gs DPSscale: 2 : 2];
  [gs DPSmoveto: 3 : 4];
  [gs DPSlineto: 8 : 9];
  PASS(atPoint(gs, 8, 9),
    "the current point is reported in user space under a transform");
  PASS(hasBBox(gs, 3, 4, 8, 9),
    "the bounding box is reported in user space under a transform");

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
