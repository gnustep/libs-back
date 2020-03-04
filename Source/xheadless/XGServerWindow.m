/* XGServerWindows - methods for window/screen handling

   Copyright (C) 1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Nov 1999
   
   This file is part of GNUstep

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#include "config.h"
#include <math.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <Foundation/NSThread.h>
#include <AppKit/DPSOperators.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSBitmapImageRep.h>

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifdef HAVE_WRASTER_H
#include "wraster.h"
#else
#include "x11/wraster.h"
#endif

// For X_HAVE_UTF8_STRING
#include <X11/Xlib.h>
#include <X11/cursorfont.h>
#if HAVE_XCURSOR
#include <X11/Xcursor/Xcursor.h>
#endif
#ifdef HAVE_XSHAPE
#include <X11/extensions/shape.h>
#endif
#if HAVE_XFIXES
#include <X11/extensions/Xfixes.h>
#endif

#include "x11/XGDragView.h"
#include "x11/XGInputServer.h"

#define	ROOT generic.appRootWindow


static BOOL handlesWindowDecorations = YES;

#define WINDOW_WITH_TAG(windowNumber) (gswindow_device_t *)NSMapGet(windowtags, (void *)(uintptr_t)windowNumber)

/* Keep track of windows */
static NSMapTable *windowmaps = NULL;
static NSMapTable *windowtags = NULL;

/* Track used window numbers */
static int		last_win_num = 0;


@interface NSCursor (BackendPrivate)
- (void *)_cid;
@end

@interface NSBitmapImageRep (GSPrivate)
- (NSBitmapImageRep *) _convertToFormatBitsPerSample: (NSInteger)bps
                                     samplesPerPixel: (NSInteger)spp
                                            hasAlpha: (BOOL)alpha
                                            isPlanar: (BOOL)isPlanar
                                      colorSpaceName: (NSString*)colorSpaceName
                                        bitmapFormat: (NSBitmapFormat)bitmapFormat 
                                         bytesPerRow: (NSInteger)rowBytes
                                        bitsPerPixel: (NSInteger)pixelBits;
@end

void __objc_xgcontextwindow_linking (void)
{
}

/*
 * The next two functions derived from WindowMaker by Alfredo K. Kojima
 */
