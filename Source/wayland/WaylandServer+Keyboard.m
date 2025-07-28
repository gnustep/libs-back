/* 
   WaylandServer - Keyboard Handling

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
#include <AppKit/NSEvent.h>
#include <AppKit/NSApplication.h>
#include <linux/input.h>
#include <AppKit/NSText.h>
#include <sys/mman.h>
#include <unistd.h>

static void
keyboard_handle_keymap(void *data, struct wl_keyboard *keyboard,
		       uint32_t format, int fd, uint32_t size)
{
  NSDebugLog(@"keyboard_handle_keymap");
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
  // NSDebugLog(@"keyboard_handle_enter");
  WaylandConfig	*wlconfig = data;
  wlconfig->event_serial = serial;
}

static void
keyboard_handle_leave(void *data, struct wl_keyboard *keyboard, uint32_t serial,
		      struct wl_surface *surface)
{
  WaylandConfig	*wlconfig = data;
  wlconfig->event_serial = serial;
  // NSDebugLog(@"keyboard_handle_leave");
}

static void
keyboard_handle_modifiers(void *data, struct wl_keyboard *keyboard,
			  uint32_t serial, uint32_t mods_depressed,
			  uint32_t mods_latched, uint32_t mods_locked,
			  uint32_t group)
{
  // NSDebugLog(@"keyboard_handle_modifiers");
  WaylandConfig *wlconfig = data;
  wlconfig->event_serial = serial;
  xkb_mod_mask_t mask;

  /* If we're not using a keymap, then we don't handle PC-style modifiers */
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
  // NSDebugLog(@"keyboard_handle_key: %d", key);
  WaylandConfig		*wlconfig = data;
  wlconfig->event_serial = serial;
  uint32_t		     code, num_syms;
  enum wl_keyboard_key_state state = state_w;
  const xkb_keysym_t	     *syms;
  xkb_keysym_t		     sym;
  struct window		*window = wlconfig->pointer.focus;

  if (!window)
    return;

  code = 0;
  if (key == 28)
    {
      sym = NSCarriageReturnCharacter;
    }
  else if (key == 14)
    {
      sym = NSDeleteCharacter;
    }
  else
    {
      code = key + 8;

      num_syms = xkb_state_key_get_syms(wlconfig->xkb.state, code, &syms);

      sym = XKB_KEY_NoSymbol;
      if (num_syms == 1)
	sym = syms[0];
    }

  NSString   *s = [NSString stringWithUTF8String:&sym];
  NSEventType eventType;

  if (state == WL_KEYBOARD_KEY_STATE_PRESSED)
    {
      eventType = NSKeyDown;
    }
  else
    {
      eventType = NSKeyUp;
    }

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

  // NSDebugLog(@"keyboard_handle_key: %@", s);
}

static void
keyboard_handle_repeat_info(void *data, struct wl_keyboard *keyboard,
			    int32_t rate, int32_t delay)
{
  // NSDebugLog(@"keyboard_handle_repeat_info");
}

const struct wl_keyboard_listener keyboard_listener
  = {keyboard_handle_keymap,	keyboard_handle_enter,
     keyboard_handle_leave,	keyboard_handle_key,
     keyboard_handle_modifiers, keyboard_handle_repeat_info};

@implementation
WaylandServer (KeyboardOps)

@end
