/*
   HeadlessServer.m

   Copyright (C) 1998,2002,2023 Free Software Foundation, Inc.

   Based on work by: Marcian Lytwyn <gnustep@advcsi.com> for Keysight
   Based on work by: Adam Fedor <fedor@gnu.org>

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
#include <Foundation/NSDebug.h>
#include <Foundation/NSValue.h>

#include "headless/HeadlessServer.h"

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

@implementation HeadlessServer

/* Initialize AppKit backend */
+ (void) initializeBackend
{
  NSDebugLog(@"Initializing GNUstep headless backend.\n");
  [GSDisplayServer setDefaultServerClass: [HeadlessServer class]];
  signal(SIGTERM, terminate);
  signal(SIGINT, terminate);
}

- (NSArray *)screenList
{
  NSDebugLog(@"GNUstep headless - fetching screen list");
  NSMutableArray *screens = [NSMutableArray arrayWithCapacity: 1];
  [screens addObject: [NSNumber numberWithInt: 1]];

  return screens;
}

- (NSRect) boundsForScreen: (int)screen
{
 return NSMakeRect(0, 0, 400, 400);
}

- (NSWindowDepth) windowDepthForScreen: (int) screen_num
{
  return 0;
}

- (void) styleoffsets: (float *) l : (float *) r : (float *) t : (float *) b
		     : (unsigned int) style
{
}

- (void) standardcursor: (int)style : (void **)cid
{
}


- (int) window: (NSRect)frame
		    : (NSBackingStoreType)type
		    : (unsigned int)style
		    : (int)screen
{
    return 1;
}

- (void) setwindowlevel: (int)level : (int)win
{
}

- (void) setWindowdevice: (int)win forContext: (NSGraphicsContext *)ctxt
{
}

- (void) orderwindow: (int)op : (int)otherWin : (int)winNum
{
}

- (void) setinputfocus: (int)win
{
}

- (void) imagecursor: (NSPoint)hotp : (NSImage *)image : (void **)cid
{
}
@end