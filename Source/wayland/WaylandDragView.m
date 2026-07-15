/*
   WaylandDragView - Drag and drop for the Wayland backend.

   Copyright (C) 2026 Free Software Foundation, Inc.

   This file is part of GNUstep.

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

#include <AppKit/NSApplication.h>
#include <AppKit/NSDragging.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>
#include <GNUstepGUI/GSDragView.h>
#include <GNUstepGUI/GSDisplayServer.h>
#include "wayland/WaylandServer.h"

#include <unistd.h>
#include <string.h>

extern NSWindow *GSWindowWithNumber(NSInteger windowNumber);

@interface WaylandDragView : GSDragView
{
  /* Source side: the offer we present to the compositor. */
  struct wl_data_source *_dataSource;
  BOOL			 _dragActive;
  NSDragOperation	 _resultOperation;

  /* Destination side: the offer the compositor hands us over one of our
   * own surfaces, plus the enter serial needed to accept it. */
  struct wl_data_offer	*_destOffer;
  uint32_t		 _destEnterSerial;
  struct window		*_destWlWindow;
}
+ (id) sharedDragView;
- (void) _writeMime: (const char *)mime toFD: (int)fd;
- (void) _dragEnded: (NSDragOperation)op;
- (void) _dragEntered: (struct window *)win
		offer: (struct wl_data_offer *)offer
	       serial: (uint32_t)serial
		   at: (NSPoint)surfacePoint;
- (void) _dragMovedTo: (NSPoint)surfacePoint;
- (void) _dragDropped;
- (void) _dragExited;
@end

@interface WaylandServer (DragAndDrop)
- (WaylandConfig *) wlconfig;
- (id <NSDraggingInfo>) dragInfo;
@end

/* Map an NSPasteboard type to the wayland mime types we advertise for it. */
static NSArray *
mimesForType(NSString *type)
{
  if ([type isEqualToString: NSStringPboardType])
    {
      return [NSArray arrayWithObjects: @"text/plain;charset=utf-8",
	      @"UTF8_STRING", @"text/plain", @"TEXT", nil];
    }
  return [NSArray arrayWithObject: type];
}

/* Map an advertised wayland mime type back to an NSPasteboard type. */
static NSString *
typeForMime(const char *mime)
{
  NSString *m = [NSString stringWithUTF8String: mime];

  if ([m hasPrefix: @"text/plain"] || [m isEqualToString: @"UTF8_STRING"]
      || [m isEqualToString: @"TEXT"])
    {
      return NSStringPboardType;
    }
  return m;
}

/* ---- wl_data_source (drag source) callbacks ---- */

static void
ds_target(void *data, struct wl_data_source *src, const char *mime) {}

static void
ds_send(void *data, struct wl_data_source *src, const char *mime, int32_t fd)
{
  [(WaylandDragView *)data _writeMime: mime toFD: fd];
}

static void
ds_cancelled(void *data, struct wl_data_source *src)
{
  [(WaylandDragView *)data _dragEnded: NSDragOperationNone];
}

static void
ds_dnd_drop_performed(void *data, struct wl_data_source *src) {}

static void
ds_dnd_finished(void *data, struct wl_data_source *src)
{
  [(WaylandDragView *)data _dragEnded: NSDragOperationCopy];
}

static void
ds_action(void *data, struct wl_data_source *src, uint32_t action) {}

static const struct wl_data_source_listener data_source_listener = {
  ds_target, ds_send, ds_cancelled, ds_dnd_drop_performed,
  ds_dnd_finished, ds_action
};

/* ---- wl_data_device (drag destination) callbacks ---- *
 * The compositor drives a drag over one of our surfaces and delivers these
 * events.  We translate them into the GSAppKitDragging* events that
 * -[NSWindow sendEvent:] dispatches to the destination view, exactly as the
 * X11 backend does from XDND client messages. */

static void
dd_data_offer(void *data, struct wl_data_device *dd, struct wl_data_offer *offer)
{
  /* A new offer is announced before the enter; the mime types follow on the
   * offer object itself.  We accept during the drag once the view has said it
   * wants the data, so nothing to do here beyond noting it exists. */
  NSDebugLLog(@"NSDragging", @"wayland: data_offer %p", offer);
}

static void
dd_enter(void *data, struct wl_data_device *dd, uint32_t serial,
	 struct wl_surface *surface, wl_fixed_t x, wl_fixed_t y,
	 struct wl_data_offer *offer)
{
  struct window *win = surface ? wl_surface_get_user_data(surface) : NULL;

  [[WaylandDragView sharedDragView]
    _dragEntered: win
	   offer: offer
	  serial: serial
	      at: NSMakePoint(wl_fixed_to_double(x), wl_fixed_to_double(y))];
}

static void
dd_leave(void *data, struct wl_data_device *dd)
{
  [[WaylandDragView sharedDragView] _dragExited];
}

static void
dd_motion(void *data, struct wl_data_device *dd, uint32_t time,
	  wl_fixed_t x, wl_fixed_t y)
{
  [[WaylandDragView sharedDragView]
    _dragMovedTo: NSMakePoint(wl_fixed_to_double(x), wl_fixed_to_double(y))];
}

