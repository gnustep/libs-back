/* WaylandInputServer - Keyboard input handling for Wayland backend

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

#ifndef _WaylandInputServer_h_INCLUDE
#define _WaylandInputServer_h_INCLUDE

#include <AppKit/NSInputServer.h>
#include "wayland/WaylandServer.h"

@interface WaylandInputServer : NSInputServer
{
  id             delegate;
  NSString      *server_name;
  int            focused_window_id;
  WaylandConfig *wlconfig;        /* back-pointer for IME geometry calls */
}

- (id) initWithDelegate: (id)aDelegate name: (NSString *)name;
- (void) setFocusedWindowId: (int)windowId;
- (int) focusedWindowId;
- (void) setWlconfig: (WaylandConfig *)config;

@end

@interface WaylandInputServer (InputMethod)
- (NSString *) inputMethodStyle;
- (NSString *) fontSize: (int *)size;
- (BOOL) clientWindowRect: (NSRect *)rect;
- (BOOL) statusArea: (NSRect *)rect;
- (BOOL) preeditArea: (NSRect *)rect;
- (BOOL) preeditSpot: (NSPoint *)p;
- (BOOL) setStatusArea: (NSRect *)rect;
- (BOOL) setPreeditArea: (NSRect *)rect;
- (BOOL) setPreeditSpot: (NSPoint *)p;
@end

#endif /* _WaylandInputServer_h_INCLUDE */
