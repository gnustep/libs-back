/* Win32FontInfo - Implements font enumerator for MSWindows

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   
   This file is part of the GNU Objective C User Interface Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/


#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>

#include "winlib/WIN32FontInfo.h"

@interface WIN32FontInfo (Private)
- (BOOL) setupAttributes;
@end

@implementation WIN32FontInfo

- initWithFontName: (NSString*)name matrix: (const float *)fmatrix
{
  [super init];
  ASSIGN(fontName, name);
  memcpy(matrix, fmatrix, sizeof(matrix));

  if (![self setupAttributes])
    {
      RELEASE(self);
      return nil;
    }

  return self;
}

- (void) dealloc
{

  [super dealloc];
}

- (float) widthOf: (const char*) s lenght: (int) len
{
  SIZE size;
  HDC hdc;

  hdc = GetDC(NULL);
  GetTextExtentPoint32(hdc, s, len, &size);
  ReleaseDC(NULL, hdc);

  return size.cx;
}

- (float) widthOfString: (NSString*)string
{
  const char *s;
  int len;
  
  s = [string cString];
  len = strlen(s);

  return [self widthOf: s lenght: len];
}

- (NSMultibyteGlyphPacking)glyphPacking
{
  return NSOneByteGlyphPacking;
}

- (NSSize) advancementForGlyph: (NSGlyph)glyph
{
  HDC hdc;
  float w;
  ABCFLOAT abc;

  hdc = GetDC(NULL);
  //GetCharWidthFloat(hdc, glyph, glyph, &w);
  GetCharABCWidthsFloat(hdc, glyph, glyph, &abc);
  ReleaseDC(NULL, hdc);

  //NSLog(@"Width for %d is %f or %f", glyph, w, (abc.abcfA + abc.abcfB + abc.abcfC));
  w = abc.abcfA + abc.abcfB + abc.abcfC;
  return NSMakeSize(w, 0);
}

- (NSRect) boundingRectForGlyph: (NSGlyph)glyph
{
  return NSMakeRect(0, 0, 0, 0);
}

- (BOOL) glyphIsEncoded: (NSGlyph)glyph
{
  return YES;
}

- (NSGlyph) glyphWithName: (NSString*)glyphName
{
  return 0;
}

- (NSPoint) positionOfGlyph: (NSGlyph)curGlyph
	    precededByGlyph: (NSGlyph)prevGlyph
		  isNominal: (BOOL*)nominal
{
  return NSMakePoint(0, 0);
}

- (void) drawString:  (NSString*)string
	 onDC: (HDC)hdc at: (POINT)p
{
}

- (void) draw:(const char*)s lenght: (int)len 
	 onDC: (HDC)hdc at: (POINT)p
{
  TextOut(hdc, p.x, p.y - ascender, s, len); 
}

@end

@implementation WIN32FontInfo (Private)

- (BOOL) setupAttributes
{
  HDC hdc;
  TEXTMETRIC metric;

  hdc = GetDC(NULL);
  GetTextMetrics(hdc, &metric);
  ReleaseDC(NULL, hdc);

  // Fill the afmDitionary and ivars
  [fontDictionary setObject: fontName forKey: NSAFMFontName];
  //ASSIGN(familyName, XGFontFamily(xdpy, font_info));
  //[fontDictionary setObject: familyName forKey: NSAFMFamilyName];
  isFixedPitch = TMPF_FIXED_PITCH & metric.tmPitchAndFamily;
  isBaseFont = NO;
  ascender = metric.tmAscent;
  [fontDictionary setObject: [NSNumber numberWithFloat: ascender] 
		  forKey: NSAFMAscender];
  descender = -metric.tmDescent;
  [fontDictionary setObject: [NSNumber numberWithFloat: descender]
		  forKey: NSAFMDescender];

  fontBBox = NSMakeRect((float)(0),
			(float)(0 - metric.tmAscent),
			(float)metric.tmMaxCharWidth,
			(float)metric.tmHeight);

  // Should come from metric.tmCharSet
  mostCompatibleStringEncoding = NSISOLatin1StringEncoding;

  return YES;
}
    
@end
