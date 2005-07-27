/*
 * CairoFaceInfo.h

 * Copyright (C) 2003 Free Software Foundation, Inc.
 * August 31, 2003
 * Written by Banlu Kemiyatorn <object at gmail dot com>
 * Base on code by Alexander Malmberg <alexander@malmberg.org>
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.

 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef CAIROFACEINFO_H
#define CAIROFACEINFO_H
#include <Foundation/Foundation.h>
#include <cairo.h>

@interface CairoFaceInfo : NSObject
{
	int _weight;
	unsigned int _traits;

	cairo_font_slant_t _c_slant;
	cairo_font_weight_t _c_weight;
	cairo_font_face_t *_fontFace; 

	NSString *_faceName;
	NSString *_familyName;
	NSString *_displayName;
	NSString *_cairoName;
}

- (id) initWithName: (NSString *)name 
	 familyName: (NSString *)familyName 
	displayName: (NSString *)displayName 
	  cairoName: (NSString *)cairoName 
	     weight: (int)weight 
	     traits: (unsigned int)traits 
	 cairoSlant: (cairo_font_slant_t)cairoSlant 
        cairoWeight: (cairo_font_weight_t)cairoWeight;
- (unsigned int) cacheSize;

- (cairo_font_weight_t) cairoWeight;
- (void) setCairoWeight: (cairo_font_weight_t) weight;
- (cairo_font_slant_t) cairoSlant;
- (void) setCairoSlant: (cairo_font_slant_t) slant;

- (int) weight;
- (void) setWeight: (int)weight;
- (unsigned int) traits;
- (void) setTraits: (unsigned int)traits;

- (NSString *) displayName;
- (void) setDisplayName: (NSString *)name;
- (NSString *) familyName;
- (void) setFamilyName: (NSString *)name;
- (NSString *) name;
- (void) setName: (NSString *)name;
- (const char *) cairoCName;
- (void) setCairoName: (NSString *)name;
- (cairo_font_face_t *)fontFace;



@end
#endif
