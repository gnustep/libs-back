/*
   XGServerEvent - Window/Event code for X11 backends.

   Copyright (C) 1998,1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Nov 1998
   
   This file is part of the GNU Objective C User Interface Library.

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

#include <AppKit/AppKitExceptions.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSWindow.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSDebug.h>

#include "x11/XGServerWindow.h"
#include "x11/XGInputServer.h"
#include "x11/XGDragView.h"
#include "x11/XGGeneric.h"
#include "x11/xdnd.h"

#ifdef HAVE_WRASTER_H
#include "wraster.h"
#else
#include "x11/wraster.h"
#endif

#include "math.h"
#include <X11/keysym.h>
#include <X11/Xproto.h>

#if LIB_FOUNDATION_LIBRARY
# include <Foundation/NSPosixFileDescriptor.h>
#elif defined(NeXT_PDO)
# include <Foundation/NSFileHandle.h>
# include <Foundation/NSNotification.h>
#endif

#define	cWin	((gswindow_device_t*)generic.cachedWindow)

extern Atom     WM_STATE;

// NumLock's mask (it depends on the keyboard mapping)
static unsigned int _num_lock_mask;
// Modifier state
static char _control_pressed = 0;
static char _command_pressed = 0;
static char _alt_pressed = 0;
// Keys used for the modifiers (you may set them with user preferences)
static KeyCode _control_keycodes[2];
static KeyCode _command_keycodes[2];
static KeyCode _alt_keycodes[2];

static BOOL _is_keyboard_initialized = NO;

void __objc_xgcontextevent_linking (void)
{
}


@interface XGServer (Private)
- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode;
- (void) setupRunLoopInputSourcesForMode: (NSString*)mode; 
- (NSDate*) timedOutEvent: (void*)data
                     type: (RunLoopEventType)type
                  forMode: (NSString*)mode;
- (int) XGErrorHandler: (Display*)display : (XErrorEvent*)err;
@end


int
XGErrorHandler(Display *display, XErrorEvent *err)
{
  XGServer	*ctxt = (XGServer*)GSCurrentServer();

  return [ctxt XGErrorHandler: display : err];
}

static NSEvent*process_key_event (XEvent* xEvent, XGServer* ctxt, 
				  NSEventType eventType);

static unichar process_char (KeySym keysym, unsigned *eventModifierFlags);

static unsigned process_modifier_flags(unsigned int state);

static void initialize_keyboard (void);

static void set_up_num_lock (void);

static inline int check_modifier (XEvent *xEvent, KeyCode key_code) 
{
  return (xEvent->xkeymap.key_vector[key_code / 8] & (1 << (key_code % 8)));  
}

@implementation XGServer (X11Methods)

- (int) XGErrorHandler: (Display*)display : (XErrorEvent*)err
{
  int length = 1024;
  char buffer[length+1];

  /*
   * Ignore attempts to set input focus to unmapped window, except for noting
   * if the most recent request failed (mark the request serial number to 0)
   * in which case we should repeat the request when the window becomes
   * mapped again.
   */
  if (err->error_code == BadMatch && err->request_code == X_SetInputFocus)
    {
      if (err->serial == generic.focusRequestNumber)
	{
	  generic.focusRequestNumber = 0;
	}
      return 0;
    }

  XGetErrorText(display, err->error_code, buffer, length);
  if (err->type == 0
      && GSDebugSet(@"XSynchronize") == NO)
    {
      NSLog(@"X-Windows error - %s\n\
          on display: %s\n\
    		type: %d\n\
       serial number: %d\n\
	request code: %d\n",
	buffer,
    	XDisplayName(DisplayString(display)),
	err->type, err->serial, err->request_code);
      return 0;
    }
  [NSException raise: NSWindowServerCommunicationException
    format: @"X-Windows error - %s\n\
          on display: %s\n\
    		type: %d\n\
       serial number: %d\n\
	request code: %d\n",
	buffer,
    	XDisplayName(DisplayString(display)),
	err->type, err->serial, err->request_code];
  return 0;
}

- (void) setupRunLoopInputSourcesForMode: (NSString*)mode
{
  int		xEventQueueFd = XConnectionNumber(dpy);
  NSRunLoop	*currentRunLoop = [NSRunLoop currentRunLoop];

#if defined(LIB_FOUNDATION_LIBRARY)
  {
    id fileDescriptor = [[[NSPosixFileDescriptor alloc]
	initWithFileDescriptor: xEventQueueFd]
	autorelease];

    // Invoke limitDateForMode: to setup the current
    // mode of the run loop (the doc says that this
    // method and acceptInputForMode: beforeDate: are
    // the only ones that setup the current mode).

    [currentRunLoop limitDateForMode: mode];

    [fileDescriptor setDelegate: self];
    [fileDescriptor monitorFileActivity: NSPosixReadableActivity];
  }
#elif defined(NeXT_PDO)
  {
    id fileDescriptor = [[[NSFileHandle alloc]
	initWithFileDescriptor: xEventQueueFd]
	autorelease];

    [[NSNotificationCenter defaultCenter] addObserver: self
	selector: @selector(activityOnFileHandle: )
	name: NSFileHandleDataAvailableNotification
	object: fileDescriptor];
    [fileDescriptor waitForDataInBackgroundAndNotifyForModes:
	[NSArray arrayWithObject: mode]];
  }
#else
  [currentRunLoop addEvent: (void*)(gsaddr)xEventQueueFd
		      type: ET_RDESC
		   watcher: (id<RunLoopEvents>)self
		   forMode: mode];
#endif
}

