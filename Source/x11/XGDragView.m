/*
   XGDragView - Drag and Drop code for X11 backends.

   Copyright (C) 1998,1999,2001 Free Software Foundation, Inc.

   Created by: Wim Oudshoorn <woudshoo@xs4all.nl>
   Date: Nov 2001

   Written by:  Adam Fedor <fedor@gnu.org>
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

#include <AppKit/NSApplication.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>

#include <Foundation/NSDebug.h>
#include <Foundation/NSThread.h>

#include "x11/XGServer.h"
#include "x11/XGServerWindow.h"
#include "x11/XGDragView.h"

/* Size of the dragged window */
#define	DWZ	48

#define XDPY  [XGServer currentXDisplay]

#define SLIDE_TIME_STEP   .02   /* in seconds */
#define SLIDE_NR_OF_STEPS 20  

#define	dragWindev [XGServer _windowWithTag: [_window windowNumber]]
#define	XX(P)	(P.x)
#define	XY(P)	(DisplayHeight(XDPY, dragWindev->screen) - P.y)

@interface XGRawWindow : NSWindow
@end

@interface NSCursor (BackendPrivate)
- (void *)_cid;
- (void) _setCid: (void *)val;
@end

// --- DRAG AND DROP SUPPORT  (XDND) -----------------------------------

/*
 * This will get initialized when we declare a window that will
 * accept dragging or if we start a dragging ourself. Up to than
 * even the dragging messages are not defined.
 */
static DndClass dnd;
static BOOL     xDndInitialized = NO;

void
GSEnsureDndIsInitialized (void)
{
  if (xDndInitialized == NO)
    {
      xDndInitialized = YES;
      xdnd_init (&dnd, XDPY);
    }
}


DndClass xdnd (void)
{
  return dnd;			// FIX ME rename with private desig
}


Atom 
GSActionForDragOperation(unsigned int op)
{
  Atom xaction;
  if (op == NSDragOperationAll)
    xaction = dnd.XdndActionPrivate;
  else if (op & NSDragOperationCopy)
    xaction = dnd.XdndActionCopy;
  else if (op & NSDragOperationLink)
    xaction = dnd.XdndActionLink;
  else if (op & NSDragOperationGeneric)
    xaction = dnd.XdndActionCopy;
  else if (op & NSDragOperationPrivate)
    xaction = dnd.XdndActionPrivate;
  else 
    xaction = None;
  return xaction;
}


NSDragOperation
GSDragOperationForAction(Atom xaction)
{
  NSDragOperation action;
  if (xaction == dnd.XdndActionCopy)
    action = NSDragOperationCopy;
  else if (xaction == dnd.XdndActionMove)
    action = NSDragOperationCopy;
  else if (xaction == dnd.XdndActionLink) 
    action = NSDragOperationLink;
  else if (xaction == dnd.XdndActionAsk) 
    action = NSDragOperationGeneric;
  else if (xaction == dnd.XdndActionPrivate) 
    action = NSDragOperationPrivate;
  else
    action = NSDragOperationNone;
  return action;
}

// The result of this function must be freed by the caller
static inline
Atom *
mimeTypeForPasteboardType(Display *xDisplay, NSZone *zone, NSArray *types)
{
  Atom	*typelist;
  int	count = [types count];
  int	i;

  typelist = NSZoneMalloc(zone, (count+1) * sizeof(Atom));
  for (i = 0; i < count; i++)
    {
      NSString	*mime;

      mime = [types objectAtIndex: i];
      mime = [NSPasteboard mimeTypeForPasteboardType: mime];
      typelist[i] = XInternAtom(xDisplay, [mime cString], False);
    }
  typelist[count] = 0;

  return typelist;
}



@implementation XGDragView

static	XGDragView	*sharedDragView = nil;

+ (XGDragView*) sharedDragView
{
  if (sharedDragView == nil)
    {
      GSEnsureDndIsInitialized ();
      sharedDragView = [XGDragView new];
    }
  return sharedDragView;
}

