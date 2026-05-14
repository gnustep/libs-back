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
#include <Foundation/NSDate.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSCell.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>

#include <unistd.h>
#include <string.h>
#include <stdlib.h>

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


/* ── MIME ↔ pasteboard type mapping ──────────────────────────────────────── */

static const struct { const char *mime; const char *pboard; } kMimeMap[] = {
  { "text/plain;charset=utf-8", "NSStringPboardType" },
  { "text/plain",               "NSStringPboardType" },
  { "text/uri-list",            "NSFilenamesPboardType" },
  { "application/rtf",          "NSRTFPboardType" },
  { "image/tiff",               "NSTIFFPboardType" },
  { "image/png",                "NSPNGPboardType" },
  { NULL, NULL }
};

static const char *
mime_for_pboard_type(NSString *pt)
{
  if ([pt isEqual: @"NSStringPboardType"] || [pt isEqual: NSPasteboardTypeString])
    return "text/plain;charset=utf-8";
  if ([pt isEqual: @"NSFilenamesPboardType"])
    return "text/uri-list";
  if ([pt isEqual: @"NSRTFPboardType"])
    return "application/rtf";
  if ([pt isEqual: @"NSTIFFPboardType"])
    return "image/tiff";
  if ([pt isEqual: @"NSPNGPboardType"])
    return "image/png";
  return NULL;
}

static NSString *
pboard_type_for_mime(const char *mime)
{
  for (int i = 0; kMimeMap[i].mime; i++)
    if (strcasecmp(mime, kMimeMap[i].mime) == 0)
      return [NSString stringWithUTF8String: kMimeMap[i].pboard];
  return nil;
}


/* ── Action mapping ──────────────────────────────────────────────────────── */

static uint32_t
ns_op_to_wl_actions(NSDragOperation op)
{
  uint32_t a = WL_DATA_DEVICE_MANAGER_DND_ACTION_NONE;
  if (op & NSDragOperationCopy)    a |= WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY;
  if (op & NSDragOperationMove)    a |= WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE;
  if (op & NSDragOperationDelete)  a |= WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE;
  if (op & NSDragOperationGeneric) a |= WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY;
  return a ? a : WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY;
}

static NSDragOperation
wl_action_to_ns(uint32_t action)
{
  switch (action) {
    case WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE: return NSDragOperationMove;
    case WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY:
    default:                                     return NSDragOperationCopy;
  }
}


/* ── Inbound offer MIME helpers ───────────────────────────────────────────── */

static void
dnd_offer_mimes_free(WaylandConfig *wlconfig)
{
  if (wlconfig->dnd_offer_mimes)
    {
      for (int i = 0; i < wlconfig->dnd_offer_mime_count; i++)
        free(wlconfig->dnd_offer_mimes[i]);
      free(wlconfig->dnd_offer_mimes);
      wlconfig->dnd_offer_mimes = NULL;
    }
  wlconfig->dnd_offer_mime_count = 0;
  wlconfig->dnd_offer_mime_cap   = 0;
}

static void
dnd_offer_mime_append(WaylandConfig *wlconfig, const char *mime)
{
  if (wlconfig->dnd_offer_mime_count >= wlconfig->dnd_offer_mime_cap)
    {
      int cap = wlconfig->dnd_offer_mime_cap ? wlconfig->dnd_offer_mime_cap * 2 : 8;
      wlconfig->dnd_offer_mimes = realloc(wlconfig->dnd_offer_mimes,
                                           cap * sizeof(char *));
      wlconfig->dnd_offer_mime_cap = cap;
    }
  wlconfig->dnd_offer_mimes[wlconfig->dnd_offer_mime_count++] = strdup(mime);
}

/* Return the first MIME type in the offer that we know how to receive.
   Populates *pboardType if non-NULL.  Returns NULL if nothing matches. */
