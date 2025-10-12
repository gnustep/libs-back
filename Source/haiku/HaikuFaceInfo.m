/*
   HaikuFaceInfo.m

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

#include <Foundation/NSDebug.h>

#include "haiku/HaikuFaceInfo.h"

@implementation HaikuFaceInfo

+ (void) initialize
{
  [GSFaceInfo setFaceInfoClass: self];
}

- (id) init
{
  self = [super init];
  if (self)
    {
      NSDebugLog(@"HaikuFaceInfo initialized\n");
    }
  return self;
}

// Font face information methods would be implemented here
// These would query Haiku's font system for detailed font metrics

@end