+ (Class) windowClass
{
  return [XGRawWindow class];
}

/*
 * External drag operation
 */
- (void) setupDragInfoFromXEvent: (XEvent *)xEvent
{
  // Start a dragging session from another application
  dragSource = nil;
  destExternal = YES;
  operationMask = NSDragOperationAll;

  ASSIGN(dragPasteboard, [NSPasteboard pasteboardWithName: NSDragPboard]);
}

- (void) updateDragInfoFromEvent: (NSEvent*)event
{
  // Store the drag info, so that we can send status messages as response 
  destWindow = [event window];
  dragPoint = [event locationInWindow];
  dragSequence = [event timestamp];
  dragMask = [event data2];
}

- (void) resetDragInfo
{
  DESTROY(dragPasteboard);
}

/*
 * Local drag operation
 */

- (void) dragImage: (NSImage*)anImage
		at: (NSPoint)screenLocation
	    offset: (NSSize)initialOffset
	     event: (NSEvent*)event
	pasteboard: (NSPasteboard*)pboard
	    source: (id)sourceObject
	 slideBack: (BOOL)slideFlag
{
  typelist = mimeTypeForPasteboardType (XDPY, [self zone], [pboard types]);
  [super dragImage: anImage
		at: screenLocation
	    offset: initialOffset
	     event: event
	pasteboard: pboard
	    source: sourceObject
	 slideBack: slideFlag];
  NSZoneFree([self zone], typelist);
  typelist = NULL;
}

- (void) postDragEvent: (NSEvent *)theEvent
{
  gswindow_device_t	*window;

  window = [XGServer _windowWithTag: [theEvent windowNumber]];
  if ([theEvent subtype] == GSAppKitDraggingStatus)
    {
      NSDragOperation action = [theEvent data2];
      
      if (destExternal)
	{
	  Atom xaction;
	  
	  xaction = GSActionForDragOperation(action);
	  xdnd_send_status(&dnd, 
			   [theEvent data1],
			   window->ident,
			   (action != NSDragOperationNone),
			   0,
			   0, 0, 0, 0,
			   xaction);
	}
      else
        {
	  if (action != targetMask)
	    {
	      targetMask = action;
	      [self _setCursor];
	    }
	}
    }
  else if ([theEvent subtype] == GSAppKitDraggingFinished)
    {
      if (destExternal)
	{
	  xdnd_send_finished(&dnd, 
			     [theEvent data1],
			     window->ident,
			     0);
	}
    }
  else
    {
      NSDebugLLog(@"NSDragging", @"Internal: unhandled post external event");
    }
}


