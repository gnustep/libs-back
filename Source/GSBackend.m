/* GSBackend - backend initialize class

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Adam Fedor <fedor@gnu.org>
   Date: Mar 2002

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

#include "config.h"
#include <Foundation/NSObject.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUserDefaults.h>

@interface GSBackend : NSObject
{
}
+ (void) initializeBackend;
@end

/* Call the correct initalization routines for the choosen
   backend. This depends both on configuration data and defaults.
   There is also a method to get a different backend class for different
   configure parameters (so you could only load in the backend configurations
   you wanted. But that is not implemented yet). */

#ifdef BUILD_X11
#include <x11/XGServer.h>
#endif
#ifdef BUILD_XLIB
#include <xlib/XGContext.h>
#endif
#ifdef BUILD_XDPS
#include <xdps/NSDPSContext.h>
#endif
#ifdef BUILD_WIN32
#include <win32/WIN32Server.h>
#endif
#ifdef BUILD_WINLIB
#include <winlib/WIN32Context.h>
#endif

@implementation GSBackend

+ (void) initializeBackend
{
  Class           contextClass;
  NSString       *context;
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

  /* Load in only one server */
#ifdef BUILD_X11
  [XGServer initializeBackend];
#else
#ifdef BUILD_WIN32
  [WIN32Server initializeBackend];
#else
  [NSException raise: NSInternalInconsistencyException
	       format: @"No Window Server configured in backend"];
#endif
#endif

  /* The way the frontend is currently structured
     it's not possible to have more than one */
#ifdef BUILD_XDPS
  context = @"xdps";
#endif
#ifdef BUILD_WINLIB
  context = @"win32";
#endif
#ifdef BUILD_XLIB
  context = @"xlib";
#endif

  /* What backend context? */
  if ([defs stringForKey: @"GSContext"])
    context = [defs stringForKey: @"GSContext"];

  if ([context isEqual: @"xdps"])
    contextClass = objc_get_class("NSDPSContext");
  else if ([context isEqual: @"win32"])
    contextClass = objc_get_class("WIN32Context");
  else
    contextClass = objc_get_class("XGContext");

  [contextClass initializeBackend];
}

@end


