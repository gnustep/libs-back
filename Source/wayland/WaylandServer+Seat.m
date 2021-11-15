/* 
   WaylandServer - Seat Handling

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

extern const struct wl_keyboard_listener keyboard_listener;

extern const struct wl_pointer_listener pointer_listener;

static void
seat_handle_capabilities(void *data, struct wl_seat *seat,
			 enum wl_seat_capability caps)
{
  WaylandConfig *wlconfig = data;

  if ((caps & WL_SEAT_CAPABILITY_POINTER) && !wlconfig->pointer.wlpointer)
    {
      wlconfig->pointer.wlpointer = wl_seat_get_pointer(seat);
      wl_pointer_set_user_data(wlconfig->pointer.wlpointer, wlconfig);
      wl_pointer_add_listener(wlconfig->pointer.wlpointer, &pointer_listener,
			      wlconfig);
    }
  else if (!(caps & WL_SEAT_CAPABILITY_POINTER) && wlconfig->pointer.wlpointer)
    {
      if (wlconfig->seat_version >= WL_POINTER_RELEASE_SINCE_VERSION)
	wl_pointer_release(wlconfig->pointer.wlpointer);
      else
	wl_pointer_destroy(wlconfig->pointer.wlpointer);
      wlconfig->pointer.wlpointer = NULL;
    }

  wl_display_dispatch_pending(wlconfig->display);
  wl_display_flush(wlconfig->display);

  if ((caps & WL_SEAT_CAPABILITY_KEYBOARD) && !wlconfig->keyboard)
    {
      wlconfig->keyboard = wl_seat_get_keyboard(seat);
      wl_keyboard_set_user_data(wlconfig->keyboard, wlconfig);
      wl_keyboard_add_listener(wlconfig->keyboard, &keyboard_listener,
			       wlconfig);
    }
  else if (!(caps & WL_SEAT_CAPABILITY_KEYBOARD) && wlconfig->keyboard)
    {
      if (wlconfig->seat_version >= WL_KEYBOARD_RELEASE_SINCE_VERSION)
	wl_keyboard_release(wlconfig->keyboard);
      else
	wl_keyboard_destroy(wlconfig->keyboard);
      wlconfig->keyboard = NULL;
    }

#if 0
    if ((caps & WL_SEAT_CAPABILITY_TOUCH) && !input->touch) {
	input->touch = wl_seat_get_touch(seat);
	wl_touch_set_user_data(input->touch, input);
	wl_touch_add_listener(input->touch, &touch_listener, input);
    } else if (!(caps & WL_SEAT_CAPABILITY_TOUCH) && input->touch) {
	if (input->seat_version >= WL_TOUCH_RELEASE_SINCE_VERSION)
	    wl_touch_release(input->touch);
	else
	    wl_touch_destroy(input->touch);
	input->touch = NULL;
    }
#endif
}

const struct wl_seat_listener seat_listener = {
  seat_handle_capabilities,
};
