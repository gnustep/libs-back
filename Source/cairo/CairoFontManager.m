/*
 * CairoFontManager.m
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
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include "cairo/CairoFontManager.h"
#include "cairo/CairoFaceInfo.h"

@implementation CairoFontManager 

NSMutableDictionary * __allFonts;
NSMutableArray *__allFamilies;

+ (void) addFace: (CairoFaceInfo *)aFace PostScriptName: (NSString *)psname
{
  [__allFonts setObject: aFace forKey: psname];
  if (![__allFamilies containsObject: [aFace familyName]])
    {
      [__allFamilies addObject: [aFace familyName]];
    }
}

+ (void) initialize
{
  id aFace;

  NSLog(@"init cairo font manager");
  __allFonts = [[NSMutableDictionary alloc] init];
  __allFamilies = [[NSMutableArray alloc] init];
  aFace = [[CairoFaceInfo alloc] initWithName: @"Medium" 
				 familyName: @"Helvetica" 
				 displayName: @"Helvetica" 
				 cairoName: @"serif" 
				 weight: 5 
				 traits: 0 
				 cairoSlant: CAIRO_FONT_SLANT_NORMAL 
				 cairoWeight: CAIRO_FONT_WEIGHT_NORMAL];
  AUTORELEASE(aFace);
  [self addFace: aFace PostScriptName: @"Helvetica"];

  aFace = [[CairoFaceInfo alloc] initWithName: @"Bold" 
				 familyName: @"Helvetica" 
				 displayName: @"Helvetica Bold" 
				 cairoName: @"serif" 
				 weight: 9 
				 traits: NSBoldFontMask 
				 cairoSlant: CAIRO_FONT_SLANT_NORMAL 
				 cairoWeight: CAIRO_FONT_WEIGHT_BOLD];
  AUTORELEASE(aFace);
  [self addFace: aFace PostScriptName: @"Helvetica-Bold"];

  aFace = [[CairoFaceInfo alloc] initWithName: @"Oblique" 
				 familyName: @"Helvetica" 
				 displayName: @"Helvetica Oblique" 
				 cairoName: @"serif" 
				 weight: 5 
				 traits: NSItalicFontMask 
				 cairoSlant: CAIRO_FONT_SLANT_OBLIQUE 
				 cairoWeight: CAIRO_FONT_WEIGHT_NORMAL];
  AUTORELEASE(aFace);
  [self addFace: aFace PostScriptName: @"Helvetica-Oblique"];

  aFace = [[CairoFaceInfo alloc] initWithName: @"Medium" 
				 familyName: @"Courier" 
				 displayName: @"Courier" 
				 cairoName: @"Courier" 
				 weight: 5 
				 traits: NSFixedPitchFontMask 
				 cairoSlant: CAIRO_FONT_SLANT_NORMAL 
				 cairoWeight: CAIRO_FONT_WEIGHT_NORMAL];
  AUTORELEASE(aFace);
  [self addFace: aFace PostScriptName: @"Courier"];
}

+ (CairoFaceInfo *) fontWithName: (NSString *) name
{
  CairoFaceInfo *face;

  face =[__allFonts objectForKey: name];
  if (!face)
    {
      NSLog (@"Font not found %@", name);
    }
  return face;
}

+ (NSArray *) allFontNames
{
  return [__allFonts allKeys];
}

@end