#if LIB_FOUNDATION_LIBRARY
- (void) activity: (NSPosixFileActivities)activity
		posixFileDescriptor: (NSPosixFileDescriptor*)fileDescriptor
{
  [self receivedEvent: 0 type: 0 extra: 0 forMode: nil];
}
#elif defined(NeXT_PDO)
- (void) activityOnFileHandle: (NSNotification*)notification
{
  id fileDescriptor = [notification object];
  id runLoopMode = [[NSRunLoop currentRunLoop] currentMode];

  [fileDescriptor waitForDataInBackgroundAndNotifyForModes:
	[NSArray arrayWithObject: runLoopMode]];
  [self receivedEvent: 0 type: 0 extra: 0 forMode: nil];
}
#endif

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
  static int		clickCount = 1;
  static unsigned int	eventFlags;
  NSEvent		*e = nil;
  XEvent		xEvent;
  static NSPoint	eventLocation;
  NSWindow              *nswin;
  Window		xWin;
  NSEventType		eventType;
  NSGraphicsContext     *gcontext;
  float                 deltaX;
  float                 deltaY;

  /* FIXME: How do you guarentee a context is associated with an event? */
  gcontext = GSCurrentContext();

  // loop and grab all of the events from the X queue
  while (XPending(dpy) > 0)
    {
      XNextEvent(dpy, &xEvent);

#ifdef USE_XIM
      if (XFilterEvent(&xEvent, None)) 
	{
	  NSDebugLLog(@"NSKeyEvent", @"Event filtered (by XIM?)\n");
	  continue;
	}
#endif

      switch (xEvent.type)
	{
	  // mouse button events
	case ButtonPress:
	  NSDebugLLog(@"NSEvent", @"%d ButtonPress: \
		  xEvent.xbutton.time %u timeOfLastClick %u \n",
		      xEvent.xbutton.window, xEvent.xbutton.time,
		      generic.lastClick);
	  /*
	       * hardwired test for a double click
	       *
	       * For multiple clicks, the clicks must remain in the same
	       * region of the same window and must occur in a limited time.
	       *
	       * default time of 300 should be user set;
	       * perhaps the movement of 3 should also be a preference?
	       */
	  {
	    BOOL	incrementCount = YES;

#define	CLICK_TIME	300
#define	CLICK_MOVE	3
	    if (xEvent.xbutton.time
		>= (unsigned long)(generic.lastClick + CLICK_TIME))
	      incrementCount = NO;
	    else if (generic.lastClickWindow != xEvent.xbutton.window)
	      incrementCount = NO;
	    else if ((generic.lastClickX - xEvent.xbutton.x) > CLICK_MOVE)
	      incrementCount = NO;
	    else if ((generic.lastClickX - xEvent.xbutton.x) < -CLICK_MOVE)
	      incrementCount = NO;
	    else if ((generic.lastClickY - xEvent.xbutton.y) > CLICK_MOVE)
	      incrementCount = NO;
	    else if ((generic.lastClickY - xEvent.xbutton.y) < -CLICK_MOVE)
	      incrementCount = NO;

	    if (incrementCount == YES)
	      {
		clickCount++;
	      }
	    else
	      {
		/*
		 * Not a multiple-click, so we must set the stored
		 * location of the click to the new values and
		 * reset the counter.
		 */
		clickCount = 1;
		generic.lastClickWindow = xEvent.xbutton.window;
		generic.lastClickX = xEvent.xbutton.x;
		generic.lastClickY = xEvent.xbutton.y;
	      }
	  }
	  generic.lastClick = xEvent.xbutton.time;
	  generic.lastTime = generic.lastClick;

	  if (xEvent.xbutton.button == generic.lMouse)
	    eventType = NSLeftMouseDown;
	  else if (xEvent.xbutton.button == generic.rMouse
		   && generic.rMouse != 0)
	    eventType = NSRightMouseDown;
	  else if (xEvent.xbutton.button == generic.mMouse
		   && generic.mMouse != 0)
	    eventType = NSOtherMouseDown;
	  else if (xEvent.xbutton.button == generic.upMouse
		   && generic.upMouse != 0)
	    {
	      deltaY = 1.;
	      eventType = NSScrollWheel;
	    }
	  else if (xEvent.xbutton.button == generic.downMouse
		   && generic.downMouse != 0)
	    {
	      deltaY = -1.;
	      eventType = NSScrollWheel;
	    }
	  else
	    {
	      break;		/* Unknown button */
	    }

	  eventFlags = process_modifier_flags(xEvent.xbutton.state);
	  // if pointer is grabbed use grab window
	  xWin = (grabWindow == 0) ? xEvent.xbutton.window : grabWindow;
	  if (cWin == 0 || xWin != cWin->ident)
	    cWin = [XGServer _windowForXWindow: xWin];
	  if (cWin == 0)
	    break;
	  eventLocation.x = xEvent.xbutton.x;
	  eventLocation.y = NSHeight(cWin->xframe)-xEvent.xbutton.y;

	  if (generic.flags.useWindowMakerIcons == 1)
	    {
	      /*
	       * We must hand over control of our icon/miniwindow
	       * to Window Maker.
		   */
	      if ((cWin->win_attrs.window_style
		   & (NSMiniWindowMask | NSIconWindowMask)) != 0
		  && eventType == NSLeftMouseDown && clickCount == 1)
		{
		  if (cWin->parent == None)
		    break;
		  xEvent.xbutton.window = cWin->parent;
		  XUngrabPointer(dpy, CurrentTime);
		  XSendEvent(dpy, cWin->parent, True,
			     ButtonPressMask, &xEvent );
		  XFlush(dpy);
		  break;
		}
	    }

	  // create NSEvent
	  e = [NSEvent mouseEventWithType: eventType
		       location: eventLocation
		       modifierFlags: eventFlags
		       timestamp: (NSTimeInterval)generic.lastClick
		       windowNumber: cWin->number
		       context: gcontext
		       eventNumber: xEvent.xbutton.serial
		       clickCount: clickCount
		       pressure: 1.0
		       buttonNumber: 0 /* FIXME */
		       deltaX: 0.
		       deltaY: deltaY
		       deltaZ: 0.];
	  break;

	case ButtonRelease:
	  NSDebugLLog(@"NSEvent", @"%d ButtonRelease\n",
		      xEvent.xbutton.window);
	  generic.lastTime = xEvent.xbutton.time;
	  if (xEvent.xbutton.button == generic.lMouse)
	    eventType = NSLeftMouseUp;
	  else if (xEvent.xbutton.button == generic.rMouse
		   && generic.rMouse != 0)
	    eventType = NSRightMouseUp;
	  else if (xEvent.xbutton.button == generic.mMouse
		   && generic.mMouse != 0)
	    eventType = NSOtherMouseUp;
	  else
	    {
	      // we ignore release of scrollUp or scrollDown
	      break;		/* Unknown button */
	    }

	  eventFlags = process_modifier_flags(xEvent.xbutton.state);
	  // if pointer is grabbed use grab window
	  xWin = (grabWindow == 0) ? xEvent.xbutton.window : grabWindow;
	  if (cWin == 0 || xWin != cWin->ident)
	    cWin = [XGServer _windowForXWindow: xWin];
	  if (cWin == 0)
	    break;
	  eventLocation.x = xEvent.xbutton.x;
	  eventLocation.y = NSHeight(cWin->xframe)-xEvent.xbutton.y;

	  e = [NSEvent mouseEventWithType: eventType
		       location: eventLocation
		       modifierFlags: eventFlags
		       timestamp: (NSTimeInterval)generic.lastTime
		       windowNumber: cWin->number
		       context: gcontext
		       eventNumber: xEvent.xbutton.serial
		       clickCount: clickCount
		       pressure: 1.0
		       buttonNumber: 0	/* FIXMME */
		       deltaX: 0.0
		       deltaY: 0.0
		       deltaZ: 0.0];
	  break;

	case CirculateNotify:
	  NSDebugLLog(@"NSEvent", @"%d CirculateNotify\n",
		      xEvent.xcirculate.window);
	  break;

	case CirculateRequest:
	  NSDebugLLog(@"NSEvent", @"%d CirculateRequest\n",
		      xEvent.xcirculaterequest.window);
	  break;

	case ClientMessage:
	  {
	    NSTimeInterval time;
	    DndClass dnd = xdnd ();
                
	    NSDebugLLog(@"NSEvent", @"%d ClientMessage\n",
			xEvent.xclient.window);
	    if (cWin == 0 || xEvent.xclient.window != cWin->ident)
	      cWin = [XGServer _windowForXWindow: xEvent.xclient.window];
	    if (cWin == 0)
	      break;
	    if (xEvent.xclient.message_type == generic.protocols_atom)
	      {
		generic.lastTime = (Time)xEvent.xclient.data.l[1];
		NSDebugLLog(@"NSEvent", @"WM Protocol - %s\n",
			    XGetAtomName(dpy, xEvent.xclient.data.l[0]));

		if (xEvent.xclient.data.l[0] == generic.delete_win_atom)
		  {
		    /*
		     * WM is asking us to close a window
		     */
		    eventLocation = NSMakePoint(0,0);
		    e = [NSEvent otherEventWithType: NSAppKitDefined
				 location: eventLocation
				 modifierFlags: 0
				 timestamp: 0
				 windowNumber: cWin->number
				 context: gcontext
				 subtype: GSAppKitWindowClose
				 data1: 0
				 data2: 0];
		  }
		else if (xEvent.xclient.data.l[0]
			 == generic.miniaturize_atom)
		  {
		    eventLocation = NSMakePoint(0,0);
		    e = [NSEvent otherEventWithType: NSAppKitDefined
				 location: eventLocation
				 modifierFlags: 0
				 timestamp: 0
				 windowNumber: cWin->number
				 context: gcontext
				 subtype: GSAppKitWindowMiniaturize
				 data1: 0
				 data2: 0];
		  }
		else if (xEvent.xclient.data.l[0]
			 == generic.take_focus_atom)
		  {
		    int win;
		    NSPoint p;
		    gswindow_device_t *w = 0;

		    /*
		     * WM is asking us to take the keyboard focus
		     */
		    NSDebugLLog(@"Focus", @"check focus: %d",
				cWin->number);
		    p = [self mouseLocationOnScreen: -1 window:(void *)&win];
		    if (win == 0)
		      {
			/*
			 * If we can't locate the window under the mouse,
			 * assume an existing window.
			 */
			nswin = [NSApp keyWindow];
			if (nswin == nil)
			  {
			    nswin = [NSApp mainWindow];
			  }
			if (nswin != nil)
			  {
			    win = [nswin windowNumber];
			  }
		      }
		    w = [XGServer _windowWithTag: win];
		    if (w != 0)
		      {
			cWin = w;
		      }
		    nswin = [NSApp keyWindow];
		    if (nswin == nil
			|| [nswin windowNumber] != cWin->number)
		      {
			generic.desiredFocusWindow = 0;
			generic.focusRequestNumber = 0;
			eventLocation = NSMakePoint(0,0);
			e = [NSEvent otherEventWithType:NSAppKitDefined
				     location: eventLocation
				     modifierFlags: 0
				     timestamp: 0
				     windowNumber: cWin->number
				     context: gcontext
				     subtype: GSAppKitWindowFocusIn
				     data1: 0
				     data2: 0];
		      }
		    if (nswin != nil
			&& [nswin windowNumber] == cWin->number)
		      {
			/*
			 * We reassert our desire to have input
			 * focus in our existing key window.
			 */
			[self setinputstate: GSTitleBarKey 
			                   : [nswin windowNumber]];
			[self setinputfocus: [nswin windowNumber]];
		      }
		  }
	      }
	    else if (xEvent.xclient.message_type == dnd.XdndEnter)
	      {
		Window source;

		NSDebugLLog(@"NSDragging", @"  XdndEnter message\n");
		source = XDND_ENTER_SOURCE_WIN(&xEvent);
		eventLocation = NSMakePoint(0,0);
		e = [NSEvent otherEventWithType: NSAppKitDefined
			     location: eventLocation
			     modifierFlags: 0
			     timestamp: 0
			     windowNumber: cWin->number
			     context: gcontext
			     subtype: GSAppKitDraggingEnter
			     data1: source
			     data2: 0];
		/* If this is a non-local drag, set the dragInfo */
		if ([XGServer _windowForXWindow: source] == NULL)
		  {
		    [[XGDragView sharedDragView] setupDragInfoFromXEvent:
						   &xEvent];
		  }
	      }
	    else if (xEvent.xclient.message_type == dnd.XdndPosition)
	      {
		Window		source;
		Atom		action;
		NSDragOperation	operation;

		NSDebugLLog(@"NSDragging", @"  XdndPosition message\n");
		source = XDND_POSITION_SOURCE_WIN(&xEvent);
		eventLocation.x = XDND_POSITION_ROOT_X(&xEvent) - 
		  NSMinX(cWin->xframe);
		eventLocation.y = XDND_POSITION_ROOT_Y(&xEvent) - 
		  NSMinY(cWin->xframe);
		eventLocation.y = NSHeight(cWin->xframe) - 
		  eventLocation.y;
		time = XDND_POSITION_TIME(&xEvent);
		action = XDND_POSITION_ACTION(&xEvent);
		operation = GSDragOperationForAction(action);
		e = [NSEvent otherEventWithType: NSAppKitDefined
			     location: eventLocation
			     modifierFlags: 0
			     timestamp: time
			     windowNumber: cWin->number
			     context: gcontext
			     subtype: GSAppKitDraggingUpdate
			     data1: source
			     data2: operation];
		/* If this is a non-local drag, update the dragInfo */
		if ([XGServer _windowForXWindow: source] == NULL)
		  {
		    [[XGDragView sharedDragView] updateDragInfoFromEvent:
						   e];
		  }
	      }
	    else if (xEvent.xclient.message_type == dnd.XdndStatus)
	      {
		Window		target;
		Atom		action;
		NSDragOperation	operation;

		NSDebugLLog(@"NSDragging", @"  XdndStatus message\n");
		target = XDND_STATUS_TARGET_WIN(&xEvent);
		eventLocation = NSMakePoint(0, 0);
		if (XDND_STATUS_WILL_ACCEPT (&xEvent))
		  {
		    action = XDND_STATUS_ACTION(&xEvent);
		  }
		else
		  {
		    action = NSDragOperationNone;
		  }
                    
		operation = GSDragOperationForAction(action);
		e = [NSEvent otherEventWithType: NSAppKitDefined
			     location: eventLocation
			     modifierFlags: 0
			     timestamp: 0
			     windowNumber: cWin->number
			     context: gcontext
			     subtype: GSAppKitDraggingStatus
			     data1: target
			     data2: operation];
	      }
	    else if (xEvent.xclient.message_type == dnd.XdndLeave)
	      {
		Window	source;

		NSDebugLLog(@"NSDragging", @"  XdndLeave message\n");
		source = XDND_LEAVE_SOURCE_WIN(&xEvent);
		eventLocation = NSMakePoint(0, 0);
		e = [NSEvent otherEventWithType: NSAppKitDefined
			     location: eventLocation
			     modifierFlags: 0
			     timestamp: 0
			     windowNumber: cWin->number
			     context: gcontext
			     subtype: GSAppKitDraggingExit
			     data1: 0
			     data2: 0];
		/* If this is a non-local drag, reset the dragInfo */
		if ([XGServer _windowForXWindow: source] == NULL)
		  {
		    [[XGDragView sharedDragView] resetDragInfo];
		  }
	      }
	    else if (xEvent.xclient.message_type == dnd.XdndDrop)
	      {
		Window	source;

		NSDebugLLog(@"NSDragging", @"  XdndDrop message\n");
		source = XDND_DROP_SOURCE_WIN(&xEvent);
		eventLocation = NSMakePoint(0, 0);
		time = XDND_DROP_TIME(&xEvent);
		e = [NSEvent otherEventWithType: NSAppKitDefined
			     location: eventLocation
			     modifierFlags: 0
			     timestamp: time
			     windowNumber: cWin->number
			     context: gcontext
			     subtype: GSAppKitDraggingDrop
			     data1: source
			     data2: 0];
	      }
	    else if (xEvent.xclient.message_type == dnd.XdndFinished)
	      {
		Window	target;

		NSDebugLLog(@"NSDragging", @"  XdndFinished message\n");
		target = XDND_FINISHED_TARGET_WIN(&xEvent);
		eventLocation = NSMakePoint(0, 0);
		e = [NSEvent otherEventWithType: NSAppKitDefined
			     location: eventLocation
			     modifierFlags: 0
			     timestamp: 0
			     windowNumber: cWin->number
			     context: gcontext
			     subtype: GSAppKitDraggingFinished
			     data1: target
			     data2: 0];
	      }
	  }
	  break;

	case ColormapNotify:
	  // colormap attribute
	  NSDebugLLog(@"NSEvent", @"%d ColormapNotify\n",
		      xEvent.xcolormap.window);
	  break;

	      // the window has been resized, change the width and height
	      // and update the window so the changes get displayed
	case ConfigureNotify:
	  NSDebugLLog(@"NSEvent", @"%d ConfigureNotify "
		      @"x:%d y:%d w:%d h:%d b:%d %c", xEvent.xconfigure.window,
		      xEvent.xconfigure.x, xEvent.xconfigure.y,
		      xEvent.xconfigure.width, xEvent.xconfigure.height,
		      xEvent.xconfigure.border_width,
		      xEvent.xconfigure.send_event ? 'T' : 'F');
	  if (cWin == 0 || xEvent.xconfigure.window != cWin->ident)
	    cWin = [XGServer _windowForXWindow:xEvent.xconfigure.window];
	  /*
	   * Ignore events for unmapped windows.
		 */
	  if (cWin != 0 && cWin->map_state == IsViewable)
	    {
	      NSRect	   r, x, n, h;
	      NSTimeInterval ts = (NSTimeInterval)generic.lastMotion;

	      /*
	       * Get OpenStep frame coordinates from X frame.
	       * If it's not from the window mmanager, ignore x and y.
	       */
	      r = cWin->xframe;
	      if (xEvent.xconfigure.send_event == 0)
		{
		  x = NSMakeRect(r.origin.x, r.origin.y,
				 xEvent.xconfigure.width, xEvent.xconfigure.height);
		}
	      else
		{
		  x = NSMakeRect(xEvent.xconfigure.x, 
				 xEvent.xconfigure.y,
				 xEvent.xconfigure.width, 
				 xEvent.xconfigure.height);
		  cWin->xframe.origin = x.origin;
		}
	      n = [self _XFrameToOSFrame: x for: cWin];
	      NSDebugLLog(@"Moving", 
			  @"Update win %d:\n   original:%@\n   new:%@",
			  cWin->number, NSStringFromRect(r), 
			  NSStringFromRect(x));
	      /*
	       * Set size hints info to be up to date with new size.
	       */
	      h = [self _OSFrameToXHints: n for: cWin];
	      cWin->siz_hints.width = h.size.width;
	      cWin->siz_hints.height = h.size.height;
	      //if (xEvent.xconfigure.send_event != 0)
	      {
		cWin->siz_hints.x = h.origin.x;
		cWin->siz_hints.y = h.origin.y;
	      }

	      /*
	       * create GNUstep event(s)
	       */
	      if (!NSEqualSizes(r.size, x.size))
		{
		  /* Resize events move the origin. There's no goo
		     place to pass this info back, so we put it in
		     the event location field */
		  e = [NSEvent otherEventWithType: NSAppKitDefined
			       location: n.origin
			       modifierFlags: eventFlags
			       timestamp: ts
			       windowNumber: cWin->number
			       context: gcontext
			       subtype: GSAppKitWindowResized
			       data1: n.size.width
			       data2: n.size.height];
		}
	      if (!NSEqualPoints(r.origin, x.origin))
		{
		  if (e != nil)
		    {
		      [event_queue addObject: e];
		    }
		  e = [NSEvent otherEventWithType: NSAppKitDefined
			       location: eventLocation
			       modifierFlags: eventFlags
			       timestamp: ts
			       windowNumber: cWin->number
			       context: gcontext
			       subtype: GSAppKitWindowMoved
			       data1: n.origin.x
			       data2: n.origin.y];
		}
	    }
	  break;

	      // same as ConfigureNotify but we get this event
	      // before the change has actually occurred
	case ConfigureRequest:
	  NSDebugLLog(@"NSEvent", @"%d ConfigureRequest\n",
		      xEvent.xconfigurerequest.window);
	  break;

	      // a window has been created
	case CreateNotify:
	  NSDebugLLog(@"NSEvent", @"%d CreateNotify\n",
		      xEvent.xcreatewindow.window);
	  break;

	      // a window has been destroyed
	case DestroyNotify:
	  NSDebugLLog(@"NSEvent", @"%d DestroyNotify\n",
		      xEvent.xdestroywindow.window);
	  break;

	      // when the pointer enters a window
	case EnterNotify:
	  NSDebugLLog(@"NSEvent", @"%d EnterNotify\n",
		      xEvent.xcrossing.window);
	  break;
		
	      // when the pointer leaves a window
	case LeaveNotify:
	  NSDebugLLog(@"NSEvent", @"%d LeaveNotify\n",
		      xEvent.xcrossing.window);
	  if (cWin == 0 || xEvent.xcrossing.window != cWin->ident)
	    cWin = [XGServer _windowForXWindow: xEvent.xcrossing.window];
	  if (cWin == 0)
	    break;
	  eventLocation = NSMakePoint(-1,-1);
	  e = [NSEvent otherEventWithType: NSAppKitDefined
		       location: eventLocation
		       modifierFlags: 0
		       timestamp: 0
		       windowNumber: cWin->number
		       context: gcontext
		       subtype: GSAppKitWindowLeave
		       data1: 0
		       data2: 0];
	  break;

	      // the visibility of a window has changed
	case VisibilityNotify:
	  NSDebugLLog(@"NSEvent", @"%d VisibilityNotify %d\n", 
		      xEvent.xvisibility.window, xEvent.xvisibility.state);
	  if (cWin == 0 || xEvent.xvisibility.window != cWin->ident)
	    cWin=[XGServer _windowForXWindow:xEvent.xvisibility.window];
	  if (cWin != 0)
	    cWin->visibility = xEvent.xvisibility.state;
	  break;

	  // a portion of the window has become visible and
	  // we must redisplay it
	case Expose:
	  NSDebugLLog(@"NSEvent", @"%d Expose\n",
		      xEvent.xexpose.window);
	  {
	    if (cWin == 0 || xEvent.xexpose.window != cWin->ident)
	      cWin=[XGServer _windowForXWindow:xEvent.xexpose.window];
	    if (cWin != 0)
	      {
		XRectangle rectangle;

		rectangle.x = xEvent.xexpose.x;
		rectangle.y = xEvent.xexpose.y;
		rectangle.width = xEvent.xexpose.width;
		rectangle.height = xEvent.xexpose.height;
		NSDebugLLog(@"NSEvent", @"Expose frame %d %d %d %d\n",
			    rectangle.x, rectangle.y,
			    rectangle.width, rectangle.height);
		[self _addExposedRectangle: rectangle : cWin->number];

		if (xEvent.xexpose.count == 0)
		  [self _processExposedRectangles: cWin->number];
	      }
	    break;
	  }

	  // keyboard focus entered a window
	case FocusIn:
	  NSDebugLLog(@"NSEvent", @"%d FocusIn\n",
		      xEvent.xfocus.window);
	  if (cWin == 0 || xEvent.xfocus.window != cWin->ident)
	    cWin=[XGServer _windowForXWindow:xEvent.xfocus.window];
	  if (cWin == 0)
	    break;
	  NSDebugLLog(@"Focus", @"%d got focus on %d\n",
		      xEvent.xfocus.window, cWin->number);
	  generic.currentFocusWindow = cWin->number;
	  if (xEvent.xfocus.serial == generic.focusRequestNumber)
	    {
	      /*
	       * This is a response to our own request - so we mark the
	       * request as complete.
		     */
	      generic.desiredFocusWindow = 0;
	      generic.focusRequestNumber = 0;
	    }
	  break;

	      // keyboard focus left a window
	case FocusOut:
	  {
	    Window	fw;
	    int		rev;

	    /*
	     * See where the focus has moved to -
	     * If it has gone to 'none' or 'PointerRoot' then 
	     * it's not one of ours.
	     * If it has gone to our root window - use the icon window.
	     * If it has gone to a window - we see if it is one of ours.
	     */
	    XGetInputFocus(xEvent.xfocus.display, &fw, &rev);
	    NSDebugLLog(@"NSEvent", @"%d FocusOut\n",
			xEvent.xfocus.window);
	    cWin = [XGServer _windowForXWindow: fw];
	    if (cWin == 0)
	      {
		cWin = [XGServer _windowForXParent: fw];
	      }
	    if (cWin == 0)
	      {
		nswin = nil;
	      }
	    else
	      {
		nswin = GSWindowWithNumber(cWin->number);
	      }
	    if (nswin == nil)
	      {
		[NSApp deactivate]; 
	      }
	    cWin = [XGServer _windowForXWindow: xEvent.xfocus.window];
	    NSDebugLLog(@"Focus", @"%d lost focus on %d\n",
			xEvent.xfocus.window, cWin->number);
	  }
	  break;

	case GraphicsExpose:
	  NSDebugLLog(@"NSEvent", @"%d GraphicsExpose\n",
		      xEvent.xexpose.window);
	  break;

	case NoExpose:
	  NSDebugLLog(@"NSEvent", @"NoExpose\n");
	  break;

	  // window is moved because of a change in the size of its parent
	case GravityNotify:
	  NSDebugLLog(@"NSEvent", @"%d GravityNotify\n",
		      xEvent.xgravity.window);
	  break;

	      // a key has been pressed
	case KeyPress:
	  NSDebugLLog(@"NSEvent", @"%d KeyPress\n",
		      xEvent.xkey.window);
	  generic.lastTime = xEvent.xkey.time;
	  e = process_key_event (&xEvent, self, NSKeyDown);
	  break;

	      // a key has been released
	case KeyRelease:
	  NSDebugLLog(@"NSEvent", @"%d KeyRelease\n",
		      xEvent.xkey.window);
	  generic.lastTime = xEvent.xkey.time;
	  e = process_key_event (&xEvent, self, NSKeyUp);
	  break;

	      // reports the state of the keyboard when pointer or
	      // focus enters a window
	case KeymapNotify:
	  NSDebugLLog(@"NSEvent", @"%d KeymapNotify\n",
		      xEvent.xkeymap.window);
	  // Check if control is pressed 
	  _control_pressed = 0;
	  if (_control_keycodes[0] 
	      && check_modifier (&xEvent, _control_keycodes[0]))
	    {
	      _control_pressed |= 1;
	    }
	  if (_control_keycodes[1] 
	      && check_modifier (&xEvent, _control_keycodes[1]))
	    {
	      _control_pressed |= 2;
	    }
	  // Check if command is pressed
	  _command_pressed = 0;
	  if (_command_keycodes[0] 
	      && check_modifier (&xEvent, _command_keycodes[0]))
	    {
	      _command_pressed |= 1;
	    }
	  if (_command_keycodes[1] 
	      && check_modifier (&xEvent, _command_keycodes[2]))
	    {
	      _command_pressed = 2;
	    }
	  // Check if alt is pressed
	  _alt_pressed = 0;
	  if (_alt_keycodes[0] 
	      && check_modifier (&xEvent, _alt_keycodes[0]))
	    {
	      _alt_pressed |= 1;
	    }
	  if (_alt_keycodes[1] 
	      && check_modifier (&xEvent, _alt_keycodes[1]))
	    {
	      _alt_pressed |= 2;
	    }
	  break;

	      // when a window changes state from ummapped to
	      // mapped or vice versa
	case MapNotify:
	  NSDebugLLog(@"NSEvent", @"%d MapNotify\n",
		      xEvent.xmap.window);
	  if (cWin == 0 || xEvent.xmap.window != cWin->ident)
	    cWin=[XGServer _windowForXWindow:xEvent.xmap.window];
	  if (cWin != 0)
	    {
	      cWin->map_state = IsViewable;
	      /*
	       * if the window that was just mapped wants the input
	       * focus, re-do the request.
	       */
	      if (generic.desiredFocusWindow == cWin->number
		  && generic.focusRequestNumber == 0)
		{
		  [self setinputfocus: cWin->number];
		}
	      /*
	       * Make sure that the newly mapped window displays.
	       */
	      nswin = GSWindowWithNumber(cWin->number);
	      [nswin update];
	    }
	  break;

	      // Window is no longer visible.
	case UnmapNotify:
	  NSDebugLLog(@"NSEvent", @"%d UnmapNotify\n",
		      xEvent.xunmap.window);
	  if (cWin == 0 || xEvent.xunmap.window != cWin->ident)
	    cWin=[XGServer _windowForXWindow:xEvent.xunmap.window];
	  if (cWin != 0)
	    {
	      cWin->map_state = IsUnmapped;
	      cWin->visibility = -1;
	    }
	  break;

	      // like MapNotify but occurs before the request is carried out
	case MapRequest:
	  NSDebugLLog(@"NSEvent", @"%d MapRequest\n",
		      xEvent.xmaprequest.window);
	  break;

	      // keyboard or mouse mapping has been changed by another client
	case MappingNotify:
	  NSDebugLLog(@"NSEvent", @"%d MappingNotify\n",
		      xEvent.xmapping.window);
	  if ((xEvent.xmapping.request == MappingModifier) 
	      || (xEvent.xmapping.request == MappingKeyboard))
	    {
	      XRefreshKeyboardMapping (&xEvent.xmapping);
	      set_up_num_lock ();
	    }
	  break;

	case MotionNotify:
	  NSDebugLLog(@"NSMotionEvent", @"%d MotionNotify - %d %d\n",
		      xEvent.xmotion.window, xEvent.xmotion.x, xEvent.xmotion.y);
	  {
	    unsigned int	state;

	    /*
	     * Compress motion events to avoid flooding.
	     */
	    while (XPending(xEvent.xmotion.display))
	      {
		XEvent	peek;

		XPeekEvent(xEvent.xmotion.display, &peek);
		if (peek.type == MotionNotify
		    && xEvent.xmotion.window == peek.xmotion.window
		    && xEvent.xmotion.subwindow == peek.xmotion.subwindow)
		  {
		    XNextEvent(xEvent.xmotion.display, &xEvent);
		  }
		else
		  {
		    break;
		  }
	      }

	    generic.lastMotion = xEvent.xmotion.time;
	    generic.lastTime = generic.lastMotion;
	    state = xEvent.xmotion.state;
	    if (state & generic.lMouseMask)
	      {
		eventType = NSLeftMouseDragged;
	      }
	    else if (state & generic.rMouseMask)
	      {
		eventType = NSRightMouseDragged;
	      }
	    else if (state & generic.mMouseMask)
	      {
		eventType = NSOtherMouseDragged;
	      }
	    else
	      {
		eventType = NSMouseMoved;
	      }

	    eventFlags = process_modifier_flags(state);
	    // if pointer is grabbed use grab window instead
	    xWin = (grabWindow == 0)
	      ? xEvent.xmotion.window : grabWindow;
	    if (cWin == 0 || xWin != cWin->ident)
	      cWin = [XGServer _windowForXWindow: xWin];
	    if (cWin == 0)
	      break;

	    deltaX = - eventLocation.x;
	    deltaY = - eventLocation.y;
	    eventLocation = NSMakePoint(xEvent.xmotion.x,
					NSHeight(cWin->xframe) 
- xEvent.xmotion.y);
	    deltaX += eventLocation.x;
	    deltaY += eventLocation.y;

	    e = [NSEvent mouseEventWithType: eventType
			 location: eventLocation
			 modifierFlags: eventFlags
			 timestamp: (NSTimeInterval)generic.lastTime
			 windowNumber: cWin->number
			 context: gcontext
			 eventNumber: xEvent.xbutton.serial
			 clickCount: clickCount
			 pressure: 1.0
			 buttonNumber: 0 /* FIXME */
			 deltaX: deltaX
			 deltaY: deltaY
			 deltaZ: 0];
	    break;
	  }

	  // a window property has changed or been deleted
	case PropertyNotify:
	  NSDebugLLog(@"NSEvent", @"%d PropertyNotify - '%s'\n",
		      xEvent.xproperty.window,
		      XGetAtomName(dpy, xEvent.xproperty.atom));
	  break;

	      // a client successfully reparents a window
	case ReparentNotify:
	  NSDebugLLog(@"NSEvent", @"%d ReparentNotify - offset %d %d\n",
		      xEvent.xreparent.window, xEvent.xreparent.x,
		      xEvent.xreparent.y);
	  if (cWin == 0 || xEvent.xreparent.window != cWin->ident)
	    cWin=[XGServer _windowForXWindow:xEvent.xreparent.window];
	  if (cWin != 0)
	    {
	      Window parent = xEvent.xreparent.parent;
	      Window new_parent = parent;

	      /* Get the WM offset info which we hope is the same
		 for all parented windows */
	      if (parent != cWin->root
		  && (xEvent.xreparent.x || xEvent.xreparent.y))
		{
		  generic.parent_offset.x = xEvent.xreparent.x;
		  generic.parent_offset.y = xEvent.xreparent.y;
		  /* FIXME: if this has changed, go through window
		     list and fix up hints */
		}

	      // Some window manager e.g. KDE2 put in multiple windows,
	      // so we have to find the right parent, closest to root
	      /* FIXME: This section of code has caused problems with
		 certain users. An X error occurs in XQueryTree and
		 later a seg fault in XFree. It's 'commented' out for
		 now unless you set the default 'GSDoubleParentWindows'
	      */
	      if (generic.flags.doubleParentWindow) {
		while (new_parent && (new_parent != cWin->root)) {
		  Window root;
		  Window *children;
		  int nchildren;
	    
		  parent = new_parent;
		  NSLog(@"QueryTree window is %d (root %d cwin root %d)", 
			parent, root, cWin->root);
		  if (!XQueryTree(dpy, parent, &root, &new_parent, 
				  &children, &nchildren))
		    {
		      new_parent = None;
		      if (children)
			{
			  NSLog(@"Bad pointer from failed X call?");
			  children = 0;
			}
		    }
		  if (children)
		    {
		      XFree(children);
		    }
		  if (new_parent && new_parent != cWin->root)
		    {
		      XWindowAttributes wattr;
		      XGetWindowAttributes(dpy, parent, &wattr);
		      if (wattr.x || wattr.y)
			{
			  generic.parent_offset.x = wattr.x;
			  generic.parent_offset.y = wattr.y;
			}
		    }
		} /* while */
	      } /* generic.flags.doubleParentWindow */
	      cWin->parent = parent;
	    }
	  break;

	      // another client attempts to change the size of a window
	case ResizeRequest:
	  NSDebugLLog(@"NSEvent", @"%d ResizeRequest\n",
		      xEvent.xresizerequest.window);
	  break;

	      // events dealing with the selection
	case SelectionClear:
	  NSDebugLLog(@"NSEvent", @"%d SelectionClear\n",
		      xEvent.xselectionclear.window);
	  break;

	case SelectionNotify:
	  NSDebugLLog(@"NSEvent", @"%d SelectionNotify\n",
		      xEvent.xselection.requestor);
	  break;

	case SelectionRequest:
	  NSDebugLLog(@"NSEvent", @"%d SelectionRequest\n",
		      xEvent.xselectionrequest.requestor);
	  break;

	      // We shouldn't get here unless we forgot to trap an event above
	default:
	  NSLog(@"Received an untrapped event\n");
	  break;
	}
      if (e)
	[event_queue addObject: e];
      e = nil;
    }
}

