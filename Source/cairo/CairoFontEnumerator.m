/*
 * CairoFontEnumerator.m
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

#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSDebug.h>
#include <GNUstepGUI/GSFontInfo.h>
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>

#include "gsc/GSGState.h"
#include "cairo/CairoFontEnumerator.h"
#include "cairo/CairoFontInfo.h"

@implementation CairoFontEnumerator 

NSMutableDictionary * __allFonts;

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

- (void) enumerateFontsAndFamilies
{
  static BOOL done = NO;

  if (!done)
    {
      NSArray *fontDef;
      NSMutableArray *fontDefs;
      CairoFaceInfo *aFace;

      __allFonts = [[NSMutableDictionary alloc] init];
      allFontFamilies =[[NSMutableDictionary alloc] init];

      fontDefs =[NSMutableArray arrayWithCapacity:10];
      [allFontFamilies setObject: fontDefs forKey:@"Helvetica"];

      fontDef =[NSArray arrayWithObjects: @"Helvetica", @"Medium",
			[NSNumber numberWithInt: 5],
			[NSNumber numberWithUnsignedInt:0], nil];
      [fontDefs addObject:fontDef];
      aFace = [[CairoFaceInfo alloc] initWithName: @"Medium" 
				     familyName: @"Helvetica" 
				     displayName: @"Helvetica" 
				     cairoName: @"serif" 
				     weight: 5 
				     traits: 0 
				     cairoSlant: CAIRO_FONT_SLANT_NORMAL 
				     cairoWeight: CAIRO_FONT_WEIGHT_NORMAL];
      [__allFonts setObject: aFace forKey: @"Helvetica"];
      RELEASE(aFace);
    
      fontDef =[NSArray arrayWithObjects: @"Helvetica-Bold", @"Bold",
			[NSNumber numberWithInt: 9],
			[NSNumber numberWithUnsignedInt:NSBoldFontMask],
			nil];
      [fontDefs addObject:fontDef];
      aFace = [[CairoFaceInfo alloc] initWithName: @"Bold" 
				     familyName: @"Helvetica" 
				     displayName: @"Helvetica Bold" 
				     cairoName: @"serif" 
				     weight: 9 
				     traits: NSBoldFontMask 
				     cairoSlant: CAIRO_FONT_SLANT_NORMAL 
				     cairoWeight: CAIRO_FONT_WEIGHT_BOLD];
      [__allFonts setObject: aFace forKey: @"Helvetica-Bold"];
      RELEASE(aFace);
      
      fontDef =[NSArray arrayWithObjects: @"Helvetica-Oblique", @"Oblique",
			[NSNumber numberWithInt: 5],
			[NSNumber numberWithUnsignedInt:NSItalicFontMask],
			nil];
      [fontDefs addObject:fontDef];
      aFace = [[CairoFaceInfo alloc] initWithName: @"Oblique" 
				     familyName: @"Helvetica" 
				     displayName: @"Helvetica Oblique" 
				     cairoName: @"serif" 
				     weight: 5 
				     traits: NSItalicFontMask 
				     cairoSlant: CAIRO_FONT_SLANT_OBLIQUE 
				     cairoWeight: CAIRO_FONT_WEIGHT_NORMAL];
      [__allFonts setObject: aFace forKey: @"Helvetica-Oblique"];
      RELEASE(aFace);

      fontDefs =[NSMutableArray arrayWithCapacity:10];
      [allFontFamilies setObject: fontDefs forKey:@"Courier"];
      
      fontDef =[NSArray arrayWithObjects: @"Courier", @"Medium",
			[NSNumber numberWithInt: 5],
			[NSNumber numberWithUnsignedInt:NSFixedPitchFontMask],
			nil];
      [fontDefs addObject:fontDef];
      aFace = [[CairoFaceInfo alloc] initWithName: @"Medium" 
				     familyName: @"Courier" 
				     displayName: @"Courier" 
				     cairoName: @"Courier" 
				     weight: 5 
				     traits: NSFixedPitchFontMask 
				     cairoSlant: CAIRO_FONT_SLANT_NORMAL 
				     cairoWeight: CAIRO_FONT_WEIGHT_NORMAL];
      [__allFonts setObject: aFace forKey: @"Courier"];
      RELEASE(aFace);
      
      ASSIGN(allFontNames, [__allFonts allKeys]);
      done = YES;
    }
  //NSLog (@"%@", allFontNames);
}

- (NSString *) defaultSystemFontName
{
  return @"Helvetica";
}

- (NSString *) defaultBoldSystemFontName
{
  return @"Helvetica-Bold";
}

- (NSString *) defaultFixedPitchFontName
{
  return @"Courier";
}

@end
