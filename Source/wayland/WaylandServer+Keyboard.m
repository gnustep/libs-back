/*
   WaylandServer - Keyboard Handling + zwp_text_input_v3 (IME/preedit)

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author: Riccardo Canalicchio <riccardo.canalicchio(at)gmail.com>
   Date: November 2021

   This file is part of the GNU Objective C Backend Library.

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

#include "wayland/WaylandServer.h"
#include <Foundation/NSDebug.h>

/* Informal protocol for marked (preedit) text — implemented by NSTextView. */
@interface NSObject (WaylandMarkedText)
- (void) setMarkedText: (id)aString selectedRange: (NSRange)selRange;
- (void) unmarkText;
- (void) insertText: (id)aString;
@end
#include <Foundation/NSDate.h>
#include <AppKit/NSAttributedString.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSText.h>
#include <AppKit/NSWindow.h>
#include <linux/input.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>


/* ── wl_keyboard listener ─────────────────────────────────────────────────── */

static void
keyboard_handle_keymap(void *data, struct wl_keyboard *keyboard,
		       uint32_t format, int fd, uint32_t size)
{
  WaylandConfig	*wlconfig = data;
  struct xkb_keymap *keymap;
  struct xkb_state  *state;
  char	       *map_str;

  if (!data)
    {
      close(fd);
      return;
    }

  if (format != WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1)
    {
      close(fd);
      return;
    }

  map_str = mmap(NULL, size, PROT_READ, MAP_SHARED, fd, 0);
  if (map_str == MAP_FAILED)
    {
      close(fd);
      return;
    }

  wlconfig->xkb_context = xkb_context_new(0);
  if (wlconfig->xkb_context == NULL)
    {
      fprintf(stderr, "Failed to create XKB context\n");
      return;
    }

  keymap = xkb_keymap_new_from_string(wlconfig->xkb_context, map_str,
				      XKB_KEYMAP_FORMAT_TEXT_V1, 0);
  munmap(map_str, size);
  close(fd);

  if (!keymap)
    {
      fprintf(stderr, "failed to compile keymap\n");
      return;
    }

  state = xkb_state_new(keymap);
  if (!state)
    {
      fprintf(stderr, "failed to create XKB state\n");
      xkb_keymap_unref(keymap);
      return;
    }

  xkb_keymap_unref(wlconfig->xkb.keymap);
  xkb_state_unref(wlconfig->xkb.state);
  wlconfig->xkb.keymap = keymap;
  wlconfig->xkb.state = state;

  NSDebugFLLog(@"WaylandIME", @"keyboard_handle_keymap: XKB keymap loaded (size=%u)", size);

  wlconfig->xkb.control_mask
    = 1 << xkb_keymap_mod_get_index(wlconfig->xkb.keymap, "Control");
  wlconfig->xkb.alt_mask
    = 1 << xkb_keymap_mod_get_index(wlconfig->xkb.keymap, "Mod1");
  wlconfig->xkb.shift_mask
    = 1 << xkb_keymap_mod_get_index(wlconfig->xkb.keymap, "Shift");
}

static void
keyboard_handle_enter(void *data, struct wl_keyboard *keyboard, uint32_t serial,
		      struct wl_surface *surface, struct wl_array *keys)
{
  WaylandConfig *wlconfig = data;
  wlconfig->event_serial = serial;
  NSDebugFLLog(@"WaylandIME", @"keyboard_handle_enter: serial=%u", serial);

  if (!surface)
    return;
  struct window *window = surface_get_window(surface);
  if (!window)
    return;

  wlconfig->keyboard_focus = window;

  NSWindow *nswindow = GSWindowWithNumber(window->window_id);
  if (!nswindow)
    return;

  NSEvent *ev = [NSEvent otherEventWithType:NSAppKitDefined
				   location:NSZeroPoint
			      modifierFlags:0
				  timestamp:0
			       windowNumber:window->window_id
				    context:GSCurrentContext()
				    subtype:GSAppKitWindowFocusIn
				      data1:0
				      data2:0];
  [nswindow sendEvent:ev];

  /* Enable text input so the compositor IM can send preedit/commit events. */
  if (wlconfig->text_input)
    {
      zwp_text_input_v3_enable(wlconfig->text_input);
      zwp_text_input_v3_commit(wlconfig->text_input);
    }
}

