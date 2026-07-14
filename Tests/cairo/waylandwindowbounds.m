/* Regression test for -windowbounds: on WaylandServer
 * (Source/wayland/WaylandServer.m).
 *
 * -windowbounds: reports a window's frame in screen coordinates, so the bounds
 * read back must match the frame the window was created with.  The y origin was
 * computed as (screen height - stored top position) but left out the window
 * height, so the reported origin sat one window-height too high and did not
 * round-trip; the x origin and the size were already correct.  The fix converts
 * the stored top-down position back to screen coordinates with WaylandToNS().
 *
 * Like the other backend tests it builds only for the wayland+cairo backend
 * (guarded through config.h's BUILD_SERVER / BUILD_GRAPHICS) and skips on every
 * other one, and at run time it skips when no compositor can be reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_wayland) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_wayland && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

static BOOL
roundTrips(GSDisplayServer *server, int screen, NSRect frame)
{
  int    win = [server window: frame
			     : NSBackingStoreBuffered
			     : 0
			     : screen];
  NSRect bounds = [server windowbounds: win];

  [server termwindow: win];
  return NSEqualRects(bounds, frame);
}

int
main(void)
{
  START_SET("WaylandServer windowbounds round-trip")
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
      int screen = [[[server screenList] objectAtIndex: 0] intValue];

      /* -windowbounds: returns the frame the window was created with, at
       * several positions and heights (the y origin depends on both). */
      PASS(roundTrips(server, screen, NSMakeRect(100, 200, 50, 40)) == YES,
	"windowbounds: round-trips a mid-screen frame")
      PASS(roundTrips(server, screen, NSMakeRect(0, 0, 10, 10)) == YES,
	"windowbounds: round-trips a frame at the origin")
      PASS(roundTrips(server, screen, NSMakeRect(300, 500, 120, 80)) == YES,
	"windowbounds: round-trips a taller frame")
    }

  LEAVE_POOL
  END_SET("WaylandServer windowbounds round-trip")
  return 0;
}

#else

int
main(void)
{
  START_SET("WaylandServer windowbounds round-trip")
    SKIP("back is not built with the wayland+cairo backend")
  END_SET("WaylandServer windowbounds round-trip")
  return 0;
}

#endif
