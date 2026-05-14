/* WaylandDragView - Drag and Drop for Wayland backend

   Copyright (C) 2024 Free Software Foundation, Inc.

   This file is part of the GNUstep Backend.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#ifndef _WaylandDragView_h_INCLUDE
#define _WaylandDragView_h_INCLUDE

#include <AppKit/NSCell.h>
#include <AppKit/NSEvent.h>
#include <GNUstepGUI/GSDragView.h>
#include <Foundation/NSGeometry.h>

@interface WaylandDragView : GSDragView

+ (id) sharedDragView;

- (void) updateDragInfoFromEvent: (NSEvent *)event;
- (void) resetDragInfo;

/** Set up NSDraggingInfo state for an inbound drag from an external app.
 *  Called from the wl_data_device.enter C callback before posting
 *  GSAppKitDraggingEnter to the target window. */
- (void) setupInboundDragWithPasteboard: (NSPasteboard *)pb
                              operation: (NSDragOperation)op;

@end

#endif /* _WaylandDragView_h_INCLUDE */
