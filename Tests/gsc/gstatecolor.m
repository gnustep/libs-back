/* Tests for the colour get/set handling in the base GSGState in
 * Source/gsc/GSGState.m: a colour set in one space is read back in the same
 * space and converted into the others, the alpha is kept across colour
 * changes, and components are clamped to [0,1].
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

@interface NSObject (GSGStateColor)
- initWithContextInfo: (NSDictionary *)info;
- initWithDrawContext: (id)ctxt;
- (void) DPSsetgray: (CGFloat)g;
- (void) DPSsetrgbcolor: (CGFloat)r : (CGFloat)g : (CGFloat)b;
- (void) DPSsetcmykcolor: (CGFloat)c : (CGFloat)m : (CGFloat)y : (CGFloat)k;
- (void) DPSsethsbcolor: (CGFloat)h : (CGFloat)s : (CGFloat)b;
- (void) DPSsetalpha: (CGFloat)a;
- (void) DPScurrentgray: (CGFloat *)g;
- (void) DPScurrentrgbcolor: (CGFloat *)r : (CGFloat *)g : (CGFloat *)b;
- (void) DPScurrentcmykcolor: (CGFloat *)c : (CGFloat *)m : (CGFloat *)y : (CGFloat *)k;
- (void) DPScurrenthsbcolor: (CGFloat *)h : (CGFloat *)s : (CGFloat *)b;
- (void) DPScurrentalpha: (CGFloat *)a;
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
  CGFloat r, g, b, k, a;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping GSGState colour tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];
  ctxt = [[NSClassFromString(@"GSStreamContext") alloc] initWithContextInfo:
    [NSDictionary dictionaryWithObject:
      [NSTemporaryDirectory() stringByAppendingPathComponent: @"gsc_color.ps"]
      forKey: @"NSOutputFile"]];
  gs = [[NSClassFromString(@"GSGState") alloc] initWithDrawContext: ctxt];
  PASS(gs != nil, "a GSGState is created for the stream context");
  if (gs == nil)
    {
      DESTROY(pool);
      return 0;
    }

  /* rgb red reads back as itself and converts into the other spaces */
  [gs DPSsetrgbcolor: 1 : 0 : 0];
  [gs DPScurrentrgbcolor: &r : &g : &b];
  PASS(eqf(r, 1) && eqf(g, 0) && eqf(b, 0), "rgb red reads back as rgb");
  [gs DPScurrentgray: &g];
  PASS(eqf(g, 0.3), "rgb red converts to the luma gray");
  [gs DPScurrentcmykcolor: &r : &g : &b : &k];
  PASS(eqf(r, 0) && eqf(g, 1) && eqf(b, 1) && eqf(k, 0),
    "rgb red converts to cmyk");
  [gs DPScurrenthsbcolor: &r : &g : &b];
  PASS(eqf(r, 0) && eqf(g, 1) && eqf(b, 1), "rgb red converts to hsb");

  /* gray reads back as itself and converts into the other spaces */
  [gs DPSsetgray: 0.5];
  [gs DPScurrentgray: &g];
  PASS(eqf(g, 0.5), "gray reads back as gray");
  [gs DPScurrentrgbcolor: &r : &g : &b];
  PASS(eqf(r, 0.5) && eqf(g, 0.5) && eqf(b, 0.5),
    "gray converts to an equal-component rgb");
  [gs DPScurrentcmykcolor: &r : &g : &b : &k];
  PASS(eqf(r, 0) && eqf(g, 0) && eqf(b, 0) && eqf(k, 0.5),
    "gray converts to cmyk black");
  [gs DPScurrenthsbcolor: &r : &g : &b];
  PASS(eqf(r, 0) && eqf(g, 0) && eqf(b, 0.5), "gray converts to hsb brightness");

  /* cmyk cyan reads back as itself and converts to rgb */
  [gs DPSsetcmykcolor: 1 : 0 : 0 : 0];
  [gs DPScurrentcmykcolor: &r : &g : &b : &k];
  PASS(eqf(r, 1) && eqf(g, 0) && eqf(b, 0) && eqf(k, 0),
    "cmyk cyan reads back as cmyk");
  [gs DPScurrentrgbcolor: &r : &g : &b];
  PASS(eqf(r, 0) && eqf(g, 1) && eqf(b, 1), "cmyk cyan converts to rgb");

  /* hsb green reads back as itself and converts to rgb */
  [gs DPSsethsbcolor: 1.0 / 3.0 : 1 : 1];
  [gs DPScurrenthsbcolor: &r : &g : &b];
  PASS(eqf(r, 1.0 / 3.0) && eqf(g, 1) && eqf(b, 1),
    "hsb green reads back as hsb");
  [gs DPScurrentrgbcolor: &r : &g : &b];
  PASS(eqf(r, 0) && eqf(g, 1) && eqf(b, 0), "hsb green converts to rgb");

  /* alpha is set and read independently, and kept when the colour changes */
  [gs DPSsetalpha: 0.25];
  [gs DPScurrentalpha: &a];
  PASS(eqf(a, 0.25), "alpha reads back what was set");
  [gs DPSsetgray: 0.7];
  [gs DPScurrentalpha: &a];
  PASS(eqf(a, 0.25), "setting a colour keeps the current alpha");

  /* components out of range are clamped */
  [gs DPSsetrgbcolor: 2 : -1 : 0.5];
  [gs DPScurrentrgbcolor: &r : &g : &b];
  PASS(eqf(r, 1) && eqf(g, 0) && eqf(b, 0.5),
    "rgb components are clamped to zero and one");

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