/*
  The dragging support works by hijacking the NSApp event loop.

  - this function loops until the dragging operation is finished
    and consumes all NSEvents during the drag operation.

  - It sets up periodic events.  The drawing and communication
    with DraggingSource and DraggingTarget is handled in the
    periodic event code.  The use of periodic events is purely
    a performance improvement.  If no periodic events are used
    the system can not process them all on time.
    At least on a 333Mhz laptop, using fairly simple
    DraggingTarget code.

  PROBLEMS:

  - No autoreleasePools are created.  So long drag operations can consume
    memory

  - It seems that sometimes a periodic event get lost.
*/
- (void) _handleDrag: (NSEvent*)theEvent
{
  Display	*xDisplay = [XGServer currentXDisplay]; // Caching some often used values.
  NSWindow	*eWindow = [theEvent window];   // Use eWindow for coordination transformation
  NSDate	*theDistantFuture = [NSDate distantFuture];
  NSImage       *dragImage = [dragCell image];
  unsigned int	eventMask = NSLeftMouseDownMask | NSLeftMouseUpMask
    | NSLeftMouseDraggedMask | NSMouseMovedMask
    | NSPeriodicMask | NSAppKitDefinedMask | NSFlagsChangedMask;
  NSPoint       startPoint;   // Storing values, to restore after we have finished.
  NSCursor      *cursorBeforeDrag = [NSCursor currentCursor];
  BOOL          refreshedView = NO;

  // Unset the target window  
  targetWindowRef = 0;
  targetMask = NSDragOperationAll;

  isDragging = YES;
  startPoint = [eWindow convertBaseToScreen: [theEvent locationInWindow]];

  // Notify the source that dragging has started
  if ([dragSource respondsToSelector:
      @selector(draggedImage:beganAt:)])
    {
      [dragSource draggedImage: dragImage
		  beganAt: startPoint];
    }

  // --- Setup up the masks for the drag operation ---------------------
  if ([dragSource respondsToSelector:
    @selector(ignoreModifierKeysWhileDragging)]
    && [dragSource ignoreModifierKeysWhileDragging])
    {
      operationMask = NSDragOperationIgnoresModifiers;
    }
  else
    {
      operationMask = 0;
      [self _updateOperationMask: theEvent];
    }

  dragMask = [dragSource draggingSourceOperationMaskForLocal: !destExternal];
  
  // --- Setup the event loop ------------------------------------------
  [self _updateAndMoveImageToCorrectPosition];
  [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.03];

  // --- Loop that handles all events during drag operation -----------
  while ([theEvent type] != NSLeftMouseUp)
    {
      [self _handleEventDuringDragging: theEvent];
      
      // FIXME: Force the redisplay of the source view after the drag.  
      // Temporary fix for bug#11352.
      if(refreshedView == NO)
	{
	  [dragSource display];
	  refreshedView = YES;
	}

      theEvent = [NSApp nextEventMatchingMask: eventMask
				    untilDate: theDistantFuture
				       inMode: NSEventTrackingRunLoopMode
				      dequeue: YES];
    }

  // --- Event loop for drag operation stopped ------------------------
  [NSEvent stopPeriodicEvents];
  [self _updateAndMoveImageToCorrectPosition];

  NSDebugLLog(@"NSDragging", @"dnd ending %x\n", targetWindowRef);

  // --- Deposit the drop ----------------------------------------------
  if ((targetWindowRef != (int) None)
    && ((targetMask & dragMask & operationMask) != NSDragOperationNone))
    {
      // FIXME: (22 Jan 2002)
      // We remove the dragged image from the screen before 
      // sending the dnd drop event to the destination.
      // This code should actually be rewritten, because
      // the depositing of the drop consist of three steps
      //  - prepareForDragOperation
      //  - performDragOperation
      //  - concludeDragOperation.
      // The dragged image should be removed from the screen
      // between the prepare and the perform operation.
      // The three steps are now executed in the NSWindow class
      // and the NSWindow class does not have access to
      // the image.  (at least not through the xdnd protocol)
      [_window orderOut: nil];
      [cursorBeforeDrag set];
      NSDebugLLog(@"NSDragging", @"sending dnd drop\n");
      if (!destExternal)
	{
	  [self _sendLocalEvent: GSAppKitDraggingDrop
			 action: 0
		       position: NSZeroPoint
		      timestamp: CurrentTime
		       toWindow: destWindow];
	}
      else
	{
	  if (targetWindowRef == dragWindev->root)
	    {
	      // FIXME There is an xdnd extension for root drop
	    }
	  xdnd_send_drop(&dnd, targetWindowRef, dragWindev->ident, CurrentTime);
	}

      //CHECKME: Why XSync here?
      XSync(xDisplay, False);
      if ([dragSource respondsToSelector:
	@selector(draggedImage:endedAt:deposited:)])
	{
          NSPoint point;
          
	  point = [theEvent locationInWindow];
	  point = [[theEvent window] convertBaseToScreen: point];
	  [dragSource draggedImage: dragImage
			   endedAt: point
			 deposited: YES];
	}
    }
  else
    {
      if (slideBack)
        {
          [self slideDraggedImageTo: startPoint];
        }
      [_window orderOut: nil];
      [cursorBeforeDrag set];
      
      if ([dragSource respondsToSelector:
	@selector(draggedImage:endedAt:deposited:)])
	{
          NSPoint point;
          
	  point = [theEvent locationInWindow];
	  point = [[theEvent window] convertBaseToScreen: point];
	  [dragSource draggedImage: dragImage
			   endedAt: point
			 deposited: NO];
	}
    }
  isDragging = NO;
}


