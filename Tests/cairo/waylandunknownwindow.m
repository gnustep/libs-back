/* Regression test for the window operations on WaylandServer
 * (Source/wayland/WaylandServer.m) when handed a window number that no window
 * has.
 *
 * get_window_with_id() returns NULL for an unknown window number (its header
 * notes that callers must handle this), which happens for a stale number, for
 * example one referred to after its window was terminated.  The window
 * operations dereferenced the result without checking, so an unknown number
 * crashed the server; -flushwindowrect: already guarded against it, and the x11
 * backend guards every such lookup.  The fix guards the remaining ones, so an
 * unknown number is ignored, -windowlevel: reports 0, and -windowbounds:
 * reports NSZeroRect.
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
  START_SET("WaylandServer unknown window number")
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
      int unknown = 999999;

      /* None of these operations has a window with this number; each must
       * ignore it rather than dereference a NULL window record. */
      [server setwindowlevel: NSNormalWindowLevel : unknown];
      [server titlewindow: @"unknown" : unknown];
      [server miniwindow: unknown];
      [server orderwindow: NSWindowOut : 0 : unknown];
      [server placewindow: NSMakeRect(0, 0, 20, 20) : unknown];
      [server setWindowdevice: unknown
		    forContext: [NSGraphicsContext currentContext]];
      [server termwindow: unknown];

      /* The two query operations report the empty answers. */
      PASS([server windowlevel: unknown] == 0,
	"windowlevel: on an unknown window number returns 0")
      PASS(NSEqualRects([server windowbounds: unknown], NSZeroRect) == YES,
	"windowbounds: on an unknown window number returns NSZeroRect")
      PASS(YES,
	"window operations on an unknown window number do not crash")
    }

  LEAVE_POOL
  END_SET("WaylandServer unknown window number")
  return 0;
}

#else

int
main(void)
{
  START_SET("WaylandServer unknown window number")
    SKIP("back is not built with the wayland+cairo backend")
  END_SET("WaylandServer unknown window number")
  return 0;
}

#endif
