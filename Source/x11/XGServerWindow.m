/* XGServerWindows - methods for window/screen handling

   Copyright (C) 1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Nov 1999
   
   This file is part of GNUstep

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include "config.h"
#include <math.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <AppKit/DPSOperators.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSWindow.h>

#ifdef HAVE_WRASTER_H
#include "wraster.h"
#else
#include "x11/wraster.h"
#endif
#include <X11/cursorfont.h>

#include "x11/XGDragView.h"
#include "x11/XGInputServer.h"

#define XDPY (((RContext *)context)->dpy)
#define XDRW (((RContext *)context)->drawable)
#define XSCR (((RContext *)context)->screen_number)

#define	ROOT generic.appRootWindow

/*
 * Name for application root window.
 */
static char	*rootName = 0;

#define WINDOW_WITH_TAG(windowNumber) (gswindow_device_t *)NSMapGet(windowtags, (void *)windowNumber) 

/* Current mouse grab window */
static gswindow_device_t *grab_window = NULL;

/* Keep track of windows */
static NSMapTable *windowmaps = NULL;
static NSMapTable *windowtags = NULL;

@interface NSCursor (BackendPrivate)
- (void *)_cid;
@end

void __objc_xgcontextwindow_linking (void)
{
}

/*
 * The next two functions derived from WindowMaker by Alfredo K. Kojima
 */
static unsigned char*
PropGetCheckProperty(Display *dpy, Window window, Atom hint, Atom type,
		     int format, int count, int *retCount)
{
  Atom type_ret;
  int fmt_ret;
  unsigned long nitems_ret;
  unsigned long bytes_after_ret;
  unsigned char *data;
  int tmp;

  if (count <= 0)
    tmp = 0xffffff;
  else
    tmp = count;

  if (XGetWindowProperty(dpy, window, hint, 0, tmp, False, type,
			 &type_ret, &fmt_ret, &nitems_ret, &bytes_after_ret,
			 (unsigned char **)&data)!=Success || !data)
    return NULL;

  if ((type!=AnyPropertyType && type!=type_ret)
    || (count > 0 && nitems_ret != count)
    || (format != 0 && format != fmt_ret))
    {
      XFree(data);
      return NULL;
    }

  if (retCount)
    *retCount = nitems_ret;

  return data;
}

static void
setNormalHints(Display *d, gswindow_device_t *w)
{
  if (w->siz_hints.flags & (USPosition | PPosition))
    NSDebugLLog(@"XGTrace", @"Hint posn %d: %d, %d",
      w->number, w->siz_hints.x, w->siz_hints.y);
  if (w->siz_hints.flags & (USSize | PSize))
    NSDebugLLog(@"XGTrace", @"Hint size %d: %d, %d",
      w->number, w->siz_hints.width, w->siz_hints.height);
  if (w->siz_hints.flags & PMinSize)
    NSDebugLLog(@"XGTrace", @"Hint mins %d: %d, %d",
      w->number, w->siz_hints.min_width, w->siz_hints.min_height);
  if (w->siz_hints.flags & PMaxSize)
    NSDebugLLog(@"XGTrace", @"Hint maxs %d: %d, %d",
      w->number, w->siz_hints.max_width, w->siz_hints.max_height);
  if (w->siz_hints.flags & PResizeInc)
    NSDebugLLog(@"XGTrace", @"Hint incr %d: %d, %d",
      w->number, w->siz_hints.width_inc, w->siz_hints.height_inc);
  XSetNormalHints(d, w->ident, &w->siz_hints);
}

/*
 * Setting Motif Hints for Window Managers (Nicola Pero, July 2000)
 */

/*
 * Motif window hints to communicate to a window manager 
 * that we want a window to have a titlebar/resize button/etc.
 */

/* Motif window hints struct */
typedef struct {
  unsigned long flags;
  unsigned long functions;
  unsigned long decorations;
  long input_mode;
  unsigned long status;
} MwmHints;

/* Number of entries in the struct */
#define PROP_MWM_HINTS_ELEMENTS 5

/* Now for each field in the struct, meaningful stuff to put in: */

/* flags */
#define MWM_HINTS_FUNCTIONS   (1L << 0)
#define MWM_HINTS_DECORATIONS (1L << 1)
#define MWM_HINTS_INPUT_MODE  (1L << 2)
#define MWM_HINTS_STATUS      (1L << 3)

/* functions */
#define MWM_FUNC_ALL          (1L << 0)
#define MWM_FUNC_RESIZE       (1L << 1)
#define MWM_FUNC_MOVE         (1L << 2)
#define MWM_FUNC_MINIMIZE     (1L << 3)
#define MWM_FUNC_MAXIMIZE     (1L << 4)
#define MWM_FUNC_CLOSE        (1L << 5)

/* decorations */
#define MWM_DECOR_ALL         (1L << 0)
#define MWM_DECOR_BORDER      (1L << 1)
#define MWM_DECOR_RESIZEH     (1L << 2)
#define MWM_DECOR_TITLE       (1L << 3)
#define MWM_DECOR_MENU        (1L << 4)
#define MWM_DECOR_MINIMIZE    (1L << 5)
#define MWM_DECOR_MAXIMIZE    (1L << 6)

/* We don't use the input_mode and status fields */

/* The atom */
#define _XA_MOTIF_WM_HINTS "_MOTIF_WM_HINTS"

/* Now the code */

/* Set the style `styleMask' for the XWindow `window' using motif
 * window hints.  This makes an X call, please make sure you do it
 * only once.
 */
static void setWindowHintsForStyle (Display *dpy, Window window, 
				 unsigned int styleMask)
{
  MwmHints *hints;
  BOOL needToFreeHints = YES;
  Atom type_ret;
  int format_ret;
  unsigned long nitems_ret;
  unsigned long bytes_after_ret;
  static Atom mwhints_atom = None;

  /* Initialize the atom if needed */
  if (mwhints_atom == None)
    mwhints_atom = XInternAtom (dpy,_XA_MOTIF_WM_HINTS, False);
  
  /* Get the already-set window hints */
  XGetWindowProperty (dpy, window, mwhints_atom, 0, 
		      sizeof (MwmHints) / sizeof (long),
		      False, AnyPropertyType, &type_ret, &format_ret, 
		      &nitems_ret, &bytes_after_ret, 
		      (unsigned char **)&hints);

  /* If no window hints were set, create new hints to 0 */
  if (type_ret == None)
    {
      needToFreeHints = NO;
      hints = alloca (sizeof (MwmHints));
      memset (hints, 0, sizeof (MwmHints));
    }

  /* Remove the hints we want to change */
  hints->flags &= ~MWM_HINTS_DECORATIONS;
  hints->flags &= ~MWM_HINTS_FUNCTIONS;
  hints->decorations = 0;
  hints->functions = 0;

  /* Now add to the hints from the styleMask */
  if (styleMask == NSBorderlessWindowMask)
    {
      hints->flags |= MWM_HINTS_DECORATIONS;
      hints->flags |= MWM_HINTS_FUNCTIONS;
      hints->decorations = 0;
      hints->functions = 0;
    }
  else
    {
      /* These need to be on all windows except mini and icon windows,
	 where they are specifically set to 0 (see below) */
      hints->flags |= MWM_HINTS_DECORATIONS;
      hints->decorations |= (MWM_DECOR_TITLE | MWM_DECOR_BORDER);
      if (styleMask & NSTitledWindowMask)
	{
	  // Without this, iceWM does not let you move the window!
	  // [idem below]
	  hints->flags |= MWM_HINTS_FUNCTIONS;
	  hints->functions |= MWM_FUNC_MOVE;
	}
      if (styleMask & NSClosableWindowMask)
	{
	  hints->flags |= MWM_HINTS_FUNCTIONS;
	  hints->functions |= MWM_FUNC_CLOSE;
	  hints->functions |= MWM_FUNC_MOVE;
	}
      if (styleMask & NSMiniaturizableWindowMask)
	{
	  hints->flags |= MWM_HINTS_DECORATIONS;
	  hints->flags |= MWM_HINTS_FUNCTIONS;
	  hints->decorations |= MWM_DECOR_MINIMIZE;
	  hints->functions |= MWM_FUNC_MINIMIZE;
	  hints->functions |= MWM_FUNC_MOVE;
	}
      if (styleMask & NSResizableWindowMask)
	{
	  hints->flags |= MWM_HINTS_DECORATIONS;
	  hints->flags |= MWM_HINTS_FUNCTIONS;
	  hints->decorations |= MWM_DECOR_RESIZEH;
	  hints->decorations |= MWM_DECOR_MAXIMIZE;
	  hints->functions |= MWM_FUNC_RESIZE;
	  hints->functions |= MWM_FUNC_MAXIMIZE;
	  hints->functions |= MWM_FUNC_MOVE;
        }
      if (styleMask & NSIconWindowMask)
	{
	  // FIXME
	  hints->flags |= MWM_HINTS_DECORATIONS;
	  hints->flags |= MWM_HINTS_FUNCTIONS;
	  hints->decorations = 0;
	  hints->functions = 0;
	}
      if (styleMask & NSMiniWindowMask)
	{
	  // FIXME
	  hints->flags |= MWM_HINTS_DECORATIONS;
	  hints->flags |= MWM_HINTS_FUNCTIONS;
	  hints->decorations = 0;
	  hints->functions = 0;
	}
    }  
  
  /* Set the hints */
  XChangeProperty (dpy, window, mwhints_atom, mwhints_atom, 32, 
		   PropModeReplace, (unsigned char *)hints, 
		   sizeof (MwmHints) / sizeof (long));
  
  /* Free the hints if allocated by the X server for us */
  if (needToFreeHints == YES)
    XFree (hints);  
}

/*
 * End of motif hints for window manager code
 */

@interface NSEvent (WindowHack)
- (void) _patchLocation: (NSPoint)loc;
@end

@implementation NSEvent (WindowHack)
- (void) _patchLocation: (NSPoint)loc
{
  location_point = loc;
}
@end

@implementation XGServer (DPSWindow)

/*
 * Where a window has been reparented by the wm, we use this method to
 * locate the window given knowledge of its border window.
 */