static void
dd_drop(void *data, struct wl_data_device *dd)
{
  [[WaylandDragView sharedDragView] _dragDropped];
}

static void
dd_selection(void *data, struct wl_data_device *dd, struct wl_data_offer *offer)
{
  /* Clipboard selection is handled through XWayland by gpbs, ignore here. */
}

const struct wl_data_device_listener data_device_listener = {
  dd_data_offer, dd_enter, dd_leave, dd_motion, dd_drop, dd_selection
};

/* ---- the drag view ---- */

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

- (WaylandConfig *) _wlconfig
{
  return [(WaylandServer *)GSCurrentServer() wlconfig];
}

- (void) _writeMime: (const char *)mime toFD: (int)fd
{
  NSString *type = typeForMime(mime);
  NSData   *d = nil;

  if ([type isEqualToString: NSStringPboardType])
    {
      NSString *s = [dragPasteboard stringForType: NSStringPboardType];
      d = [s dataUsingEncoding: NSUTF8StringEncoding];
    }
  else
    {
      d = [dragPasteboard dataForType: type];
    }

  if (d != nil)
    {
      const char *bytes = [d bytes];
      NSUInteger len = [d length];
      NSUInteger off = 0;
      while (off < len)
	{
	  ssize_t n = write(fd, bytes + off, len - off);
	  if (n <= 0)
	    break;
	  off += n;
	}
    }
  close(fd);
}

- (void) _dragEnded: (NSDragOperation)op
{
  _resultOperation = op;
  _dragActive = NO;
}

- (void) dragImage: (NSImage *)anImage
		at: (NSPoint)screenLocation
	    offset: (NSSize)initialOffset
	     event: (NSEvent *)event
	pasteboard: (NSPasteboard *)pboard
	    source: (id)sourceObject
	 slideBack: (BOOL)slideFlag
{
  WaylandConfig *wlconfig = [self _wlconfig];
  struct window *win;
  struct wl_surface *origin = NULL;
  NSEnumerator *e;
  NSString *type;

  if (wlconfig == NULL || wlconfig->data_device == NULL
      || wlconfig->data_device_manager == NULL)
    {
      NSDebugLLog(@"NSDragging", @"wayland: no data device, cannot drag");
      return;
    }

  ASSIGN(dragPasteboard, pboard);
  ASSIGN(dragSource, sourceObject);
  slideBack = slideFlag;
  dragSequence = [event timestamp];

  win = get_window_with_id(wlconfig, [[event window] windowNumber]);
  if (win != NULL)
    origin = win->surface;

  /* Build a data source offering the pasteboard types. */
  _dataSource = wl_data_device_manager_create_data_source(
    wlconfig->data_device_manager);
  wl_data_source_add_listener(_dataSource, &data_source_listener, self);

  e = [[pboard types] objectEnumerator];
  while ((type = [e nextObject]) != nil)
    {
      NSEnumerator *me = [mimesForType(type) objectEnumerator];
      NSString *mime;
      while ((mime = [me nextObject]) != nil)
	{
	  wl_data_source_offer(_dataSource, [mime UTF8String]);
	}
    }

  wl_data_source_set_actions(_dataSource,
    WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY
    | WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE);

  if ([dragSource respondsToSelector: @selector(draggedImage:beganAt:)])
    {
      [dragSource draggedImage: anImage beganAt: screenLocation];
    }

  /* Hand the drag over to the compositor, which resolves the drop target.
   * Unlike the X11 backend we do not run a client-side tracking loop: on
   * Wayland the compositor owns the pointer for the duration of the drag. */
  _dragActive = YES;
  _resultOperation = NSDragOperationNone;
  wl_data_device_start_drag(wlconfig->data_device, _dataSource, origin,
    NULL /* no drag icon surface */, wlconfig->pointer.serial);
  wl_display_flush(wlconfig->display);

  /* Modal loop until the compositor concludes the drag.  This mirrors the
   * ordinary application event loop: pump events in the default run loop mode
   * (where the Wayland display fd is watched) so the data_device callbacks
   * fire, the GSAppKitDragging* events we post are delivered to the
   * destination view, and the drop's Finished handler clears _dragActive. */
  while (_dragActive)
    {
      NSEvent *ev;

      ev = [NSApp nextEventMatchingMask: NSAnyEventMask
			      untilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]
				 inMode: NSDefaultRunLoopMode
				dequeue: YES];
      if (ev != nil)
	{
	  [NSApp sendEvent: ev];
	}
    }

  if ([dragSource respondsToSelector: @selector(draggedImage:endedAt:operation:)])
    {
      [dragSource draggedImage: anImage
		       endedAt: dragPosition
		     operation: _resultOperation];
    }

  _dataSource = NULL;
  DESTROY(dragSource);
}

/* ---- destination side ---- */