// Return the key_code corresponding to the user defaults string
// Return 1 (which is an invalid keycode) if the user default 
// is not set
static KeyCode
default_key_code (Display *display, NSUserDefaults *defaults, 
		  NSString *aString)
{
  NSString *keySymString;
  KeySym a_key_sym;
  
  keySymString = [defaults stringForKey: aString];
  if (keySymString == nil)
    return 1; 
  
  a_key_sym = XStringToKeysym ([keySymString cString]);
  if (a_key_sym == NoSymbol)
    {
      // This is not necessarily an error.
      // If you want on purpose to disable a key, 
      // set its default to 'NoSymbol'.
      NSLog (@"KeySym %@ not found; disabling %@", keySymString, aString);
      return 0;
    }
  
  return XKeysymToKeycode (display, a_key_sym);
}

// This function should be called before any keyboard event is dealed with.
static void
initialize_keyboard (void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  Display *display = [XGServer currentXDisplay];

  // Initialize Control
  _control_keycodes[0] = default_key_code (display, defaults, 
					   @"GSFirstControlKey");
  if (_control_keycodes[0] == 1) // No User Default Set
    _control_keycodes[0] = XKeysymToKeycode (display, XK_Control_L);

  _control_keycodes[1] = default_key_code (display, defaults, 
					   @"GSSecondControlKey");
  if (_control_keycodes[1] == 1) 
    _control_keycodes[1] = XKeysymToKeycode (display, XK_Control_R);

  // Initialize Command
  _command_keycodes[0] = default_key_code (display, defaults, 
					      @"GSFirstCommandKey");
  if (_command_keycodes[0] == 1) 
    _command_keycodes[0] = XKeysymToKeycode (display, XK_Alt_L);

  _command_keycodes[1] = default_key_code (display, defaults, 
					   @"GSSecondCommandKey");
  if (_command_keycodes[1] == 1) 
    _command_keycodes[1] = 0;  

  // Initialize Alt
  _alt_keycodes[0] = default_key_code (display, defaults, 
				       @"GSFirstAlternateKey");
  if (_alt_keycodes[0] == 1) 
    {
      _alt_keycodes[0] = XKeysymToKeycode (display, XK_Alt_R);
      if (_alt_keycodes[0] == 0)
	_alt_keycodes[0] = XKeysymToKeycode (display, XK_Mode_switch);
    }
  _alt_keycodes[1] = default_key_code (display, defaults, 
				       @"GSSecondAlternateKey");
  if (_alt_keycodes[1] == 1) 
    _alt_keycodes[1] = 0;  
  
  set_up_num_lock ();
  
  _is_keyboard_initialized = YES;
}