+ (gswindow_device_t *) _windowForXParent: (Window)xWindow
{
  NSMapEnumerator	enumerator;
  Window		x;
  gswindow_device_t	*d;

  enumerator = NSEnumerateMapTable(windowmaps);
  while (NSNextMapEnumeratorPair(&enumerator, (void**)&x, (void**)&d) == YES)
    {
      if (d->root != d->parent && d->parent == xWindow)
	{
	  return d;
	}
    }
  return 0;
}

+ (gswindow_device_t *) _windowForXWindow: (Window)xWindow
{
  return NSMapGet(windowmaps, (void *)xWindow);
}

+ (gswindow_device_t *) _windowWithTag: (int)windowNumber
{
  return WINDOW_WITH_TAG(windowNumber);
}

/*
 * Convert a window frame in OpenStep absolute screen coordinates to
 * a frame in X absolute screen coordinates by flipping an applying
 * offsets to allow for the X window decorations.
 */
- (NSRect) _OSFrameToXFrame: (NSRect)o for: (void*)window
{
  gswindow_device_t	*win = (gswindow_device_t*)window;
  NSRect	x;
  float	t, b, l, r;

  [self styleoffsets: &l : &r : &t : &b : win->win_attrs.window_style];

  x.size.width = o.size.width - l - r;
  x.size.height = o.size.height - t - b;
  x.origin.x = o.origin.x + l;
  x.origin.y = o.origin.y + o.size.height - t;
  x.origin.y = DisplayHeight(XDPY, win->screen) - x.origin.y;
NSDebugLLog(@"Frame", @"O2X %d, %@, %@", win->number,
  NSStringFromRect(o), NSStringFromRect(x));
  return x;
}

/*
 * Convert a window frame in OpenStep absolute screen coordinates to
 * a frame suitable for setting X hints for a window manager.
 */
- (NSRect) _OSFrameToXHints: (NSRect)o for: (void*)window
{
  gswindow_device_t	*win = (gswindow_device_t*)window;
  NSRect	x;
  float	t, b, l, r;

  [self styleoffsets: &l : &r : &t : &b : win->win_attrs.window_style];

  x.size.width = o.size.width - l - r;
  x.size.height = o.size.height - t - b;
  x.origin.x = o.origin.x;
  x.origin.y = o.origin.y + o.size.height;
  x.origin.y = DisplayHeight(XDPY, win->screen) - x.origin.y;
NSDebugLLog(@"Frame", @"O2H %d, %@, %@", win->number,
  NSStringFromRect(o), NSStringFromRect(x));
  return x;
}

/*
 * Convert a window frame in X absolute screen coordinates to a frame
 * in OpenStep absolute screen coordinates by flipping an applying
 * offsets to allow for the X window decorations.
 */
- (NSRect) _XFrameToOSFrame: (NSRect)x for: (void*)window
{
  gswindow_device_t	*win = (gswindow_device_t*)window;
  NSRect	o;
  float	t, b, l, r;

  [self styleoffsets: &l : &r : &t : &b : win->win_attrs.window_style];
  o.size.width = x.size.width + l + r;
  o.size.height = x.size.height + t + b;
  o.origin.x = x.origin.x - l;
  o.origin.y = DisplayHeight(XDPY, win->screen) - x.origin.y;
  o.origin.y = o.origin.y - o.size.height + t;
NSDebugLLog(@"Frame", @"X2O %d, %@, %@", win->number,
  NSStringFromRect(x), NSStringFromRect(o));
  return o;
}

- (XGWMProtocols) _checkWindowManager
{
  int wmflags;
  Window root;
  Window *win;
  Atom	*data;
  Atom	atom;
  int	count;

  root = DefaultRootWindow(XDPY);
  wmflags = XGWM_UNKNOWN;

  /* Check for WindowMaker */
  atom = XInternAtom(XDPY, "_WINDOWMAKER_WM_PROTOCOLS", False);
  data = (Atom*)PropGetCheckProperty(XDPY, root, atom, XA_ATOM, 32, -1, &count);
  if (data != 0)
    {
      Atom	noticeboard;
      int	i = 0;

      noticeboard = XInternAtom(XDPY, "_WINDOWMAKER_NOTICEBOARD", False);
      while (i < count && data[i] != noticeboard)
	{
	  i++;
	}
      XFree(data);

      if (i < count)
	{
	  Window	*win;
	  void		*d;

	  win = (Window*)PropGetCheckProperty(XDPY, root, 
	    noticeboard, XA_WINDOW, 32, -1, &count);

	  if (win != 0)
	    {
	      d = PropGetCheckProperty(XDPY, *win, noticeboard,
		XA_WINDOW, 32, 1, NULL);
	      if (d != 0)
		{
		  XFree(d);
		  wmflags |= XGWM_WINDOWMAKER;
		}
	    }
	}
      else
	{
	  wmflags |= XGWM_WINDOWMAKER;
	}
    }

  /* Now check for Gnome */
  atom = XInternAtom(XDPY, "_WIN_SUPPORTING_WM_CHECK", False);
  win = (Window*)PropGetCheckProperty(XDPY, root, atom, 
				      XA_CARDINAL, 32, -1, &count);
  if (win != 0)
    {
      Window *win1;

      win1 = (Window*)PropGetCheckProperty(XDPY, *win, atom, 
					   XA_CARDINAL, 32, -1, &count);
      // If the two are not identical, the flag on the root window, was
      // a left over from an old window manager.
      if (*win1 == *win)
        {
	  wmflags |= XGWM_GNOME;

	  generic.wintypes.win_type_atom = 
	      XInternAtom(XDPY, "_WIN_LAYER", False);
	}
    }

  /* Now check for NET (EWMH) compliant window manager */
  atom = XInternAtom(XDPY, "_NET_SUPPORTING_WM_CHECK", False);
  win = (Window*)PropGetCheckProperty(XDPY, root, atom, 
				      XA_WINDOW, 32, -1, &count);

  if (win != 0)
    {
      Window *win1;

      win1 = (Window*)PropGetCheckProperty(XDPY, *win, atom, 
					   XA_WINDOW, 32, -1, &count);
      // If the two are not identical, the flag on the root window, was
      // a left over from an old window manager.
      if (*win1 == *win)
        {
	  wmflags |= XGWM_EWMH;

	  // Store window type Atoms for this WM
	  generic.wintypes.win_type_atom = 
	      XInternAtom(XDPY, "_NET_WM_WINDOW_TYPE", False);
	  generic.wintypes.win_desktop_atom = 
	      XInternAtom(XDPY, "_NET_WM_WINDOW_TYPE_DESKTOP", False);
	  generic.wintypes.win_dock_atom = 
	      XInternAtom(XDPY, "_NET_WM_WINDOW_TYPE_DOCK", False);
	  generic.wintypes.win_floating_atom = 
	      XInternAtom(XDPY, "_NET_WM_WINDOW_TYPE_TOOLBAR", False);
	  generic.wintypes.win_menu_atom = 
	      XInternAtom(XDPY, "_NET_WM_WINDOW_TYPE_MENU", False);
	  generic.wintypes.win_modal_atom = 
	      XInternAtom(XDPY, "_NET_WM_WINDOW_TYPE_DIALOG", False);
	  generic.wintypes.win_normal_atom = 
	      XInternAtom(XDPY, "_NET_WM_WINDOW_TYPE_NORMAL", False);
	}
    }

  NSDebugLLog(@"WM", 
	      @"WM Protocols: WindowMaker=(%s) GNOME=(%s) KDE=(%s) EWMH=(%s)",
	      (wmflags & XGWM_WINDOWMAKER) ? "YES" : "NO",
	      (wmflags & XGWM_GNOME) ? "YES" : "NO",
	      (wmflags & XGWM_KDE) ? "YES" : "NO",
	      (wmflags & XGWM_EWMH) ? "YES" : "NO");

  return wmflags;
}

- (gswindow_device_t *)_rootWindowForScreen: (int)screen
{
  int x, y, width, height;
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(screen);
  if (window)
    return window;

  window = objc_malloc(sizeof(gswindow_device_t));
  memset(window, '\0', sizeof(gswindow_device_t));

  window->display = XDPY;
  window->screen = screen;
  window->ident  = RootWindow(XDPY, screen);
  window->root   = window->ident;
  window->type   = NSBackingStoreNonretained;
  window->number = screen;
  window->map_state = IsViewable;
  window->visibility = -1;
  if (window->ident)
    XGetGeometry(XDPY, window->ident, &window->root, 
		 &x, &y, &width, &height,
		 &window->border, &window->depth);

  window->xframe = NSMakeRect(x, y, width, height);
  NSMapInsert (windowtags, (void*)window->number, window);
  NSMapInsert (windowmaps, (void*)window->ident,  window);
  return window;
}

/* Create the window and screen list if necessary, add the root window to
   the window list as window 0 */
- (void) _checkWindowlist
{
  if (windowmaps)
    return;

  windowmaps = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
				 NSNonOwnedPointerMapValueCallBacks, 20);
  windowtags = NSCreateMapTable(NSIntMapKeyCallBacks,
				 NSNonOwnedPointerMapValueCallBacks, 20);
}

- (void) _setupMouse
{
  int			numButtons;
  unsigned char		mouseNumbers[5];
  unsigned char		buttons[5] = {
			  Button1,
			  Button2,
			  Button3,
			  Button4,
			  Button5
			};
  int			masks[5] = {
			  Button1Mask,
			  Button2Mask,
			  Button3Mask,
			  Button4Mask,
			  Button5Mask
			};
  /*
   * Get pointer information - so we know which mouse buttons we have.
   * With a two button
   */
  numButtons = XGetPointerMapping(XDPY, mouseNumbers, 5);
  if (numButtons > 5)
    {
      NSLog(@"Warning - mouse/pointer seems to have more than 5 buttons"
	@" - just using one to five");
      numButtons = 5;
    }
  generic.lMouse = buttons[0];
  generic.lMouseMask = masks[0];
  if (numButtons >= 5)
    {
      generic.upMouse = buttons[3];
      generic.downMouse = buttons[4];
      generic.rMouse = buttons[2];
      generic.rMouseMask = masks[2];
      generic.mMouse = buttons[1];
      generic.mMouseMask = masks[1];
    }
  else if (numButtons == 3)
    {
// FIXME: Button4 and Button5 are ScrollWheel up and ScrollWheel down 
//      generic.rMouse = buttons[numButtons-1];
//      generic.rMouseMask = masks[numButtons-1];
      generic.upMouse = 0;
      generic.downMouse = 0;
      generic.rMouse = buttons[2];
      generic.rMouseMask = masks[2];
      generic.mMouse = buttons[1];
      generic.mMouseMask = masks[1];
    }
  else if (numButtons == 2)
    {
      generic.upMouse = 0;
      generic.downMouse = 0;
      generic.rMouse = buttons[1];
      generic.rMouseMask = masks[1];
      generic.mMouse = 0;
      generic.mMouseMask = 0;
    }
  else if (numButtons == 1)
    {
      generic.upMouse = 0;
      generic.downMouse = 0;
      generic.rMouse = 0;
      generic.rMouseMask = 0;
      generic.mMouse = 0;
      generic.mMouseMask = 0;
    }
  else
    {
      NSLog(@"Warning - mouse/pointer seems to have NO buttons");
    }
}

