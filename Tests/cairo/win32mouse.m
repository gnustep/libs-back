/* Coverage for the win32 display server's mouse location: -mouselocation and
 * -mouseLocationOnScreen:window: on WIN32Server (Source/win32/WIN32Server.m).
 *
 * The cursor is moved to two known screen positions and the reported location
 * is checked: moving the cursor right increases the reported x by the same
 * amount, and moving it down decreases the reported y (the win32 top-left screen
 * origin is flipped to the GS bottom-left origin).  -mouseLocationOnScreen:window:
 * reports the same point as -mouselocation.  The cursor is restored afterwards.
 *
 * It guards on the win32 server with the cairo graphics backend being the one
 * built, and skips when the backend cannot be reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_win32) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_win32 && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <windows.h>

int
main(void)
{
  START_SET("WIN32Server mouse location")
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
      SKIP("no win32 server available")
    }
  else
    {
      int     screen = [[[server screenList] objectAtIndex: 0] intValue];
      POINT   saved;
      NSPoint m1, m2, onScreen, plain;

      GetCursorPos(&saved);

      /* Moving the cursor right by 100 px increases the reported x by 100. */
      SetCursorPos(200, 150);
      m1 = [server mouselocation];
      SetCursorPos(300, 250);
      m2 = [server mouselocation];

      PASS((m2.x - m1.x) == 100.0,
	"mouselocation tracks the cursor x")

      /* Moving the cursor down by 100 px in win32 coordinates lowers the
       * reported y by 100, since the origin is flipped. */
      PASS((m1.y - m2.y) == 100.0,
	"mouselocation flips the win32 y origin to GS coordinates")

      /* -mouseLocationOnScreen:window: reports the same point. */
      SetCursorPos(250, 200);
      onScreen = [server mouseLocationOnScreen: screen window: NULL];
      plain = [server mouselocation];
      PASS(NSEqualPoints(onScreen, plain) == YES,
	"mouseLocationOnScreen:window: matches mouselocation")

      SetCursorPos(saved.x, saved.y);
    }

  LEAVE_POOL
  END_SET("WIN32Server mouse location")
  return 0;
}

#else

int
main(void)
{
  START_SET("WIN32Server mouse location")
    SKIP("back is not built with the win32+cairo backend")
  END_SET("WIN32Server mouse location")
  return 0;
}

#endif
