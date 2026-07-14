/* Coverage for the win32 window style mapping: -windowStyleForGSStyle: and
 * -exwindowStyleForGSStyle: on WIN32Server (Source/win32/WIN32Server.m), which
 * turn an NSWindow style mask into the Win32 WS_* and WS_EX_* window styles.
 *
 * When the server does not draw the decorations every window is a plain popup.
 * When it does, a titled window gets a caption, a closable one a system menu, a
 * miniaturizable one a minimize box, and a resizable one a sizing border, and
 * every result clips its children.  The extended style places bordered windows
 * in the taskbar and keeps utility and borderless windows out of it, and drops
 * every window to a tool window frame when the native taskbar is not used.
 *
 * The methods are private to the backend, so they are reached through a category
 * on the running server.  It guards on the win32 server with cairo, and skips
 * when the backend cannot be reached.
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

@interface NSObject (WIN32ServerStyle)
- (void) setHandlesWindowDecorations: (BOOL) b;
- (void) setUsesNativeTaskbar: (BOOL) b;
- (DWORD) windowStyleForGSStyle: (unsigned int) style;
- (DWORD) exwindowStyleForGSStyle: (unsigned int) style;
@end

int
main(void)
{
  START_SET("WIN32Server window style mapping")
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
      DWORD s;

      /* Without server-drawn decorations every window is a plain popup. */
      [server setHandlesWindowDecorations: NO];
      PASS([server windowStyleForGSStyle: NSTitledWindowMask]
	     == (DWORD)(WS_POPUP | WS_CLIPCHILDREN),
	"without decorations a window maps to a clipped popup")

      /* With decorations the style bits map to the Win32 window styles. */
      [server setHandlesWindowDecorations: YES];

      PASS([server windowStyleForGSStyle: NSBorderlessWindowMask]
	     == (DWORD)(WS_POPUP | WS_CLIPCHILDREN),
	"a borderless window maps to a clipped popup")

      s = [server windowStyleForGSStyle: NSTitledWindowMask];
      PASS((s & WS_CAPTION) == WS_CAPTION, "a titled window has a caption")

      s = [server windowStyleForGSStyle: NSClosableWindowMask];
      PASS((s & WS_SYSMENU) == WS_SYSMENU, "a closable window has a system menu")

      s = [server windowStyleForGSStyle: NSMiniaturizableWindowMask];
      PASS((s & WS_MINIMIZEBOX) == WS_MINIMIZEBOX
	&& (s & WS_SYSMENU) == WS_SYSMENU,
	"a miniaturizable window has a minimize box and system menu")

      s = [server windowStyleForGSStyle: NSResizableWindowMask];
      PASS((s & WS_SIZEBOX) == WS_SIZEBOX
	&& (s & WS_MAXIMIZEBOX) == WS_MAXIMIZEBOX,
	"a resizable window has a sizing border and maximize box")

      s = [server windowStyleForGSStyle:
	     (NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)];
      PASS((s & WS_CAPTION) == WS_CAPTION
	&& (s & WS_SYSMENU) == WS_SYSMENU
	&& (s & WS_SIZEBOX) == WS_SIZEBOX,
	"a titled, closable, resizable window combines the styles")
      PASS((s & WS_CLIPCHILDREN) == WS_CLIPCHILDREN,
	"a decorated window still clips its children")

      /* The extended style manages the taskbar and tool-window frame. */
      [server setUsesNativeTaskbar: YES];

      PASS(([server exwindowStyleForGSStyle: NSUtilityWindowMask]
	     & WS_EX_TOOLWINDOW) == WS_EX_TOOLWINDOW,
	"a utility window gets a tool window frame")

      PASS(([server exwindowStyleForGSStyle: NSTitledWindowMask]
	     & WS_EX_APPWINDOW) == WS_EX_APPWINDOW,
	"a bordered window is requested in the taskbar")

      s = [server exwindowStyleForGSStyle: NSBorderlessWindowMask];
      PASS((s & WS_EX_TOOLWINDOW) == WS_EX_TOOLWINDOW
	&& (s & WS_EX_APPWINDOW) == 0,
	"a borderless window stays out of the taskbar")

      /* Without a native taskbar bordered windows drop to a tool window. */
      [server setUsesNativeTaskbar: NO];
      PASS(([server exwindowStyleForGSStyle: NSTitledWindowMask]
	     & WS_EX_TOOLWINDOW) == WS_EX_TOOLWINDOW,
	"without a native taskbar a bordered window is a tool window")

      /* Restore the server defaults. */
      [server setUsesNativeTaskbar: YES];
    }

  LEAVE_POOL
  END_SET("WIN32Server window style mapping")
  return 0;
}

#else

int
main(void)
{
  START_SET("WIN32Server window style mapping")
    SKIP("back is not built with the win32+cairo backend")
  END_SET("WIN32Server window style mapping")
  return 0;
}

#endif