/* Post one GSAppKitDragging* event to the destination window; -[NSWindow
 * sendEvent:] picks it up out of the queue and drives the view's dragging
 * protocol using this drag view as the NSDraggingInfo. */
- (void) _postDrag: (GSAppKitSubtype)subtype
		at: (NSPoint)winPoint
	    window: (int)winId
	    action: (NSDragOperation)action
{
  NSEvent *e;

  e = [NSEvent otherEventWithType: NSAppKitDefined
			 location: winPoint
		    modifierFlags: 0
			timestamp: 0
		     windowNumber: winId
			  context: GSCurrentContext()
			  subtype: subtype
			    data1: winId
			    data2: action];
  [GSCurrentServer() postEvent: e atStart: NO];
}

- (void) _dragEntered: (struct window *)win
		offer: (struct wl_data_offer *)offer
	       serial: (uint32_t)serial
		   at: (NSPoint)surfacePoint
{
  NSPoint winPoint;

  if (win == NULL)
    {
      return;
    }

  _destWlWindow = win;
  _destOffer = offer;
  _destEnterSerial = serial;
  destWindow = GSWindowWithNumber(win->window_id);

  /* Make the inherited NSDraggingInfo getters report a usable operation mask.
   * For a drag started in this process dragMask/dragPasteboard are already set
   * by -dragImage:; guard the cross-process case so the mask is never empty. */
  operationMask = NSDragOperationEvery;
  if (dragMask == NSDragOperationNone)
    {
      dragMask = NSDragOperationCopy | NSDragOperationMove
	| NSDragOperationGeneric | NSDragOperationPrivate;
    }

  winPoint = NSMakePoint(surfacePoint.x, win->height - surfacePoint.y);
  dragPoint = winPoint;

  [self _postDrag: GSAppKitDraggingEnter at: winPoint window: win->window_id
	   action: NSDragOperationNone];
  [self _postDrag: GSAppKitDraggingUpdate at: winPoint window: win->window_id
	   action: dragMask];
}

- (void) _dragMovedTo: (NSPoint)surfacePoint
{
  NSPoint winPoint;

  if (_destWlWindow == NULL)
    {
      return;
    }
  winPoint = NSMakePoint(surfacePoint.x, _destWlWindow->height - surfacePoint.y);
  dragPoint = winPoint;
  [self _postDrag: GSAppKitDraggingUpdate
	       at: winPoint
	   window: _destWlWindow->window_id
	   action: dragMask];
}

- (void) _dragDropped
{
  if (_destWlWindow == NULL)
    {
      return;
    }
  [self _postDrag: GSAppKitDraggingDrop
	       at: dragPoint
	   window: _destWlWindow->window_id
	   action: NSDragOperationNone];
}

- (void) _dragExited
{
  if (_destWlWindow == NULL)
    {
      return;
    }
  [self _postDrag: GSAppKitDraggingExit
	       at: dragPoint
	   window: _destWlWindow->window_id
	   action: NSDragOperationNone];
  _destWlWindow = NULL;
}

/* Called back by -[NSWindow sendEvent:] after it has run the view's dragging
 * protocol: Status carries the operation the view will accept, Finished marks
 * the drop as concluded. */
- (void) postDragEvent: (NSEvent *)theEvent
{
  WaylandConfig *wlconfig = [self _wlconfig];
  GSAppKitSubtype subtype = (GSAppKitSubtype)[theEvent subtype];

  if (subtype == GSAppKitDraggingStatus)
    {
      NSDragOperation action = [theEvent data2];

      if (_destOffer != NULL)
	{
	  if (action != NSDragOperationNone && [[dragPasteboard types] count] > 0)
	    {
	      NSString *type = [[dragPasteboard types] objectAtIndex: 0];
	      NSString *mime = [mimesForType(type) objectAtIndex: 0];

	      wl_data_offer_set_actions(_destOffer,
		WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY
		| WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE,
		WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY);
	      wl_data_offer_accept(_destOffer, _destEnterSerial,
		[mime UTF8String]);
	    }
	  else
	    {
	      wl_data_offer_accept(_destOffer, _destEnterSerial, NULL);
	    }
	  if (wlconfig != NULL)
	    wl_display_flush(wlconfig->display);
	}
    }
  else if (subtype == GSAppKitDraggingFinished)
    {
      if (_destOffer != NULL)
	{
	  wl_data_offer_finish(_destOffer);
	  wl_data_offer_destroy(_destOffer);
	  _destOffer = NULL;
	}
      if (wlconfig != NULL)
	wl_display_flush(wlconfig->display);

      /* For a drag that both started and ended in this process the compositor
       * may not round-trip a data_source.dnd_finished, so release the modal
       * loop here as well. */
      _destWlWindow = NULL;
      _resultOperation = NSDragOperationCopy;
      _dragActive = NO;
    }
}

@end

/* Wire the drag view into the Wayland server. */

@implementation WaylandServer (DragAndDrop)

- (WaylandConfig *) wlconfig
{
  return wlconfig;
}

- (id <NSDraggingInfo>) dragInfo
{
  return [WaylandDragView sharedDragView];
}

@end