static void
keyboard_handle_leave(void *data, struct wl_keyboard *keyboard, uint32_t serial,
		      struct wl_surface *surface)
{
  WaylandConfig *wlconfig = data;
  wlconfig->event_serial = serial;
  NSDebugFLLog(@"WaylandIME", @"keyboard_handle_leave: serial=%u", serial);

  if (!wlconfig->keyboard_focus)
    {
      /* Disable text input even if we lost track of focus window. */
      if (wlconfig->text_input)
        {
          zwp_text_input_v3_disable(wlconfig->text_input);
          zwp_text_input_v3_commit(wlconfig->text_input);
        }
      return;
    }

  /* Clear any pending preedit before disabling. */
  if (wlconfig->ime_pending_preedit)
    {
      free(wlconfig->ime_pending_preedit);
      wlconfig->ime_pending_preedit = NULL;
    }

  NSWindow *nswindow = GSWindowWithNumber(wlconfig->keyboard_focus->window_id);
  if (nswindow)
    {
      NSEvent *ev = [NSEvent otherEventWithType:NSAppKitDefined
				       location:NSZeroPoint
				  modifierFlags:0
				      timestamp:0
				   windowNumber:wlconfig->keyboard_focus->window_id
					context:GSCurrentContext()
					subtype:GSAppKitWindowFocusOut
					  data1:0
					  data2:0];
      [nswindow sendEvent:ev];
    }

  wlconfig->keyboard_focus = NULL;

  if (wlconfig->text_input)
    {
      zwp_text_input_v3_disable(wlconfig->text_input);
      zwp_text_input_v3_commit(wlconfig->text_input);
      wlconfig->text_input_active = NO;
    }
}

static void
keyboard_handle_modifiers(void *data, struct wl_keyboard *keyboard,
			  uint32_t serial, uint32_t mods_depressed,
			  uint32_t mods_latched, uint32_t mods_locked,
			  uint32_t group)
{
  WaylandConfig *wlconfig = data;
  wlconfig->event_serial = serial;
  xkb_mod_mask_t mask;

  if (!wlconfig->xkb.keymap)
    return;

  xkb_state_update_mask(wlconfig->xkb.state, mods_depressed, mods_latched,
			mods_locked, 0, 0, group);
  mask
    = xkb_state_serialize_mods(wlconfig->xkb.state, XKB_STATE_MODS_DEPRESSED
						      | XKB_STATE_MODS_LATCHED);
  wlconfig->modifiers = 0;
  if (mask & wlconfig->xkb.control_mask)
    wlconfig->modifiers |= NSCommandKeyMask;
  if (mask & wlconfig->xkb.alt_mask)
    wlconfig->modifiers |= NSAlternateKeyMask;
  if (mask & wlconfig->xkb.shift_mask)
    wlconfig->modifiers |= NSShiftKeyMask;
}

static void
keyboard_handle_key(void *data, struct wl_keyboard *keyboard, uint32_t serial,
		    uint32_t time, uint32_t key, uint32_t state_w)
{
  WaylandConfig		    *wlconfig = data;
  wlconfig->event_serial = serial;
  enum wl_keyboard_key_state state = state_w;
  uint32_t		     code;

  struct window *window = wlconfig->keyboard_focus
			    ? wlconfig->keyboard_focus
			    : wlconfig->pointer.focus;
  if (!window)
    return;

  /* Resolve the XKB keycode (evdev + 8 offset). */
  code = key + 8;

  /* Build the character string for this keypress.
   *
   * xkb_state_key_get_utf8 handles the full XKB composition pipeline,
   * including dead-key sequences (e.g. dead_acute + 'e' → 'é').
   * It returns 0 for non-printable keysyms (arrows, function keys, etc.).
   */
  char utf8buf[16] = {0};
  NSString *s = @"";

  if (key == 28)          /* Enter / Return */
    {
      unichar cr = NSCarriageReturnCharacter;
      s = [NSString stringWithCharacters:&cr length:1];
    }
  else if (key == 14)     /* Backspace */
    {
      unichar del = NSDeleteCharacter;
      s = [NSString stringWithCharacters:&del length:1];
    }
  else if (wlconfig->xkb.state)
    {
      int len = xkb_state_key_get_utf8(wlconfig->xkb.state, code,
				        utf8buf, sizeof(utf8buf) - 1);
      if (len > 0)
        s = [NSString stringWithUTF8String:utf8buf];
    }

  NSEventType eventType = (state == WL_KEYBOARD_KEY_STATE_PRESSED)
                          ? NSKeyDown : NSKeyUp;

  NSEvent *ev = [NSEvent keyEventWithType:eventType
				 location:NSZeroPoint
			    modifierFlags:wlconfig->modifiers
				timestamp:time / 1000.0
			     windowNumber:window->window_id
				  context:GSCurrentContext()
			       characters:s
	      charactersIgnoringModifiers:s
				isARepeat:NO
				  keyCode:code];

  [GSCurrentServer() postEvent:ev atStart:NO];
}