/*
 * Handle the events for the event loop during drag and drop
 */
- (void) _handleEventDuringDragging: (NSEvent *) theEvent
{
  switch ([theEvent type])
    {
    case  NSAppKitDefined:
      {
        GSAppKitSubtype	sub = [theEvent subtype];
        
        switch (sub)
        {
        case GSAppKitWindowMoved:
        case GSAppKitWindowResized:
          /*
           * Keep window up-to-date with its current position.
           */
          [NSApp sendEvent: theEvent];
          break;
          
        case GSAppKitDraggingStatus:
          NSDebugLLog(@"NSDragging", @"got GSAppKitDraggingStatus\n");
          if ((Window)[theEvent data1] == targetWindowRef)
            {
              unsigned int newTargetMask = [theEvent data2];

              if (newTargetMask != targetMask)
                {
                  targetMask = newTargetMask;
                  [self _setCursor];
                }
            }
          break;
          
        case GSAppKitDraggingFinished:
          NSLog(@"Internal: got GSAppKitDraggingFinished out of seq");
          break;
          
        case GSAppKitWindowFocusIn:
	case GSAppKitWindowFocusOut:
	case GSAppKitWindowLeave:
	case GSAppKitWindowEnter:
          break;
          
        default:
          NSLog(@"Internal: dropped NSAppKitDefined (%d) event", sub);
          break;
        }
      }
      break;
      
    case NSMouseMoved:
    case NSLeftMouseDragged:
    case NSLeftMouseDown:
    case NSLeftMouseUp:
      newPosition = [[theEvent window] convertBaseToScreen:
	[theEvent locationInWindow]];
      break;
    case NSFlagsChanged:
      if ([self _updateOperationMask: theEvent])
        {
	  // If flags change, send update to allow
	  // destination to take note.
	  if (destWindow)
            {
              [self _sendLocalEvent: GSAppKitDraggingUpdate
		    action: dragMask & operationMask
		    position: newPosition
		    timestamp: CurrentTime
		    toWindow: destWindow];
	    }
	  else
	    {
	      xdnd_send_position(&dnd, targetWindowRef, dragWindev->ident,
		GSActionForDragOperation(dragMask & operationMask),
		XX(newPosition), XY(newPosition), CurrentTime);
	    }
          [self _setCursor];
        }
      break;
    case NSPeriodic:
      if (newPosition.x != dragPosition.x || newPosition.y != dragPosition.y) 
        {
          [self _updateAndMoveImageToCorrectPosition];
        }
      break;
    default:
      NSLog(@"Internal: dropped event (%d) during dragging", [theEvent type]);
    }
}
  
/*
 * This method will move the drag image and update all associated data
 */