static void
set_up_num_lock (void)
{
  XModifierKeymap *modifier_map;
  int i, j;
  unsigned int modifier_masks[8] = 
  {
    ShiftMask, LockMask, ControlMask, Mod1Mask, 
    Mod2Mask, Mod3Mask, Mod4Mask, Mod5Mask
  };
  Display *display = [XGServer currentXDisplay];
  KeyCode _num_lock_keycode;
  
  // Get NumLock keycode
  _num_lock_keycode = XKeysymToKeycode (display, XK_Num_Lock);
  if (_num_lock_keycode == 0)
    {
      // Weird.  There is no NumLock in this keyboard.
      _num_lock_mask = 0; 
      return;
    }

  // Get the current modifier mapping
  modifier_map = XGetModifierMapping (display);
  
  // Scan the modifiers for NumLock
  for (j = 0; j < 8; j++)
    for (i = 0; i < (modifier_map->max_keypermod); i++)
      {
	if ((modifier_map->modifiermap)[i + j*modifier_map->max_keypermod] 
	    == _num_lock_keycode)
	  {
	    _num_lock_mask = modifier_masks[j];
	    XFreeModifiermap (modifier_map);
	    return;
	  }
      }
  // Weird.  NumLock is not among the modifiers
  _num_lock_mask = 0;
  XFreeModifiermap (modifier_map);
  return;
}