- (void) _setupRootWindow
{
  NSProcessInfo		*pInfo = [NSProcessInfo processInfo];
  NSArray		*args;
  unsigned		i;
  int			argc;
  char			**argv;
  XClassHint		classhint; 
  XTextProperty		windowName;
  NSUserDefaults	*defs;
  const char *host_name = [[pInfo hostName] cString];

  /*
   * Initialize time of last events to be the start of time - not
   * the current time!
   */
  if (CurrentTime == 0)
    {
      generic.lastClick = 1;
      generic.lastMotion = 1;
      generic.lastTime = 1;
    }

  /*
   * Set up standard atoms.
   */
  generic.protocols_atom = XInternAtom(XDPY, "WM_PROTOCOLS", False);
  generic.take_focus_atom = XInternAtom(XDPY, "WM_TAKE_FOCUS", False);
  generic.delete_win_atom = XInternAtom(XDPY, "WM_DELETE_WINDOW", False);
  generic.miniaturize_atom
    = XInternAtom(XDPY, "_GNUSTEP_WM_MINIATURIZE_WINDOW", False);
  generic.win_decor_atom = XInternAtom(XDPY,"_GNUSTEP_WM_ATTR", False);
  generic.titlebar_state_atom
    = XInternAtom(XDPY, "_GNUSTEP_TITLEBAR_STATE", False);

  [self _setupMouse];
  [self _checkWindowlist];

  /*
   * determine window manager in use.
   */
  generic.wm = [self _checkWindowManager];

  /*
   * Now check user defaults.
   */
  defs = [NSUserDefaults standardUserDefaults];
  generic.flags.useWindowMakerIcons = NO;
  if ((generic.wm & XGWM_WINDOWMAKER) != 0)
    {
      generic.flags.useWindowMakerIcons = YES;
      if ([defs stringForKey: @"UseWindowMakerIcons"] != nil
	&& [defs boolForKey: @"UseWindowMakerIcons"] == NO)
	{
	  generic.flags.useWindowMakerIcons = NO;
	}
    }
  generic.flags.appOwnsMiniwindow = YES;
  if ([defs stringForKey: @"GSAppOwnsMiniwindow"] != nil
    && [defs boolForKey: @"GSAppOwnsMiniwindow"] == NO)
    {
      generic.flags.appOwnsMiniwindow = NO;
    }
  generic.flags.doubleParentWindow = NO;
  if ([defs stringForKey: @"GSDoubleParentWindows"] != nil
    && [defs boolForKey: @"GSDoubleParentWindows"] == YES)
    {
      generic.flags.doubleParentWindow = YES;
    }


  /*
   * make app root window
   */
  ROOT = XCreateSimpleWindow(XDPY,RootWindow(XDPY,XSCR),0,0,1,1,0,0,0);

  /*
   * set hints for root window
   */
  {
    XWMHints		gen_hints;

    gen_hints.flags = WindowGroupHint | StateHint;
    gen_hints.initial_state = WithdrawnState;
    gen_hints.window_group = ROOT;
    XSetWMHints(XDPY, ROOT, &gen_hints);
  }

  /*
   * Mark this as a GNUstep app with the current application name.
   */
  if (rootName == 0)
    {
      NSString *str;
      str = [pInfo processName];
      i = [str cStringLength];
      rootName = objc_malloc(i+1);
      [str getCString: rootName];
    }
  classhint.res_name = rootName;
  classhint.res_class = "GNUstep";
  XSetClassHint(XDPY, ROOT, &classhint);

  /*
   * Set app name as root window title - probably unused unless
   * the window manager wants to keep us in a menu or something like that.
   */
  XStringListToTextProperty((char**)&classhint.res_name, 1, &windowName);
  XSetWMName(XDPY, ROOT, &windowName);
  XSetWMIconName(XDPY, ROOT, &windowName);

  /*
   * Record the information used to start this app.
   * If we have a user default set up (eg. by the openapp script) use it.
   * otherwise use the process arguments.
   */
  args = [defs arrayForKey: @"GSLaunchCommand"];
  if (args == nil)
    {
      args = [pInfo arguments];
    }
  argc = [args count];
  argv = (char**)objc_malloc(argc*sizeof(char*));
  for (i = 0; i < argc; i++)
    {
      argv[i] = (char*)[[args objectAtIndex: i] cString];
    }
  XSetCommand(XDPY, ROOT, argv, argc);
  objc_free(argv);

  // Store the host name of the machine we a running on
  XStringListToTextProperty((char**)&host_name, 1, &windowName);
  XSetWMClientMachine(XDPY, ROOT, &windowName);

  if ((generic.wm & XGWM_WINDOWMAKER) != 0)
    {
      GNUstepWMAttributes	win_attrs;

      /*
       * Tell WindowMaker not to set up an app icon for us - we'll make our own.
       */
      win_attrs.flags = GSExtraFlagsAttr;
      win_attrs.extra_flags = GSNoApplicationIconFlag;
      XChangeProperty(XDPY, ROOT,
	generic.win_decor_atom, generic.win_decor_atom,
	32, PropModeReplace, (unsigned char *)&win_attrs,
	sizeof(GNUstepWMAttributes)/sizeof(CARD32));
    }

  if ((generic.wm & XGWM_EWMH) != 0)
    {
      // Store the id of our process
      Atom pid_atom = XInternAtom(XDPY, "_NET_WM_PID", False);
      int pid = [pInfo processIdentifier];

      XChangeProperty(XDPY, ROOT,
		      pid_atom, XA_CARDINAL,
		      32, PropModeReplace, 
		      (unsigned char*)&pid, 1);

      // We should store the GNUStepMenuImage in the root window
      // and use that as our title bar icon
      //  pid_atom = XInternAtom(XDPY, "_NET_WM_ICON", False);
    }
}

/* Destroys all the windows and other window resources that belong to
   this context */
- (void) _destroyServerWindows
{
  int num;
  gswindow_device_t *d;
  NSMapEnumerator   enumerator;
  NSMapTable        *mapcopy;

  /* Have to get a copy, since termwindow will remove them from
     the map table */
  mapcopy = NSCopyMapTableWithZone(windowtags, [self zone]);
  enumerator = NSEnumerateMapTable(mapcopy);
  while (NSNextMapEnumeratorPair(&enumerator, (void**)&num, (void**)&d) == YES)
    {
      if (d->display == XDPY && d->ident != d->root)
	[self termwindow: num];
    }
  NSFreeMapTable(mapcopy);
}

/* Sets up a backing pixmap when a window is created or resized.  This is
   only done if the Window is buffered or retained. */
- (void) _createBuffer: (gswindow_device_t *)window
{
  if (window->type == NSBackingStoreNonretained)
    return;

  if (window->depth == 0)
    window->depth = DefaultDepth(XDPY, XSCR);
  if (NSWidth(window->xframe) == 0 && NSHeight(window->xframe) == 0)
    {
      NSDebugLLog(@"NSWindow", @"Cannot create buffer for ZeroRect frame");
      return;
    }

  window->buffer = XCreatePixmap(XDPY, window->root,
				 NSWidth(window->xframe),
				 NSHeight(window->xframe),
				 window->depth);

  if (!window->buffer)
    {
      NSLog(@"DPS Windows: Unable to create backing store\n");
      return;
    }

  XFillRectangle(XDPY,
		 window->buffer,
		 window->gc,
		 0, 0, 
		 NSWidth(window->xframe),
		 NSHeight(window->xframe));

  /* Set background pixmap to avoid redundant fills */
  XSetWindowBackgroundPixmap(XDPY, window->ident, window->buffer);
}

