/* -*- mode: ObjC -*-
  <title>XGDragView</title>

   <abstract>View that is dragged during drag and drop</abstract>

   Written By: <author name="Wim Oudshoorn"><email>woudshoo@xs4all.nl</email></author>
   Date: Nov 2001
   
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

#include <AppKit/NSCell.h>
#include <AppKit/NSEvent.h>
#include <GNUstepGUI/GSDragView.h>
#include <Foundation/NSGeometry.h>
#include "x11/xdnd.h"
#include "x11/XGServerWindow.h"

/*"
  Drag and drop support functions
  "*/

void 		GSEnsureDndIsInitialized (void);
DndClass 	xdnd (void);
Atom		GSActionForDragOperation(unsigned int op);
NSDragOperation	GSDragOperationForAction(Atom xaction);


/*"
  WRO (notes made 18 Nov 2001)
  
  The object that is dragged over the screen.  
  It hijacks the event loop and manages the complete
  drag and drop sequence.
 "*/
@interface	XGDragView : GSDragView
{
  Atom           *typelist;
}

+ (id) sharedDragView;

- (void) setupDragInfoFromXEvent: (XEvent *)xEvent;
- (void) updateDragInfoFromEvent: (NSEvent *)event;
- (void) resetDragInfo;
- (void) _sendLocalEvent: (GSAppKitSubtype)subtype
		  action: (NSDragOperation)action
	        position: (NSPoint)eventLocation
	       timestamp: (NSTimeInterval)time
		toWindow: (NSWindow*)dWindow;
- (void) dragImage: (NSImage*)anImage
		at: (NSPoint)screenLocation
	    offset: (NSSize)initialOffset
	     event: (NSEvent*)event
	pasteboard: (NSPasteboard*)pboard
	    source: (id)sourceObject
	 slideBack: (BOOL)slideFlag;
- (void) postDragEvent: (NSEvent *)theEvent;
- (void) _setCursor;
- (void) _handleDrag: (NSEvent*)theEvent;
- (void) _handleEventDuringDragging: (NSEvent*) theEvent;
- (void) _updateAndMoveImageToCorrectPosition;
- (void) _moveDraggedImageToNewPosition;
- (void) _slideDraggedImageTo: (NSPoint)screenPoint
                numberOfSteps: (int) steps
               waitAfterSlide: (BOOL) waitFlag;
- (Window) _xWindowAcceptingDnDunderX: (int) x Y: (int) y;
@end