static const char *
best_mime_for_offer(WaylandConfig *wlconfig, NSString **pboardType)
{
  static const char *preferred[] = {
    "text/plain;charset=utf-8", "text/plain", "text/uri-list",
    "application/rtf", "image/tiff", "image/png", NULL
  };
  for (int p = 0; preferred[p]; p++)
    for (int i = 0; i < wlconfig->dnd_offer_mime_count; i++)
      if (strcasecmp(wlconfig->dnd_offer_mimes[i], preferred[p]) == 0)
        {
          NSString *pt = pboard_type_for_mime(preferred[p]);
          if (pt)
            {
              if (pboardType) *pboardType = pt;
              return preferred[p];
            }
        }
  return NULL;
}


/* ── Read all data from a pipe FD into NSData ─────────────────────────────── */

static NSData *
read_fd_to_data(int fd)
{
  size_t cap = 4096, total = 0;
  char *buf = malloc(cap);
  if (!buf) { close(fd); return nil; }

  ssize_t n;
  while ((n = read(fd, buf + total, cap - total)) > 0)
    {
      total += n;
      if (total == cap)
        {
          cap *= 2;
          char *nb = realloc(buf, cap);
          if (!nb) { free(buf); close(fd); return nil; }
          buf = nb;
        }
    }
  close(fd);

  NSData *d = [NSData dataWithBytes: buf length: total];
  free(buf);
  return d;
}


/* ── Post a fake NSLeftMouseUp to exit GSDragView's event loop ────────────── */

static void
post_fake_mouse_up(void)
{
  NSEvent *ev =
    [NSEvent mouseEventWithType: NSLeftMouseUp
                       location: NSZeroPoint
                  modifierFlags: 0
                      timestamp: [NSDate timeIntervalSinceReferenceDate]
                   windowNumber: 0
                        context: nil
                    eventNumber: 0
                     clickCount: 1
                       pressure: 0.0
                   buttonNumber: 0
                         deltaX: 0
                         deltaY: 0
                         deltaZ: 0];
  [NSApp postEvent: ev atStart: YES];
}


/* ── wl_data_source listener (outbound drag) ──────────────────────────────── */

static void
data_source_target(void *data, struct wl_data_source *source, const char *mime)
{
  NSDebugFLLog(@"WaylandDnD", @"data_source_target: %s", mime ? mime : "(none)");
}

static void
data_source_send(void *data, struct wl_data_source *source,
                 const char *mime_type, int32_t fd)
{
  NSDebugFLLog(@"WaylandDnD", @"data_source_send: %s", mime_type);

  WaylandDragView *dv = [WaylandDragView sharedDragView];
  NSPasteboard   *pb = [dv draggingPasteboard];

  if (strcmp(mime_type, "text/plain;charset=utf-8") == 0
      || strcmp(mime_type, "text/plain") == 0)
    {
      NSString *s = [pb stringForType: NSStringPboardType];
      if (!s) s = [pb stringForType: NSPasteboardTypeString];
      if (s)
        {
          const char *utf8 = [s UTF8String];
          write(fd, utf8, strlen(utf8));
        }
    }
  else if (strcmp(mime_type, "text/uri-list") == 0)
    {
      NSArray *names = [pb propertyListForType: @"NSFilenamesPboardType"];
      if (names)
        {
          NSMutableString *list = [NSMutableString string];
          for (NSString *path in names)
            {
              NSURL *url = [NSURL fileURLWithPath: path];
              [list appendFormat: @"%@\r\n", [url absoluteString]];
            }
          const char *utf8 = [list UTF8String];
          write(fd, utf8, strlen(utf8));
        }
    }
  else
    {
      /* Generic binary fallback: look for a pasteboard type whose MIME matches */
      NSString *pt = pboard_type_for_mime(mime_type);
      if (pt)
        {
          NSData *d = [pb dataForType: pt];
          if (d) write(fd, [d bytes], [d length]);
        }
    }

  close(fd);
}

