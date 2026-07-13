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

#include "config.h"

#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSWindow.h>
#include <GNUstepGUI/GSDisplayServer.h>

#include "wayland/WaylandInputServer.h"

@implementation WaylandInputServer

- (id) initWithDelegate: (id)aDelegate name: (NSString *)name
{
  delegate = aDelegate;
  ASSIGN(server_name, name);
  focused_window_id = 0;
  NSDebugLog(@"WaylandInputServer: initialized");
  return self;
}

- (void) dealloc
{
  DESTROY(server_name);
  [super dealloc];
}

- (void) setFocusedWindowId: (int)windowId
{
  focused_window_id = windowId;
  NSDebugLog(@"WaylandInputServer: focused window id = %d", windowId);
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

  /* sender is a text client; -window is checked via respondsToSelector above */
  NSWindow *window = [sender performSelector: @selector(window)];
  if (window != nil)
    {
      focused_window_id = [window windowNumber];
      NSDebugLog(@"WaylandInputServer: conversation changed, focused window = %d",
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
  /* Wayland keyboard input is handled directly via XKB in WaylandServer+Keyboard.m.
     No input method overlay is used. */
  return nil;
}

- (NSString *) fontSize: (int *)size
{
  NSString *str;

  str = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSFontSize"];
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

- (BOOL) statusArea: (NSRect *)rect
{
  return NO;
}

- (BOOL) preeditArea: (NSRect *)rect
{
  return NO;
}

- (BOOL) preeditSpot: (NSPoint *)p
{
  return NO;
}

- (BOOL) setStatusArea: (NSRect *)rect
{
  return NO;
}

- (BOOL) setPreeditArea: (NSRect *)rect
{
  return NO;
}

- (BOOL) setPreeditSpot: (NSPoint *)p
{
  return NO;
}

@end
