/* The _MOTIF_WM_HINTS of windows whose decorations the gui library draws
 * (GSBackHandlesWindowDecorations NO): they ask the window manager for no
 * decorations, but keep the functions their style allows, plus move, so
 * that the window manager still moves, resizes, minimizes, maximizes and
 * closes them when asked to (_NET_WM_MOVERESIZE, _NET_WM_STATE, its window
 * menu and keyboard shortcuts).  With functions 0 Mutter refuses all of
 * these.  A borderless window still allows nothing.
 *
 * Only the property the backend sets is read, so the test works with or
 * without a window manager on the display.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) && BUILD_SERVER == SERVER_x11

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

/* From the Motif window manager hints (XGServerWindow.m). */
#define HINTS_FUNCTIONS		(1L << 0)
#define HINTS_DECORATIONS	(1L << 1)
#define FUNC_RESIZE		(1L << 1)
#define FUNC_MOVE		(1L << 2)
#define FUNC_MINIMIZE		(1L << 3)
#define FUNC_MAXIMIZE		(1L << 4)
#define FUNC_CLOSE		(1L << 5)

/* Sets a default for this process only, in the argument domain. */
static void
setDefault(id value, NSString *key)
{
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary	*args;

  args = [[defs volatileDomainForName: NSArgumentDomain] mutableCopy];
  if (args == nil)
    {
      args = [NSMutableDictionary new];
    }
  [args setObject: value forKey: key];
  [defs removeVolatileDomainForName: NSArgumentDomain];
  [defs setVolatileDomain: args forName: NSArgumentDomain];
  [args release];
}

/* The window's Motif hints as "flags functions decorations", or "none".
 * The backend's own connection is flushed first: what it set may still be
 * in its buffer.
 */
static NSString *
motifHints(GSDisplayServer *srv, Display *dpy, int win)
{
  Window	w = (Window)[srv windowDevice: win];
  Atom		type;
  int		format;
  unsigned long	n, after;
  unsigned char	*data = NULL;
  NSString	*s = @"none";

  XSync((Display *)[srv serverDevice], False);
  if (XGetWindowProperty(dpy, w, XInternAtom(dpy, "_MOTIF_WM_HINTS", False),
      0, 5, False, AnyPropertyType, &type, &format, &n, &after, &data)
    == Success && data != NULL)
    {
      unsigned long *v = (unsigned long *)data;

      if (n >= 3)
	{
	  s = [NSString stringWithFormat: @"%lu %lu %lu", v[0], v[1], v[2]];
	}
      XFree(data);
    }
  return s;
}

static NSString *
expected(unsigned long functions)
{
  return [NSString stringWithFormat: @"%lu %lu %lu",
    (unsigned long)(HINTS_FUNCTIONS | HINTS_DECORATIONS), functions, 0UL];
}

int
main(int argc, const char **argv)
{
  START_SET("motif hints")

  extern void	initialize_gnustep_backend(void);
  GSDisplayServer	*srv = nil;
  Display		*dpy;
  int			win;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      SKIP("no window server available")
    }
  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      SKIP("no window server available")
    }

  setDefault(@"NO", @"GSBackHandlesWindowDecorations");
  NS_DURING
    {
      initialize_gnustep_backend();
      srv = [GSDisplayServer serverWithAttributes: nil];
    }
  NS_HANDLER
    {
      NSLog(@"the display server did not start: %@", localException);
      SKIP("It looks like the GNUstep backend is not installed")
    }
  NS_ENDHANDLER
  if (srv == nil || [srv isMemberOfClass: [GSDisplayServer class]])
    {
      SKIP("no concrete display server")
    }
  [GSDisplayServer setCurrentServer: srv];

  PASS([srv handlesWindowDecorations] == NO,
    "with GSBackHandlesWindowDecorations NO the gui draws the decorations");

  win = [srv window: NSMakeRect(100, 100, 400, 300)
		   : NSBackingStoreBuffered
		   : NSTitledWindowMask | NSClosableWindowMask
		     | NSMiniaturizableWindowMask | NSResizableWindowMask
		   : 0];
  PASS_EQUAL(motifHints(srv, dpy, win),
    expected(FUNC_MOVE | FUNC_CLOSE | FUNC_MINIMIZE | FUNC_RESIZE
      | FUNC_MAXIMIZE),
    "a fully styled window asks for no decorations and allows every function");
  [srv termwindow: win];

  win = [srv window: NSMakeRect(100, 100, 400, 300)
		   : NSBackingStoreBuffered
		   : NSTitledWindowMask | NSClosableWindowMask
		   : 0];
  PASS_EQUAL(motifHints(srv, dpy, win),
    expected(FUNC_MOVE | FUNC_CLOSE),
    "a closable window that isn't resizable allows move and close only");
  [srv termwindow: win];

  win = [srv window: NSMakeRect(100, 100, 400, 300)
		   : NSBackingStoreBuffered : NSTitledWindowMask : 0];
  PASS_EQUAL(motifHints(srv, dpy, win),
    expected(FUNC_MOVE),
    "a titled window allows move");
  [srv termwindow: win];

  win = [srv window: NSMakeRect(100, 100, 200, 100)
		   : NSBackingStoreBuffered : NSBorderlessWindowMask : 0];
  PASS_EQUAL(motifHints(srv, dpy, win),
    expected(0),
    "a borderless window asks for no decorations and allows no functions");
  [srv termwindow: win];

  XCloseDisplay(dpy);

  END_SET("motif hints")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("motif hints")
    SKIP("back is not built with the x11 server")
  END_SET("motif hints")
  return 0;
}

#endif
