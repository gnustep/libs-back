/* Regression test for createShmBuffer() in
 * Source/cairo/WaylandCairoShmSurface.m.
 *
 * createShmBuffer() allocates a pool_buffer and then bails out with a plain
 * "return NULL" on its error paths (a zero-area request, or a failed pool-file
 * / mmap), leaking the allocation (and, on the mmap path, the open fd).  The
 * zero-area path returns before any wl_* call, so it can be exercised with no
 * Wayland compositor.
 *
 * The real source file is compiled in directly (with a tiny CairoSurface
 * stand-in) so the test does not need the gui-linked back bundle.  Built with
 * -fsanitize=address (see GNUmakefile) it fails before the fix with a
 * LeakSanitizer report at WaylandCairoShmSurface.m and passes after it.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "cairo/CairoSurface.h"

/* Minimal stand-in for CairoSurface (the real one lives in CairoSurface.m). */
@implementation CairoSurface
- (id) initWithDevice: (void *)device { gsDevice = device; return self; }
- (NSSize) size { return NSMakeSize(0, 0); }
- (void) setSize: (NSSize)newSize { (void)newSize; }
- (cairo_surface_t *) surface { return _surface; }
- (void) handleExposeRect: (NSRect)rect { (void)rect; }
- (BOOL) isDrawingToScreen { return NO; }
@end

#include "cairo/WaylandCairoShmSurface.m"

int
main(void)
{
  START_SET("WaylandCairoShmSurface createShmBuffer")
  ENTER_POOL
  int	i;
  BOOL	ok = YES;

  /* A zero-area request must be rejected (returning NULL) without leaking the
   * pool_buffer it allocates up front. */
  for (i = 0; i < 100; i++)
    {
      if (createShmBuffer(64, 0, NULL) != NULL)
	{
	  ok = NO;
	}
    }
  PASS(ok == YES,
    "createShmBuffer rejects a zero-area request without leaking the buffer")
  LEAVE_POOL
  END_SET("WaylandCairoShmSurface createShmBuffer")
  return 0;
}
