/* WaylandInputServer - Input method / preedit support for Wayland backend

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

#include "config.h"

#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSScreen.h>
#include <AppKit/NSWindow.h>
#include <GNUstepGUI/GSDisplayServer.h>

#include "wayland/WaylandInputServer.h"

/* Commit pending text_input state to the compositor. */
static void
commit_text_input(WaylandConfig *wlconfig)
{
  if (wlconfig && wlconfig->text_input)
    {
      zwp_text_input_v3_commit(wlconfig->text_input);
      wl_display_flush(wlconfig->display);
    }
}


@implementation WaylandInputServer

- (id) initWithDelegate: (id)aDelegate name: (NSString *)name
{
  delegate   = aDelegate;
  ASSIGN(server_name, name);
  focused_window_id = 0;
  wlconfig          = NULL;
  NSDebugMLLog(@"WaylandIME", @"WaylandInputServer: initialized");
  return self;
}

- (void) dealloc
{
  DESTROY(server_name);
  [super dealloc];
}

- (void) setWlconfig: (WaylandConfig *)config
{
  wlconfig = config;
}

- (void) setFocusedWindowId: (int)windowId
{
  focused_window_id = windowId;
  NSDebugMLLog(@"WaylandIME", @"WaylandInputServer: focused window id = %d", windowId);
}

- (int) focusedWindowId
{
  return focused_window_id;
}


/* NSInputServiceProvider protocol */

- (void) activeConversationChanged: (id)sender
             toNewConversation: (long)newConversation
{
  [super activeConversationChanged: sender toNewConversation: newConversation];

  if ([sender respondsToSelector: @selector(window)] == NO)
    return;

  NSWindow *window = [sender performSelector: @selector(window)];
  if (window != nil)
    {
      focused_window_id = [window windowNumber];
      NSDebugMLLog(@"WaylandIME",
                   @"WaylandInputServer: conversation changed, focused window = %d",
                   focused_window_id);
    }
}

- (void) activeConversationWillChange: (id)sender
             fromOldConversation: (long)oldConversation
{
  [super activeConversationWillChange: sender
             fromOldConversation: oldConversation];
}

@end


@implementation WaylandInputServer (InputMethod)

- (NSString *) inputMethodStyle
{
  /* When text_input_v3 is available the preedit is delivered inline via
   * setMarkedText:selectedRange: on the focused responder; no separate IM
   * window is needed.  Return nil so AppKit does not try to manage an IM
   * panel on our behalf.                                                  */
  return nil;
}

- (NSString *) fontSize: (int *)size
{
  NSString *str = [[NSUserDefaults standardUserDefaults]
                    stringForKey: @"NSFontSize"];
  if (!str)
    str = @"12";
  if (size)
    *size = (int) strtol([str cString], NULL, 10);
  return str;
}

- (BOOL) clientWindowRect: (NSRect *)rect
{
  if (!rect || focused_window_id == 0)
    return NO;
  NSWindow *window = GSWindowWithNumber(focused_window_id);
  if (window == nil)
    return NO;
  *rect = [window frame];
  return YES;
}

/* ── IME geometry: status area ─────────────────────────────────────────────
 *
 * The status area is where the IM draws its mode indicator (e.g. "あ" for
 * hiragana mode).  We report the bottom-left corner of the focused window
 * as a reasonable default; a real status bar is not rendered in the backend.
 */
- (BOOL) statusArea: (NSRect *)rect
{
  if (!rect)
    return NO;

  if (focused_window_id != 0)
    {
      NSWindow *window = GSWindowWithNumber(focused_window_id);
      if (window)
        {
          NSRect frame = [window frame];
          *rect = NSMakeRect(frame.origin.x,
                             frame.origin.y,
                             frame.size.width,
                             20.0);
          return YES;
        }
    }

  /* Fallback: bottom-left of screen. */
  NSRect screen = [[NSScreen mainScreen] frame];
  *rect = NSMakeRect(screen.origin.x, screen.origin.y, screen.size.width, 20.0);
  return YES;
}

/* ── IME geometry: preedit area ─────────────────────────────────────────────
 *
 * The preedit area covers the region where candidate text is displayed.
 * We return the stored rect if we have one, otherwise the client window rect.
 */
- (BOOL) preeditArea: (NSRect *)rect
{
  if (!rect)
    return NO;

  if (wlconfig && !NSIsEmptyRect(wlconfig->ime_preedit_rect))
    {
      *rect = wlconfig->ime_preedit_rect;
      return YES;
    }

  return [self clientWindowRect: rect];
}

/* ── IME geometry: preedit spot ─────────────────────────────────────────────
 *
 * The preedit spot is the screen coordinate of the text-insertion cursor.
 * The compositor IM uses this to position its candidate window.
 */
- (BOOL) preeditSpot: (NSPoint *)p
{
  if (!p)
    return NO;

  if (wlconfig && wlconfig->text_input_active)
    {
      *p = wlconfig->ime_preedit_spot;
      return YES;
    }

  /* Fallback: centre of the focused window. */
  if (focused_window_id != 0)
    {
      NSWindow *window = GSWindowWithNumber(focused_window_id);
      if (window)
        {
          NSRect frame = [window frame];
          *p = NSMakePoint(NSMidX(frame), NSMidY(frame));
          return YES;
        }
    }

  return NO;
}

/* ── IME geometry setters ───────────────────────────────────────────────────
 *
 * AppKit calls these when the text cursor moves.  We store the values and
 * forward them to the compositor via set_cursor_rectangle so the IM can
 * reposition its candidate window.
 */
- (BOOL) setStatusArea: (NSRect *)rect
{
  /* Status area is compositor-managed; acknowledge but don't act. */
  return YES;
}

- (BOOL) setPreeditArea: (NSRect *)rect
{
  if (!rect || !wlconfig)
    return NO;

  wlconfig->ime_preedit_rect = *rect;

  if (wlconfig->text_input && wlconfig->text_input_active)
    {
      zwp_text_input_v3_set_cursor_rectangle(
          wlconfig->text_input,
          (int32_t) rect->origin.x,
          (int32_t) rect->origin.y,
          (int32_t) rect->size.width,
          (int32_t) rect->size.height);
      commit_text_input(wlconfig);
    }

  return YES;
}

- (BOOL) setPreeditSpot: (NSPoint *)p
{
  if (!p || !wlconfig)
    return NO;

  wlconfig->ime_preedit_spot = *p;

  /* Forward cursor position as a 1×(line-height) rectangle. */
  if (wlconfig->text_input && wlconfig->text_input_active)
    {
      int32_t lineHeight = 16; /* sensible default; AppKit can update via setPreeditArea: */
      zwp_text_input_v3_set_cursor_rectangle(
          wlconfig->text_input,
          (int32_t) p->x,
          (int32_t) p->y,
          0,
          lineHeight);
      commit_text_input(wlconfig);
      NSDebugMLLog(@"WaylandIME",
                   @"WaylandInputServer: preedit spot → (%g,%g)", p->x, p->y);
    }

  return YES;
}

@end