- (void) _updateAndMoveImageToCorrectPosition
{
  NSWindow		*oldDragWindow;
  BOOL                   oldDragExternal;
  gswindow_device_t	*dwindev;
  Window                 mouseWindow; 
  BOOL                   changeCursor = NO;
            
  //--- Move drag image to the new position -----------------------------------

  [self _moveDraggedImageToNewPosition];
  
  //--- Store old values -----------------------------------------------------
            
  oldDragWindow = destWindow;
  oldDragExternal = destExternal;
            
            
  //--- Determine target XWindow ---------------------------------------------

  mouseWindow = [self _xWindowAcceptingDnDunderX: XX(dragPosition) Y: XY(dragPosition)];

  //--- Determine target NSWindow --------------------------------------------

  dwindev = [XGServer _windowForXWindow: mouseWindow];
            
  if (dwindev != 0)
    {
      destWindow = GSWindowWithNumber(dwindev->number);
    }
  else
    {
      destWindow = nil;
    }

  // If we have are not hovering above a window that we own
  // we are dragging to an external application.
            
  destExternal = (mouseWindow != (Window) None) && (destWindow == nil);
            
  if (destWindow)
    {
      dragPoint = [destWindow convertScreenToBase: dragPosition];
    }
            
  NSDebugLLog(@"NSDragging", @"mouse window %x\n", mouseWindow);
            
            
            
  //--- send exit message if necessary -------------------------------------
            
  if ((mouseWindow != targetWindowRef) && targetWindowRef)
    {
      /* If we change windows and the old window is dnd aware, we send an
         dnd exit */
                
      NSDebugLLog(@"NSDragging", @"sending dnd exit\n");
                
      if (oldDragWindow)   
        {
          [self _sendLocalEvent: GSAppKitDraggingExit
			 action: dragMask & operationMask
		       position: NSZeroPoint
                      timestamp: dragSequence
		       toWindow: oldDragWindow];
        }  
      else
        {  
          xdnd_send_leave(&dnd, targetWindowRef, dragWindev->ident);
        }
    }

  //  Reset drag mask when we switch from external to internal or back
  //
  if (oldDragExternal != destExternal)
    {
      unsigned int newMask;

      newMask = [dragSource draggingSourceOperationMaskForLocal: destExternal];
      if (newMask != dragMask)
        {
          dragMask = newMask;
          changeCursor = YES;
        }
    }


  if (mouseWindow == targetWindowRef && targetWindowRef)  
    { // same window, sending update
      NSDebugLLog(@"NSDragging", @"sending dnd pos\n");
      if (destWindow)
        {
          [self _sendLocalEvent: GSAppKitDraggingUpdate
			 action: dragMask & operationMask
		       position: dragPosition
		      timestamp: CurrentTime
		       toWindow: destWindow];
        }
      else
        {
          xdnd_send_position(&dnd, targetWindowRef, dragWindev->ident,
	    GSActionForDragOperation (dragMask & operationMask),
	    XX(dragPosition), XY(dragPosition), CurrentTime);
        }
    }
  else if (mouseWindow != (Window) None)
    {
      //FIXME: We might force the cursor update here, if the
      //target wants to change the cursor.
      
      NSDebugLLog(@"NSDragging",
                  @"sending dnd enter/pos\n");
      
      if (destWindow)
        {
          [self _sendLocalEvent: GSAppKitDraggingEnter
                action: dragMask
                position:dragPosition
                timestamp: CurrentTime
                toWindow: destWindow];
        }
      else
        {
          xdnd_send_enter(&dnd, mouseWindow, dragWindev->ident, typelist);
          xdnd_send_position(&dnd, mouseWindow, dragWindev->ident,
	    GSActionForDragOperation (dragMask & operationMask),
	    XX(dragPosition), XY(dragPosition), CurrentTime);
        }
    }

  if (targetWindowRef != mouseWindow)
    {
      targetWindowRef = mouseWindow;
      changeCursor = YES;
    }
  
  if (changeCursor)
    {
      [self _setCursor];
    }
}


