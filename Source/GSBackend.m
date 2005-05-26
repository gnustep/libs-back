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
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
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

#if BUILD_SERVER == SERVER_x11
#include <x11/XGServer.h>
#elif BUILD_SERVER == SERVER_win32
#include <win32/WIN32Server.h>
#endif

/* Call the correct initalization routines for the choosen
   backend. This depends both on configuration data and defaults.
*/
@implementation GSBackend

+ (void) initializeBackend
{
  Class           contextClass;
  NSString       *context;
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

  /* Load in only one server */
#if BUILD_SERVER == SERVER_x11
  [XGServer initializeBackend];
#elif BUILD_SERVER == SERVER_win32
  [WIN32Server initializeBackend];
#else
  [NSException raise: NSInternalInconsistencyException
	       format: @"No Window Server configured in backend"];
#endif

  /* The way the frontend is currently structured
     it's not possible to have more than one */
  context = [NSString stringWithCString: STRINGIFY(BUILD_GRAPHICS)];

  /* What backend context? */
  if ([defs stringForKey: @"GSContext"])
    context = [defs stringForKey: @"GSContext"];

  if ([context isEqual: @"xdps"])
    contextClass = objc_get_class("NSDPSContext");
  else if ([context isEqual: @"art"])
    contextClass = objc_get_class("ARTContext");
  else if ([context isEqual: @"winlib"])
    contextClass = objc_get_class("WIN32Context");
   else if ([context isEqual: @"cairo"])
    contextClass = objc_get_class("CairoContext");
 else
    contextClass = objc_get_class("XGContext");

  [contextClass initializeBackend];
}

@end