- (int) window: (NSRect)frame : (NSBackingStoreType)type : (unsigned int)style
{
  static int		last_win_num = 0;
  gswindow_device_t	*window;
  gswindow_device_t	*root;
  XGCValues		values;
  unsigned long		valuemask;
  XClassHint		classhint;

  NSDebugLLog(@"XGTrace", @"DPSwindow: %@ %d", NSStringFromRect(frame), type);
  root = [self _rootWindowForScreen: XSCR];

  /* We're not allowed to create a zero rect window */
  if (NSWidth(frame) <= 0 || NSHeight(frame) <= 0)
    {
      frame.size.width = 2;
      frame.size.height = 2;
    }
  /* Translate to X coordinates */
  frame.origin.y = DisplayHeight(XDPY, XSCR) - NSMaxY(frame);

  window = objc_malloc(sizeof(gswindow_device_t));
  memset(window, '\0', sizeof(gswindow_device_t));
  window->display = XDPY;
  window->screen = XSCR;
  window->xframe = frame;
  window->type = type;
  window->root = root->ident;
  window->parent = root->ident;
  window->depth = ((RContext *)context)->depth;
  window->xwn_attrs.border_pixel = ((RContext *)context)->black;
  window->xwn_attrs.background_pixel = ((RContext *)context)->white;
  window->xwn_attrs.colormap = ((RContext *)context)->cmap;

  window->ident = XCreateWindow(XDPY, window->root,
				NSMinX(frame), NSMinY(frame), 
				NSWidth(frame), NSHeight(frame),
				0, 
				((RContext *)context)->depth,
				CopyFromParent,
				((RContext *)context)->visual,
				(CWColormap | CWBackPixel|CWBorderPixel),
				&window->xwn_attrs);

  /*
   * Mark this as a GNUstep app with the current application name.
   */
  classhint.res_name = rootName;
  classhint.res_class = "GNUstep";
  XSetClassHint(XDPY, window->ident, &classhint);

  window->xwn_attrs.save_under = False;
  window->xwn_attrs.override_redirect = False;
  window->map_state = IsUnmapped;
  window->visibility = -1;

  // Create an X GC for the content view set it's colors
  values.foreground = window->xwn_attrs.background_pixel;
  values.background = window->xwn_attrs.background_pixel;
  values.function = GXcopy;
  valuemask = (GCForeground | GCBackground | GCFunction);
  window->gc = XCreateGC(XDPY, window->ident, valuemask, &values);

  // Set the X event mask
  XSelectInput(XDPY, window->ident, ExposureMask | KeyPressMask |
				KeyReleaseMask | ButtonPressMask |
			     ButtonReleaseMask | ButtonMotionMask |
			   StructureNotifyMask | PointerMotionMask |
			       EnterWindowMask | LeaveWindowMask |
			       FocusChangeMask | PropertyChangeMask |
			    ColormapChangeMask | KeymapStateMask |
			    VisibilityChangeMask);

  /*
   * Initial attributes for any GNUstep window tell Window Maker not to
   * create an app icon for us.
   */
  window->win_attrs.flags = GSExtraFlagsAttr;
  window->win_attrs.extra_flags = GSNoApplicationIconFlag;

  /*
   * Prepare size/position hints, but don't set them now - ordering
   * the window in should automatically do it.
   */
  window->win_attrs.flags |= GSWindowStyleAttr;
  window->win_attrs.window_style = style;
  frame = [self _XFrameToOSFrame: window->xframe for: window];
  frame = [self _OSFrameToXHints: frame for: window];
  window->siz_hints.x = NSMinX(frame);
  window->siz_hints.y = NSMinY(frame);
  window->siz_hints.width = NSWidth(frame);
  window->siz_hints.height = NSHeight(frame);
  window->siz_hints.flags = USPosition|PPosition|USSize|PSize;

  // send to the WM window style hints
  if ((generic.wm & XGWM_WINDOWMAKER) != 0)
    {
      XChangeProperty(XDPY, window->ident, generic.win_decor_atom, 
		      generic.win_decor_atom, 32, PropModeReplace, 
		      (unsigned char *)&window->win_attrs,
		      sizeof(GNUstepWMAttributes)/sizeof(CARD32));
    }
  else
    {
      setWindowHintsForStyle (XDPY, window->ident, style);
    }

  // Use the globally active input mode
  window->gen_hints.flags = InputHint;
  window->gen_hints.input = False;
  // All the windows of a GNUstep application belong to one group.
  window->gen_hints.flags |= WindowGroupHint;
  window->gen_hints.window_group = ROOT;

  /*
   * Prepare the protocols supported by the window.
   * These protocols should be set on the window when it is ordered in.
   */
  window->numProtocols = 0;
  window->protocols[window->numProtocols++] = generic.take_focus_atom;
  window->protocols[window->numProtocols++] = generic.delete_win_atom;
  if ((generic.wm & XGWM_WINDOWMAKER) != 0)
    {
      window->protocols[window->numProtocols++] = generic.miniaturize_atom;
    }
  // FIXME Add ping protocol for EWMH 
  XSetWMProtocols(XDPY, window->ident, window->protocols, window->numProtocols);

  window->exposedRects = [NSMutableArray new];
  window->region = XCreateRegion();
  window->buffer = 0;
  window->alpha_buffer = 0;
  window->ic = 0;

  // make sure that new window has the correct cursor
  [self _initializeCursorForXWindow: window->ident];

  /*
   * FIXME - should this be protected by a lock for thread safety?
   * generate a unique tag for this new window.
   */
  do
    {
      last_win_num++;
    }
  while (last_win_num == 0 || WINDOW_WITH_TAG(last_win_num) != 0);
  window->number = last_win_num;

  // Insert window into the mapping
  NSMapInsert(windowmaps, (void*)window->ident, window);
  NSMapInsert(windowtags, (void*)window->number, window);
  [self _setWindowOwnedByServer: window->number];
  return window->number;
}

- (void) termwindow: (int)win
{
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return;

  if (window->root == window->ident)
    {
      NSLog(@"DPStermwindow: Trying to destroy root window");
      return;
    }

  NSDebugLLog(@"XGTrace", @"DPStermwindow: %d", win);
  if (window->ic)
    {
      [inputServer ximCloseIC: window->ic];
    }
  if (window->ident)
    {
      XDestroyWindow(XDPY, window->ident);
      if (window->gc)
	XFreeGC (XDPY, window->gc);
      NSMapRemove(windowmaps, (void*)window->ident);
    }

  if (window->buffer)
    XFreePixmap (XDPY, window->buffer);
  if (window->alpha_buffer)
    XFreePixmap (XDPY, window->alpha_buffer);
  if (window->region)
    XDestroyRegion (window->region);
  RELEASE(window->exposedRects);
  NSMapRemove(windowtags, (void*)win);
  objc_free(window);
}

/*
 * Return the offsets between the window content-view and it's frame
 * depending on the window style.
 */
- (void) styleoffsets: (float *) l : (float *) r : (float *) t : (float *) b : (int) style
{
  /* First try to get the offset information that we have obtained from
     the WM. This will only work if the application has already created
     a window that has been reparented by the WM. Otherwise we have to
     guess.
  */
  if (generic.parent_offset.x || generic.parent_offset.y)
    {
      if (style == NSBorderlessWindowMask
	  || (style & NSIconWindowMask) || (style & NSMiniWindowMask))
	{
	  *l = *r = *t = *b = 0.0;
	}
      else
	{
	  *l = *r = *t = *b = generic.parent_offset.x;
	  if (NSResizableWindowMask & style)
	    {
	      /* We just have to guess this. Usually it doesn't matter */
	      if ((generic.wm & XGWM_WINDOWMAKER) != 0)
		*b = 9;
	      else if ((generic.wm & XGWM_EWMH) != 0)
		*b = 7;
	    }
	  if ((style & NSTitledWindowMask) || (style & NSClosableWindowMask)
	      || (style & NSMiniaturizableWindowMask))
	    {
	      *t = generic.parent_offset.y;
	      }
	}
    }
  else if ((generic.wm & XGWM_WINDOWMAKER) != 0)
    {
      if (style == NSBorderlessWindowMask
	  || (style & NSIconWindowMask) || (style & NSMiniWindowMask))
	{
	  *l = *r = *t = *b = 0.0;
	}
      else
	{
	  *l = *r = *t = *b = 0;
	  if (NSResizableWindowMask & style)
	    {
	      *b = 9;
	    }
	  if ((style & NSTitledWindowMask) || (style & NSClosableWindowMask)
	      || (style & NSMiniaturizableWindowMask))
	    {
	      *t = 22;
	      }
	}
    }
  else if ((generic.wm & XGWM_EWMH) != 0)
    {
      if (style == NSBorderlessWindowMask
	  || (style & NSIconWindowMask) || (style & NSMiniWindowMask))
	{
	  *l = *r = *t = *b = 0.0;
	}
      else
	{
	  *l = *r = *t = *b = 4;
	  if (NSResizableWindowMask & style)
	    {
	      *b = 7;
	    }
	  if ((style & NSTitledWindowMask) || (style & NSClosableWindowMask)
	      || (style & NSMiniaturizableWindowMask))
	    {
	      *t = 20;
	      }
	}
    }
  else
    {
      /* No known WM protocols */
      /*
       * FIXME
       * This should make a good guess - at the moment use no offsets.
       */
      *l = *r = *t = *b = 0.0;
    }
}

- (void) stylewindow: (int)style : (int) win
{
  gswindow_device_t	*window;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return;

  NSDebugLLog(@"XGTrace", @"DPSstylewindow: %d : %d", style, win);
  if (window->win_attrs.window_style != style
    || (window->win_attrs.flags & GSWindowStyleAttr) == 0)
    {
      NSRect h;
      window->win_attrs.flags |= GSWindowStyleAttr;
      window->win_attrs.window_style = style;

      /* Fix up hints */
      h = [self _XFrameToOSFrame: window->xframe for: window];
      h = [self _OSFrameToXHints: h for: window];
      window->siz_hints.x = NSMinX(h);
      window->siz_hints.y = NSMinY(h);
      window->siz_hints.width = NSWidth(h);
      window->siz_hints.height = NSHeight(h);

      // send to the WM window style hints
      if ((generic.wm & XGWM_WINDOWMAKER) != 0)
	{
	  XChangeProperty(XDPY, window->ident, generic.win_decor_atom, 
			  generic.win_decor_atom, 32, PropModeReplace, 
			  (unsigned char *)&window->win_attrs,
			  sizeof(GNUstepWMAttributes)/sizeof(CARD32));
	}
      else
	{
	  setWindowHintsForStyle (XDPY, window->ident, style);
	}
    }
}

- (void) windowbacking: (NSBackingStoreType)type
{
  [self subclassResponsibility: _cmd];
}

- (void) titlewindow: (NSString *)window_title : (int) win
{
  XTextProperty windowName;
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return;

  NSDebugLLog(@"XGTrace", @"DPStitlewindow: %@ : %d", window_title, win);
  if (window_title && window->ident)
    {
      const char *title = [window_title lossyCString];
      XStringListToTextProperty((char**)&title, 1, &windowName);
      XSetWMName(XDPY, window->ident, &windowName);
      XSetWMIconName(XDPY, window->ident, &windowName);
    }
}

- (void) docedited: (int)edited : (int) win
{
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return;

  NSDebugLLog(@"XGTrace", @"DPSdocedited: %d : %d", edited, win);
  window->win_attrs.flags |= GSExtraFlagsAttr;
  if (edited)
    {
      window->win_attrs.extra_flags |= GSDocumentEditedFlag;
    }
  else
    {
      window->win_attrs.extra_flags &= ~GSDocumentEditedFlag;
    }
  // send WindowMaker WM window style hints
  if ((generic.wm & XGWM_WINDOWMAKER) != 0)
    {
      XChangeProperty(XDPY, window->ident,
	generic.win_decor_atom, generic.win_decor_atom,
	32, PropModeReplace, (unsigned char *)&window->win_attrs,
	sizeof(GNUstepWMAttributes)/sizeof(CARD32));
    }
}

- (BOOL) appOwnsMiniwindow
{
  return generic.flags.appOwnsMiniwindow;
}

