/* Coverage for the Wayland display server's window mapping path: ordering a
 * window in and out, which drives -orderwindow:::, -createSurfaceShell:,
 * -createTopLevel:, -titlewindow:: and -destroyWindowShell: on WaylandServer
 * (Source/wayland/WaylandServer.m).
 *
 * The window is driven through NSWindow, the way an application maps one: an
 * ordered-in titled window keeps a valid window number and reports a
 * positive-size frame, a title can be set on it, ordering it out and back in
 * again (which destroys and recreates the surface role) keeps it valid, and a
 * second window maps alongside the first with its own number.
 *
 * As with the other backend tests it builds only for the wayland+cairo backend
 * and skips on every other one, and at run time it skips when no compositor can
 * be reached.
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
  START_SET("WaylandServer window mapping")
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
      NSWindow *win = [[NSWindow alloc]
			initWithContentRect: NSMakeRect(120, 130, 200, 150)
				  styleMask: NSTitledWindowMask
				    backing: NSBackingStoreBuffered
				      defer: NO];
      int number = (int) [win windowNumber];

      /* A titled window has a valid backend window number. */
      PASS(number > 0, "a titled window has a valid window number")

      /* Ordering it in maps a surface and keeps a positive-size frame. */
      [win setTitle: @"Mapping test"];
      [win orderFront: nil];
      {
	NSRect b = [server windowbounds: number];
	PASS(b.size.width > 0.0 && b.size.height > 0.0,
	  "an ordered-in window reports a positive-size frame")
      }

      /* Ordering out then back in destroys and recreates the surface role,
       * and the window stays valid. */
      [win orderOut: nil];
      [win orderFront: nil];
      {
	NSRect b = [server windowbounds: number];
	PASS(b.size.width > 0.0 && b.size.height > 0.0,
	  "a re-ordered-in window still reports a positive-size frame")
      }

      /* A second window maps alongside the first with its own number. */
      {
	NSWindow *win2 = [[NSWindow alloc]
			   initWithContentRect: NSMakeRect(400, 300, 160, 120)
				     styleMask: NSTitledWindowMask
				       backing: NSBackingStoreBuffered
					 defer: NO];
	int number2 = (int) [win2 windowNumber];

	[win2 orderFront: nil];
	PASS(number2 > 0 && number2 != number,
	  "a second mapped window has its own window number")
	[win2 close];
      }

      [win close];
    }

  LEAVE_POOL
  END_SET("WaylandServer window mapping")
  return 0;
}

#else

int
main(void)
{
  START_SET("WaylandServer window mapping")
    SKIP("back is not built with the wayland+cairo backend")
  END_SET("WaylandServer window mapping")
  return 0;
}

#endif
