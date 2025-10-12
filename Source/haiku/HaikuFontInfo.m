/*
   HaikuFontInfo.m

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
#include <Foundation/NSString.h>

#include "haiku/HaikuFontInfo.h"

@implementation HaikuFontInfo

- (id) init
{
  self = [super init];
  if (self)
    {
      _haiku_font = NULL;
    }
  return self;
}

- (void) dealloc
{
  if (_haiku_font)
    {
      // TODO: delete (BFont*)_haiku_font;
    }
  [super dealloc];
}

- (void*) haikuFont
{
  return _haiku_font;
}

- (void) setFamilyName: (NSString*)name
{
  [super setFamilyName: name];
  // TODO: Update Haiku font family
  NSDebugLog(@"HaikuFontInfo setFamilyName: %@ not implemented\n", name);
}

- (float) pointSize
{
  // TODO: Get size from Haiku font
  return [super pointSize];
}

- (void) setPointSize: (float)size
{
  [super setPointSize: size];
  // TODO: Update Haiku font size
  NSDebugLog(@"HaikuFontInfo setPointSize: %f not implemented\n", size);
}

- (NSRect) boundingRectForFont
{
  // TODO: Get bounding rect from Haiku font metrics
  return [super boundingRectForFont];
}

- (float) widthOfString: (NSString*)string
{
  // TODO: Calculate string width using Haiku BFont::StringWidth
  NSDebugLog(@"HaikuFontInfo widthOfString not implemented\n");
  return 0.0;
}

@end