/* Coverage for the Wayland display server's window operations: -window::::,
 * -windowbounds:, -setwindowlevel::, -windowlevel:, -styleoffsets::::: and
 * -handlesWindowDecorations on WaylandServer (Source/wayland/WaylandServer.m).
 *
 * A window is created straight through the GSDisplayServer interface (no
 * NSWindow), which allocates the backend's window record and registers its
 * number, and its attributes are read back.  The checks follow the
 * GSDisplayServer contract: a fresh window number is positive and unique, a
 * zero-area frame is not accepted, -windowbounds: reports the requested size and
 * x origin, the window level set is the level read back, and an undecorated
 * backend reports zero style offsets.
 *
 * As with the other backend tests it builds only for the wayland+cairo backend
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

int
main(void)
{
  START_SET("WaylandServer window operations")
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
      int      screen = [[screens objectAtIndex: 0] intValue];
      NSRect   frame = NSMakeRect(100, 200, 50, 40);
      int      win;
      int      win2;

      win = [server window: frame
			   : NSBackingStoreBuffered
			   : 0
			   : screen];

      /* A created window has a positive number... */
      PASS(win > 0, "window:::: returns a positive window number")

      /* ...and a second window gets a distinct one. */
      win2 = [server window: frame
			    : NSBackingStoreBuffered
			    : 0
			    : screen];
      PASS(win2 > 0 && win2 != win,
	"a second window gets a distinct number")

      /* -windowbounds: reports the requested width, height and x origin. */
      {
	NSRect b = [server windowbounds: win];

	PASS(b.size.width == frame.size.width
	  && b.size.height == frame.size.height,
	  "windowbounds: reports the requested size")
	PASS(b.origin.x == frame.origin.x,
	  "windowbounds: reports the requested x origin")
      }

      /* A zero-area frame is not accepted as a window with no extent. */
      {
	int    z = [server window: NSMakeRect(0, 0, 0, 0)
			     : NSBackingStoreBuffered
			     : 0
			     : screen];
	NSRect zb = [server windowbounds: z];

	PASS(zb.size.width > 0.0 && zb.size.height > 0.0,
	  "a zero-area frame yields a window with a positive size")
	[server termwindow: z];
      }

      /* -setwindowlevel:: / -windowlevel: round-trip the level. */
      [server setwindowlevel: NSFloatingWindowLevel : win];
      PASS([server windowlevel: win] == NSFloatingWindowLevel,
	"windowlevel: reads back a set floating level")
      [server setwindowlevel: NSNormalWindowLevel : win];
      PASS([server windowlevel: win] == NSNormalWindowLevel,
	"windowlevel: reads back a set normal level")

      /* An undecorated backend reports zero style offsets... */
      {
	float l = -1.0, r = -1.0, t = -1.0, b = -1.0;

	[server styleoffsets: &l : &r : &t : &b : NSTitledWindowMask];
	PASS(l == 0.0 && r == 0.0 && t == 0.0 && b == 0.0,
	  "styleoffsets::::: reports no decoration insets")
      }

      /* ...consistent with not handling window decorations. */
      PASS([server handlesWindowDecorations] == NO,
	"handlesWindowDecorations is NO")

      [server termwindow: win2];
      [server termwindow: win];
    }

  LEAVE_POOL
  END_SET("WaylandServer window operations")
  return 0;
}

#else

int
main(void)
{
  START_SET("WaylandServer window operations")
    SKIP("back is not built with the wayland+cairo backend")
  END_SET("WaylandServer window operations")
  return 0;
}

#endif