- (void) miniwindow: (int) win
{
  gswindow_device_t	*window;

  window = WINDOW_WITH_TAG(win);
  if (window == 0 || (window->win_attrs.window_style & NSIconWindowMask) != 0)
    {
      return;
    }
  NSDebugLLog(@"XGTrace", @"DPSminiwindow: %d ", win);
  /*
   * If we haven't already done so - set the icon window hint for this
   * window so that the GNUstep miniwindow is displayed (if supported).
   */
  if (generic.flags.appOwnsMiniwindow
      && (window->gen_hints.flags & IconWindowHint) == 0)
    {
      NSWindow		*nswin;

      nswin = GSWindowWithNumber(window->number);
      if (nswin != nil)
	{
	  int			iNum = [[nswin counterpart] windowNumber];
	  gswindow_device_t	*iconw = WINDOW_WITH_TAG(iNum);

	  if (iconw != 0)
	    {
	      window->gen_hints.flags |= IconWindowHint;
	      window->gen_hints.icon_window = iconw->ident;
	      XSetWMHints(XDPY, window->ident, &window->gen_hints);
	    }
	}
    }
  XIconifyWindow(XDPY, window->ident, XSCR);
}

/**
   Make sure we have the most up-to-date window information and then
   make sure the current context has our new information
*/
- (void) windowdevice: (int)win
{
  int      x, y;
  unsigned width, height;
  unsigned old_width;
  unsigned old_height;
  XWindowAttributes winattr;
  gswindow_device_t *window;
  NSGraphicsContext *ctxt;

  NSDebugLLog(@"XGTrace", @"DPSwindowdevice: %d ", win);
  window = WINDOW_WITH_TAG(win);
  if (!window)
    {
      NSLog(@"Invalidparam: Invalid window number %d", win);
      return;
    }

  if (!window->ident)
    return;

  old_width = NSWidth(window->xframe);
  old_height = NSHeight(window->xframe);

  XFlush (XDPY);

  /* hack:
   * wait until a resize of window is finished (especially for NSMenu)
   * is there any way to wait until X finished it's stuff?
   * XSync(), XFlush() doesn't do the job!
   */
  { 
    int	i = 0;
    do
      {
	XGetGeometry(XDPY, window->ident, &window->root,
		     &x, &y, &width, &height,
		     &window->border, &window->depth);
      }
    while( i++<10 && height != window->siz_hints.height );
  }
  window->xframe.size.width = width;
  window->xframe.size.height = height;

  XGetWindowAttributes(XDPY, window->ident, &winattr);
  window->map_state = winattr.map_state;
  
  NSDebugLLog (@"NSWindow", @"window geom device ((%f, %f), (%f, %f))",
	        window->xframe.origin.x,  window->xframe.origin.y, 
	        window->xframe.size.width,  window->xframe.size.height);
  
  if (window->buffer && (old_width != width || old_height != height))
    {
      [isa waitAllContexts];
      XFreePixmap(XDPY, window->buffer);
      window->buffer = 0;
      if (window->alpha_buffer)
	XFreePixmap(XDPY, window->alpha_buffer);
      window->alpha_buffer = 0;
    }

  if (window->buffer == 0)
    {
      [self _createBuffer: window];
    }

  ctxt = GSCurrentContext();
  [ctxt contextDevice: window->number];
  DPSsetgcdrawable(ctxt, window->gc, 
		   (window->buffer) 
		   ? (void *)window->buffer : (void *)window->ident,
		   0, NSHeight(window->xframe));
  DPSinitmatrix(ctxt);
  DPSinitclip(ctxt);
}

- (void) orderwindow: (int)op : (int)otherWin : (int)winNum
{
  gswindow_device_t	*window;
  gswindow_device_t	*other;
  int		level;

  window = WINDOW_WITH_TAG(winNum);
  if (winNum == 0 || window == NULL)
    {
      NSLog(@"Invalidparam: Ordering invalid window %d", winNum);
      return;
    }

  if (op != NSWindowOut)
    {
      /*
       * Some window managers ignore any hints and properties until the
       * window is actually mapped, so we need to set them all up
       * immediately bofore mapping the window ...
       */

      setNormalHints(XDPY, window);
      XSetWMHints(XDPY, window->ident, &window->gen_hints);

      /*
       * If we are asked to set hints for the appicon and Window Maker is
       * to control it, we must let Window maker know that this window is
       * the icon window for the app root window.
       */
      if ((window->win_attrs.window_style & NSIconWindowMask) != 0
	&& generic.flags.useWindowMakerIcons == 1)
	{
	  XWMHints		gen_hints;

	  gen_hints.flags = WindowGroupHint | StateHint | IconWindowHint;
	  gen_hints.initial_state = WithdrawnState;
	  gen_hints.window_group = ROOT;
	  gen_hints.icon_window = window->ident;
	  XSetWMHints(XDPY, ROOT, &gen_hints);
	}

      /*
       * Tell the window manager what protocols this window conforms to.
       */
      XSetWMProtocols(XDPY, window->ident, window->protocols,
	window->numProtocols);
    }

  if (generic.flags.useWindowMakerIcons == 1)
    {
      /*
       * Icon windows are mapped/unmapped by the window manager - so we
       * mustn't do anything with them here - though we can raise the
       * application root window to let Window Maker know it should use
       * our appicon window.
       */
      if ((window->win_attrs.window_style & NSIconWindowMask) != 0)
	{
	  if (op != NSWindowOut)
	    {
	      XMapRaised(XDPY, ROOT);
	    }
	  return;
	}
      if ((window->win_attrs.window_style & NSMiniWindowMask) != 0)
	{
	  return;
	}
    }

  NSDebugLLog(@"XGTrace", @"DPSorderwindow: %d : %d : %d",op,otherWin,winNum);
  level = window->win_attrs.window_level;
  if (otherWin != 0)
    {
      other = WINDOW_WITH_TAG(otherWin);
      level = other->win_attrs.window_level;
    }
  else
    {
      other = NULL;
    }
  [self setwindowlevel: level : winNum];

  /*
   * When we are ordering a window in, we must ensure that the position
   * and size hints are set for the window - the window could have been
   * moved or resized by the window manager before it was ordered out,
   * in which case, we will have been notified of the new position, but
   * will not yet have updated the window hints, so if the window manager
   * looks at the existing hints when re-mapping the window it will
   * place the window in an old location.
   * We also set other hints and protocols supported by the window.
   */
  if (op != NSWindowOut && window->map_state != IsViewable)
    {
      XMoveWindow(XDPY, window->ident, window->siz_hints.x,
	window->siz_hints.y);
      setNormalHints(XDPY, window);
    }

  switch (op)
    {
      case NSWindowBelow:
        if (other != 0)
	  {
	    XWindowChanges chg;
	    chg.sibling = other->ident;
	    chg.stack_mode = Below;
	    XReconfigureWMWindow(XDPY, window->ident, window->screen,
	      CWSibling|CWStackMode, &chg);
	  }
	else
	  {
	    XWindowChanges chg;
	    chg.stack_mode = Below;
	    XReconfigureWMWindow(XDPY, window->ident, window->screen,
	      CWStackMode, &chg);
	  }
	XMapWindow(XDPY, window->ident);
	break;

      case NSWindowAbove:
        if (other != 0)
	  {
	    XWindowChanges chg;
	    chg.sibling = other->ident;
	    chg.stack_mode = Above;
	    XReconfigureWMWindow(XDPY, window->ident, window->screen,
	      CWSibling|CWStackMode, &chg);
	  }
	else
	  {
	    XWindowChanges chg;
	    chg.stack_mode = Above;
	    XReconfigureWMWindow(XDPY, window->ident, window->screen,
	      CWStackMode, &chg);
	  }
	XMapWindow(XDPY, window->ident);
	break;

      case NSWindowOut:
	XUnmapWindow(XDPY, window->ident);
	break;
    }
  /*
   * When we are ordering a window in, we must ensure that the position
   * and size hints are set for the window - the window could have been
   * moved or resized by the window manager before it was ordered out,
   * in which case, we will have been notified of the new position, but
   * will not yet have updated the window hints, so if the window manager
   * looks at the existing hints when re-mapping the window it will
   * place the window in an old location.
   */
  if (op != NSWindowOut && window->map_state != IsViewable)
    {
      XMoveWindow(XDPY, window->ident, window->siz_hints.x,
	window->siz_hints.y);
      setNormalHints(XDPY, window);
      /*
       * Do we need to setup drag types when the window is mapped or will
       * they work on the set up before mapping?
       *
       * [self _resetDragTypesForWindow: GSWindowWithNumber(window->number)];
       */
    }
  XFlush(XDPY);
}

- (void) movewindow: (NSPoint)loc : (int)win
{
}

