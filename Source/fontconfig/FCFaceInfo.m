/*
   FCFaceInfo.m
 
   Copyright (C) 2003 Free Software Foundation, Inc.

   August 31, 2003
   Written by Banlu Kemiyatorn <object at gmail dot com>
   Base on original code of Alex Malmberg
   Rewrite: Fred Kiefer <fredkiefer@gmx.de>
   Date: Jan 2006
 
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

#include "fontconfig/FCFaceInfo.h"
#include "fontconfig/FCFontEnumerator.h"
#include <AppKit/NSFontManager.h>

@implementation FCFaceInfo 

- (id) initWithfamilyName: (NSString *)familyName 
                   weight: (int)weight 
                   traits: (unsigned int)traits 
                  pattern: (FcPattern *)pattern
{
  _pattern = pattern;
  FcPatternReference(_pattern);

  [self setFamilyName: familyName];
  [self setWeight: weight];
  [self setTraits: traits];

  return self;
}

- (void) dealloc
{
  FcPatternDestroy(_pattern);
  RELEASE(_familyName);
  RELEASE(_characterSet);
  [super dealloc];
}

- (void) setFamilyName: (NSString *)name
{
  ASSIGN(_familyName, name);
}

- (NSString *)familyName
{
  return _familyName;
}

- (int) weight
{
  return _weight;
}

- (void) setWeight: (int)weight
{
  _weight = weight;
}

- (unsigned int) traits
{
  return _traits;
}

- (void) setTraits: (unsigned int)traits
{
  _traits = traits;
}

- (unsigned int) cacheSize
{
  return 257;
}

- (void *) fontFace
{
  [self subclassResponsibility: _cmd];
  return NULL;
}

- (FcPattern *) matchedPattern
{
  FcResult result;
  FcPattern *resolved;

  FcConfigSubstitute(NULL, _pattern, FcMatchPattern); 
  FcDefaultSubstitute(_pattern);
  resolved = FcFontMatch(NULL, _pattern, &result);

  return resolved;
}

- (NSCharacterSet*)characterSet
{
  if (_characterSet == nil && !_hasNoCharacterSet)
    {
      FcResult result;
      FcPattern *resolved;
      FcCharSet *charset;
      
      FcConfigSubstitute(NULL, _pattern, FcMatchPattern); 
      FcDefaultSubstitute(_pattern);
      resolved = FcFontMatch(NULL, _pattern, &result);
      
      if (FcResultMatch == FcPatternGetCharSet(resolved, FC_CHARSET, 0, &charset))
	{
	  _characterSet = [[FontconfigCharacterSet alloc] initWithFontconfigCharSet: charset];
	}  
      
      /* Only try to get the character set once because FcFontMatch is expensive */
      if (_characterSet == nil)
	{
	  _hasNoCharacterSet = YES;
	}

      FcPatternDestroy(resolved);
    }
  return _characterSet;
}

@end