static void
data_source_cancelled(void *data, struct wl_data_source *source)
{
  NSDebugFLLog(@"WaylandDnD", @"data_source_cancelled");
  WaylandConfig *wlconfig = data;
  wlconfig->dnd_source = NULL;
  post_fake_mouse_up();
}

static void
data_source_dnd_drop_performed(void *data, struct wl_data_source *source)
{
  NSDebugFLLog(@"WaylandDnD", @"data_source_dnd_drop_performed");
  /* Wait for dnd_finished before exiting the drag loop. */
}

static void
data_source_dnd_finished(void *data, struct wl_data_source *source)
{
  NSDebugFLLog(@"WaylandDnD", @"data_source_dnd_finished");
  WaylandConfig *wlconfig = data;
  wlconfig->dnd_source = NULL;
  post_fake_mouse_up();
}

static void
data_source_action(void *data, struct wl_data_source *source, uint32_t action)
{
  NSDebugFLLog(@"WaylandDnD", @"data_source_action: %u", action);
  WaylandConfig *wlconfig = data;
  wlconfig->dnd_current_action = action;
}

static const struct wl_data_source_listener data_source_listener = {
  data_source_target,
  data_source_send,
  data_source_cancelled,
  data_source_dnd_drop_performed,
  data_source_dnd_finished,
  data_source_action,
};


/* ── wl_data_offer listener (inbound MIME accumulation) ──────────────────── */

static void
data_offer_offer(void *data, struct wl_data_offer *offer, const char *mime_type)
{
  WaylandConfig *wlconfig = data;
  NSDebugFLLog(@"WaylandDnD", @"data_offer_offer: %s", mime_type);
  dnd_offer_mime_append(wlconfig, mime_type);
}

static void
data_offer_source_actions(void *data, struct wl_data_offer *offer,
                          uint32_t source_actions)
{
  WaylandConfig *wlconfig = data;
  wlconfig->dnd_offer_source_actions = source_actions;
  NSDebugFLLog(@"WaylandDnD", @"data_offer_source_actions: 0x%x", source_actions);
}

static void
data_offer_action(void *data, struct wl_data_offer *offer, uint32_t dnd_action)
{
  WaylandConfig *wlconfig = data;
  wlconfig->dnd_current_action = dnd_action;
  NSDebugFLLog(@"WaylandDnD", @"data_offer_action: %u", dnd_action);
}

static const struct wl_data_offer_listener data_offer_listener = {
  data_offer_offer,
  data_offer_source_actions,
  data_offer_action,
};


/* ── wl_data_device listener (inbound drag events) ───────────────────────── */

static void
device_data_offer(void *data, struct wl_data_device *device,
                  struct wl_data_offer *offer)
{
  WaylandConfig *wlconfig = data;
  NSDebugFLLog(@"WaylandDnD", @"device_data_offer: %p", (void *)offer);

  /* Reset MIME list for this new offer; offer_offer callbacks follow. */
  dnd_offer_mimes_free(wlconfig);
  wlconfig->dnd_offer               = offer;
  wlconfig->dnd_offer_source_actions = 0;
  wlconfig->dnd_current_action       = 0;
  wl_data_offer_add_listener(offer, &data_offer_listener, wlconfig);
}

static void
device_enter(void *data, struct wl_data_device *device,
             uint32_t serial, struct wl_surface *surface,
             wl_fixed_t x_fixed, wl_fixed_t y_fixed,
             struct wl_data_offer *offer)
{
  WaylandConfig *wlconfig = data;
  float x = wl_fixed_to_double(x_fixed);
  float y = wl_fixed_to_double(y_fixed);

  wlconfig->dnd_x        = x;
  wlconfig->dnd_y        = y;
  wlconfig->dnd_incoming = YES;
  wlconfig->event_serial = serial;

  struct window *window = surface ? wl_surface_get_user_data(surface) : NULL;
  wlconfig->dnd_target = window;

  NSDebugFLLog(@"WaylandDnD", @"device_enter: win=%d pos=(%g,%g)",
               window ? window->window_id : -1, x, y);

