/* Coverage for the win32 display server's window operations: -window::::,
 * -windowbounds:, -setwindowlevel::, -windowlevel: and -styleoffsets::::: on
 * WIN32Server (Source/win32/WIN32Server.m).
 *
 * A hidden window is created through the GSDisplayServer interface and its
 * attributes are read back: the window number is positive and unique,
 * -windowbounds: reports the frame the window was created with, a set window
 * level is read back, and -styleoffsets: reports the decoration insets for a
 * titled window with a taller top for the title bar, or no insets when the
 * server does not draw decorations.
 *
 * It guards on the win32 server with the cairo graphics backend being the one
 * built, and at run time it skips when the backend cannot be reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_win32) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_win32 && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

@interface NSObject (WIN32ServerDecorations)
- (void) setHandlesWindowDecorations: (BOOL) b;
@end

int
main(void)
{
  START_SET("WIN32Server window operations")
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
      int    screen = [[[server screenList] objectAtIndex: 0] intValue];
      NSRect frame = NSMakeRect(100, 100, 200, 150);
      int    win;
      int    win2;

      win = [server window: frame
			   : NSBackingStoreBuffered
			   : NSTitledWindowMask
			   : screen];

      /* A created window has a positive number... */
      PASS(win > 0, "window:::: returns a positive window number")

      /* ...and a second window gets a distinct one. */
      win2 = [server window: frame
			    : NSBackingStoreBuffered
			    : NSTitledWindowMask
			    : screen];
      PASS(win2 > 0 && win2 != win,
	"a second window gets a distinct number")

      /* -windowbounds: reports the frame the window was created with. */
      PASS(NSEqualRects([server windowbounds: win], frame) == YES,
	"windowbounds: reports the created frame")

      /* -setwindowlevel:: / -windowlevel: round-trip the level. */
      [server setwindowlevel: NSFloatingWindowLevel : win];
      PASS([server windowlevel: win] == NSFloatingWindowLevel,
	"windowlevel: reads back a set floating level")
      [server setwindowlevel: NSNormalWindowLevel : win];
      PASS([server windowlevel: win] == NSNormalWindowLevel,
	"windowlevel: reads back a set normal level")

      /* -styleoffsets: reports the decoration insets of a titled window, with
       * a taller top inset for the title bar. */
      {
	float l = -1, r = -1, t = -1, b = -1;

	[server styleoffsets: &l : &r : &t : &b : NSTitledWindowMask];
	PASS(l > 0.0 && r > 0.0 && t > 0.0 && b > 0.0,
	  "styleoffsets::::: reports positive decoration insets")
	PASS(t > l && t > b,
	  "styleoffsets::::: reports a taller top inset for the title bar")
      }

      /* When the server does not draw decorations there are no insets. */
      {
	float l = -1, r = -1, t = -1, b = -1;
	BOOL  saved = [server handlesWindowDecorations];

	[server setHandlesWindowDecorations: NO];
	[server styleoffsets: &l : &r : &t : &b : NSTitledWindowMask];
	PASS(l == 0.0 && r == 0.0 && t == 0.0 && b == 0.0,
	  "styleoffsets::::: reports no insets without decorations")
	[server setHandlesWindowDecorations: saved];
      }

      [server termwindow: win2];
      [server termwindow: win];
    }

  LEAVE_POOL
  END_SET("WIN32Server window operations")
  return 0;
}

#else

int
main(void)
{
  START_SET("WIN32Server window operations")
    SKIP("back is not built with the win32+cairo backend")
  END_SET("WIN32Server window operations")
  return 0;
}

#endif
