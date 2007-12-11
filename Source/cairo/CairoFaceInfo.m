/*
   CairoFaceInfo.m
 
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
   version 3 of the License, or (at your option) any later version.

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

#include "cairo/CairoFaceInfo.h"
#include <cairo-ft.h>
#include <AppKit/NSFontManager.h>

@implementation CairoFaceInfo

- (id) initWithfamilyName: (NSString *)familyName
                 fullName: (NSString *)fullName
                   weight: (int)weight 
              italicAngle: (float)italicAngle
                   traits: (unsigned int)traits 
										files: (NSArray *)paths
                    index: (int)index
{
	[super init];

  [self setFamilyName: familyName];
	[self setFullName: fullName];
  [self setWeight: weight];
  [self setItalicAngle: italicAngle];
  [self setTraits: traits];
  [self setFiles: paths];
  [self setIndex: index];
	
	return self;
}

- (void) dealloc
{
  if (_fontFace)
    {
      cairo_font_face_destroy(_fontFace);
    }
	if (_ftface)
		{
			FT_Done_Face(_ftface);
		}
	if (_ftlibrary)
		{
			FT_Done_FreeType(_ftlibrary);
		}
  RELEASE(_familyName);
	RELEASE(_filePaths);

  [super dealloc];
}

- (NSString *)familyName
{
  return _familyName;
}

- (void) setFamilyName: (NSString *)name
{
  ASSIGN(_familyName, name);
}

- (NSString *)fullName
{
  return _fullName;
}

- (void) setFullName: (NSString *)name
{
  ASSIGN(_fullName, name);
}

- (int) weight
{
  return _weight;
}

- (void) setWeight: (int)weight
{
  _weight = weight;
}

- (int) italicAngle
{
  return _italicAngle;
}

- (void) setItalicAngle: (float)italicAngle
{
  _italicAngle = italicAngle;
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

- (void) setFiles: (NSArray *)paths
{
  ASSIGN(_filePaths, paths);
}

- (NSArray *)files
{
  return _filePaths;
}

- (void) setIndex: (int)index
{
  _indexInFile = index;
}

- (int)index
{
  return _indexInFile;
}

- (cairo_font_face_t *)fontFace
{
  if (!_fontFace)
    {
			const char *cPath;
			int i;
			int count;
			
			/* FIXME: There should only be one FT_Library for all faces. */
			if (!_ftlibrary)
			{
				FT_Init_FreeType(&_ftlibrary);
			}
			
			if (! _ftface)
				{
					count = [_filePaths count];
					for (i = 0; i < count; i++)
						{
							cPath = [[_filePaths objectAtIndex: i] UTF8String];
							
							if (i > 0)
								{
									if (FT_Attach_File(_ftface, cPath) != 0)
										NSLog(@"Could not attach %@ to font face.",
										      [_filePaths objectAtIndex: i]);
								}
							else
								{
									if (FT_New_Face(_ftlibrary, cPath, _indexInFile, &_ftface) != 0)
										{
											NSLog(@"Creating a font face failed %@", _familyName);
											_ftface = NULL;
											return NULL;
										}
								}
						}
				}
      _fontFace =
				cairo_ft_font_face_create_for_ft_face(_ftface, FT_LOAD_DEFAULT);
			
      if ((!_fontFace)
	|| (cairo_font_face_status(_fontFace) != CAIRO_STATUS_SUCCESS))
	{
	  NSLog(@"Creating a font face failed %@", _familyName);
	  cairo_font_face_destroy(_fontFace);
		
		FT_Done_Face(_ftface);
		FT_Done_FreeType(_ftlibrary);
		
	  _fontFace = NULL;
		_ftface = NULL;
		_ftlibrary = NULL;
	  return NULL;
	}
    }

  return _fontFace;
}

@end