/*
  Search all descendents of parent and return
  X window  containing screen coordinates (x,y) that accepts drag and drop.
  -1        if we can only find the X window that we are dragging
  None      if there is no X window that accepts drag and drop.
*/
- (Window) _xWindowAcceptingDnDDescendentOf: (Window) parent 
				     underX: (int) x 
					  Y: (int) y
{
  Window *children;
  unsigned int nchildren;
  Window  result = None;
  Window  ignore, child2, root;
  Display *display = XDPY;
  XWindowAttributes attr;
  int ret_x, ret_y;

  if (parent == dragWindev->ident)
    return -1;
  
  XQueryTree(display, parent, &root, &ignore, &children, &nchildren);

  while (nchildren-- > 0)
    {
      Window child = children [nchildren];
  
      if (XGetWindowAttributes (display, child, &attr)
	&& attr.map_state == IsViewable 
	&& XTranslateCoordinates (display, root, child, x, y, &ret_x, &ret_y,
	  &child2)
	&& ret_x >= 0 && ret_x < attr.width
	&& ret_y >= 0 && ret_y < attr.height)
        {
          result = [self _xWindowAcceptingDnDDescendentOf: child
						   underX: x
							Y: y];
          if (result != (Window)-1)
            break;
        }
    }

  if (children)
    {
      XFree (children);
    } 
  if (result == (Window) None)
    {
      if (xdnd_is_dnd_aware (&dnd, parent, &dnd.dragging_version, typelist))
        {
          result = parent;
        }
    }
  
  return result;
}

/*
  Return window under the mouse that accepts drag and drop
 */
- (Window) _xWindowAcceptingDnDunderX: (int) x Y: (int) y
{
  Window result;

  result = [self _xWindowAcceptingDnDDescendentOf: dragWindev->root
					   underX: x
						Y: y];
  if (result == (Window)-1)
    return None;
  else
    return result;
}

@end



@interface XGServer (DragAndDrop)
- (void) _resetDragTypesForWindow: (NSWindow *)win;
@end


@implementation XGServer (DragAndDrop)

- (void) _resetDragTypesForWindow: (NSWindow *)win
{
  int			winNum;
  Atom			*typelist;
  gswindow_device_t	*window;
  NSCountedSet		*drag_set = [self dragTypesForWindow: win];

  winNum = [win windowNumber];
  window = [isa _windowWithTag: winNum];

  GSEnsureDndIsInitialized ();

  typelist = mimeTypeForPasteboardType(XDPY, [self zone],
				       [drag_set allObjects]);
  NSDebugLLog(@"NSDragging", @"Set types on %x to %@", 
	      window->ident, drag_set);
  xdnd_set_dnd_aware(&dnd, window->ident, typelist);

  NSZoneFree([self zone], typelist);
}

- (BOOL) addDragTypes: (NSArray*)types toWindow: (NSWindow *)win
{
  BOOL	did_add;
  int	winNum;

  did_add = [super addDragTypes: types toWindow: win];
  /* Check if window device exists */
  winNum = [win windowNumber];
  if (winNum > 0 && did_add == YES)
    {
      [self _resetDragTypesForWindow: win];
    }
  return did_add;
}

- (BOOL) removeDragTypes: (NSArray*)types fromWindow: (NSWindow *)win
{
  BOOL	did_change;
  int	winNum;

  did_change = [super removeDragTypes: types fromWindow: win];
  /* Check if window device exists. */
  winNum = [win windowNumber];
  if (winNum > 0 && did_change == YES)
    {
      [self _resetDragTypesForWindow: win];
    }
  return did_change;
}

@end




@implementation XGRawWindow

- (BOOL) canBecomeMainWindow
{
  return NO;
}

- (BOOL) canBecomeKeyWindow
{
  return NO;
}

- (void) _initDefaults
{
  [super _initDefaults];
  [self setReleasedWhenClosed: NO];
  [self setExcludedFromWindowsMenu: YES];
}

- (void) orderWindow: (NSWindowOrderingMode)place relativeTo: (int)otherWin
{
  XSetWindowAttributes winattrs;
  unsigned long valuemask;
  gswindow_device_t *window;

  [super orderWindow: place relativeTo: otherWin];

  window = [XGServer _windowWithTag: _windowNum];
  valuemask = (CWSaveUnder|CWOverrideRedirect);
  winattrs.save_under = True;
  /* Temporarily make this False? we don't handle it correctly (fedor) */
  winattrs.override_redirect = False;
  XChangeWindowAttributes (XDPY, window->ident, valuemask, &winattrs);
  [self setLevel: NSPopUpMenuWindowLevel];
}

@end
