/*
   Copyright (C) 2002, 2003, 2004, 2005 Free Software Foundation, Inc.

   Author:  Alexander Malmberg <alexander@malmberg.org>

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

#include <Foundation/NSString.h>
#include <Foundation/NSDebug.h>
#include "FTFaceInfo.h"

@interface FTFaceInfo (Private)
- (void) resolve;
@end

@implementation FTFaceInfo

/* Read the file and the hinting out of the pattern fontconfig matched, once. */
- (void) resolve
{
  FcPattern *pattern;
  FcChar8   *file = NULL;
  int        index = 0;
  FcBool     antialias = FcTrue;
  FcBool     hinting = FcTrue;
  FcBool     autohint = FcFalse;
  unsigned int hints;

  if (_resolved)
    {
      return;
    }
  _resolved = YES;

  pattern = [self matchedPattern];
  if (pattern == NULL)
    {
      return;
    }

  if (FcPatternGetString(pattern, FC_FILE, 0, &file) == FcResultMatch)
    {
      ASSIGN(_fontFile, [NSString stringWithUTF8String: (const char *)file]);
    }
  if (FcPatternGetInteger(pattern, FC_INDEX, 0, &index) == FcResultMatch)
    {
      _faceIndex = index;
    }
  FcPatternGetBool(pattern, FC_ANTIALIAS, 0, &antialias);
  FcPatternGetBool(pattern, FC_HINTING, 0, &hinting);
  FcPatternGetBool(pattern, FC_AUTOHINT, 0, &autohint);
  FcPatternDestroy(pattern);

  hints = (autohint == FcTrue ? 1 : 0) | (hinting == FcTrue ? 2 : 0);
  _renderHints = hints | (hints << 8)
    | (antialias == FcTrue ? 0x10000 : 0);
}

- (NSString *) fontFile
{
  [self resolve];
  return _fontFile;
}

- (int) faceIndex
{
  [self resolve];
  return _faceIndex;
}

- (unsigned int) renderHints
{
  [self resolve];
  return _renderHints;
}

/* The renderer opens the file itself, so there is no face to hand back. */
- (void *) fontFace
{
  return NULL;
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"<FTFaceInfo %p: '%@' %@ %i %i>",
    self, [self familyName], [self fontFile], [self weight], [self traits]];
}

- (void) dealloc
{
  DESTROY(_fontFile);
  [super dealloc];
}

@end

