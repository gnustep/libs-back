/*
   HaikuGState.m

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

#include "haiku/HaikuGState.h"
#include "haiku/HaikuContext.h"

@implementation HaikuGState

+ (void) initialize
{
  [GSGState setGStateClass: self];
}

+ (Class) contextClass
{
  return [HaikuContext class];
}

- (id) init
{
  self = [super init];
  if (self)
    {
      NSDebugLog(@"HaikuGState initialized\n");
    }
  return self;
}

// Color and drawing state management would go here
// These methods would set appropriate Haiku drawing state

- (void) setFillColor: (NSColor*)color
{
  [super setFillColor: color];
  // TODO: Set Haiku fill color
  NSDebugLog(@"HaikuGState setFillColor not implemented\n");
}

- (void) setStrokeColor: (NSColor*)color
{
  [super setStrokeColor: color];
  // TODO: Set Haiku stroke color
  NSDebugLog(@"HaikuGState setStrokeColor not implemented\n");
}

- (void) setLineWidth: (float)width
{
  [super setLineWidth: width];
  // TODO: Set Haiku line width
  NSDebugLog(@"HaikuGState setLineWidth not implemented\n");
}

@end