  if (!offer || !window)
    return;

  /* Find the best MIME type we can receive. */
  NSString   *pboardType = nil;
  const char *mime       = best_mime_for_offer(wlconfig, &pboardType);

  if (mime)
    {
      wl_data_offer_accept(offer, serial, mime);

      if (wlconfig->data_device_manager_version >= 3)
        {
          uint32_t myActions = ns_op_to_wl_actions(
              NSDragOperationCopy | NSDragOperationMove);
          wl_data_offer_set_actions(offer, myActions,
                                    WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY);
        }
    }
  else
    {
      wl_data_offer_accept(offer, serial, NULL);
    }

  /* Set up the shared drag view as NSDraggingInfo for AppKit. */
  WaylandDragView *dv = [WaylandDragView sharedDragView];
  [dv setupInboundDragWithPasteboard:
        [NSPasteboard pasteboardWithName: NSDragPboard]
                           operation: wl_action_to_ns(
                               wlconfig->dnd_offer_source_actions
                               ? wlconfig->dnd_offer_source_actions
                               : WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY)];

  NSWindow *nswindow = GSWindowWithNumber(window->window_id);
  if (!nswindow)
    return;

  NSPoint nsPos = NSMakePoint(x, window->height - y);
  NSEvent *ev =
    [NSEvent otherEventWithType: NSAppKitDefined
                       location: nsPos
                  modifierFlags: 0
                      timestamp: [[NSDate date] timeIntervalSinceReferenceDate]
                   windowNumber: window->window_id
                        context: nil
                        subtype: GSAppKitDraggingEnter
                          data1: 0
                          data2: 0];
  [NSApp postEvent: ev atStart: NO];
}

static void
device_leave(void *data, struct wl_data_device *device)
{
  WaylandConfig *wlconfig = data;
  NSDebugFLLog(@"WaylandDnD", @"device_leave");

  struct window *window  = wlconfig->dnd_target;
  wlconfig->dnd_incoming = NO;
  wlconfig->dnd_target   = NULL;

  if (window)
    {
      NSWindow *nswindow = GSWindowWithNumber(window->window_id);
      if (nswindow)
        {
          NSEvent *ev =
            [NSEvent otherEventWithType: NSAppKitDefined
                               location: NSZeroPoint
                          modifierFlags: 0
                              timestamp: [[NSDate date] timeIntervalSinceReferenceDate]
                           windowNumber: window->window_id
                                context: nil
                                subtype: GSAppKitDraggingExit
                                  data1: 0
                                  data2: 0];
          [NSApp postEvent: ev atStart: NO];
        }
    }

  if (wlconfig->dnd_offer)
    {
      wl_data_offer_destroy(wlconfig->dnd_offer);
      wlconfig->dnd_offer = NULL;
      dnd_offer_mimes_free(wlconfig);
    }
}

static void
device_motion(void *data, struct wl_data_device *device,
              uint32_t time, wl_fixed_t x_fixed, wl_fixed_t y_fixed)
{
  WaylandConfig *wlconfig = data;
  float x = wl_fixed_to_double(x_fixed);
  float y = wl_fixed_to_double(y_fixed);
  wlconfig->dnd_x = x;
  wlconfig->dnd_y = y;

  struct window *window = wlconfig->dnd_target;
  if (!window)
    return;

  NSDebugFLLog(@"WaylandDnD", @"device_motion: (%g,%g)", x, y);

  /* Keep accepting so the compositor knows we still want the drag. */
  if (wlconfig->dnd_offer)
    {
      NSString   *pt   = nil;
      const char *mime = best_mime_for_offer(wlconfig, &pt);
      if (mime)
        wl_data_offer_accept(wlconfig->dnd_offer, wlconfig->event_serial, mime);
    }

  NSWindow *nswindow = GSWindowWithNumber(window->window_id);
  if (!nswindow)
    return;

  NSPoint nsPos = NSMakePoint(x, window->height - y);
  NSEvent *ev =
    [NSEvent otherEventWithType: NSAppKitDefined
                       location: nsPos
                  modifierFlags: 0
                      timestamp: (NSTimeInterval)time / 1000.0
                   windowNumber: window->window_id
                        context: nil
                        subtype: GSAppKitDraggingUpdate
                          data1: (NSInteger)NSDragOperationCopy
                          data2: 0];
  [NSApp postEvent: ev atStart: NO];
}

