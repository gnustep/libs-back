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
 *
 * A backend test can only build against the backend it belongs to, so it guards
 * itself on the backend actually being built: config.h names it as BUILD_SERVER
 * / BUILD_GRAPHICS, and this test compiles the wayland+cairo source and runs the
 * check only for that backend, skipping cleanly on every other one.  The
 * matching GNUmakefile.preamble adds the wayland/cairo headers and libraries
 * under the same condition, so the test builds everywhere but pulls in a
 * backend's dependencies only where that backend is present.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_wayland) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_wayland && BUILD_GRAPHICS == GRAPHICS_cairo

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

#else

int
main(void)
{
  START_SET("WaylandCairoShmSurface createShmBuffer")
    SKIP("back is not built with the wayland+cairo backend")
  END_SET("WaylandCairoShmSurface createShmBuffer")
  return 0;
}

#endif