static void
keyboard_handle_repeat_info(void *data, struct wl_keyboard *keyboard,
			    int32_t rate, int32_t delay)
{
  /* Key repeat is handled by AppKit; nothing to do here. */
}

const struct wl_keyboard_listener keyboard_listener
  = {keyboard_handle_keymap,	keyboard_handle_enter,
     keyboard_handle_leave,	keyboard_handle_key,
     keyboard_handle_modifiers, keyboard_handle_repeat_info};


/* ── zwp_text_input_v3 listener (IME/preedit) ────────────────────────────── */

/* Apply pending preedit to the focused text view via setMarkedText:. */
static void
apply_pending_preedit(WaylandConfig *wlconfig)
{
  if (!wlconfig->keyboard_focus || !wlconfig->ime_pending_preedit)
    return;

  NSWindow *win = GSWindowWithNumber(wlconfig->keyboard_focus->window_id);
  if (!win)
    return;

  id responder = [win firstResponder];
  if (![responder respondsToSelector:@selector(setMarkedText:selectedRange:)])
    return;

  NSString *preeditStr =
    [NSString stringWithUTF8String:wlconfig->ime_pending_preedit];
  if (!preeditStr)
    return;

  /* Underline the preedit text — standard IM convention. */
  NSAttributedString *marked =
    [[NSAttributedString alloc]
      initWithString:preeditStr
          attributes:@{NSUnderlineStyleAttributeName:
                         @(NSUnderlineStyleSingle)}];

  /* Convert byte cursor offsets to character offsets (UTF-8 → UTF-16).
   * For simplicity we use the midpoint of the preedit range as selection. */
  NSUInteger len = [preeditStr length];
  NSRange sel = (len > 0) ? NSMakeRange(len / 2, 0) : NSMakeRange(0, 0);

  [responder setMarkedText:marked selectedRange:sel];
  [marked release];
}

/* Clear any marked text that was set by the IME. */
static void
clear_marked_text(WaylandConfig *wlconfig)
{
  if (!wlconfig->keyboard_focus)
    return;
  NSWindow *win = GSWindowWithNumber(wlconfig->keyboard_focus->window_id);
  if (!win)
    return;
  id responder = [win firstResponder];
  if ([responder respondsToSelector:@selector(unmarkText)])
    [responder unmarkText];
}

static void
text_input_enter(void *data, struct zwp_text_input_v3 *ti,
                 struct wl_surface *surface)
{
  WaylandConfig *wlconfig = data;
  wlconfig->text_input_active = YES;
  NSDebugFLLog(@"WaylandIME", @"text_input_enter");

  zwp_text_input_v3_enable(ti);
  zwp_text_input_v3_commit(ti);
}

static void
text_input_leave(void *data, struct zwp_text_input_v3 *ti,
                 struct wl_surface *surface)
{
  WaylandConfig *wlconfig = data;
  NSDebugFLLog(@"WaylandIME", @"text_input_leave");

  /* Clear any preedit text the IM left behind. */
  if (wlconfig->ime_pending_preedit)
    {
      clear_marked_text(wlconfig);
      free(wlconfig->ime_pending_preedit);
      wlconfig->ime_pending_preedit = NULL;
    }
  if (wlconfig->ime_pending_commit)
    {
      free(wlconfig->ime_pending_commit);
      wlconfig->ime_pending_commit = NULL;
    }

  wlconfig->text_input_active = NO;
  zwp_text_input_v3_disable(ti);
  zwp_text_input_v3_commit(ti);
}

static void
text_input_preedit_string(void *data, struct zwp_text_input_v3 *ti,
                          const char *text, int32_t cursor_begin,
                          int32_t cursor_end)
{
  WaylandConfig *wlconfig = data;
  NSDebugFLLog(@"WaylandIME", @"text_input_preedit: '%s' [%d,%d]",
               text ? text : "", cursor_begin, cursor_end);

  free(wlconfig->ime_pending_preedit);
  wlconfig->ime_pending_preedit    = text ? strdup(text) : NULL;
  wlconfig->ime_preedit_cursor_begin = cursor_begin;
  wlconfig->ime_preedit_cursor_end   = cursor_end;
}