static void
device_drop(void *data, struct wl_data_device *device)
{
  WaylandConfig *wlconfig = data;
  NSDebugFLLog(@"WaylandDnD", @"device_drop");

  struct window *window = wlconfig->dnd_target;

  if (!window || !wlconfig->dnd_offer)
    {
      if (wlconfig->dnd_offer)
        {
          wl_data_offer_destroy(wlconfig->dnd_offer);
          wlconfig->dnd_offer = NULL;
          dnd_offer_mimes_free(wlconfig);
        }
      wlconfig->dnd_incoming = NO;
      return;
    }

  NSString   *pboardType = nil;
  const char *mime       = best_mime_for_offer(wlconfig, &pboardType);

  if (!mime || !pboardType)
    {
      wl_data_offer_destroy(wlconfig->dnd_offer);
      wlconfig->dnd_offer = NULL;
      dnd_offer_mimes_free(wlconfig);
      wlconfig->dnd_incoming = NO;
      return;
    }

  /* Receive the data via a pipe. */
  int pipefd[2];
  if (pipe(pipefd) < 0)
    {
      wl_data_offer_destroy(wlconfig->dnd_offer);
      wlconfig->dnd_offer = NULL;
      dnd_offer_mimes_free(wlconfig);
      wlconfig->dnd_incoming = NO;
      return;
    }

  wl_data_offer_receive(wlconfig->dnd_offer, mime, pipefd[1]);
  close(pipefd[1]);
  wl_display_flush(wlconfig->display);

  /* Block-read; the source writes after the flush above. */
  NSData *rawData = read_fd_to_data(pipefd[0]);

  /* Populate the drag pasteboard. */
  NSPasteboard *pboard = [NSPasteboard pasteboardWithName: NSDragPboard];
  [pboard declareTypes: @[pboardType] owner: nil];

  if ([pboardType isEqual: @"NSStringPboardType"]
      || [pboardType isEqual: NSPasteboardTypeString])
    {
      NSString *s = [[NSString alloc]
                      initWithData: rawData encoding: NSUTF8StringEncoding];
      if (!s)
        s = [[NSString alloc]
              initWithData: rawData encoding: NSISOLatin1StringEncoding];
      if (s)
        {
          [pboard setString: s forType: pboardType];
          [s release];
        }
    }
  else if ([pboardType isEqual: @"NSFilenamesPboardType"])
    {
      NSString *raw = [[NSString alloc]
                        initWithData: rawData encoding: NSUTF8StringEncoding];
      NSArray  *lines = [raw componentsSeparatedByCharactersInSet:
                              [NSCharacterSet newlineCharacterSet]];
      NSMutableArray *paths = [NSMutableArray array];
      for (NSString *line in lines)
        {
          NSString *trimmed = [line stringByTrimmingCharactersInSet:
                                      [NSCharacterSet whitespaceCharacterSet]];
          if ([trimmed length] == 0 || [trimmed hasPrefix: @"#"])
            continue;
          NSURL *url = [NSURL URLWithString: trimmed];
          if ([url isFileURL])
            [paths addObject: [url path]];
          else if ([trimmed hasPrefix: @"/"])
            [paths addObject: trimmed];
        }
      [pboard setPropertyList: paths forType: @"NSFilenamesPboardType"];
      [raw release];
    }
  else
    {
      [pboard setData: rawData forType: pboardType];
    }

  /* Deliver the drop event to the AppKit window. */
  NSWindow *nswindow = GSWindowWithNumber(window->window_id);
  if (nswindow)
    {
      NSDragOperation op = wl_action_to_ns(wlconfig->dnd_current_action);
      NSPoint nsPos = NSMakePoint(wlconfig->dnd_x, window->height - wlconfig->dnd_y);

      NSEvent *ev =
        [NSEvent otherEventWithType: NSAppKitDefined
                           location: nsPos
                      modifierFlags: 0
                          timestamp: [[NSDate date] timeIntervalSinceReferenceDate]
                       windowNumber: window->window_id
                            context: nil
                            subtype: GSAppKitDraggingDrop
                              data1: (NSInteger)op
                              data2: 0];
      [NSApp postEvent: ev atStart: NO];
    }

  /* Finish and destroy the offer. */
  if (wlconfig->data_device_manager_version >= 3)
    wl_data_offer_finish(wlconfig->dnd_offer);

  wl_data_offer_destroy(wlconfig->dnd_offer);
  wlconfig->dnd_offer = NULL;
  dnd_offer_mimes_free(wlconfig);
  wlconfig->dnd_incoming = NO;
}

