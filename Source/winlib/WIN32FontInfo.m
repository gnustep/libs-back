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

- initWithFontName: (NSString*)name
	    matrix: (const float *)fmatrix
	screenFont: (BOOL)screenFont
{
  if (screenFont)
    {
      RELEASE(self);
      return nil;
    }

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
  if (hFont)
    {
      DeleteObject(hFont);
      hFont = NULL;
    }
  [super dealloc];
}

- (float) widthOf: (const char*) s length: (int) len
{
  SIZE size;
  HDC hdc;
  HFONT old;

  hdc = GetDC(NULL);
  old = SelectObject(hdc, hFont);
  GetTextExtentPoint32(hdc, s, len, &size);
  SelectObject(hdc, old);
  ReleaseDC(NULL, hdc);

  return size.cx;
}

- (float) widthOfString: (NSString*)string
{
  const char *s;
  int len;
  
  s = [string cString];
  len = strlen(s);

  return [self widthOf: s length: len];
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
  HFONT old;

  hdc = GetDC(NULL);
  old = SelectObject(hdc, hFont);
  //GetCharWidthFloat(hdc, glyph, glyph, &w);
  GetCharABCWidthsFloat(hdc, glyph, glyph, &abc);
  SelectObject(hdc, old);
  ReleaseDC(NULL, hdc);

  //NSLog(@"Width for %d is %f or %f", glyph, w, (abc.abcfA + abc.abcfB + abc.abcfC));
  w = abc.abcfA + abc.abcfB + abc.abcfC;
  return NSMakeSize(w, 0);
}

- (NSRect) boundingRectForGlyph: (NSGlyph)glyph
{
  HDC hdc;
  HFONT old;
  GLYPHMETRICS gm;
  NSRect rect;

  hdc = GetDC(NULL);
  old = SelectObject(hdc, hFont);
  if (GDI_ERROR != GetGlyphOutline(hdc, glyph, 
				   GGO_METRICS, // || GGO_GLYPH_INDEX
				   &gm, 0, NULL, NULL))
    {
      rect = NSMakeRect(gm.gmptGlyphOrigin.x, 
			gm.gmptGlyphOrigin.y - gm.gmBlackBoxY,
			gm.gmCellIncX, gm.gmCellIncY);
    }
  else
    {
      rect  = NSMakeRect(0, 0, 0, 0);
    }

  SelectObject(hdc, old);
  ReleaseDC(NULL, hdc);

  return rect;
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
  HFONT old;

  old = SelectObject(hdc, hFont);
  TextOut(hdc, p.x, p.y - ascender, s, len); 
  SelectObject(hdc, old);
}

- (void) drawGlyphs: (const NSGlyph*)s
	     length: (int)len 
	       onDC: (HDC)hdc
		 at: (POINT)p
{
  HFONT old;
  WORD	buf[len];
  int	i;

  /*
   * For now, assume that a glyph is a unicode character and can be
   * stored in a windows WORD
   */
  for (i = 0; i < len; i++)
    {
      buf[i] = s[i];
    }
  old = SelectObject(hdc, hFont);
  TextOutW(hdc, p.x, p.y - ascender, buf, len); 
  SelectObject(hdc, old);
}

@end

@implementation WIN32FontInfo (Private)

- (BOOL) setupAttributes
{
  HDC hdc;
  TEXTMETRIC metric;
  HFONT old;
  LOGFONT logfont;
  NSString *weightString;
  NSRange range;

  //NSLog(@"Creating Font %@ of size %f", fontName, matrix[0]);
  memset(&logfont, 0, sizeof(LOGFONT));
  // FIXME This hack gets the font size about right, but what is the real solution?
  logfont.lfHeight = (int)(matrix[0] * 4 / 3);

  range = [fontName rangeOfString: @"Bold"];
  if (range.length)
    logfont.lfWeight = FW_BOLD;

  range = [fontName rangeOfString: @"Italic"];
  if (range.length)
    logfont.lfItalic = 1; 

  logfont.lfQuality = ANTIALIASED_QUALITY;
  strncpy(logfont.lfFaceName, [fontName cString], LF_FACESIZE);
  hFont = CreateFontIndirect(&logfont);
  if (!hFont)
    {
      NSLog(@"Could not create font %@", fontName);
      return NO;
    }

  hdc = GetDC(NULL);
  old = SelectObject(hdc, hFont);
  GetTextMetrics(hdc, &metric);
  SelectObject(hdc, old);
  ReleaseDC(NULL, hdc);

  // Fill the afmDitionary and ivars
  [fontDictionary setObject: fontName forKey: NSAFMFontName];
  //ASSIGN(familyName, XGFontFamily(xdpy, font_info));
  //[fontDictionary setObject: familyName forKey: NSAFMFamilyName];
  isFixedPitch = TMPF_FIXED_PITCH & metric.tmPitchAndFamily;
  isBaseFont = NO;
  ascender = metric.tmAscent;
  //NSLog(@"Resulted in height %d and ascent %d", metric.tmHeight, metric.tmAscent);
  [fontDictionary setObject: [NSNumber numberWithFloat: ascender] 
		  forKey: NSAFMAscender];
  descender = -metric.tmDescent;
  [fontDictionary setObject: [NSNumber numberWithFloat: descender]
		  forKey: NSAFMDescender];

  fontBBox = NSMakeRect((float)(0),
			(float)(0 - metric.tmAscent),
			(float)metric.tmMaxCharWidth,
			(float)metric.tmHeight);

  // The MS names are a bit different from the NS ones!
  switch (metric.tmWeight)
    {
      case FW_THIN:
	weight = 1;
	break;
      case FW_EXTRALIGHT:
	weight = 2;
	break;
      case FW_LIGHT:
	weight = 3;
	break;
      case FW_REGULAR:
	weight = 5;
	break;
      case FW_MEDIUM:
	weight = 6;
	break;
      case FW_DEMIBOLD:
	weight = 7;
	break;
      case FW_BOLD:
	weight = 9;
	break;
      case FW_EXTRABOLD:
	weight = 10;
	break;
      case FW_BLACK:
	weight = 12;
	break;
    default:
	// Try to map the range 0 to 1000 into 1 to 14.
	weight = (int)(metric.tmWeight * 14 / 1000);
	break;
    }

  if (weight >= 9)
    traits |= NSBoldFontMask;
  else
    traits |= NSUnboldFontMask;

  if (metric.tmItalic)
    traits |= NSItalicFontMask;
  else
    traits |= NSUnitalicFontMask;

  weightString = [GSFontInfo stringForWeight: weight];
  if (weightString != nil)
    {
      [fontDictionary setObject: weightString forKey: NSAFMWeight];
    }

  // Should come from metric.tmCharSet
  mostCompatibleStringEncoding = NSISOLatin1StringEncoding;

  return YES;
}
    
@end