static void
text_input_commit_string(void *data, struct zwp_text_input_v3 *ti,
                         const char *text)
{
  WaylandConfig *wlconfig = data;
  NSDebugFLLog(@"WaylandIME", @"text_input_commit: '%s'", text ? text : "");

  free(wlconfig->ime_pending_commit);
  wlconfig->ime_pending_commit = text ? strdup(text) : NULL;
}

static void
text_input_delete_surrounding_text(void *data, struct zwp_text_input_v3 *ti,
                                   uint32_t before_length,
                                   uint32_t after_length)
{
  NSDebugFLLog(@"WaylandIME",
               @"text_input_delete_surrounding: before=%u after=%u",
               before_length, after_length);
  /* Full surrounding text deletion is deferred to a later milestone. */
}

static void
text_input_done(void *data, struct zwp_text_input_v3 *ti, uint32_t serial)
{
  WaylandConfig *wlconfig = data;
  wlconfig->ime_serial = serial;
  NSDebugFLLog(@"WaylandIME", @"text_input_done: serial=%u", serial);

  struct window *window = wlconfig->keyboard_focus;
  if (!window)
    goto cleanup;

  NSWindow *nswindow = GSWindowWithNumber(window->window_id);
  if (!nswindow)
    goto cleanup;

  id responder = [nswindow firstResponder];

  /* ── Commit string: insert text into the focused control ── */
  if (wlconfig->ime_pending_commit)
    {
      NSString *commitStr =
        [NSString stringWithUTF8String:wlconfig->ime_pending_commit];
      if (commitStr && [commitStr length] > 0)
        {
          /* Clear any preedit before committing. */
          if ([responder respondsToSelector:@selector(unmarkText)])
            [responder unmarkText];

          if ([responder respondsToSelector:@selector(insertText:)])
            {
              [responder insertText:commitStr];
            }
          else
            {
              /* Fallback: deliver each character as a key event. */
              for (NSUInteger i = 0; i < [commitStr length]; i++)
                {
                  unichar c  = [commitStr characterAtIndex:i];
                  NSString *cs = [NSString stringWithCharacters:&c length:1];
                  NSEvent *ev = [NSEvent keyEventWithType:NSKeyDown
                                                 location:NSZeroPoint
                                            modifierFlags:0
                                                timestamp:[[NSDate date]
                                                   timeIntervalSinceReferenceDate]
                                             windowNumber:window->window_id
                                                  context:nil
                                               characters:cs
                                 charactersIgnoringModifiers:cs
                                                isARepeat:NO
                                                  keyCode:0];
                  [nswindow sendEvent:ev];
                }
            }
        }
      free(wlconfig->ime_pending_commit);
      wlconfig->ime_pending_commit = NULL;
    }

  /* ── Preedit string: show/update marked text ── */
  if (wlconfig->ime_pending_preedit)
    {
      apply_pending_preedit(wlconfig);
      /* Keep ime_pending_preedit alive for area/spot queries. */
    }
  else
    {
      /* NULL preedit = clear any marked text the IM set previously. */
      clear_marked_text(wlconfig);
    }

cleanup:;
}

/* v2 events — logged but not acted on in this milestone. */
static void
text_input_action(void *data, struct zwp_text_input_v3 *ti,
                  uint32_t index, uint32_t direction)
{
  NSDebugFLLog(@"WaylandIME", @"text_input_action: idx=%u dir=%u",
               index, direction);
}

static void
text_input_language(void *data, struct zwp_text_input_v3 *ti,
                    const char *language)
{
  NSDebugFLLog(@"WaylandIME", @"text_input_language: %s",
               language ? language : "");
}

static void
text_input_preedit_hint(void *data, struct zwp_text_input_v3 *ti,
                        uint32_t start, uint32_t end, uint32_t hint)
{
  NSDebugFLLog(@"WaylandIME", @"text_input_preedit_hint: [%u,%u] hint=%u",
               start, end, hint);
}

const struct zwp_text_input_v3_listener text_input_v3_listener = {
  text_input_enter,
  text_input_leave,
  text_input_preedit_string,
  text_input_commit_string,
  text_input_delete_surrounding_text,
  text_input_done,
  text_input_action,
  text_input_language,
  text_input_preedit_hint,
};


@implementation WaylandServer (KeyboardOps)

@end