static BOOL
keysym_is_X_modifier (KeySym keysym)
{
  switch (keysym)
    {
    case XK_Num_Lock: 
    case XK_Shift_L:    
    case XK_Shift_R:    
    case XK_Caps_Lock:  
    case XK_Shift_Lock: 
      return YES;

    default:
      return NO;
    }
}

static NSEvent*
process_key_event (XEvent* xEvent, XGServer* context, NSEventType eventType)
{
  NSString	*keys, *ukeys;
  KeySym	keysym;
  NSPoint	eventLocation;
  unsigned short keyCode;
  unsigned int	eventFlags;
  unichar       unicode;
  NSEvent	*event = nil;
  NSEventType   originalType;
  gswindow_device_t *window;
  int		control_key = 0;
  int		command_key = 0;
  int		alt_key = 0;
  
  if (_is_keyboard_initialized == NO)
    initialize_keyboard ();

  /* Process NSFlagsChanged events.  We can't use a switch because we
     are not comparing to constants. Make sure keyCode is not 0 since
     XIM events can potentially return 0 keyCodes. */
  keyCode = ((XKeyEvent *)xEvent)->keycode;
  if (keyCode)
    {
      if (keyCode == _control_keycodes[0]) 
	{
	  control_key = 1;
	}
      else if (keyCode == _control_keycodes[1])
	{
	  control_key = 2;
	}
      else if (keyCode == _command_keycodes[0]) 
	{
	  command_key = 1;
	}
      else if (keyCode == _command_keycodes[1]) 
	{
	  command_key = 2;
	}
      else if (keyCode == _alt_keycodes[0]) 
	{
	  alt_key = 1;
	}
      else if (keyCode == _alt_keycodes[1]) 
	{
	  alt_key = 2;
	}
    }

  originalType = eventType;
  if (control_key || command_key || alt_key)
    {
      eventType = NSFlagsChanged;
      if (xEvent->xkey.type == KeyPress)
	{
	  if (control_key)
	    _control_pressed |= control_key;
	  if (command_key)
	    _command_pressed |= command_key;
	  if (alt_key)
	    _alt_pressed |= alt_key;
	}
      else if (xEvent->xkey.type == KeyRelease)
	{
	  if (control_key)
	    _control_pressed &= ~control_key;
	  if (command_key)
	    _command_pressed &= ~command_key;
	  if (alt_key)
	    _alt_pressed &= ~alt_key;
	}
    }

  /* Process modifiers */
  eventFlags = process_modifier_flags (xEvent->xkey.state);

  /* Process location */
  window = [XGServer _windowWithTag: [[NSApp keyWindow] windowNumber]];
  eventLocation.x = xEvent->xbutton.x;
  if (window)
    {
      eventLocation.y = window->siz_hints.height - xEvent->xbutton.y;
    }
  else
    {
      eventLocation.y = xEvent->xbutton.y;
    }
    
  /* Process characters */
  keys = [context->inputServer lookupStringForEvent: (XKeyEvent *)xEvent
		 window: window
		 keysym: &keysym];

  /* Process keycode */
  //ximKeyCode = XKeysymToKeycode([XGServer currentXDisplay],keysym);

  /* Add NSNumericPadKeyMask if the key is in the KeyPad */
  if (IsKeypadKey (keysym))
    eventFlags = eventFlags | NSNumericPadKeyMask;

  NSDebugLLog (@"NSKeyEvent", @"keysym=%d, keyCode=%d flags=%d (state=%d)",
	      keysym, keyCode, eventFlags, ((XKeyEvent *)xEvent)->state);
  
  /* Add NSFunctionKeyMask if the key is a function or a misc function key */
  /* We prefer not to do this and do it manually in process_char
     because X's idea of what is a function key seems to be different
     from OPENSTEP's one */
  /* if (IsFunctionKey (keysym) || IsMiscFunctionKey (keysym))
       eventFlags = eventFlags | NSFunctionKeyMask; */

  /* First, check to see if the key event if a Shift, NumLock or
     CapsLock or ShiftLock keypress/keyrelease.  If it is, then use a
     NSFlagsChanged event type.  This will generate a NSFlagsChanged
     event each time you press/release a shift key, even if the flags
     haven't actually changed.  I don't see this as a problem - if we
     didn't, the shift keypress/keyrelease event would never be
     notified to the application.

     NB - to know if shift was pressed, we need to check the X keysym
     - it doesn't work to compare the X modifier flags of this
     keypress X event with the ones of the previous one, because when
     you press Shift, the X shift keypress event has the *same* X
     modifiers flags as the X keypress event before it - only
     keypresses coming *after* the shift keypress will get a different
     X modifier mask.  */
  if (keysym_is_X_modifier (keysym))
    {
      eventType = NSFlagsChanged;
    }

  /* Now we get the unicode character for the pressed key using 
     our internal table */
  unicode = process_char (keysym, &eventFlags);

  /* If that didn't work, we use what X gave us */
  if (unicode != 0)
    {
      keys = [NSString stringWithCharacters: &unicode  length: 1];
    }

  // Now the same ignoring modifiers, except Shift, ShiftLock, NumLock.
  xEvent->xkey.state = (xEvent->xkey.state & (ShiftMask | LockMask 
					      | _num_lock_mask));
  ukeys = [context->inputServer lookupStringForEvent: (XKeyEvent *)xEvent
		  window: window
		  keysym: &keysym];
  unicode = process_char (keysym, &eventFlags);
  if (unicode != 0)
    {
      ukeys = [NSString stringWithCharacters: &unicode  length: 1];
    }

  event = [NSEvent keyEventWithType: eventType
		   location: eventLocation
		   modifierFlags: eventFlags
		   timestamp: (NSTimeInterval)xEvent->xkey.time
		   windowNumber: window->number
		   context: GSCurrentContext()
		   characters: keys
		   charactersIgnoringModifiers: ukeys
		   isARepeat: NO /* isARepeat can't be supported with X */
		   keyCode: keyCode];

  return event;
}

