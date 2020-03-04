/* XIMInputServer - XIM Keyboard input handling

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Christian Gillot <cgillot@neo-rousseaux.org>
   Date: Nov 2001
   Author: Adam Fedor <fedor@gnu.org>
   Date: Jan 2002

   This file is part of the GNUstep GUI Library.

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

#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <GNUstepBase/Unicode.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>

#include "xheadless/XGInputServer.h"

@interface XIMInputServer (XIMPrivate)
- (BOOL) ximInit: (Display *)dpy;
- (void) ximClose;
- (int) ximStyleInit;
- (XIC) ximCreateIC: (Window)w;
- (unsigned long) ximXicGetMask: (XIC)xic;
@end

#define BUF_LEN 255

@implementation XIMInputServer

- (id) initWithDelegate: (id)aDelegate
		   name: (NSString *)name
{
  Display *dpy = [XGServer currentXDisplay];
  return [self initWithDelegate: aDelegate display: dpy name: name];
}

- (id) initWithDelegate: (id)aDelegate
		display: (Display *)dpy
		   name: (NSString *)name
{
  return self;
}

- (void) dealloc
{
  DESTROY(server_name);
  [self ximClose];
  [super dealloc];
}

/* ----------------------------------------------------------------------
   XInputFiltering protocol methods
*/
- (BOOL) filterEvent: (XEvent *)event
{
  return NO;
}

- (NSString *) lookupStringForEvent: (XKeyEvent *)event 
			     window: (gswindow_device_t *)windev
			     keysym: (KeySym *)keysymptr
{
  return nil;
}

/* ----------------------------------------------------------------------
   NSInputServiceProvider protocol methods
*/
- (void) activeConversationChanged: (id)sender
		 toNewConversation: (long)newConversation
{
}

- (void) activeConversationWillChange: (id)sender
		  fromOldConversation: (long)oldConversation
{
  [super activeConversationWillChange: sender
	          fromOldConversation: oldConversation];
}

/* ----------------------------------------------------------------------
   XIM private methods
*/
- (BOOL) ximInit: (Display *)dpy
{
  return YES;
}

static XIMStyle
betterStyle(XIMStyle a, XIMStyle b, XIMStyle xim_requested_style)
{
  return 0;
}

- (int) ximStyleInit
{
  return 1;
}

- (void) ximClose
{
}

- (void) ximFocusICWindow: (gswindow_device_t *)windev
{
}

- (XIC) ximCreateIC: (Window)w
{
  return NULL;
}

- (unsigned long) ximXicGetMask: (XIC)xic
{
  return 0;
}

- (void) ximCloseIC: (XIC)xic
{
}

@end

@implementation XIMInputServer (InputMethod)
- (NSString *) inputMethodStyle
{
  return nil;
}

- (NSString *) fontSize: (int *)size
{
  return @"12";
}

- (BOOL) clientWindowRect: (NSRect *)rect
{
  if (!rect) return NO;

  *rect = NSMakeRect(0, 0, 0, 0);

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

@end // XIMInputServer (InputMethod)
