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

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSRect winRect = {{0, 0}, {DWZ, DWZ}};
      XGRawWindow *sharedDragWindow = [XGRawWindow alloc];

      dragCell = [[NSCell alloc] initImageCell: nil];
      [dragCell setBordered: NO];
      
      [sharedDragWindow initWithContentRect: winRect
				  styleMask: NSBorderlessWindowMask
				    backing: NSBackingStoreNonretained
				      defer: NO];
      [sharedDragWindow setContentView: self];
      RELEASE(self);

      // Cache the X structure of our window
      dragWindev = [XGServer _windowWithTag: [sharedDragWindow windowNumber]];
    }

  return self;
}

- (BOOL) isDragging
{
  return isDragging;
}

- (void) dealloc
{
  [super dealloc];
  RELEASE(cursors);
}

- (void) drawRect: (NSRect)rect
{
  [dragCell drawWithFrame: [self frame] inView: self];
}


/*
 * External drag operation
 */
- (void) setupDragInfoFromXEvent: (XEvent *)xEvent
{
  // Start a dragging session from another application
  dragSource = nil;
  dragExternal = YES;
  operationMask = NSDragOperationAll;

  ASSIGN(dragPasteboard, [NSPasteboard pasteboardWithName: NSDragPboard]);
}

- (void) updateDragInfoFromEvent: (NSEvent*)event
{
  // Store the drag info, so that we can send status messages as response 
  dragWindow = [event window];
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

/*
 * TODO:
 *  - use initialOffset
 *  - use screenLocation
 */
- (void) dragImage: (NSImage*)anImage
		at: (NSPoint)screenLocation
	    offset: (NSSize)initialOffset
	     event: (NSEvent*)event
	pasteboard: (NSPasteboard*)pboard
	    source: (id)sourceObject
	 slideBack: (BOOL)slideFlag
{
  if (anImage == nil)
    {
      anImage = [NSImage imageNamed: @"common_Close"];
    }

  [dragCell setImage: anImage];

  ASSIGN(dragPasteboard, pboard);
  dragSource = RETAIN(sourceObject);
  dragSequence = [event timestamp];
  dragExternal = NO;
  slideBack = slideFlag;

  NSDebugLLog(@"NSDragging", @"Start drag with %@", [pboard types]);
  typelist = mimeTypeForPasteboardType (XDPY, [self zone], [pboard types]);
  [self _handleDrag: event];
  NSZoneFree([self zone], typelist);
  typelist = NULL;
  RELEASE(dragSource);
}

- (void) _sendLocalEvent: (GSAppKitSubtype)subtype
		  action: (NSDragOperation)action
	        position: (NSPoint)eventLocation
	       timestamp: (NSTimeInterval)time
	        toWindow: (NSWindow*)dWindow
{
  NSEvent *e;
  NSGraphicsContext *context = GSCurrentContext();
  gswindow_device_t *windev;

  windev = [XGServer _windowWithTag: [dWindow windowNumber]];
  eventLocation = NSMakePoint(eventLocation.x - NSMinX(windev->xframe),
			      eventLocation.y - NSMinY(windev->xframe));
  eventLocation.y = NSHeight(windev->xframe) - eventLocation.y;

  e = [NSEvent otherEventWithType: NSAppKitDefined
	  location: eventLocation
	  modifierFlags: 0
	  timestamp: time
	  windowNumber: windev->number
	  context: context
	  subtype: subtype
	  data1: dragWindev->ident
	  data2: action];
  [dWindow sendEvent: e];
}

- (void) postDragEvent: (NSEvent *)theEvent
{
  gswindow_device_t	*window;

  window = [XGServer _windowWithTag: [theEvent windowNumber]];
  if ([theEvent subtype] == GSAppKitDraggingStatus)
    {
      NSDragOperation action = [theEvent data2];
      
      if (dragExternal)
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
      if (dragExternal)
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
  Method to initialize the dragview before it is put on the screen.
  It only initializes the instance variables that have to do with
  moving the image over the screen and variables that are used
  to keep track where we are.

  So it is typically used just before the dragview is actually displayed.

  Pre coniditions:
  - dragCell is initialized with the image to drag.
  - typelist is initialized with the dragging types
  Post conditions:
  - all instance variables pertaining to moving the window are initialized
  - all instance variables pertaining to X-Windows  are initialized
  
 */
- (void) _setupWindow: (NSPoint) dragStart
{
  NSSize imageSize = [[dragCell image] size];
  
  offset = NSMakePoint (imageSize.width / 2.0, imageSize.height / 2.0);
  
  [_window setFrame: NSMakeRect (dragStart.x - offset.x, 
                                 dragStart.y - offset.y,
                                 imageSize.width, imageSize.height)
           display: NO];

  NSDebugLLog (@"NSDragging", @"---dragWindow: %x <- %x",
                 dragWindev->parent, dragWindev->ident);

  /* setup the wx and wy coordinates, used for moving the view around */
  wx = dragWindev->siz_hints.x;
  wy = dragWindev->siz_hints.y;

  dragPosition = dragStart;
  newPosition = dragStart;

  // Only display the image
  [GSServerForWindow(_window) restrictWindow: dragWindev->number
		    toImage: [dragCell image]];

  [_window orderFront: nil];
}


/*
  updates the operationMask by examining modifier keys
  pressed during -theEvent-.

  If the current value of operationMask == NSDragOperationIgnoresModifiers
  it will return immediately without updating the operationMask
  
  This method will return YES if the operationMask
  is changed, NO if it is still the same.
*/
- (BOOL) _updateOperationMask: (NSEvent*) theEvent
{
  unsigned int mod = [theEvent modifierFlags];
  unsigned int oldOperationMask = operationMask;

  if (operationMask == NSDragOperationIgnoresModifiers)
    {
      return NO;
    }
  
  if (mod & NSControlKeyMask)
    {
      operationMask = NSDragOperationLink;
    }
  else if (mod & NSAlternateKeyMask)
    {
      operationMask = NSDragOperationCopy;
    }
  else if (mod & NSCommandKeyMask)
    {
      operationMask = NSDragOperationGeneric;
    }
  else
    {
      operationMask = NSDragOperationAll;
    }

  return (operationMask != oldOperationMask);
}
  
/**
  _setCursor examines the state of the dragging and update
  the cursor accordingly.  It will not save the current cursor,
  if you want to keep the original you have to save it yourself.

  The code recogines 4 cursors:

  - NONE - when the source does not allow dragging
  - COPY - when the current operation is ONLY Copy
  - LINK - when the current operation is ONLY Link
  - GENERIC - all other cases

  And two colors

  - GREEN - when the target accepts the drop
  - BLACK - when the target does not accept the drop

  Note that the code to figure out which of the 4 cursor to use
  depends on the fact that

  {NSDragOperationNone, NSDragOperationCopy, NSDragOperationLink} = {0, 1, 2}
*/
- (void) _setCursor
{
  NSCursor *newCursor;
  NSString *name;
  NSString *iname;
  int       mask;

  mask = dragMask & operationMask;

  if (targetWindow)
    mask &= targetMask;

  NSDebugLLog (@"NSDragging",
               @"drag, operation, target mask = (%x, %x, %x), dnd aware = %d\n",
               dragMask, operationMask, targetMask,
               (targetWindow != (Window) None));
  
  if (cursors == nil)
    cursors = RETAIN([NSMutableDictionary dictionary]);
  
  name = nil;
  newCursor = nil;
  switch (mask)
    {
    case NSDragOperationNone:
      name = @"NoCursor";
      iname = @"common_noCursor";
      break;
    case NSDragOperationCopy:
      name = @"CopyCursor";
      iname = @"common_copyCursor";
      break;
    case NSDragOperationLink:
      name = @"LinkCursor";
      iname = @"common_linkCursor";
      break;
    case NSDragOperationGeneric:
      break;
    default:
      // FIXME: Should not happen, add warning?
      break;
    }

  if (name != nil)
    {
      newCursor = [cursors objectForKey: name];
      if (newCursor == nil)
	{
	  NSImage *image = [NSImage imageNamed: iname];
	  newCursor = [[NSCursor alloc] initWithImage: image];
	  [cursors setObject: newCursor forKey: name];
	  RELEASE(newCursor);
	}
    }
  if (newCursor == nil)
    {
      name = @"ArrowCursor";
      newCursor = [cursors objectForKey: name];
      if (newCursor == nil)
	{
	  /* Make our own arrow cursor, since we want to color it */
	  void *c;
	  
	  newCursor = [[NSCursor alloc] initWithImage: nil];
	  [GSCurrentServer() standardcursor: GSArrowCursor : &c];
	  [newCursor _setCid: c];
	  [cursors setObject: newCursor forKey: name];
	  RELEASE(newCursor);
	}
    }
  
  [newCursor set];

  if ((targetWindow != (Window) None) && mask != NSDragOperationNone)
    {
      [GSCurrentServer() setcursorcolor: [NSColor greenColor] 
		      : [NSColor blackColor] 
		      : [newCursor _cid]];
    }
  else
    {
      [GSCurrentServer() setcursorcolor: [NSColor blackColor] 
		      : [NSColor whiteColor] 
		      : [newCursor _cid]];
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
  // Caching some often used values. These values do not
  // change in this method.
  Display	*xDisplay = [XGServer currentXDisplay];
  // Use eWindow for coordination transformation
  NSWindow	*eWindow = [theEvent window];
  NSDate	*theDistantFuture = [NSDate distantFuture];
  NSImage       *dragImage = [dragCell image];
  unsigned int	eventMask = NSLeftMouseDownMask | NSLeftMouseUpMask
    | NSLeftMouseDraggedMask | NSMouseMovedMask
    | NSPeriodicMask | NSAppKitDefinedMask | NSFlagsChangedMask;

  NSPoint       startPoint;
  
  // Storing values, to restore after we have finished.
  NSCursor      *cursorBeforeDrag = [NSCursor currentCursor];
  
  // Unset the target window  
  targetWindow = 0;
  targetMask = NSDragOperationAll;

  isDragging = YES;
  startPoint = [eWindow convertBaseToScreen: [theEvent locationInWindow]];

  [self _setupWindow: startPoint];

  // Notify the source that dragging has started
  if ([dragSource respondsToSelector:
      @selector(draggedImage:beganAt:)])
    {
      [dragSource draggedImage: dragImage
		  beganAt: startPoint];
    }

  NSDebugLLog(@"NSDragging", @"Drag window X origin %d %d\n", wx, wy);
  
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

  dragMask = [dragSource draggingSourceOperationMaskForLocal: !dragExternal];
  
  // --- Setup the event loop ------------------------------------------
  [self _updateAndMoveImageToCorrectPosition];
  [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.03];

  // --- Loop that handles all events during drag operation -----------
  while ([theEvent type] != NSLeftMouseUp)
    {
      [self _handleEventDuringDragging: theEvent];

      theEvent = [NSApp nextEventMatchingMask: eventMask
				    untilDate: theDistantFuture
				       inMode: NSEventTrackingRunLoopMode
				      dequeue: YES];
    }

  // --- Event loop for drag operation stopped ------------------------
  [NSEvent stopPeriodicEvents];
  [self _updateAndMoveImageToCorrectPosition];

  NSDebugLLog(@"NSDragging", @"dnd ending %x\n", targetWindow);

  // --- Deposit the drop ----------------------------------------------
  if ((targetWindow != (Window) None)
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
      if (!dragExternal)
	{
	  [self _sendLocalEvent: GSAppKitDraggingDrop
			 action: 0
		       position: NSZeroPoint
		      timestamp: CurrentTime
		       toWindow: dragWindow];
	}
      else
	{
	  if (targetWindow == dragWindev->root)
	    {
	      // FIXME There is an xdnd extension for root drop
	    }
	  xdnd_send_drop(&dnd, targetWindow, dragWindev->ident, CurrentTime);
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
          /*
           * Keep window up-to-date with its current position.
           */
          [NSApp sendEvent: theEvent];
          break;
          
        case GSAppKitDraggingStatus:
          NSDebugLLog(@"NSDragging", @"got GSAppKitDraggingStatus\n");
          if ([theEvent data1] == targetWindow)
            {
              int newTargetMask = [theEvent data2];

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
	  if (dragWindow)
            {
              [self _sendLocalEvent: GSAppKitDraggingUpdate
		    action: dragMask & operationMask
		    position: NSMakePoint(wx + offset.x, wy + offset.y)
		    timestamp: CurrentTime
		    toWindow: dragWindow];
	    }
	  else
	    {
	      xdnd_send_position(&dnd, targetWindow, dragWindev->ident,
		GSActionForDragOperation(dragMask & operationMask),
		wx + offset.x, wy + offset.y, CurrentTime);
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
            
  oldDragWindow = dragWindow;
  oldDragExternal = dragExternal;
            
            
  //--- Determine target XWindow ---------------------------------------------
            
  mouseWindow = [self _xWindowAcceptingDnDunderX: wx + offset.x
					       Y: wy + offset.y];

  //--- Determine target NSWindow --------------------------------------------

  dwindev = [XGServer _windowForXWindow: mouseWindow];
            
  if (dwindev != 0)
    {
      dragWindow = GSWindowWithNumber(dwindev->number);
    }
  else
    {
      dragWindow = nil;
    }

  // If we have are not hovering above a window that we own
  // we are dragging to an external application.
            
  dragExternal = (mouseWindow != (Window) None) && (dragWindow == nil);
            
  if (dragWindow)
    {
      dragPoint = [dragWindow convertScreenToBase: dragPosition];
    }
            
  NSDebugLLog(@"NSDragging", @"mouse window %x\n", mouseWindow);
            
            
            
  //--- send exit message if necessary -------------------------------------
            
  if ((mouseWindow != targetWindow) && targetWindow)
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
          xdnd_send_leave(&dnd, targetWindow, dragWindev->ident);
        }
    }

  //  Reset drag mask when we switch from external to internal or back
  //
  if (oldDragExternal != dragExternal)
    {
      int newMask;

      newMask = [dragSource draggingSourceOperationMaskForLocal: dragExternal];
      if (newMask != dragMask)
        {
          dragMask = newMask;
          changeCursor = YES;
        }
    }


  if (mouseWindow == targetWindow && targetWindow)  
    { // same window, sending update
      NSDebugLLog(@"NSDragging", @"sending dnd pos\n");
      if (dragWindow)
        {
          [self _sendLocalEvent: GSAppKitDraggingUpdate
			 action: dragMask & operationMask
		       position: NSMakePoint (wx + offset.x, wy + offset.y)
		      timestamp: CurrentTime
		       toWindow: dragWindow];
        }
      else
        {
          xdnd_send_position(&dnd, targetWindow, dragWindev->ident,
	    GSActionForDragOperation (dragMask & operationMask), wx + offset.x, 
	    wy + offset.y, CurrentTime);
        }
    }
  else if (mouseWindow != (Window) None)
    {
      //FIXME: We might force the cursor update here, if the
      //target wants to change the cursor.
      
      NSDebugLLog(@"NSDragging",
                  @"sending dnd enter/pos\n");
      
      if (dragWindow)
        {
          [self _sendLocalEvent: GSAppKitDraggingEnter
                action: dragMask
                position: NSMakePoint (wx + offset.x, wy + offset.y)
                timestamp: CurrentTime
                toWindow: dragWindow];
        }
      else
        {
          xdnd_send_enter(&dnd, mouseWindow, dragWindev->ident, typelist);
          xdnd_send_position(&dnd, mouseWindow, dragWindev->ident,
	    GSActionForDragOperation (dragMask & operationMask),
	    wx + offset.x, wy + offset.y, CurrentTime);
        }
    }

  if (targetWindow != mouseWindow)
    {
      targetWindow = mouseWindow;
      changeCursor = YES;
    }
  
  if (changeCursor)
    {
      [self _setCursor];
    }
}

/* NSDraggingInfo protocol */
- (NSWindow*) draggingDestinationWindow
{
  return dragWindow;
}

- (NSPoint) draggingLocation
{
  return dragPoint;
}

- (NSPasteboard*) draggingPasteboard
{
  return dragPasteboard;
}

- (int) draggingSequenceNumber
{
  return dragSequence;
}

- (id) draggingSource
{
  return dragSource;
}

- (unsigned int) draggingSourceOperationMask
{
  // Mix in possible modifiers
  return dragMask & operationMask;
}

- (NSImage*) draggedImage
{
  if (dragSource)
    return [dragCell image];
  else
    return nil;
}

- (NSPoint) draggedImageLocation
{
  NSPoint loc;

  if (dragSource)
    {
      NSSize size;

      size = [[dragCell image] size];
      loc = NSMakePoint(dragPoint.x-size.width/2, dragPoint.y - size.height/2);
    }
  else
    {
      loc = dragPoint;
    }
  return loc;
}


/*
 * Move the dragged image immediately to the position indicated by
 * the instance variable newPosition.
 *
 * In doing so it will update the (wx, wy) and dragPosition instance variables.
 */
- (void) _moveDraggedImageToNewPosition
{
  wx += (int) (newPosition.x - dragPosition.x);
  wy += (int) (dragPosition.y - newPosition.y);

  // We use this instead of the simpler `dragPosition = newPosition'
  // because we want to keep the dragPosition in sync with (wx, wy)
  // and (wx, wy) are integers.
  dragPosition.x += (float) ((int) newPosition.x - dragPosition.x);
  dragPosition.y += (float) ((int) newPosition.y - dragPosition.y);
/*
  XMoveWindow (XDPY, dragWindev->ident, wx, wy);
*/
  [GSServerForWindow(_window) movewindow: NSMakePoint(newPosition.x - offset.x, 
						      newPosition.y - offset.y) 
		    : dragWindev->number];
}


- (void) _slideDraggedImageTo: (NSPoint)screenPoint
                numberOfSteps: (int) steps
               waitAfterSlide: (BOOL) waitFlag
{
  // --- If we do not need multiple redrawing, just move the image immediately
  //     to its desired spot.

  if (steps < 2)
    {
      newPosition = screenPoint;
      [self _moveDraggedImageToNewPosition];
    }
  else
    {
      [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: SLIDE_TIME_STEP];

      // Use the event loop to redraw the image repeatedly.
      // Using the event loop to allow the application to process
      // expose events.  
      while (steps)
        {
          NSEvent *theEvent = [NSApp nextEventMatchingMask: NSPeriodicMask
                                     untilDate: [NSDate distantFuture]
                                     inMode: NSEventTrackingRunLoopMode
                                     dequeue: YES];
          
          if ([theEvent type] != NSPeriodic)
            {
              NSDebugLLog (@"NSDragging", 
			   @"Unexpected event type: %d during slide",
                           [theEvent type]);
            }
          newPosition.x = (screenPoint.x + ((float) steps - 1.0) 
			   * dragPosition.x) / ((float) steps);
          newPosition.y = (screenPoint.y + ((float) steps - 1.0) 
			   * dragPosition.y) / ((float) steps);

          [self _moveDraggedImageToNewPosition];
          steps --;
        }
      [NSEvent stopPeriodicEvents];
    }
  if (waitFlag)
    {
      [NSThread sleepUntilDate: 
	[NSDate dateWithTimeIntervalSinceNow: SLIDE_TIME_STEP * 2.0]];
    }
}


- (void) slideDraggedImageTo:  (NSPoint) point
{
  [self _slideDraggedImageTo: point 
	       numberOfSteps: SLIDE_NR_OF_STEPS 
	      waitAfterSlide: YES];
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
  int nchildren;
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
          if (result != -1)
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
  if (result == -1)
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