static unichar 
process_char (KeySym keysym, unsigned *eventModifierFlags)
{
  switch (keysym)
    {
      /* NB: Whatever is explicitly put in this conversion table takes
	 precedence over what is returned by XLookupString.  Not sure
	 this is a good idea for latin-1 character input. */
    case XK_Return:       return NSCarriageReturnCharacter;
    case XK_KP_Enter:     return NSEnterCharacter;
    case XK_Linefeed:     return NSFormFeedCharacter;
    case XK_Tab:          return NSTabCharacter;
#ifdef XK_XKB_KEYS
    case XK_ISO_Left_Tab: return NSTabCharacter;
#endif
      /* FIXME: The following line ? */
    case XK_Escape:       return 0x1b;
    case XK_BackSpace:    return NSBackspaceKey;

      /* The following keys need to be reported as function keys */
#define XGPS_FUNCTIONKEY \
*eventModifierFlags = *eventModifierFlags | NSFunctionKeyMask;

    case XK_F1:           XGPS_FUNCTIONKEY return NSF1FunctionKey;
    case XK_F2:           XGPS_FUNCTIONKEY return NSF2FunctionKey;
    case XK_F3:           XGPS_FUNCTIONKEY return NSF3FunctionKey;
    case XK_F4:           XGPS_FUNCTIONKEY return NSF4FunctionKey;
    case XK_F5:           XGPS_FUNCTIONKEY return NSF5FunctionKey;
    case XK_F6:           XGPS_FUNCTIONKEY return NSF6FunctionKey;
    case XK_F7:           XGPS_FUNCTIONKEY return NSF7FunctionKey;
    case XK_F8:           XGPS_FUNCTIONKEY return NSF8FunctionKey;
    case XK_F9:           XGPS_FUNCTIONKEY return NSF9FunctionKey;
    case XK_F10:          XGPS_FUNCTIONKEY return NSF10FunctionKey;
    case XK_F11:          XGPS_FUNCTIONKEY return NSF11FunctionKey;
    case XK_F12:          XGPS_FUNCTIONKEY return NSF12FunctionKey;
    case XK_F13:          XGPS_FUNCTIONKEY return NSF13FunctionKey;
    case XK_F14:          XGPS_FUNCTIONKEY return NSF14FunctionKey;
    case XK_F15:          XGPS_FUNCTIONKEY return NSF15FunctionKey;
    case XK_F16:          XGPS_FUNCTIONKEY return NSF16FunctionKey;
    case XK_F17:          XGPS_FUNCTIONKEY return NSF17FunctionKey;
    case XK_F18:          XGPS_FUNCTIONKEY return NSF18FunctionKey;
    case XK_F19:          XGPS_FUNCTIONKEY return NSF19FunctionKey;
    case XK_F20:          XGPS_FUNCTIONKEY return NSF20FunctionKey;
    case XK_F21:          XGPS_FUNCTIONKEY return NSF21FunctionKey;
    case XK_F22:          XGPS_FUNCTIONKEY return NSF22FunctionKey;
    case XK_F23:          XGPS_FUNCTIONKEY return NSF23FunctionKey;
    case XK_F24:          XGPS_FUNCTIONKEY return NSF24FunctionKey;
    case XK_F25:          XGPS_FUNCTIONKEY return NSF25FunctionKey;
    case XK_F26:          XGPS_FUNCTIONKEY return NSF26FunctionKey;
    case XK_F27:          XGPS_FUNCTIONKEY return NSF27FunctionKey;
    case XK_F28:          XGPS_FUNCTIONKEY return NSF28FunctionKey;
    case XK_F29:          XGPS_FUNCTIONKEY return NSF29FunctionKey;
    case XK_F30:          XGPS_FUNCTIONKEY return NSF30FunctionKey;
    case XK_F31:          XGPS_FUNCTIONKEY return NSF31FunctionKey;
    case XK_F32:          XGPS_FUNCTIONKEY return NSF32FunctionKey;
    case XK_F33:          XGPS_FUNCTIONKEY return NSF33FunctionKey;
    case XK_F34:          XGPS_FUNCTIONKEY return NSF34FunctionKey;
    case XK_F35:          XGPS_FUNCTIONKEY return NSF35FunctionKey;
    case XK_Delete:       XGPS_FUNCTIONKEY return NSDeleteFunctionKey;
    case XK_Home:         XGPS_FUNCTIONKEY return NSHomeFunctionKey;  
    case XK_Left:         XGPS_FUNCTIONKEY return NSLeftArrowFunctionKey;
    case XK_Right:        XGPS_FUNCTIONKEY return NSRightArrowFunctionKey;
    case XK_Up:           XGPS_FUNCTIONKEY return NSUpArrowFunctionKey;  
    case XK_Down:         XGPS_FUNCTIONKEY return NSDownArrowFunctionKey;
//  case XK_Prior:        XGPS_FUNCTIONKEY return NSPrevFunctionKey;
//  case XK_Next:         XGPS_FUNCTIONKEY return NSNextFunctionKey;
    case XK_End:          XGPS_FUNCTIONKEY return NSEndFunctionKey; 
    case XK_Begin:        XGPS_FUNCTIONKEY return NSBeginFunctionKey;
    case XK_Select:       XGPS_FUNCTIONKEY return NSSelectFunctionKey;
    case XK_Print:        XGPS_FUNCTIONKEY return NSPrintFunctionKey;  
    case XK_Execute:      XGPS_FUNCTIONKEY return NSExecuteFunctionKey;
    case XK_Insert:       XGPS_FUNCTIONKEY return NSInsertFunctionKey; 
    case XK_Undo:         XGPS_FUNCTIONKEY return NSUndoFunctionKey;
    case XK_Redo:         XGPS_FUNCTIONKEY return NSRedoFunctionKey;
    case XK_Menu:         XGPS_FUNCTIONKEY return NSMenuFunctionKey;
    case XK_Find:         XGPS_FUNCTIONKEY return NSFindFunctionKey;
    case XK_Help:         XGPS_FUNCTIONKEY return NSHelpFunctionKey;
    case XK_Break:        XGPS_FUNCTIONKEY return NSBreakFunctionKey;
    case XK_Mode_switch:  XGPS_FUNCTIONKEY return NSModeSwitchFunctionKey;
    case XK_Scroll_Lock:  XGPS_FUNCTIONKEY return NSScrollLockFunctionKey;
    case XK_Pause:        XGPS_FUNCTIONKEY return NSPauseFunctionKey;
    case XK_Clear:        XGPS_FUNCTIONKEY return NSClearDisplayFunctionKey;
#ifndef NeXT
    case XK_Page_Up:      XGPS_FUNCTIONKEY return NSPageUpFunctionKey;
    case XK_Page_Down:    XGPS_FUNCTIONKEY return NSPageDownFunctionKey;
    case XK_Sys_Req:      XGPS_FUNCTIONKEY return NSSysReqFunctionKey;  
#endif
    case XK_KP_F1:        XGPS_FUNCTIONKEY return NSF1FunctionKey;
    case XK_KP_F2:        XGPS_FUNCTIONKEY return NSF2FunctionKey;
    case XK_KP_F3:        XGPS_FUNCTIONKEY return NSF3FunctionKey;
    case XK_KP_F4:        XGPS_FUNCTIONKEY return NSF4FunctionKey;
#ifndef NeXT
    case XK_KP_Home:      XGPS_FUNCTIONKEY return NSHomeFunctionKey;
    case XK_KP_Left:      XGPS_FUNCTIONKEY return NSLeftArrowFunctionKey;
    case XK_KP_Up:        XGPS_FUNCTIONKEY return NSUpArrowFunctionKey;  
    case XK_KP_Right:     XGPS_FUNCTIONKEY return NSRightArrowFunctionKey;
    case XK_KP_Down:      XGPS_FUNCTIONKEY return NSDownArrowFunctionKey; 
//  case XK_KP_Prior:     return NSPrevFunctionKey;      
    case XK_KP_Page_Up:   XGPS_FUNCTIONKEY return NSPageUpFunctionKey;    
//  case XK_KP_Next:      return NSNextFunctionKey;      
    case XK_KP_Page_Down: XGPS_FUNCTIONKEY return NSPageDownFunctionKey;  
    case XK_KP_End:       XGPS_FUNCTIONKEY return NSEndFunctionKey;       
    case XK_KP_Begin:     XGPS_FUNCTIONKEY return NSBeginFunctionKey;     
    case XK_KP_Insert:    XGPS_FUNCTIONKEY return NSInsertFunctionKey;    
    case XK_KP_Delete:    XGPS_FUNCTIONKEY return NSDeleteFunctionKey;    
#endif
#undef XGPS_FUNCTIONKEY
    default:              return 0;
    }
}