- (void) placewindow: (NSRect)rect : (int)win
{
  NSAutoreleasePool	*arp;
  NSRect		xVal;
  NSRect		last;
  NSEvent		*event;
  NSDate		*limit;
  NSMutableArray	*tmpQueue;
  unsigned		pos;
  float			xdiff;
  float			ydiff;
  gswindow_device_t	*window;
  NSWindow              *nswin;
  NSRect		frame;
  BOOL			resize = NO;
  BOOL			move = NO;

  window = WINDOW_WITH_TAG(win);
  if (win == 0 || window == NULL)
    {
      NSLog(@"Invalidparam: Placing invalid window %d", win);
      return;
    }

  NSDebugLLog(@"XGTrace", @"DPSplacewindow: %@ : %d", NSStringFromRect(rect), 
	      win);
  nswin  = GSWindowWithNumber(win);
  frame = [nswin frame];
  if (NSEqualRects(rect, frame) == YES)
    return;
  if (NSEqualSizes(rect.size, frame.size) == NO)
    {
      resize = YES;
      move = YES;
    }
  if (NSEqualPoints(rect.origin, frame.origin) == NO)
    {
      move = YES;
    }
  xdiff = rect.origin.x - frame.origin.x;
  ydiff = rect.origin.y - frame.origin.y;

  xVal = [self _OSFrameToXHints: rect for: window];
  window->siz_hints.width = (int)xVal.size.width;
  window->siz_hints.height = (int)xVal.size.height;
  window->siz_hints.x = (int)xVal.origin.x;
  window->siz_hints.y = (int)xVal.origin.y;
  xVal = [self _OSFrameToXFrame: rect for: window];

  last = window->xframe;

  NSDebugLLog(@"Moving", @"Place %d - o:%@, x:%@", window->number,
    NSStringFromRect(rect), NSStringFromRect(xVal));
  
  XMoveResizeWindow (XDPY, window->ident,
    window->siz_hints.x, window->siz_hints.y,
    window->siz_hints.width, window->siz_hints.height);
  setNormalHints(XDPY, window);

  /*
   * Now massage all the events currently in the queue to make sure
   * mouse locations in our window are adjusted as necessary.
   */
  arp = [NSAutoreleasePool new];
  limit = [NSDate distantPast];	/* Don't wait for new events.	*/
  tmpQueue = [NSMutableArray arrayWithCapacity: 8];
  for (;;)
    {
      NSEventType	type;

      event = DPSGetEvent(self, NSAnyEventMask, limit,
	NSEventTrackingRunLoopMode);
      if (event == nil)
	break;
      type = [event type];
      if (type == NSAppKitDefined && [event windowNumber] == win)
	{
	  GSAppKitSubtype	sub = [event subtype];

	  /*
	   * Window movement or resize events for the window we are
	   * watching are posted immediately, so they can take effect
	   * before the placewindow returns.
	   */
	  if (sub == GSAppKitWindowMoved || sub == GSAppKitWindowResized)
	    {
	      [nswin sendEvent: event];
	    }
	  else
	    {
	      [tmpQueue addObject: event];
	    }
	}
      else if (type != NSPeriodic && type != NSLeftMouseDragged
	&& type != NSOtherMouseDragged && type != NSRightMouseDragged
	&& type != NSMouseMoved)
	{
	  /*
	   * Save any events that arrive before our window is moved - excepting
	   * periodic events (which we can assume will be outdated) and mouse
	   * movement events (which might flood us).
	   */
	  [tmpQueue addObject: event];
	}
      if (NSEqualRects(xVal, window->xframe) == YES ||
	NSEqualRects(rect, [nswin frame]) == YES)
	{
	  break;
	}
      if (NSEqualRects(last, window->xframe) == NO)
	{
	  NSDebugLLog(@"Moving", @"From: %@\nWant %@\nGot %@",
	    NSStringFromRect(last),
	    NSStringFromRect(xVal),
	    NSStringFromRect(window->xframe));
	  last = window->xframe;
	}
    }
  /*
   * If we got any events while waiting for the window movement, we
   * may need to adjust their locations to match the new window position.
   */
  pos = [tmpQueue count];
  while (pos-- > 0) 
    {
      event = [tmpQueue objectAtIndex: pos];
      if ([event windowNumber] == win)
	{
	  NSPoint	loc = [event locationInWindow];

	  loc.x -= xdiff;
	  loc.y -= ydiff;
	  [event _patchLocation: loc];
	}
      DPSPostEvent(self, event, YES);
    }
  RELEASE(arp);

  /*
   * Failsafe - if X hasn't told us it has moved/resized the window, we
   * fake the notification and post them immediately, so they can take
   * effect before the placewindow returns.
   */
  if (NSEqualRects([nswin frame], rect) == NO)
    {
      NSEvent	*e;

      if (resize == YES)
	{
	  NSDebugLLog(@"Moving", @"Fake size %d - %@", window->number,
	    NSStringFromSize(rect.size));
	  e = [NSEvent otherEventWithType: NSAppKitDefined
				 location: rect.origin
			    modifierFlags: 0
				timestamp: 0
			     windowNumber: win
		                  context: GSCurrentContext()
				  subtype: GSAppKitWindowResized
				    data1: rect.size.width
				    data2: rect.size.height];
	  [nswin sendEvent: e];
	}
      if (move == YES)
	{
	  NSDebugLLog(@"Moving", @"Fake move %d - %@", window->number,
	    NSStringFromPoint(rect.origin));
	  e = [NSEvent otherEventWithType: NSAppKitDefined
				 location: NSZeroPoint
			    modifierFlags: 0
				timestamp: 0
			     windowNumber: win
		                  context: GSCurrentContext()
				  subtype: GSAppKitWindowMoved
				    data1: rect.origin.x
				    data2: rect.origin.y];
	  [nswin sendEvent: e];
	}
    }
}

- (BOOL) findwindow: (NSPoint)loc : (int) op : (int) otherWin : (NSPoint *)floc 
: (int*) winFound
{
  return NO;
}

- (NSRect) windowbounds: (int)win
{
  gswindow_device_t *window;
  int screenHeight;
  NSRect rect;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return NSZeroRect;

  NSDebugLLog(@"XGTrace", @"DPScurrentwindowbounds: %d", win);
  screenHeight = DisplayHeight(XDPY, window->screen);
  rect = window->xframe;
  rect.origin.y = screenHeight - NSMaxY(window->xframe);
  return rect;
}

- (void) setwindowlevel: (int)level : (int)win
{
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return;

  NSDebugLLog(@"XGTrace", @"DPSsetwindowlevel: %d : %d", level, win);
  if (window->win_attrs.window_level != level
    || (window->win_attrs.flags & GSWindowLevelAttr) == 0)
    {
      window->win_attrs.flags |= GSWindowLevelAttr;
      window->win_attrs.window_level = level;

      // send WindowMaker WM window style hints
      if ((generic.wm & XGWM_WINDOWMAKER) != 0)
	{
	  XEvent	event;

	  /*
	   * First change the window properties so that, if the window
	   * is not mapped, we have stored the required info for when
	   * the WM maps it.
	   */
	  XChangeProperty(XDPY, window->ident,
	    generic.win_decor_atom, generic.win_decor_atom,
	    32, PropModeReplace, (unsigned char *)&window->win_attrs,
	    sizeof(GNUstepWMAttributes)/sizeof(CARD32));
	  /*
	   * Now send a message for rapid handling.
	   */
	  event.xclient.type = ClientMessage;
	  event.xclient.message_type = generic.win_decor_atom;
	  event.xclient.format = 32;
	  event.xclient.display = XDPY;
	  event.xclient.window = window->ident;
	  event.xclient.data.l[0] = GSWindowLevelAttr;
	  event.xclient.data.l[1] = window->win_attrs.window_level;
	  event.xclient.data.l[2] = 0;
	  event.xclient.data.l[3] = 0;
	  XSendEvent(XDPY, DefaultRootWindow(XDPY), False,
	    SubstructureRedirectMask, &event);
	}
      else if ((generic.wm & XGWM_EWMH) != 0)
	{
	  Atom flag = generic.wintypes.win_normal_atom;
	  
	  if (level == NSModalPanelWindowLevel)
	    flag = generic.wintypes.win_modal_atom;
	  // For strang reasons this level does not work out for the main menu
	  else if (//level == NSMainMenuWindowLevel || 
		   level == NSSubmenuWindowLevel ||
		   level == NSFloatingWindowLevel ||
		   level == NSTornOffMenuWindowLevel ||
		   level == NSPopUpMenuWindowLevel)
	    flag = generic.wintypes.win_menu_atom;
	  else if (level == NSDockWindowLevel)
	    flag =generic.wintypes.win_dock_atom;
	  else if (level == NSStatusWindowLevel)
	    flag = generic.wintypes.win_floating_atom;
	  else if (level == NSDesktopWindowLevel)
	    flag = generic.wintypes.win_desktop_atom;

	  XChangeProperty(XDPY, window->ident, generic.wintypes.win_type_atom,
			  XA_ATOM, 32, PropModeReplace, 
			  (unsigned char *)&flag, 1);
	}
      else if ((generic.wm & XGWM_GNOME) != 0)
	{
	  XEvent event;
	  int    flag = WIN_LAYER_NORMAL;

	  if (level == NSDesktopWindowLevel)
	    flag = WIN_LAYER_DESKTOP;
	  else if (level == NSSubmenuWindowLevel 
		   || level == NSFloatingWindowLevel 
		   || level == NSTornOffMenuWindowLevel)
	    flag = WIN_LAYER_ONTOP;
	  else if (level == NSMainMenuWindowLevel)
	    flag = WIN_LAYER_MENU;
	  else if (level == NSDockWindowLevel
		   || level == NSStatusWindowLevel)
	    flag = WIN_LAYER_DOCK;
	  else if (level == NSModalPanelWindowLevel
		   || level == NSPopUpMenuWindowLevel)
	    flag = WIN_LAYER_ONTOP;
	  else if (level == NSScreenSaverWindowLevel)
	    flag = WIN_LAYER_ABOVE_DOCK;

	  XChangeProperty(XDPY, window->ident, generic.wintypes.win_type_atom,
			  XA_CARDINAL, 32, PropModeReplace, 
			  (unsigned char *)&flag, 1);

	  event.xclient.type = ClientMessage;
	  event.xclient.window = window->ident;
	  event.xclient.display = XDPY;
	  event.xclient.message_type = generic.wintypes.win_type_atom;
	  event.xclient.format = 32;
	  event.xclient.data.l[0] = flag;
	  XSendEvent(XDPY, window->root, False, 
		     SubstructureNotifyMask, &event);
	}
    }
}

- (int) windowlevel: (int)win
{
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  /*
   * If we have previously set a level for this window - return the value set.
   */
  if (window != 0 && (window->win_attrs.flags & GSWindowLevelAttr))
    return window->win_attrs.window_level;
  return 0;
}

- (NSArray *) windowlist
{
  return nil;
}

- (int) windowdepth: (int)win
{
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return 0;

  return window->depth;
}

- (void) setmaxsize: (NSSize)size : (int)win
{
  gswindow_device_t	*window;
  NSRect		r;

  window = WINDOW_WITH_TAG(win);
  if (window == 0)
    {
      return;
    }
  r = NSMakeRect(0, 0, size.width, size.height);
  r = [self _OSFrameToXFrame: r for: window];
  window->siz_hints.flags |= PMaxSize;
  window->siz_hints.max_width = r.size.width;
  window->siz_hints.max_height = r.size.height;
  setNormalHints(XDPY, window);
}

- (void) setminsize: (NSSize)size : (int)win
{
  gswindow_device_t	*window;
  NSRect		r;

  window = WINDOW_WITH_TAG(win);
  if (window == 0)
    {
      return;
    }
  r = NSMakeRect(0, 0, size.width, size.height);
  r = [self _OSFrameToXFrame: r for: window];
  window->siz_hints.flags |= PMinSize;
  window->siz_hints.min_width = r.size.width;
  window->siz_hints.min_height = r.size.height;
  setNormalHints(XDPY, window);
}

