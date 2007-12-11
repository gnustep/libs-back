/*
   CairoFaceInfo.h

   Copyright (C) 2003 Free Software Foundation, Inc.

   August 31, 2003
   Written by Banlu Kemiyatorn <object at gmail dot com>
   Base on code by Alexander Malmberg <alexander@malmberg.org>
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

#ifndef CAIROFACEINFO_H
#define CAIROFACEINFO_H

#include <Foundation/Foundation.h>
#include <ft2build.h>  
#include FT_FREETYPE_H
#include <cairo-ft.h>

@interface CairoFaceInfo : NSObject
{
	int _weight;
	float _italicAngle;
	unsigned int _traits;
	
	FT_Library _ftlibrary;
	FT_Face _ftface;

	cairo_font_face_t *_fontFace;
	
	NSArray *_filePaths;
	int _indexInFile;

	NSString *_familyName;
	NSString *_fullName;
}

- (id) initWithfamilyName: (NSString *)familyName
                 fullName: (NSString *)fullName
                   weight: (int)weight 
              italicAngle: (float)italicAngle
                   traits: (unsigned int)traits 
										files: (NSArray *)paths
                    index: (int)index;

- (unsigned int) cacheSize;

- (int) weight;
- (void) setWeight: (int)weight;
- (int) italicAngle;
- (void) setItalicAngle: (float)italicAngle;
- (unsigned int) traits;
- (void) setTraits: (unsigned int)traits;

- (NSString *) familyName;
- (void) setFamilyName: (NSString *)name;
- (NSString *)fullName;
- (void) setFullName: (NSString *)name;

- (void) setFiles: (NSArray *)path;
- (NSArray *)files;
- (void) setIndex: (int)index;
- (int)index;

- (cairo_font_face_t *)fontFace;

@end
#endif