// process_modifier_flags() determines which modifier keys (Command, Control,
// Shift,  and so forth) were held down while the event occured.
static unsigned int
process_modifier_flags(unsigned int state)
{
  unsigned int eventModifierFlags = 0;

  if (state & ShiftMask)
    eventModifierFlags = eventModifierFlags | NSShiftKeyMask;

  if (state & LockMask)
    eventModifierFlags = eventModifierFlags | NSShiftKeyMask;

  if (_control_pressed != 0)
    eventModifierFlags = eventModifierFlags | NSControlKeyMask;

  if (_command_pressed != 0)
    eventModifierFlags = eventModifierFlags | NSCommandKeyMask;

  if (_alt_pressed != 0)
    eventModifierFlags = eventModifierFlags | NSAlternateKeyMask;
  
  // Other modifiers ignored for now. 

  return eventModifierFlags;
}

- (NSDate*) timedOutEvent: (void*)data
                     type: (RunLoopEventType)type
                  forMode: (NSString*)mode
{
  return nil;
}

/* Drag and Drop */
- (id <NSDraggingInfo>)dragInfo
{
  return [XGDragView sharedDragView];
}

@end

@implementation XGServer (XSync)
- (BOOL) xSyncMap: (void*)windowHandle
{
  gswindow_device_t	*window = (gswindow_device_t*)windowHandle;

  /*
   * if the window is not mapped, make sure we have sent all requests to the
   * X-server, it may be that our mapping request was buffered.
   */
  if (window->map_state != IsViewable)
    {
      XSync(dpy, False);
      [self receivedEvent: 0 type: 0 extra: 0 forMode: nil];
    }
  /*
   * If the window is still not mapped, it may be that the window-manager
   * intercepted our mapping request, and hasn't dealt with it yet.
   * Listen for input for up to a second, in the hope of getting the mapping.
   */
  if (window->map_state != IsViewable)
    {
      NSDate	*d = [NSDate dateWithTimeIntervalSinceNow: 1.0];
      NSRunLoop	*l = [NSRunLoop currentRunLoop];
      NSString	*m = [l currentMode];

      while (window->map_state != IsViewable && [d timeIntervalSinceNow] > 0)
        {
	  [l runMode: m beforeDate: d];
	}
    }
  if (window->map_state != IsViewable)
    {
      NSLog(@"Window still not mapped a second after mapping request made");
      return NO;
    }
  return YES;
}
@end