static void
device_selection(void *data, struct wl_data_device *device,
                 struct wl_data_offer *offer)
{
  WaylandConfig *wlconfig = data;
  NSDebugFLLog(@"WaylandDnD", @"device_selection: %p", (void *)offer);

  /* Clipboard selection is outside M1 scope.  Destroy the offer if it's the
   * same as the pending dnd_offer (which means it was a selection, not DnD). */
  if (offer && offer == wlconfig->dnd_offer)
    {
      wl_data_offer_destroy(offer);
      wlconfig->dnd_offer = NULL;
      dnd_offer_mimes_free(wlconfig);
    }
  else if (offer)
    {
      wl_data_offer_destroy(offer);
    }
}

const struct wl_data_device_listener data_device_listener = {
  device_data_offer,
  device_enter,
  device_leave,
  device_motion,
  device_drop,
  device_selection,
};


/* ── Lightweight NSWindow subclass for the drag icon ─────────────────────── */

@interface WaylandRawWindow : NSWindow
@end

@implementation WaylandRawWindow

- (BOOL) canBecomeMainWindow { return NO; }
- (BOOL) canBecomeKeyWindow  { return NO; }

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


/* ── WaylandDragView ─────────────────────────────────────────────────────── */

@interface WaylandDragView ()
{
  void *_dragCursorCid;
  BOOL  _waylandExternalDragActive; /* YES after wl_data_device_start_drag */
}
@end


@implementation WaylandDragView

static WaylandDragView *sharedDragView = nil;

+ (id) sharedDragView
{
  if (sharedDragView == nil)
    sharedDragView = [WaylandDragView new];
  return sharedDragView;
}

+ (Class) windowClass
{
  return [WaylandRawWindow class];
}

- (void) updateDragInfoFromEvent: (NSEvent *)event
{
  destWindow   = [event window];
  dragPoint    = [event locationInWindow];
  dragSequence = [event timestamp];
  dragMask     = [event data2];
}

- (void) resetDragInfo
{
  DESTROY(dragPasteboard);
}

/* Called from device_enter to set up NSDraggingInfo for an inbound drag. */
- (void) setupInboundDragWithPasteboard: (NSPasteboard *)pb
                              operation: (NSDragOperation)op
{
  ASSIGN(dragPasteboard, pb);
  dragSource     = nil;
  destExternal   = YES;
  dragMask       = op;
  operationMask  = NSDragOperationAll;
}


/* ── Outbound drag ─────────────────────────────────────────────────────────
 *
 * Override dragImage: to call wl_data_device_start_drag before letting
 * GSDragView run its event loop.  The data_source callbacks post a fake
 * NSLeftMouseUp to exit the loop when the compositor signals completion.
 */