- (void) setresizeincrements: (NSSize)size : (int)win
{
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (window == 0)
    {
      return;
    }
  window->siz_hints.flags |= PResizeInc;
  window->siz_hints.width_inc = size.width;
  window->siz_hints.height_inc = size.height;
  setNormalHints(XDPY, window);
}

// process expose event
- (void) _addExposedRectangle: (XRectangle)rectangle : (int)win
{
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return;

  if (window->type != NSBackingStoreNonretained)
    {
      XGCValues values;
      unsigned long valuemask;

      // window has a backing store so just copy the exposed rect from the
      // pixmap to the X window

      NSDebugLLog (@"NSWindow", @"copy exposed area ((%d, %d), (%d, %d))",
		  rectangle.x, rectangle.y, rectangle.width, rectangle.height);

      values.function = GXcopy;
      values.plane_mask = AllPlanes;
      values.clip_mask = None;
      values.foreground = ((RContext *)context)->white;
      valuemask = (GCFunction | GCPlaneMask | GCClipMask | GCForeground);
      XChangeGC(XDPY, window->gc, valuemask, &values);
      [isa waitAllContexts];
      XCopyArea (XDPY, window->buffer, window->ident, window->gc,
		 rectangle.x, rectangle.y, rectangle.width, rectangle.height,
		 rectangle.x, rectangle.y);
    }
  else
    {
      NSRect	rect;

      // no backing store, so keep a list of exposed rects to be
      // processed in the _processExposedRectangles method
      // Add the rectangle to the region used in -_processExposedRectangles
      // to set the clipping path.
      XUnionRectWithRegion (&rectangle, window->region, window->region);

      // Transform the rectangle's coordinates to PS coordinates and add
      // this new rectangle to the list of exposed rectangles.
      rect.origin = NSMakePoint((float)rectangle.x, rectangle.y);
      rect.size = NSMakeSize(rectangle.width, rectangle.height);
      [window->exposedRects addObject: [NSValue valueWithRect: rect]];
    }
}

- (void) flushwindowrect: (NSRect)rect : (int)win
{
  int xi, yi, width, height;
  XGCValues values;
  unsigned long valuemask;
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (win == 0 || window == NULL)
    {
      NSLog(@"Invalidparam: Placing invalid window %d", win);
      return;
    }

  NSDebugLLog(@"XGTrace", @"DPSflushwindowrect: %@ : %d", 
	      NSStringFromRect(rect), win);
  if (window->type == NSBackingStoreNonretained)
    {
      XFlush(XDPY);
      return;
    }

  /* FIXME: Doesn't take into account any offset added to the window
     (from PSsetgcdrawable) or possible scaling (unlikely in X-windows,
     but what about other devices?) */
  rect.origin.y = NSHeight(window->xframe) - NSMaxY(rect);

  values.function = GXcopy;
  values.plane_mask = AllPlanes;
  values.clip_mask = None;
  valuemask = (GCFunction | GCPlaneMask | GCClipMask);
  XChangeGC(XDPY, window->gc, valuemask, &values);

  xi = NSMinX(rect);		// width/height seems
  yi = NSMinY(rect);		// to require +1 pixel
  width = NSWidth(rect) + 1;	// to copy out
  height = NSHeight(rect) + 1;

  NSDebugLLog (@"NSWindow", 
	       @"copy X rect ((%d, %d), (%d, %d))", xi, yi, width, height);

  if (width > 0 || height > 0)
    {
      [isa waitAllContexts];
      XCopyArea (XDPY, window->buffer, window->ident, window->gc, 
		 xi, yi, width, height, xi, yi);
    }

  XFlush(XDPY);
}

// handle X expose events
- (void) _processExposedRectangles: (int)win
{
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return;

  if (window->type != NSBackingStoreNonretained)
    return;

  // Set the clipping path to the exposed rectangles
  // so that further drawing will not affect the non-exposed region
  XSetRegion (XDPY, window->gc, window->region);

  // We should determine the views that need to be redisplayed. Until we
  // fully support scalation and rotation of views redisplay everything.
  // FIXME: It seems wierd to trigger a front-end method from here...
  [GSWindowWithNumber(win) display];

  // Restore the exposed rectangles and the region
  [window->exposedRects removeAllObjects];
  XDestroyRegion (window->region);
  window->region = XCreateRegion();
  XSetClipMask (XDPY, window->gc, None);
}

- (BOOL) capturemouse: (int)win
{
  int ret;
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (!window)
    return NO;

  ret = XGrabPointer(XDPY, window->ident, False,
		     PointerMotionMask | ButtonReleaseMask | ButtonPressMask,
		     GrabModeAsync, GrabModeAsync, None, None, CurrentTime);

  if (ret != GrabSuccess)
    NSDebugLLog(@"XGTrace", @"Failed to grab pointer\n");
  else
    {
      grab_window = window;
      NSDebugLLog(@"XGTrace", @"Grabbed pointer\n");
    }
  return (ret == GrabSuccess) ? YES : NO;
}

- (void) releasemouse
{
  XUngrabPointer(XDPY, CurrentTime);
  grab_window = NULL;
}

- (void) setinputfocus: (int)win
{
  gswindow_device_t *window = WINDOW_WITH_TAG(win);

  if (win == 0 || window == 0)
    {
      NSDebugLLog(@"Focus", @"Setting focus to unknown win %d", win);
      return;
    }
  
  NSDebugLLog(@"XGTrace", @"DPSsetinputfocus: %d", win);
  /*
   * If we have an outstanding request to set focus to this window,
   * we don't want to do it again.
   */
  if (win == generic.desiredFocusWindow && generic.focusRequestNumber != 0)
    {
      NSDebugLLog(@"Focus", @"Resetting focus to %d", window->number);
    }
  else
    {
      NSDebugLLog(@"Focus", @"Setting focus to %d", window->number);
    }
  generic.desiredFocusWindow = win;
  generic.focusRequestNumber = XNextRequest(XDPY);
  XSetInputFocus(XDPY, window->ident, RevertToParent, generic.lastTime);
  [inputServer ximFocusICWindow: window];
}

/*
 * Instruct window manager that the specified window is 'key', 'main', or
 * just a normal window.
 */
- (void) setinputstate: (int)st : (int)win
{
  NSDebugLLog(@"XGTrace", @"DPSsetinputstate: %d : %d", win, st);
  if ((generic.wm & XGWM_WINDOWMAKER) != 0)
    {
      gswindow_device_t *window = WINDOW_WITH_TAG(win);
      XEvent		event;

      event.xclient.type = ClientMessage;
      event.xclient.message_type = generic.titlebar_state_atom;
      event.xclient.format = 32;
      event.xclient.display = XDPY;
      event.xclient.window = window->ident;
      event.xclient.data.l[0] = st;
      event.xclient.data.l[1] = 0;
      event.xclient.data.l[2] = 0;
      event.xclient.data.l[3] = 0;
      XSendEvent(XDPY, DefaultRootWindow(XDPY), False,
		 SubstructureRedirectMask, &event);
    }
}

- (void *) serverDevice
{
  return XDPY;
}

- (void *) windowDevice: (int)win
{
  static Window ptrloc;
  gswindow_device_t *window;

  window = WINDOW_WITH_TAG(win);
  if (window != NULL)
    ptrloc = window->ident;
  else
    ptrloc = 0;
  return &ptrloc;
}

/* Cursor Ops */
typedef struct _xgps_cursor_id_t {
  Cursor c;
} xgps_cursor_id_t;

static char xgps_blank_cursor_bits [] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

static Cursor xgps_blank_cursor = None;
static BOOL   cursor_hidden = NO;

- (Cursor) _blankCursor
{
  if (xgps_blank_cursor == None)
    {
      Pixmap shape, mask;
      XColor black, white;
      
      shape = XCreatePixmapFromBitmapData(XDPY, XDRW,
					  xgps_blank_cursor_bits, 
					  16, 16, 1, 0, 1);
      mask = XCreatePixmapFromBitmapData(XDPY, XDRW,
					 xgps_blank_cursor_bits, 
					 16, 16, 1, 0, 1);
      black.red = black.green = black.blue = 0;
      black = [self xColorFromColor: black];
      white.red = white.green = white.blue = 65535;
      white = [self xColorFromColor: white];
      
      xgps_blank_cursor = XCreatePixmapCursor(XDPY, shape, mask, 
					      &white, &black,  0, 0);
      XFreePixmap(XDPY, shape);
      XFreePixmap(XDPY, mask);
    }
  return xgps_blank_cursor;
}

/*
  set the cursor for a newly created window.
*/

- (void) _initializeCursorForXWindow: (Window) win
{
  if (cursor_hidden)
    {
      XDefineCursor (XDPY, win, [self _blankCursor]);
    }
  else
    {
      xgps_cursor_id_t *cid = [[NSCursor currentCursor] _cid];
      
      XDefineCursor (XDPY, win, cid->c);
    }
}


/*
  set cursor on all XWindows we own.  if `set' is NO
  the cursor is unset on all windows.
  Normally the cursor `c' correspond to the [NSCursor currentCursor]
  The only exception should be when the cursor is hidden.
  In that case `c' will be a blank cursor.
*/

- (void) _DPSsetcursor: (Cursor)c : (BOOL)set
{
  Window win;
  NSMapEnumerator enumerator;
  gswindow_device_t  *d;

  NSDebugLLog (@"NSCursor", @"_DPSsetcursor: cursor = %p, set = %d", c, set);
  
  enumerator = NSEnumerateMapTable (windowmaps);
  while (NSNextMapEnumeratorPair (&enumerator, (void**)&win, (void**)&d) == YES)
    {
      if (set)
        XDefineCursor(XDPY, win, c);
      else
        XUndefineCursor(XDPY, win); 
    }
}

#define ALPHA_THRESHOLD 158

