/* Window ops for X11 server

   Copyright (C) 1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Nov 1999
   
   This file is part of the GNU Objective C User Interface library.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#ifndef _XGServerWindow_h_INCLUDE
#define _XGServerWindow_h_INCLUDE

#define BOOL XWINDOWSBOOL	// prevent X windows BOOL
#include <X11/Xmd.h>		// warning
#undef BOOL
#include <x11/XGServer.h>

//
// WindowMaker window manager interaction
//
typedef struct {
    CARD32 flags;
    CARD32 window_style;
    CARD32 window_level;
    CARD32 reserved;
    Pixmap miniaturize_pixmap;		// pixmap for miniaturize button
    Pixmap close_pixmap;		// pixmap for close button
    Pixmap miniaturize_mask;		// miniaturize pixmap mask
    Pixmap close_mask;			// close pixmap mask
    CARD32 extra_flags;
} GNUstepWMAttributes;

#define GSWindowStyleAttr	(1<<0)
#define GSWindowLevelAttr	(1<<1)
#define GSMiniaturizePixmapAttr (1<<3)
#define GSClosePixmapAttr	(1<<4)
#define GSMiniaturizeMaskAttr	(1<<5)
#define GSCloseMaskAttr		(1<<6)
#define GSExtraFlagsAttr	(1<<7)

#define GSDocumentEditedFlag			(1<<0)
#define GSWindowWillResizeNotificationsFlag	(1<<1)
#define GSWindowWillMoveNotificationsFlag 	(1<<2)
#define GSNoApplicationIconFlag			(1<<5)
#define WMFHideOtherApplications		10
#define WMFHideApplication			12

/* Graphics Driver protocol. Setup in [NSGraphicsContext-contextDevice:] */
enum {
  GDriverHandlesBacking = 1,
  GDriverHandlesExpose = 2
};

typedef struct _gswindow_device_t {
  Display               *display;      /* Display this window is on */
  Window                ident;         /* Window handle */
  Window                root;          /* Handle of root window */
  Window		parent;        /* Handle of parent window */
  int                   screen;        /* Screeen this window is on */
  GC                    gc;            /* GC for drawing */
  long                  number;        /* Globally unique identifier */
  int                   depth;         /* Window depth */
  int                   border;        /* Border size */
  int			map_state;     /* X map state */
  int                   visibility;    /* X visibility */
  NSBackingStoreType    type;          /* Backing type */
  NSRect                xframe;        /* Window frame */

  unsigned int          buffer_width;  /* Size in pixels of the current buffers. */
  unsigned int          buffer_height;
  Drawable              buffer;        /* Backing store pixmap */
  Drawable              alpha_buffer;  /* Alpha buffer. Managed by gdriver
					  will be freed if HandlesBacking=0 */
  BOOL			is_exposed;
  NSMutableArray	*exposedRects; /* List of exposure event rects */
  Region		region;	       /* Used between several expose events */
  XWMHints		gen_hints;
  XSizeHints		siz_hints;
  GNUstepWMAttributes	win_attrs;
  XSetWindowAttributes	xwn_attrs;
  int			xoff;
  int			yoff;
  int			boff;
  Atom			protocols[4];
  int			numProtocols;
  XIC                   ic;
  void                  *gdriver;      /* gdriver ident. Managed by gdriver */
  int                   gdriverProtocol; /* Managed by gdriver */
} gswindow_device_t;

#define GET_XDRAWABLE(win)  ((win)->buffer ? (win)->buffer: (win)->ident)

@interface XGServer (DPSWindow)
+ (gswindow_device_t *) _windowForXWindow: (Window)xWindow;
+ (gswindow_device_t *) _windowForXParent: (Window)xWindow;
+ (gswindow_device_t *) _windowWithTag: (int)windowNumber;
- (void) _addExposedRectangle: (XRectangle)rectangle : (int)win;
- (void) _processExposedRectangles: (int)win;
- (void) _initializeCursorForXWindow: (Window) win;
- (void) _destroyServerWindows;

/* This needs to go in GSDisplayServer */
- (void) _DPSsetcursor: (Cursor)c : (BOOL)set;
@end

extern Pixmap
xgps_cursor_mask(Display *xdpy, Drawable draw, const unsigned char *data,
		 int w, int h, int colors);
#endif
