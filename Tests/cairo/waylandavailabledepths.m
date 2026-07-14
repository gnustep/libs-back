/* Regression test for -availableDepthsForScreen: on WaylandServer
 * (Source/wayland/WaylandServer.m).
 *
 * -availableDepthsForScreen: returns a zero-terminated list of the window
 * depths a screen supports, which -[NSScreen supportedWindowDepths] hands back
 * and then frees.  The method returned NULL, so -supportedWindowDepths logged an
 * internal error and reported no depths.  The fix returns a zone-allocated list
 * holding the depth -windowDepthForScreen: reports, terminated with a zero.
 *
 * Like the other backend tests it builds only for the wayland+cairo backend and
 * skips on every other one, and at run time it skips when no compositor can be
 * reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_wayland) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_wayland && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

int
main(void)
{
  START_SET("WaylandServer availableDepthsForScreen")
  ENTER_POOL

  GSDisplayServer *server = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      server = GSCurrentServer();
      if (server == nil)
	{
	  server = [GSDisplayServer serverWithAttributes: nil];
	}
    }
  NS_HANDLER
    {
      server = nil;
    }
  NS_ENDHANDLER

  if (server == nil)
    {
      SKIP("no Wayland compositor available")
    }
  else
    {
      int                  screen = [[[server screenList] objectAtIndex: 0] intValue];
      const NSWindowDepth *depths = [server availableDepthsForScreen: screen];

      /* The list is present... */
      PASS(depths != NULL,
	"availableDepthsForScreen: returns a depth list")

      if (depths != NULL)
	{
	  NSWindowDepth want = [server windowDepthForScreen: screen];
	  BOOL          terminated = NO;
	  BOOL          found = NO;
	  int           i;

	  /* ...zero-terminated (searched within a sane bound)... */
	  for (i = 0; i < 64; i++)
	    {
	      if (depths[i] == 0)
		{
		  terminated = YES;
		  break;
		}
	      if (depths[i] == want)
		{
		  found = YES;
		}
	    }
	  PASS(terminated == YES,
	    "availableDepthsForScreen: list is zero-terminated")

	  /* ...and contains the depth the screen reports. */
	  PASS(found == YES,
	    "availableDepthsForScreen: list includes the screen window depth")

	  /* The caller owns the list, as -[NSScreen dealloc] frees it. */
	  NSZoneFree(NSDefaultMallocZone(), (void *) depths);
	}
    }

  LEAVE_POOL
  END_SET("WaylandServer availableDepthsForScreen")
  return 0;
}

#else

int
main(void)
{
  START_SET("WaylandServer availableDepthsForScreen")
    SKIP("back is not built with the wayland+cairo backend")
  END_SET("WaylandServer availableDepthsForScreen")
  return 0;
}

#endif