static unsigned char*PropGetCheckProperty(Display *dpy, Window window, Atom hint, Atom type,
		     int format, int count, int *retCount)
{
  return NULL;
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
  unsigned long input_mode;
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

@interface XGServer (WindowOps)
- (gswindow_device_t *) _rootWindowForScreen: (int)screen;
- (void) styleoffsets: (float *) l : (float *) r : (float *) t : (float *) b
                     : (unsigned int) style : (Window) win;
- (void) _setSupportedWMProtocols: (gswindow_device_t *) window;
@end

@implementation XGServer (WindowOps)

- (BOOL) handlesWindowDecorations
{
  return handlesWindowDecorations;
}


/*
 * Where a window has been reparented by the wm, we use this method to
 * locate the window given knowledge of its border window.
 */
+ (gswindow_device_t *) _windowForXParent: (Window)xWindow
{
  NSMapEnumerator	enumerator;
  void		*key;
  gswindow_device_t	*d;

  enumerator = NSEnumerateMapTable(windowmaps);
  while (NSNextMapEnumeratorPair(&enumerator, &key, (void**)&d) == YES)
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

+ (gswindow_device_t *) _windowWithTag: (NSInteger)windowNumber
{
  return WINDOW_WITH_TAG(windowNumber);
}

/*
 * Convert a window frame in OpenStep absolute screen coordinates to
 * a frame in X absolute screen coordinates by flipping an applying
 * offsets to allow for the X window decorations.
 * The result is the rectangle of the window we can actually draw
 * to (in the X coordinate system).
 */
- (NSRect) _OSFrameToXFrame: (NSRect)o for: (void*)window
{
  return NSMakeRect(0, 0, 0, 0);
}

/*
 * Convert a window frame in OpenStep absolute screen coordinates to
 * a frame suitable for setting X hints for a window manager.
 * NB. Hints use the coordinates of the parent decoration window,
 * but the size of the actual window.
 */
- (NSRect) _OSFrameToXHints: (NSRect)o for: (void*)window
{
  return NSMakeRect(0, 0, 0, 0);
}

/*
 * Convert a rectangle in X  coordinates relative to the X-window
 * to a rectangle in OpenStep coordinates (base coordinates of the NSWindow).
 */
- (NSRect) _XWinRectToOSWinRect: (NSRect)x for: (void*)window
{
  return NSMakeRect(0, 0, 0, 0);
}

/*
 * Convert a window frame in X absolute screen coordinates to a frame
 * in OpenStep absolute screen coordinates by flipping an applying
 * offsets to allow for the X window decorations.
 */
- (NSRect) _XFrameToOSFrame: (NSRect)x for: (void*)window
{
  return NSMakeRect(0, 0, 0, 0);
}

/*
 * Convert a window frame in X absolute screen coordinates to
 * a frame suitable for setting X hints for a window manager.
 */
- (NSRect) _XFrameToXHints: (NSRect)o for: (void*)window
{
  return NSMakeRect(0, 0, 0, 0);
}

- (void)_sendRoot: (Window)root
             type: (Atom)type 
           window: (Window)window
            data0: (long)data0
            data1: (long)data1
            data2: (long)data2
            data3: (long)data3
{
}

/*
 * Check if the window manager supports a feature.
 */
- (BOOL) _checkWMSupports: (Atom)feature
{
  return NO;
}

Bool _get_next_prop_new_event(Display *display, XEvent *event, char *arg)
{
  return False;
}

- (BOOL) _tryRequestFrameExtents: (gswindow_device_t *)window
{
  return NO;
}

- (BOOL) _checkStyle: (unsigned)style
{
  NSDebugLLog(@"Offset", @"Checking offsets for style %d\n", style);
  return NO;
}

- (XGWMProtocols) _checkWindowManager
{
  return XGWM_UNKNOWN;
}

- (gswindow_device_t *) _rootWindowForScreen: (int)screen
{
  gswindow_device_t *window;

  /* Screen number is negative to avoid conflict with windows */
  window = WINDOW_WITH_TAG(-screen);
  if (window)
    return window;

  window = NSAllocateCollectable(sizeof(gswindow_device_t), NSScannedOption);
  memset(window, '\0', sizeof(gswindow_device_t));

  window->display = dpy;
  window->screen = screen;
  window->ident  = 0; //RootWindow(dpy, screen);
  window->root   = window->ident;
  window->type   = NSBackingStoreNonretained;
  window->number = -screen;
  window->map_state = IsViewable;
  window->visibility = -1;
  window->wm_state = NormalState;
  window->xframe = NSMakeRect(0, 0, 0, 0);
  NSMapInsert (windowtags, (void*)(uintptr_t)window->number, window);
  NSMapInsert (windowmaps, (void*)(uintptr_t)window->ident,  window);
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
}

- (void) _setSupportedWMProtocols: (gswindow_device_t *) window
{
}

- (void) _setupRootWindow
{
  /*
   * Initialize time of last events to be the start of time - not
   * the current time!
   */
  generic.lastClick = 1;
  generic.lastMotion = 1;
  generic.lastTime = 1;

  /*
   * Set up standard atoms.
   */

  [self _checkWindowlist];
  handlesWindowDecorations = NO;
  return;
}

/* Destroys all the windows and other window resources that belong to
   this context */
- (void) _destroyServerWindows
{
  void *key;
  gswindow_device_t *d;
  NSMapEnumerator   enumerator;
  NSMapTable        *mapcopy;

  /* Have to get a copy, since termwindow will remove them from
     the map table */
  mapcopy = NSCopyMapTableWithZone(windowtags, [self zone]);
  enumerator = NSEnumerateMapTable(mapcopy);
  while (NSNextMapEnumeratorPair(&enumerator, &key, (void**)&d) == YES)
    {
      if (d->display == dpy && d->ident != d->root)
	[self termwindow: (NSInteger)(intptr_t)key];
    }
  NSFreeMapTable(mapcopy);
}

/* Sets up a backing pixmap when a window is created or resized.  This is
   only done if the Window is buffered or retained. */
- (void) _createBuffer: (gswindow_device_t *)window
{
}

/*
 * Code to build up a NET WM icon from our application icon
 */

-(BOOL) _createNetIcon: (NSImage*)image 
		result: (long**)pixeldata 
		  size: (int*)size
{
  return NO;
}   

- (void) _setNetWMIconFor: (Window) window
{
}

- (NSInteger) window: (NSRect)frame : (NSBackingStoreType)type : (unsigned int)style : (int)screen
{
  gswindow_device_t	*window;

  NSDebugLLog(@"XGTrace", @"DPSwindow: %@ %d", NSStringFromRect(frame), (int)type);

  /* Create the window structure and set the style early so we can use it to
  convert frames. */
  window = NSAllocateCollectable(sizeof(gswindow_device_t), NSScannedOption);
  memset(window, '\0', sizeof(gswindow_device_t));

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
  NSMapInsert(windowmaps, (void*)(uintptr_t)window->ident, window);
  NSMapInsert(windowtags, (void*)(uintptr_t)window->number, window);
  [self _setWindowOwnedByServer: window->number];

  return window->number;
}

- (NSInteger) nativeWindow: (void *)winref : (NSRect*)frame : (NSBackingStoreType*)type
		    : (unsigned int*)style : (int*)screen
{
  return 0;
}

- (void) termwindow: (NSInteger)win
{
}

/*
 * Return the offsets between the window content-view and it's frame
 * depending on the window style.
 */
- (void) styleoffsets: (float *) l : (float *) r : (float *) t : (float *) b 
		     : (unsigned int) style
{
  [self styleoffsets: l : r : t : b : style : (Window) 0];
}

- (void) styleoffsets: (float *) l : (float *) r : (float *) t : (float *) b 
		     : (unsigned int) style : (Window) win
{
}

- (void) stylewindow: (unsigned int)style : (NSInteger) win
{
}

- (void) setbackgroundcolor: (NSColor *)color : (NSInteger)win
{
}

- (void) windowbacking: (NSBackingStoreType)type : (NSInteger) win
{
}

- (void) titlewindow: (NSString *)window_title : (NSInteger) win
{
}

- (void) docedited: (int)edited : (NSInteger) win
{
}

- (BOOL) appOwnsMiniwindow
{
  return generic.flags.appOwnsMiniwindow;
}

- (void) miniwindow: (NSInteger) win
{
}

/**
   Make sure we have the most up-to-date window information and then
   make sure the context has our new information
*/
- (void) setWindowdevice: (NSInteger)win forContext: (NSGraphicsContext *)ctxt
{
}

-(int) _createAppIconPixmaps
{
  return 1;
}   

- (void) orderwindow: (int)op : (NSInteger)otherWin : (NSInteger)winNum
{
}

#define ALPHA_THRESHOLD 158

/* Restrict the displayed part of the window to the given image.
   This only yields usefull results if the window is borderless and 
   displays the image itself */
- (void) restrictWindow: (NSInteger)win toImage: (NSImage*)image
{
}

/* This method is a fast implementation of move that only works 
   correctly for borderless windows. Use with caution. */
- (void) movewindow: (NSPoint)loc : (NSInteger)win
{
}

- (void) placewindow: (NSRect)rect : (NSInteger)win
{
}

- (BOOL) findwindow: (NSPoint)loc : (int) op : (NSInteger) otherWin : (NSPoint *)floc
: (int*) winFound
{
  return NO;
}

- (NSRect) windowbounds: (NSInteger)win
{

  return NSMakeRect(0, 0, 0, 0);
}

- (void) setwindowlevel: (int)level : (NSInteger)win
{
}

- (int) windowlevel: (NSInteger)win
{
  return 0;
}

- (NSArray *) windowlist
{
  return [NSMutableArray array];
}

- (int) windowdepth: (NSInteger)win
{
    return 0;
}

- (void) setmaxsize: (NSSize)size : (NSInteger)win
{
}

- (void) setminsize: (NSSize)size : (NSInteger)win
{
}

- (void) setresizeincrements: (NSSize)size : (NSInteger)win
{
}

// process expose event
- (void) _addExposedRectangle: (XRectangle)rectangle : (NSInteger)win : (BOOL) ignoreBacking
{
}

- (void) flushwindowrect: (NSRect)rect : (NSInteger)win
{
}

// handle X expose events
- (void) _processExposedRectangles: (NSInteger)win
{
}

- (BOOL) capturemouse: (NSInteger)win
{
  return NO;
}

- (void) setMouseLocation: (NSPoint)mouseLocation onScreen: (int)aScreen
{
}

- (void) setinputfocus: (NSInteger)win
{
}

/*
 * Instruct window manager that the specified window is 'key', 'main', or
 * just a normal window.
 */
- (void) setinputstate: (int)st : (NSInteger)win
{
}

/** Sets the transparancy value for the whole window */
- (void) setalpha: (float)alpha : (NSInteger) win
{
}

- (float) getAlpha: (NSInteger)win
{
  return 1;
}

- (void *) serverDevice
{
  return dpy;
}

- (void *) windowDevice: (NSInteger)win
{
  return (void *)NULL;
}

/* Cursor Ops */
static BOOL   cursor_hidden = NO;

- (Cursor) _blankCursor
{
  return None;
}

/*
  set the cursor for a newly created window.
*/

- (void) _initializeCursorForXWindow: (Window) win
{
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
}

#define ALPHA_THRESHOLD 158

Pixmap
xgps_cursor_mask(Display *xdpy, Drawable draw, const unsigned char *data,
		  int w, int h, int colors)
{
  return 0;
}

Pixmap
xgps_cursor_image(Display *xdpy, Drawable draw, const unsigned char *data, 
		  int w, int h, int colors, XColor *fg, XColor *bg)
{
  return None;
}

- (void) hidecursor
{
  cursor_hidden = YES;
}

- (void) showcursor
{
  cursor_hidden = NO;
}

- (void) standardcursor: (int)style : (void **)cid
{
}

- (void) imagecursor: (NSPoint)hotp : (NSImage *)image : (void **)cid
{
}

- (void) recolorcursor: (NSColor *)fg : (NSColor *)bg : (void*) cid
{

}

- (void) setcursor: (void*) cid
{
}

- (void) freecursor: (void*) cid
{
}

- (NSArray *)screenList
{
 NSMutableArray *screens = [NSMutableArray arrayWithCapacity: 1];
 [screens addObject: [NSNumber numberWithInt: defScreen]];

 return screens;
}

- (NSWindowDepth) windowDepthForScreen: (int) screen_num
{ 
  return 0;
}

- (const NSWindowDepth *) availableDepthsForScreen: (int) screen_num
{  
  return NULL;
}

- (NSSize) resolutionForScreen: (int)screen_num
{ 
  // NOTE:
  // -gui now trusts the return value of resolutionForScreen:,
  // so if it is not {72, 72} then the entire UI will be scaled.
  //
  // I commented out the implementation below because it may not
  // be safe to use the DPI value we get from the X server.
  // (i.e. I don't know if it will be a "fake" DPI like 72 or 96,
  //  or a real measurement reported from the monitor's firmware
  //  (possibly incorrect?))
  // More research needs to be done.

  return NSMakeSize(72, 72);
}

- (NSRect) boundsForScreen: (int)screen
{
 return NSMakeRect(0, 0, 400, 400);
}

- (NSImage *) iconTileImage
{
  return nil;
}

- (NSSize) iconSize
{
  return [super iconSize];
}

- (unsigned int) numberOfDesktops: (int)screen
{
  return 1;
}

- (NSArray *) namesOfDesktops: (int)screen
{
  return nil;
}

- (unsigned int) desktopNumberForScreen: (int)screen
{
  return 0;
}

- (void) setDesktopNumber: (unsigned int)workspace forScreen: (int)screen
{
}

- (unsigned int) desktopNumberForWindow: (int)win
{
  return 0;
}

- (void) setDesktopNumber: (unsigned int)workspace forWindow: (int)win
{
}

- (void) setShadow: (BOOL)hasShadow : (int)win
{
}

- (BOOL) hasShadow: (int)win
{
  return NO;
}

/*
 * Check whether the window is miniaturized according to the ICCCM window
 * state property.
 */
- (int) _wm_state: (Window)win
{
  return WithdrawnState;
}

/*
 * Check whether the EWMH window state includes the _NET_WM_STATE_HIDDEN
 * state. On EWMH, a window is iconified if it is iconic state and the
 * _NET_WM_STATE_HIDDEN is present.
 */
- (BOOL) _ewmh_isHidden: (Window)win
{
  return NO;
}

- (void) setParentWindow: (NSInteger)parentWin
          forChildWindow: (NSInteger)childWin
{
}

- (void) setIgnoreMouse: (BOOL)ignoreMouse : (int)win
{
}

@end
