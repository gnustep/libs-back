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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
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
#include "cairo/CairoFontManager.h"

@implementation CairoFontEnumerator 

+ (void) initializeBackend
{
}

- (void) enumerateFontsAndFamilies
{
  static BOOL done = NO;

  if (!done)
    {
      NSArray *fontDef;
      NSMutableArray *fontDefs;

      ASSIGN(allFontNames, [CairoFontManager allFontNames]);
      allFontFamilies =[[NSMutableDictionary alloc] init];

      fontDefs =[NSMutableArray arrayWithCapacity:10];
      [allFontFamilies setObject: fontDefs forKey:@"Helvetica"];
      fontDef =[NSArray arrayWithObjects: @"Helvetica", @"Medium",
			[NSNumber numberWithInt: 5],
			[NSNumber numberWithUnsignedInt:0], nil];
      [fontDefs addObject:fontDef];
      
      fontDef =[NSArray arrayWithObjects: @"Helvetica-Bold", @"Bold",
			[NSNumber numberWithInt: 9],
			[NSNumber numberWithUnsignedInt:NSBoldFontMask],
			nil];
      [fontDefs addObject:fontDef];
      
      fontDef =[NSArray arrayWithObjects: @"Helvetica-Oblique", @"Oblique",
			[NSNumber numberWithInt: 5],
			[NSNumber numberWithUnsignedInt:NSItalicFontMask],
			nil];
      [fontDefs addObject:fontDef];
      
      fontDefs =[NSMutableArray arrayWithCapacity:10];
      [allFontFamilies setObject: fontDefs forKey:@"Courier"];
      
      fontDef =[NSArray arrayWithObjects: @"Courier", @"Medium",
			[NSNumber numberWithInt: 5],
			[NSNumber numberWithUnsignedInt:NSFixedPitchFontMask],
			nil];
      [fontDefs addObject:fontDef];
      
      done = YES;
    }
  NSLog (@"%@", allFontNames);
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
