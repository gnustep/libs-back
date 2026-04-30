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

#include <Foundation/NSDebug.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSCell.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>

#include "wayland/WaylandServer.h"
#include "wayland/WaylandDragView.h"

/* Private category to expose wlconfig from WaylandServer */
@interface WaylandServer (DragViewAccess)
- (WaylandConfig *) wlconfig;
@end

@implementation WaylandServer (DragViewAccess)
- (WaylandConfig *) wlconfig
{
  return wlconfig;
}
@end


/* Lightweight NSWindow subclass used to hold the GSDragView content.
   We never actually show this window - the drag icon is rendered on the
   Wayland cursor surface instead, so it follows the pointer automatically.
   The window must still exist for GSDragView's internal event handling. */
@interface WaylandRawWindow : NSWindow
@end

@implementation WaylandRawWindow

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

- (void) orderWindow: (NSWindowOrderingMode)place relativeTo: (NSInteger)otherWin
{
  [super orderWindow: place relativeTo: otherWin];
  [self setLevel: NSPopUpMenuWindowLevel];
}

@end


/* Private ivar extension */
@interface WaylandDragView ()
{
  void *_dragCursorCid;
}
@end


@implementation WaylandDragView

static WaylandDragView *sharedDragView = nil;

+ (id) sharedDragView
{
  if (sharedDragView == nil)
    {
      sharedDragView = [WaylandDragView new];
    }
  return sharedDragView;
}

+ (Class) windowClass
{
  return [WaylandRawWindow class];
}

- (void) updateDragInfoFromEvent: (NSEvent *)event
{
  destWindow = [event window];
  dragPoint = [event locationInWindow];
  dragSequence = [event timestamp];
  dragMask = [event data2];
}

- (void) resetDragInfo
{
  DESTROY(dragPasteboard);
}

- (void) postDragEvent: (NSEvent *)theEvent
{
  if (destExternal)
    {
      /* Inter-process drag via wl_data_device is not yet implemented. */
      NSDebugLog(@"WaylandDragView: external postDragEvent not yet supported");
    }
  else
    {
      [super postDragEvent: theEvent];
    }
}

- (void) sendExternalEvent: (GSAppKitSubtype)subtype
                    action: (NSDragOperation)action
                  position: (NSPoint)eventLocation
                 timestamp: (NSTimeInterval)time
                  toWindow: (int)dWindowNumber
{
  /* Wayland inter-process DnD requires the wl_data_device protocol,
     which is not yet implemented in this backend. */
  NSDebugLog(@"WaylandDragView: sendExternalEvent not yet implemented "
	     @"(subtype=%d, window=%d)", (int)subtype, dWindowNumber);
}

/* Override to render the drag icon on the Wayland cursor surface instead
   of positioning a floating window.  The cursor follows the pointer
   automatically, so the icon tracks the mouse with no extra work. */
- (void) _setupWindowFor: (NSImage *)anImage
           mousePosition: (NSPoint)mPoint
           imagePosition: (NSPoint)iPoint
{
  if (anImage == nil)
    anImage = [NSImage imageNamed: @"common_Close"];

  NSSize imageSize = [anImage size];

  /* Set internal GSDragView state (mirrors what the base implementation does
     before calling orderFront:, which we intentionally omit here). */
  [dragCell setImage: anImage];
  dragPosition = mPoint;
  newPosition  = mPoint;
  offset.width  = mPoint.x - iPoint.x;
  offset.height = mPoint.y - iPoint.y;

  /* Hotspot: cursor position within the image in Wayland pixel coords
     (origin top-left, Y increasing downwards).
       hotspot_x = cursor_x - image_left    (same in NS and Wayland)
       hotspot_y = image_height - (cursor_y - image_bottom_NS)   (flip Y) */
  NSPoint hotspot;
  hotspot.x = offset.width;
  hotspot.y = imageSize.height - offset.height;
  if (hotspot.x < 0) hotspot.x = 0;
  if (hotspot.y < 0) hotspot.y = 0;

  NSDebugLog(@"WaylandDragView: setting drag cursor hotspot=(%g,%g)",
	     hotspot.x, hotspot.y);

  WaylandServer *server = (WaylandServer *) GSCurrentServer();
  [server imagecursor: hotspot : anImage : &_dragCursorCid];
  if (_dragCursorCid != NULL)
    [server setcursor: _dragCursorCid];
}

/* Restore the default arrow cursor and release the drag cursor resource. */
- (void) _clearupWindow
{
  WaylandServer *server = (WaylandServer *) GSCurrentServer();

  /* Restore the default cursor first so the compositor stops using the
     drag-image surface before we destroy the underlying buffer. */
  void *arrowCid = NULL;
  [server standardcursor: GSArrowCursor : &arrowCid];
  if (arrowCid != NULL)
    [server setcursor: arrowCid];

  if (_dragCursorCid != NULL)
    {
      [server freecursor: _dragCursorCid];
      _dragCursorCid = NULL;
    }
}

/* The cursor surface already follows the pointer automatically via the
   Wayland compositor; no window repositioning is needed. */
- (void) _moveDraggedImageToNewPosition
{
  dragPosition = newPosition;
}

- (NSWindow *) windowAcceptingDnDunder: (NSPoint)p
                             windowRef: (int *)mouseWindowRef
{
  WaylandConfig *wlconfig =
    [(WaylandServer *) GSCurrentServer() wlconfig];
  struct window *window;
  struct output *output = NULL;

  /* Use the first output for screen-height conversion. */
  wl_list_for_each(output, &wlconfig->output_list, link)
  {
    break;
  }

  if (output == NULL)
    {
      if (mouseWindowRef)
	*mouseWindowRef = 0;
      return nil;
    }

  int dragWinNum = (_window != nil) ? [_window windowNumber] : -1;

  /* Walk the window list; keep updating candidate so we end up with the
     topmost (last-inserted) window whose bounds contain the point. */
  struct window *candidate = NULL;
  wl_list_for_each(window, &wlconfig->window_list, link)
  {
    if (window->window_id == dragWinNum)
      continue;
    if (window->ignoreMouse || window->terminated || !window->configured)
      continue;

    /* Convert Wayland window rect to NS screen coordinates:
         NS origin.y = output->height - pos_y(wl-top) - height */
    float ns_x = window->pos_x;
    float ns_y = output->height - window->pos_y - window->height;

    if (p.x >= ns_x && p.x < ns_x + window->width
	&& p.y >= ns_y && p.y < ns_y + window->height)
      {
	NSWindow *nswindow = GSWindowWithNumber(window->window_id);
	if (nswindow == nil)
	  continue;
	NSCountedSet *dragTypes =
	  [GSCurrentServer() dragTypesForWindow: nswindow];
	if ([dragTypes count] > 0)
	  candidate = window;
      }
  }

  if (candidate != NULL)
    {
      if (mouseWindowRef)
	*mouseWindowRef = candidate->window_id;
      return GSWindowWithNumber(candidate->window_id);
    }

  if (mouseWindowRef)
    *mouseWindowRef = 0;
  return nil;
}

@end


@implementation WaylandServer (DragAndDrop)

- (id <NSDraggingInfo>) dragInfo
{
  return [WaylandDragView sharedDragView];
}

- (BOOL) addDragTypes: (NSArray *)types toWindow: (NSWindow *)win
{
  return [super addDragTypes: types toWindow: win];
}

- (BOOL) removeDragTypes: (NSArray *)types fromWindow: (NSWindow *)win
{
  return [super removeDragTypes: types fromWindow: win];
}

@end
