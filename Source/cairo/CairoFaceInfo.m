/*
 * CairoFaceInfo.m
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 * August 31, 2003
 * Written by Banlu Kemiyatorn <object at gmail dot com>
 * Base on original code of Alex Malmberg
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
 */

#include "cairo/CairoFaceInfo.h"

@ implementation CairoFaceInfo 

- (id) initWithName: (NSString *)name 
	 familyName: (NSString *)familyName 
	displayName: (NSString *)displayName 
	  cairoName: (NSString *)cairoName 
	     weight: (int)weight 
	     traits: (unsigned int)traits 
	 cairoSlant: (cairo_font_slant_t)cairoSlant 
	cairoWeight: (cairo_font_weight_t)cairoWeight
{
  [self setName: name];
  [self setFamilyName: familyName];
  [self setDisplayName: displayName];
  [self setCairoName: cairoName];
  [self setWeight: weight];
  [self setTraits: traits];
  [self setCairoSlant: cairoSlant];
  [self setCairoWeight: cairoWeight];

  return self;
}

- (void) setFamilyName: (NSString *)name
{
  ASSIGN(_familyName, name);
}

- (void) setName: (NSString *)name
{
  ASSIGN(_faceName, name);
}

- (void) setDisplayName: (NSString *)name
{
  ASSIGN(_displayName, name);
}

- (const char *) cairoCName
{
  return [_cairoName lossyCString];
}

- (void) setCairoName: (NSString *)name
{
  ASSIGN(_cairoName, name);
}

- (NSString *)familyName
{
  return _familyName;
}

- (NSString *) name
{
  return _faceName;
}

- (NSString *) displayName
{
  return _displayName;
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

- (cairo_font_weight_t) cairoWeight
{
  return _c_weight;
}

- (cairo_font_slant_t) cairoSlant
{
  return _c_slant;
}

- (void) setCairoWeight: (cairo_font_weight_t)weight
{
  _c_weight = weight;
}

- (void) setCairoSlant: (cairo_font_slant_t)slant
{
  _c_slant = slant;
}

- (void) setTraits: (unsigned int)traits
{
  _traits = traits;
}

- (unsigned int) cacheSize
{
  return 257;
}

@end