- (void) dragImage: (NSImage *)anImage
                at: (NSPoint)screenLocation
            offset: (NSSize)initialOffset
             event: (NSEvent *)event
        pasteboard: (NSPasteboard *)pboard
            source: (id)sourceObject
         slideBack: (BOOL)slideFlag
{
  WaylandConfig *wlconfig = [(WaylandServer *)GSCurrentServer() wlconfig];

  if (!wlconfig->data_device || !wlconfig->data_device_manager)
    {
      NSDebugMLLog(@"WaylandDnD",
                   @"WaylandDragView: no wl_data_device — skipping external drag");
      [super dragImage: anImage at: screenLocation offset: initialOffset
                 event: event pasteboard: pboard source: sourceObject
             slideBack: slideFlag];
      return;
    }

  /* Find the origin surface (the surface the drag started on). */
  int originWinNum = [event windowNumber];
  struct window *originWin = get_window_with_id(wlconfig, originWinNum);
  struct wl_surface *originSurface = originWin ? originWin->surface : NULL;

  if (!originSurface)
    {
      NSDebugMLLog(@"WaylandDnD",
                   @"WaylandDragView: no origin surface for window %d", originWinNum);
      [super dragImage: anImage at: screenLocation offset: initialOffset
                 event: event pasteboard: pboard source: sourceObject
             slideBack: slideFlag];
      return;
    }

  /* Create the data source and offer all MIME types from the pasteboard. */
  struct wl_data_source *source =
    wl_data_device_manager_create_data_source(wlconfig->data_device_manager);
  if (!source)
    {
      NSDebugMLLog(@"WaylandDnD", @"WaylandDragView: failed to create wl_data_source");
      [super dragImage: anImage at: screenLocation offset: initialOffset
                 event: event pasteboard: pboard source: sourceObject
             slideBack: slideFlag];
      return;
    }

  wl_data_source_add_listener(source, &data_source_listener, wlconfig);

  for (NSString *pt in [pboard types])
    {
      const char *mime = mime_for_pboard_type(pt);
      if (mime)
        {
          wl_data_source_offer(source, mime);
          /* Also offer the plain ASCII variant for text so legacy apps can receive it. */
          if (strcmp(mime, "text/plain;charset=utf-8") == 0)
            wl_data_source_offer(source, "text/plain");
        }
    }

  if (wlconfig->data_device_manager_version >= 3)
    {
      NSDragOperation srcMask =
        [sourceObject draggingSourceOperationMaskForLocal: NO];
      wl_data_source_set_actions(source, ns_op_to_wl_actions(srcMask));
    }

  wlconfig->dnd_source = source;

  /* The drag serial comes from the button-press event that triggered this drag. */
  uint32_t serial = (uint32_t)[event eventNumber];

  wl_data_device_start_drag(wlconfig->data_device, source,
                             originSurface,
                             NULL,   /* icon surface — cursor is set via wl_pointer */
                             serial);
  wl_display_flush(wlconfig->display);

  _waylandExternalDragActive = YES;

  NSDebugMLLog(@"WaylandDnD",
               @"WaylandDragView: wl_data_device_start_drag (serial=%u)", serial);

  /* Let GSDragView run its standard event loop.  The data_source callbacks
   * (cancelled / dnd_finished) will post a fake NSLeftMouseUp to exit it. */
  [super dragImage: anImage at: screenLocation offset: initialOffset
             event: event pasteboard: pboard source: sourceObject
         slideBack: slideFlag];

  _waylandExternalDragActive = NO;

  /* Clean up the source if the compositor did not fire dnd_finished
   * (e.g., version < 3 compositor). */
  if (wlconfig->dnd_source)
    {
      wl_data_source_destroy(wlconfig->dnd_source);
      wlconfig->dnd_source = NULL;
    }
}

