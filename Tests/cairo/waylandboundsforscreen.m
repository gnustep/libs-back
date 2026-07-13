/* Regression test for -boundsForScreen: on WaylandServer
 * (Source/wayland/WaylandServer.m).
 *
 * -boundsForScreen: is passed a screen number, one of the values -screenList
 * reports, and returns that screen's bounds, or NSZeroRect for a screen that is
 * not present.  The loop returned the first output's bounds without ever
 * comparing the requested number against output->server_output_id, so a screen
 * number that is not present, or a negative one, was answered with the first
 * output's bounds instead of NSZeroRect.  The fix matches the requested number
 * against the outputs, the same way -window:::: locates a screen.
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
  START_SET("WaylandServer boundsForScreen")
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
      NSArray *screens = [server screenList];
      int      present = [[screens objectAtIndex: 0] intValue];
      int      absent = 999999;
      NSRect   b;

      /* A screen that -screenList reports has a positive, origin-zero rect. */
      b = [server boundsForScreen: present];
      PASS(b.origin.x == 0.0 && b.origin.y == 0.0
	&& b.size.width > 0.0 && b.size.height > 0.0,
	"boundsForScreen: returns the bounds of a present screen")

      /* Pick an id that -screenList does not report. */
      while ([screens containsObject: [NSNumber numberWithInt: absent]])
	{
	  absent++;
	}

      /* A screen that is not present is answered with NSZeroRect... */
      PASS(NSEqualRects([server boundsForScreen: absent], NSZeroRect) == YES,
	"boundsForScreen: returns NSZeroRect for a screen that is not present")

      /* ...as is a negative screen number. */
      PASS(NSEqualRects([server boundsForScreen: -1], NSZeroRect) == YES,
	"boundsForScreen: returns NSZeroRect for a negative screen number")
    }

  LEAVE_POOL
  END_SET("WaylandServer boundsForScreen")
  return 0;
}

#else

int
main(void)
{
  START_SET("WaylandServer boundsForScreen")
    SKIP("back is not built with the wayland+cairo backend")
  END_SET("WaylandServer boundsForScreen")
  return 0;
}

#endif