Pixmap
xgps_cursor_mask(Display *xdpy, Drawable draw, const char *data, 
		  int w, int h, int colors)
{
  int j, i;
  unsigned char	ialpha;
  Pixmap pix;
  int bitmapSize = ((w + 7) >> 3) * h; // (w/8) rounded up times height
  char *aData = calloc(1, bitmapSize);
  char *cData = aData;

  if (colors == 4)
    {
      int k;
      for (j = 0; j < h; j++)
	{
	  k = 0;
	  for (i = 0; i < w; i++, k++)
	    {
	      if (k > 7)
		{
	      	  cData++;
	      	  k = 0;
	      	}
	      data += 3;
	      ialpha = (unsigned short)((char)*data++);
	      if (ialpha > ALPHA_THRESHOLD)
		{
		  *cData |= (0x01 << k);
		}
	    }
	  cData++;
	}
    }
  else
    {
      for (j = 0; j < bitmapSize; j++)
	{
	  *cData++ = 0xff;
	}
    }

  pix = XCreatePixmapFromBitmapData(xdpy, draw, (char *)aData, w, h, 
				    1L, 0L, 1);
  free(aData);
  return pix;
}

Pixmap
xgps_cursor_image(Display *xdpy, Drawable draw, const unsigned char *data, 
		  int w, int h, int colors, XColor *fg, XColor *bg)
{
  int j, i, min, max;
  Pixmap pix;
  int bitmapSize = ((w + 7) >> 3) * h; // w/8 rounded up multiplied by h
  char *aData = calloc(1, bitmapSize);
  char *cData = aData;

  min = 1 << 16;
  max = 0;
  if (colors == 4 || colors == 3)
    {
      int k;
      for (j = 0; j < h; j++)
	{
	  k = 0;
	  for (i = 0; i < w; i++, k++)
	    {
	      /* colors is in the range 0..65535 
		 and value is the percieved brightness, obtained by
		 averaging 0.3 red + 0.59 green + 0.11 blue 
	      */
	      int color = ((77 * data[0]) + (151 * data[1]) + (28 * data[2]));

	      if (k > 7)
		{
		  cData++;
		  k = 0;
		}
	      if (color > (1 << 15))
		{
		  *cData |= (0x01 << k);
		}
	      if (color < min)
		{
		  min = color;
		  bg->red = (int)data[0] * 256; 
		  bg->green = (int)data[1] * 256; 
		  bg->blue = (int)data[2] * 256;
		}
	      else if (color > max)
		{
		  max = color;
		  fg->red = (int)data[0] * 256; 
		  fg->green = (int)data[1] * 256; 
		  fg->blue = (int)data[2] * 256;
		}
	      data += 3;
	      if (colors == 4)
		{
		  data++;
		}
	    }
	  cData++;
	}
    }
  else
    {
      for (j = 0; j < bitmapSize; j++)
	{
	  if ((unsigned short)((char)*data++) > 128)
	    {
	      *cData |= (0x01 << i);
	    }
	  cData++;
	}
    }
  
  pix = XCreatePixmapFromBitmapData(xdpy, draw, (char *)aData, w, h, 
				    1L, 0L, 1);
  free(aData);
  return pix;
}

- (void) hidecursor
{
  if (cursor_hidden)
    return;

  [self _DPSsetcursor: [self _blankCursor] : YES];
  cursor_hidden = YES;
}

- (void) showcursor
{
  if (cursor_hidden)
    {
      /* This just resets the cursor to the parent window's cursor.
	 I'm not even sure it's needed */
      [self _DPSsetcursor: None : NO];
      /* Reset the current cursor */
      [[NSCursor currentCursor] set];
    }
  cursor_hidden = NO;
}

- (void) standardcursor: (int)style : (void **)cid
{
  xgps_cursor_id_t *cursor;
  cursor = NSZoneMalloc([self zone], sizeof(xgps_cursor_id_t));
  switch (style)
    {
    case GSArrowCursor:
      cursor->c = XCreateFontCursor(XDPY, XC_left_ptr);     
      break;
    case GSIBeamCursor:
      cursor->c = XCreateFontCursor(XDPY, XC_xterm);
      break;
    default:
      cursor->c = XCreateFontCursor(XDPY, XC_left_ptr);     
      break;
    }
  if (cid)
    *cid = (void *)cursor;
}

- (void) imagecursor: (NSPoint)hotp : (int) w :  (int) h : (int)colors : (const char *)image : (void **)cid
{
  xgps_cursor_id_t *cursor;
  Pixmap source, mask;
  unsigned int maxw, maxh;
  XColor fg, bg;

  /* FIXME: We might create a blank cursor here? */
  if (image == NULL || w == 0 || h == 0)
    {
      *cid = NULL;
      return;
    }

  /* FIXME: Handle this better or return an error? */
  XQueryBestCursor(XDPY, ROOT, w, h, &maxw, &maxh);
  if (w > maxw)
    w = maxw;
  if (h > maxh)
    h = maxh;

  cursor = NSZoneMalloc([self zone], sizeof(xgps_cursor_id_t));
  source = xgps_cursor_image(XDPY, ROOT, image, w, h, colors, &fg, &bg);
  mask = xgps_cursor_mask(XDPY, ROOT, image, w, h, colors);
  bg = [self xColorFromColor: bg];
  fg = [self xColorFromColor: fg];

  cursor->c = XCreatePixmapCursor(XDPY, source, mask, &fg, &bg, 
				  (int)hotp.x, (int)(h - hotp.y));
  XFreePixmap(XDPY, source);
  XFreePixmap(XDPY, mask);
  if (cid)
    *cid = (void *)cursor;
}

- (void) setcursorcolor: (NSColor *)fg : (NSColor *)bg : (void*) cid
{
  XColor xf, xb;
  xgps_cursor_id_t *cursor;

  cursor = (xgps_cursor_id_t *)cid;
  if (cursor == NULL)
    NSLog(@"Invalidparam: Invalid cursor");

  [self _DPSsetcursor: cursor->c : YES];
  /* Special hack: Don't set the color when fg == nil. Used by NSCursor
     to just set the cursor but not the color. */
  if (fg == nil)
    {
      return;
    }

  fg = [fg colorUsingColorSpaceName: NSDeviceRGBColorSpace];
  bg = [bg colorUsingColorSpaceName: NSDeviceRGBColorSpace];
  xf.red   = 65535 * [fg redComponent];
  xf.green = 65535 * [fg greenComponent];
  xf.blue  = 65535 * [fg blueComponent];
  xb.red   = 65535 * [bg redComponent];
  xb.green = 65535 * [bg greenComponent];
  xb.blue  = 65535 * [bg blueComponent];
  xf = [self xColorFromColor: xf];
  xb = [self xColorFromColor: xb];

  XRecolorCursor(XDPY, cursor->c, &xf, &xb);
}

static NSWindowDepth
_computeDepth(int class, int bpp)
{
  int		spp = 0;
  int		bitValue = 0;
  int		bps = 0;
  NSWindowDepth	depth = 0;

  switch (class)
    {
      case GrayScale:
      case StaticGray:
	bitValue = _GSGrayBitValue;
	spp = 1;
	break;
      case PseudoColor:
      case StaticColor:
	bitValue = _GSCustomBitValue;
	spp = 1;
	break;
      case DirectColor:
      case TrueColor:
	bitValue = _GSRGBBitValue;
	spp = 3;
	break;
      default:
	break;
    }

  bps = (bpp/spp);
  depth = (bitValue | bps);

  return depth;
}

- (NSArray *)screenList
{
  /* I guess screen numbers are in order starting from zero, but we
     put the main screen first */
 int i;
 int count = ScreenCount(XDPY);
 NSMutableArray *windows = [NSMutableArray arrayWithCapacity: count];
 if (count > 0)
   [windows addObject: [NSNumber numberWithInt: XSCR]];
 for (i = 0; i < count; i++)
   {
     if (i != XSCR)
       [windows addObject: [NSNumber numberWithInt: i]];
   }
 return windows;
}

- (NSWindowDepth) windowDepthForScreen: (int) screen_num
{ 
  Display	*display;
  Screen	*screen;
  int		 class = 0, bpp = 0;

  display = XDPY;
  if (display == NULL)
    {
      return 0;
    }

  screen = XScreenOfDisplay(display, screen_num);
  if (screen == NULL)
    {
      return 0;
    }

  bpp = screen->root_depth;
  class = screen->root_visual->class;

  return _computeDepth(class, bpp);
}

- (const NSWindowDepth *) availableDepthsForScreen: (int) screen_num
{  
  Display	*display;
  Screen	*screen;
  int		 class = 0;
  int		 index = 0;
  int		 ndepths = 0;
  NSZone	*defaultZone = NSDefaultMallocZone();
  NSWindowDepth	*depths = 0;

  display = XDPY;
  if (display == NULL)
    {
      return NULL;
    }

  screen = XScreenOfDisplay(display, screen_num);
  if (screen == NULL)
    {
      return NULL;
    }

  // Allocate the memory for the array and fill it in.
  ndepths = screen->ndepths;
  class = screen->root_visual->class;
  depths = NSZoneMalloc(defaultZone, sizeof(NSWindowDepth)*(ndepths + 1));
  for (index = 0; index < ndepths; index++)
    {
      int depth = screen->depths[index].depth;
      depths[index] = _computeDepth(class, depth);
    }
  depths[index] = 0; // terminate with a zero.

  return depths;
}

- (NSSize) resolutionForScreen: (int)screen_num
{ 
  Display *display;
  int res_x, res_y;

  display = XDPY;
  if (screen_num < 0 || screen_num >= ScreenCount(XDPY))
    {
      NSLog(@"Invalidparam: no screen %d", screen_num);
      return NSMakeSize(0,0);
    }
  // This does not take virtual displays into account!! 
  res_x = DisplayWidth(display, screen_num) / 
      (DisplayWidthMM(display, screen_num) / 25.4);
  res_y = DisplayHeight(display, screen_num) / 
      (DisplayHeightMM(display, screen_num) / 25.4);
	
  return NSMakeSize(res_x, res_y);
}

- (NSRect) boundsForScreen: (int)screen
{
 if (screen < 0 || screen >= ScreenCount(XDPY))
   {
     NSLog(@"Invalidparam: no screen %d", screen);
     return NSZeroRect;
   }
 return NSMakeRect(0, 0, DisplayWidth(XDPY, screen), 
		   DisplayHeight(XDPY, screen));
}

@end


#include	"x11/XGSlideView.h"

@implementation XGServer (Sliding)
- (BOOL) slideImage: (NSImage*)image from: (NSPoint)from to: (NSPoint)to
{
  return [XGSlideView _slideImage: image from: from to: to];
}
@end