- (void) postDragEvent: (NSEvent *)theEvent
{
  /* During a Wayland external drag, pointer events from the compositor stop.
   * We only care about the fake NSLeftMouseUp we post from data_source
   * callbacks to exit the event loop.  Suppress all other routing. */
  if (_waylandExternalDragActive)
    {
      if ([theEvent type] == NSLeftMouseUp)
        isDragging = NO;
      return;
    }
  [super postDragEvent: theEvent];
}

- (void) sendExternalEvent: (GSAppKitSubtype)subtype
                    action: (NSDragOperation)action
                  position: (NSPoint)eventLocation
                 timestamp: (NSTimeInterval)time
                  toWindow: (int)dWindowNumber
{
  /* The Wayland compositor manages the external drag entirely after
   * wl_data_device_start_drag — no protocol messages need to be sent here. */
  NSDebugMLLog(@"WaylandDnD",
               @"WaylandDragView: sendExternalEvent (subtype=%d) — handled by compositor",
               (int)subtype);
}


/* ── Drag icon (outbound) ─────────────────────────────────────────────────── */

- (void) _setupWindowFor: (NSImage *)anImage
           mousePosition: (NSPoint)mPoint
           imagePosition: (NSPoint)iPoint
{
  if (anImage == nil)
    anImage = [NSImage imageNamed: @"common_Close"];

  NSSize imageSize = [anImage size];

  [dragCell setImage: anImage];
  dragPosition = mPoint;
  newPosition  = mPoint;
  offset.width  = mPoint.x - iPoint.x;
  offset.height = mPoint.y - iPoint.y;

  NSPoint hotspot;
  hotspot.x = offset.width;
  hotspot.y = imageSize.height - offset.height;
  if (hotspot.x < 0) hotspot.x = 0;
  if (hotspot.y < 0) hotspot.y = 0;

  NSDebugMLLog(@"WaylandDnD", @"WaylandDragView: drag cursor hotspot=(%g,%g)",
               hotspot.x, hotspot.y);

  WaylandServer *server = (WaylandServer *)GSCurrentServer();
  [server imagecursor: hotspot : anImage : &_dragCursorCid];
  if (_dragCursorCid != NULL)
    [server setcursor: _dragCursorCid];
}

- (void) _clearupWindow
{
  WaylandServer *server = (WaylandServer *)GSCurrentServer();

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

- (void) _moveDraggedImageToNewPosition
{
  dragPosition = newPosition;
}

- (NSWindow *) windowAcceptingDnDunder: (NSPoint)p
                             windowRef: (int *)mouseWindowRef
{
  WaylandConfig *wlconfig =
    [(WaylandServer *)GSCurrentServer() wlconfig];
  struct window *window;
  struct output *output = NULL;

  wl_list_for_each(output, &wlconfig->output_list, link)
    break;

  if (output == NULL)
    {
      if (mouseWindowRef) *mouseWindowRef = 0;
      return nil;
    }

  int dragWinNum = (_window != nil) ? [_window windowNumber] : -1;

  struct window *candidate = NULL;
  wl_list_for_each(window, &wlconfig->window_list, link)
  {
    if (window->window_id == dragWinNum)
      continue;
    if (window->ignoreMouse || window->terminated || !window->configured)
      continue;

    float ns_x = window->pos_x;
    float ns_y = output->height - window->pos_y - window->height;

    if (p.x >= ns_x && p.x < ns_x + window->width
        && p.y >= ns_y && p.y < ns_y + window->height)
      {
        NSWindow *nswindow = GSWindowWithNumber(window->window_id);
        if (nswindow == nil) continue;
        NSCountedSet *dragTypes =
          [GSCurrentServer() dragTypesForWindow: nswindow];
        if ([dragTypes count] > 0)
          candidate = window;
      }
  }

  if (candidate != NULL)
    {
      if (mouseWindowRef) *mouseWindowRef = candidate->window_id;
      return GSWindowWithNumber(candidate->window_id);
    }

  if (mouseWindowRef) *mouseWindowRef = 0;
  return nil;
}

@end


/* ── WaylandServer (DragAndDrop) ─────────────────────────────────────────── */

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
