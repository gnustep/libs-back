/* XGInputServer - Keyboard input handling

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Adam Fedor <fedor@gnu.org>
   Date: January 2002

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#ifndef _GNUstep_H_XGInputServer
#define _GNUstep_H_XGInputServer

#include <AppKit/NSInputServer.h>
#include <x11/XGServerWindow.h>

@protocol XInputFiltering
- (BOOL) filterEvent: (XEvent *)event;
- (NSString *) lookupStringForEvent: (XKeyEvent *)event 
			     window: (gswindow_device_t *)window
                             keysym: (KeySym *)keysymptr;
@end


@interface XIMInputServer: NSInputServer <XInputFiltering>
{
  id        delegate;
  NSString *server_name;
  XIM       xim;
  XIMStyle  xim_style;
  NSMutableData   *dbuf;
  NSStringEncoding encoding;
}

- (id) initWithDelegate: (id)aDelegate
		display: (Display *)dpy
		   name: (NSString *)name;
- (void) ximFocusICWindow: (gswindow_device_t *)windev;
- (void) ximCloseIC: (XIC)xic;
@end

#endif
