/* Tests that GSGState's GSSetCTM takes its own copy of the matrix, so the
 * gstate and the caller's transform do not alias each other: neither one
 * changing after the call disturbs the other.
 *
 * GSGState lives in the backend bundle, so the test needs a backend loaded
 * (hence a window server); it skips when no display server can be reached.  The
 * code under test is the same for every backend; it is built for the cairo
 * backend.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
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
  START_SET("GSGState alias")
  id ctxt, gs;
  NSAffineTransform *t;
  NSPoint p;

  NS_DURING
    {
      [NSApplication sharedApplication];
      if (nil == GSCurrentServer())
	{
	  SKIP("no window server available")
	}
    }
  NS_HANDLER
    {
      SKIP("It looks like GNUstep backend is not yet installed")
    }
  NS_ENDHANDLER
  ctxt = [[NSClassFromString(@"GSStreamContext") alloc] initWithContextInfo:
    [NSDictionary dictionaryWithObject:
      [NSTemporaryDirectory() stringByAppendingPathComponent: @"gsc_alias.ps"]
      forKey: @"NSOutputFile"]];
  AUTORELEASE(ctxt);
  gs = [[NSClassFromString(@"GSGState") alloc] initWithDrawContext: ctxt];
  AUTORELEASE(gs);
  PASS(gs != nil, "a GSGState is created for the stream context");
  if (gs == nil)
    {
      SKIP("gs could not be created")
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

  END_SET("GSGState alias")
  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("GSGState alias")
    SKIP("back is not built with the cairo graphics backend")
  END_SET("GSGState alias")
  return 0;
}

#endif
