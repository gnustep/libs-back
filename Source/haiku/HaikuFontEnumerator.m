/*
   HaikuFontEnumerator.m

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
#include <Foundation/NSArray.h>

#include "haiku/HaikuFontEnumerator.h"

@implementation HaikuFontEnumerator

+ (void) initialize
{
  [GSFontEnumerator setFontEnumeratorClass: self];
}

- (void) enumerateFontsAndFamilies
{
  NSDebugLog(@"HaikuFontEnumerator enumerateFontsAndFamilies\n");
  
  // TODO: Enumerate fonts using Haiku API
  // This would typically use count_font_families() and get_font_family()
  // to discover all available fonts on the system
  
  // For now, add some default fonts that are commonly available on Haiku
  [self addFontFamily: @"DejaVu Sans" traits: 0 weight: 5 isFixedPitch: NO];
  [self addFontFamily: @"DejaVu Serif" traits: 0 weight: 5 isFixedPitch: NO];  
  [self addFontFamily: @"DejaVu Sans Mono" traits: 0 weight: 5 isFixedPitch: YES];
  [self addFontFamily: @"Noto Sans" traits: 0 weight: 5 isFixedPitch: NO];
  [self addFontFamily: @"Noto Serif" traits: 0 weight: 5 isFixedPitch: NO];
  
  // These would be discovered programmatically:
  /*
  int32 font_family_count = count_font_families();
  for (int32 i = 0; i < font_family_count; i++) 
    {
      font_family family;
      if (get_font_family(i, &family) == B_OK)
        {
          NSString *familyName = [NSString stringWithCString: family
                                                    encoding: NSUTF8StringEncoding];
          
          int32 style_count = count_font_styles(family);
          for (int32 j = 0; j < style_count; j++)
            {
              font_style style;
              uint16 face;
              if (get_font_style(family, j, &style, &face) == B_OK)
                {
                  // Determine traits based on face flags
                  NSFontTraitMask traits = 0;
                  int weight = 5; // medium weight
                  
                  if (face & B_ITALIC_FACE)
                    traits |= NSItalicFontMask;
                  if (face & B_BOLD_FACE)
                    {
                      traits |= NSBoldFontMask;
                      weight = 9;
                    }
                  if (face & B_CONDENSED_FACE)
                    traits |= NSCondensedFontMask;
                    
                  // Check if fixed pitch - would need font metrics
                  BOOL isFixedPitch = NO;
                  
                  [self addFontFamily: familyName 
                               traits: traits 
                               weight: weight 
                         isFixedPitch: isFixedPitch];
                }
            }
        }
    }
  */
}

@end