@implementation XGServer (X11Ops)

/*
 * Return mouse location in base coords ignoring the event loop
 */
- (NSPoint) mouselocation
{
  return [self mouseLocationOnScreen: defScreen window: NULL];
}

- (NSPoint) mouseLocationOnScreen: (int)screen window: (int *)win
{
  Window	rootWin;
  Window	childWin;
  int		currentX;
  int		currentY;
  int		winX;
  int		winY;
  unsigned	mask;
  BOOL		ok;
  NSPoint       p;
  int           height;
  int           screen_number;
  
  screen_number = (screen >= 0) ? screen : defScreen;
  ok = XQueryPointer (dpy, [self xDisplayRootWindowForScreen: screen_number],
    &rootWin, &childWin, &currentX, &currentY, &winX, &winY, &mask);
  p = NSMakePoint(-1,-1);
  if (ok == False)
    {
      /* Mouse not on the specified screen_number */
      XWindowAttributes attribs;
      ok = XGetWindowAttributes(dpy, rootWin, &attribs);
      if (ok == False)
	{
	  return p;
	}
      screen_number = XScreenNumberOfScreen(attribs.screen);
      if (screen >= 0 && screen != screen_number)
	{
	  /* Mouse not on the requred screen, return an invalid point */
	  return p;
	}
      height = attribs.height;
    }
  else
    height = DisplayHeight(dpy, screen_number);
  p = NSMakePoint(currentX, height - currentY);
  if (win)
    {
      gswindow_device_t *w = 0;
      w = [XGServer _windowForXWindow: childWin];
      if (w == NULL)
	w = [XGServer _windowForXParent: childWin];
      if (w)
	*win = w->number;
      else
	*win = 0;
    }
  return p;
}

- (NSEvent*) getEventMatchingMask: (unsigned)mask
		       beforeDate: (NSDate*)limit
			   inMode: (NSString*)mode
			  dequeue: (BOOL)flag
{
  [self receivedEvent: 0 type: 0 extra: 0 forMode: nil];
  return [super getEventMatchingMask: mask
			  beforeDate: limit
			      inMode: mode
			     dequeue: flag];
}

- (void) discardEventsMatchingMask: (unsigned)mask
		       beforeEvent: (NSEvent*)limit
{
  [self receivedEvent: 0 type: 0 extra: 0 forMode: nil];
  [super discardEventsMatchingMask: mask
		       beforeEvent: limit];
}

@end


