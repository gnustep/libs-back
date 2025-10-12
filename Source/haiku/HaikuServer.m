/*
   HaikuServer.m

   Copyright (C) 2025 Free Software Foundation, Inc.

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

#include "config.h"

#include <AppKit/NSApplication.h>
#include <AppKit/NSScreen.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSMutableArray.h>
#include <Foundation/NSMutableDictionary.h>

#include "haiku/HaikuServer.h"

#ifdef __cplusplus
extern "C" {
#endif

// Haiku C++ headers would go here
// #include <Application.h>
// #include <Screen.h>
// #include <Window.h>

#ifdef __cplusplus
}
#endif

/* Terminate cleanly if we get a signal to do so */
static void
terminate(int sig)
{
  if (nil != NSApp)
    {
      [NSApp terminate: NSApp];
    }
  else
    {
      exit(1);
    }
}

@implementation HaikuServer

/* Initialize AppKit backend */
+ (void) initializeBackend
{
  NSDebugLog(@"Initializing GNUstep Haiku backend.\n");
  [GSDisplayServer setDefaultServerClass: [HaikuServer class]];
  signal(SIGTERM, terminate);
  signal(SIGINT, terminate);
}

- (id) init
{
  self = [super init];
  if (self)
    {
      _screen_list = [[NSMutableArray alloc] init];
      _window_dict = [[NSMutableDictionary alloc] init];
      _haiku_app_launched = NO;
      
      [self _initializeHaikuApplication];
      [self _setupScreens];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_screen_list);
  RELEASE(_window_dict);
  [super dealloc];
}

- (void) _initializeHaikuApplication
{
  if (!_haiku_app_launched)
    {
      NSDebugLog(@"Launching Haiku BApplication...\n");
      // TODO: Initialize Haiku BApplication here
      // BApplication *app = new BApplication("application/x-vnd.GNUstep");
      _haiku_app_launched = YES;
    }
}

- (void) _setupScreens
{
  // TODO: Query Haiku screen configuration
  // For now, create a default screen
  NSScreen *screen;
  NSRect frame = NSMakeRect(0, 0, 1024, 768);
  NSDictionary *device = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInt: 0], @"NSScreenNumber",
    [NSValue valueWithRect: frame], @"NSDeviceSize",
    [NSValue valueWithRect: frame], @"NSDeviceScreenBounds",
    nil];
  
  screen = [[NSScreen alloc] initWithDevice: device];
  [_screen_list addObject: screen];
  RELEASE(screen);
}

- (NSArray *) screenList
{
  return _screen_list;
}

- (void) beep
{
  // TODO: Implement Haiku system beep
  NSDebugLog(@"Haiku beep requested\n");
}

- (BOOL) handlesWindowDecorations: (NSWindow *)window
{
  // Let Haiku handle window decorations
  return YES;
}

- (NSPoint) mouseLocationOnScreen: (NSScreen *)screen
{
  // TODO: Get mouse position from Haiku
  return NSMakePoint(0, 0);
}

- (void) restrictWindow: (int)win toImage: (NSRect)rect
{
  // TODO: Implement window shape restriction
}

- (void) setWindow: (int)win 
	      size: (NSSize)size
{
  // TODO: Resize Haiku window
}

- (void) setWindow: (int)win 
        backingType: (NSBackingStoreType)type
{
  // TODO: Set window backing store type
}

- (void) titleWindow: (int)win 
		title: (NSString *)title
{
  // TODO: Set Haiku window title
}

- (int) window: (NSRect)frame : (NSBackingStoreType)type : (unsigned int)style
	    : (int)screen
{
  // TODO: Create new Haiku window
  static int window_id = 1;
  return window_id++;
}

- (void) termwindow: (int)win
{
  // TODO: Destroy Haiku window
  [_window_dict removeObjectForKey: [NSNumber numberWithInt: win]];
}

@end