/*
   HaikuServer.h

   Copyright (C) 2025 Free Software Foundation, Inc.

   This file is part of GNUstep.

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

#ifndef HaikuServer_h
#define HaikuServer_h

#include "config.h"

#include <GNUstepGUI/GSDisplayServer.h>

@class NSMutableArray;
@class NSMutableDictionary;

@interface HaikuServer : GSDisplayServer
{
  NSMutableArray *_screen_list;
  NSMutableDictionary *_window_dict;
  BOOL _haiku_app_launched;
}

- (void) _initializeHaikuApplication;
- (void) _setupScreens;

@end

#endif /* HaikuServer_h */