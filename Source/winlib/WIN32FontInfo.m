/* Win32FontInfo - Implements font enumerator for MSWindows

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   
   This file is part of the GNU Objective C User Interface Library.

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

#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <AppKit/NSBezierPath.h>

#include "winlib/WIN32FontInfo.h"

#include <string.h>

int win32_font_weight(LONG tmWeight);
NSString *win32_font_family(NSString *fontName);

/* The standard glyph names of the Latin set, for -glyphWithName:. The names
   of the letters and digits are the characters themselves, apart from the
   digits, so only the ones that differ are listed. */
static const struct
{
  const char *name;
  unichar     character;
}
standardGlyphNames[] =
{
  {"space", 0x0020},       {"exclam", 0x0021},      {"quotedbl", 0x0022},
  {"numbersign", 0x0023},  {"dollar", 0x0024},      {"percent", 0x0025},
  {"ampersand", 0x0026},   {"quotesingle", 0x0027}, {"parenleft", 0x0028},
  {"parenright", 0x0029},  {"asterisk", 0x002A},    {"plus", 0x002B},
  {"comma", 0x002C},       {"hyphen", 0x002D},      {"period", 0x002E},
  {"slash", 0x002F},       {"zero", 0x0030},        {"one", 0x0031},
  {"two", 0x0032},         {"three", 0x0033},       {"four", 0x0034},
  {"five", 0x0035},        {"six", 0x0036},         {"seven", 0x0037},
  {"eight", 0x0038},       {"nine", 0x0039},        {"colon", 0x003A},
  {"semicolon", 0x003B},   {"less", 0x003C},        {"equal", 0x003D},
  {"greater", 0x003E},     {"question", 0x003F},    {"at", 0x0040},
  {"bracketleft", 0x005B}, {"backslash", 0x005C},   {"bracketright", 0x005D},
  {"asciicircum", 0x005E}, {"underscore", 0x005F},  {"grave", 0x0060},
  {"braceleft", 0x007B},   {"bar", 0x007C},         {"braceright", 0x007D},
  {"asciitilde", 0x007E},  {"quoteleft", 0x2018},   {"quoteright", 0x2019}
};

/* CreateFontIndirect() picks a face for whatever it is handed, including an
   empty name, so a name has to be checked against the enumerated families
   before a font is built for it. */
static BOOL
win32_font_available(NSString *fontName)
{
  GSFontEnumerator *enumerator;
  NSString *family;
  NSRange hyphen;

  if ([fontName length] == 0)
    {
      return NO;
    }

  enumerator = [GSFontEnumerator sharedEnumerator];
  if ([[enumerator availableFonts] containsObject: fontName])
    {
      return YES;
    }

  /* The enumerator builds "<family> Bold" and the like from the family, so
     the family is what has to exist. */
  family = win32_font_family(fontName);
  if ([[enumerator availableFontFamilies] containsObject: family])
    {
      return YES;
    }

  /* NSFont builds hyphenated names of this shape when it replaces Helvetica. */
  hyphen = [family rangeOfString: @"-" options: NSBackwardsSearch];
  if (hyphen.length != 0)
    {
      family = [family substringToIndex: hyphen.location];
      if ([[enumerator availableFontFamilies] containsObject: family])
        {
          return YES;
        }
    }

  return NO;
}

@interface WIN32FontInfo (Private)
- (BOOL) setupAttributes;
@end

@implementation WIN32FontInfo

- initWithFontName: (NSString*)name
	    matrix: (const CGFloat *)fmatrix
	screenFont: (BOOL)screenFont
{
  if (screenFont)
    {
      RELEASE(self);
      return nil;
    }

  if (!win32_font_available(name))
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

- (CGFloat) widthOfString: (NSString*)string
{
  SIZE size;
  HDC hdc;
  HFONT old;

  hdc = CreateCompatibleDC(NULL);
  old = SelectObject(hdc, hFont);
  GetTextExtentPoint32W(hdc,
    (const unichar*)[string cStringUsingEncoding: NSUnicodeStringEncoding],
    [string length],
    &size);
  SelectObject(hdc, old);
  DeleteDC(hdc);

  return size.cx;
}

- (NSMultibyteGlyphPacking)glyphPacking
{
  return NSOneByteGlyphPacking;
}

- (NSSize) advancementForGlyph: (NSGlyph)glyph
{
  unichar u = (unichar)glyph;
  HDC hdc;
  float w;
  ABCFLOAT abc;
  HFONT old;

  hdc = CreateCompatibleDC(NULL);
  old = SelectObject(hdc, hFont);
  // FIXME ... currently a gnustep glyph is a unichar ... what if that changes.
  GetCharABCWidthsFloatW(hdc, u, u, &abc);
  SelectObject(hdc, old);
  DeleteDC(hdc);

  //NSLog(@"Width for %d is %f or %f", glyph, w, (abc.abcfA + abc.abcfB + abc.abcfC));
  w = abc.abcfA + abc.abcfB + abc.abcfC;
  return NSMakeSize(w, 0);
}

- (NSRect) boundingRectForGlyph: (NSGlyph)glyph
{
  WORD c = (WORD)glyph;
  WORD windowsGlyph;
  HDC hdc;
  HFONT old;
  GLYPHMETRICS gm;
  NSRect rect;
  /* GetGlyphOutline takes no null transform, so hand it the identity one. */
  static const MAT2 identity = {{0, 1}, {0, 0}, {0, 0}, {0, 1}};

  hdc = CreateCompatibleDC(NULL);
  old = SelectObject(hdc, hFont);
  // Convert from GNUstep glyph (unichar) to windows glyph.
  if (GetGlyphIndicesW(hdc, &c, 1, &windowsGlyph, 0) == GDI_ERROR)
    {
      SelectObject(hdc, old);
      DeleteDC(hdc);
NSLog(@"No glyph for U%d", c);
      return NSMakeRect(0, 0, 0, 0);	// No such glyph
    }
  if (GDI_ERROR != GetGlyphOutlineW(hdc, windowsGlyph,
				   GGO_METRICS | GGO_GLYPH_INDEX,
				   &gm, 0, NULL, &identity))
    {
      rect = NSMakeRect(gm.gmptGlyphOrigin.x,
			gm.gmptGlyphOrigin.y - gm.gmBlackBoxY,
			gm.gmBlackBoxX, gm.gmBlackBoxY);
    }
  else
    {
      rect  = NSMakeRect(0, 0, 0, 0);
    }

  SelectObject(hdc, old);
  DeleteDC(hdc);

  return rect;
}

- (BOOL) glyphIsEncoded: (NSGlyph)glyph
{
  WORD c = (WORD)glyph;
  WORD windowsGlyph;
  HDC hdc;
  HFONT old;
  BOOL result = YES;

  hdc = CreateCompatibleDC(NULL);
  old = SelectObject(hdc, hFont);
  // Convert from GNUstep glyph (unichar) to windows glyph.
  if ((GetGlyphIndicesW(hdc, &c, 1, &windowsGlyph, 
                        GGI_MARK_NONEXISTING_GLYPHS) == GDI_ERROR)
      || (windowsGlyph == 0xFFFF))
    {
      result = NO;
    }
  SelectObject(hdc, old);
  DeleteDC(hdc);
  return result;
}

- (NSGlyph) glyphWithName: (NSString*)glyphName
{
  unichar c = 0;

  /* A glyph is a character here, which is what -glyphIsEncoded: and
     -advancementForGlyph: read, so a name is answered as the character it
     stands for. A name of a single character is that character, and the rest
     are the standard names of the Latin set. GDI has no call that reads the
     names a face carries, so a name outside that set has no answer, as a
     character the font does not carry has none. */
  if ([glyphName length] == 1)
    {
      c = [glyphName characterAtIndex: 0];
    }
  else
    {
      const char *name = [glyphName UTF8String];
      unsigned    i;

      for (i = 0; i < sizeof(standardGlyphNames) / sizeof(*standardGlyphNames);
	   i++)
	{
	  if (strcmp(standardGlyphNames[i].name, name) == 0)
	    {
	      c = standardGlyphNames[i].character;
	      break;
	    }
	}
    }

  if (c == 0 || [self glyphIsEncoded: (NSGlyph)c] == NO)
    {
      return NSNullGlyph;
    }

  return (NSGlyph)c;
}

- (NSPoint) positionOfGlyph: (NSGlyph)curGlyph
	    precededByGlyph: (NSGlyph)prevGlyph
		  isNominal: (BOOL*)nominal
{
  return NSMakePoint(0, 0);
}

- (NSCharacterSet*) coveredCharacterSet
{
  if (coveredCharacterSet == nil)
    {
      NSMutableCharacterSet	*ms;
      unsigned	count; 
      GLYPHSET *gs = 0;
      HDC hdc;
      HFONT old;

      ms = [NSMutableCharacterSet new];
      if (!ms)
        return nil;

      hdc = CreateCompatibleDC(NULL);
      old = SelectObject(hdc, hFont);
      count = (unsigned)GetFontUnicodeRanges(hdc, 0);
      if (count > 0)
        {
          gs = (GLYPHSET*)malloc(count);
          if (!gs)
            {
              SelectObject(hdc, old);
              DeleteDC(hdc);
              RELEASE(ms);
              return nil;
            }

          gs->cbThis = count;
          if ((unsigned)GetFontUnicodeRanges(hdc, gs) == count)
            {
              numberOfGlyphs = gs->cGlyphsSupported;
              if (gs->flAccel == 1 /* GS_8BIT_INDICES */)
                {
                  for (count = 0; count < gs->cRanges; count++)
                    {
                      NSRange	range;
                      
                      range.location = gs->ranges[count].wcLow & 0xff;
                      range.length = gs->ranges[count].cGlyphs;
                      [ms addCharactersInRange: range];
                    }
                }
              else
                {
                  for (count = 0; count < gs->cRanges; count++)
                    {
                      NSRange	range;
                      
                      range.location = gs->ranges[count].wcLow;
                      range.length = gs->ranges[count].cGlyphs;
                      [ms addCharactersInRange: range];
                    }
                }
            }
          free(gs);
        }
      SelectObject(hdc, old);
      DeleteDC(hdc);
      coveredCharacterSet = [ms copy];
      RELEASE(ms);
    }

  return coveredCharacterSet;
}

- (void) drawString: (NSString*)string
               onDC: (HDC)hdc
                 at: (POINT)p
{
  HFONT old;

  old = SelectObject(hdc, hFont);
  TextOutW(hdc,
    p.x,
    p.y - ascender,
    (const unichar*)[string cStringUsingEncoding: NSUnicodeStringEncoding],
    [string length]); 
  SelectObject(hdc, old);
}

- (void) draw:(const char*)s length: (int)len 
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
  WORD buf[len];
  HFONT old;
  int i;

  old = SelectObject(hdc, hFont);
  /*
   * For now, assume that a glyph is a unicode character and can be
   * stored in a windows WORD
   */
  for (i = 0; i < len; i++)
    {
      buf[i] = (WORD)s[i];
    }
  TextOutW(hdc, p.x, p.y - ascender, buf, len); 
  SelectObject(hdc, old);
}

- (unsigned) numberOfglyphs
{
  if (coveredCharacterSet == nil)
    {
      [self coveredCharacterSet];
    }
  return numberOfGlyphs;
}

- (void) appendBezierPathWithGlyphs: (NSGlyph *)glyphs
                              count: (int)length
                       toBezierPath: (NSBezierPath *)path
{
  WORD buf[length];
  int	i;
  SIZE sBoundBox;
  int h;
  int iPoints;
  POINT *ptPoints;
  BYTE *bTypes;
  NSPoint startPoint;
  HDC hDC = CreateCompatibleDC(NULL);

  if (!hDC)
    {
      NSDebugLLog(@"WIN32FontInfo", 
                  @"Problem creating HDC for appendBezierPathWithGlyphs:");
      return;
    }

  SetGraphicsMode(hDC, GM_ADVANCED);
  SetMapMode(hDC, MM_ANISOTROPIC);
  SetWindowExtEx(hDC, 1, 1, NULL);
  SetViewportExtEx(hDC, 1, -1, NULL);
  SetViewportOrgEx(hDC, 0, 0, NULL);
  
  /*
   * For now, assume that a glyph is a unicode character and can be
   * stored in a windows WORD
   */
  for (i = 0; i < length; i++)
    {
      buf[i] = glyphs[i];
    }
  
  SelectObject(hDC, hFont);
  GetTextExtentPoint32W(hDC, buf, length, &sBoundBox);
  h = sBoundBox.cy;
  
  if ([path elementCount] > 0)
    {
      startPoint = [path currentPoint];
    }
  else
    {
      startPoint = NSZeroPoint;
    }

  SetBkMode(hDC, TRANSPARENT);
  BeginPath(hDC);
  SetTextAlign(hDC, TA_LEFT | TA_TOP);
  TextOutW(hDC, startPoint.x, -startPoint.y, buf, length); 
  EndPath(hDC);
  
  iPoints = GetPath(hDC, NULL, NULL, 0);
  if (iPoints == 0)
    {
      DeleteDC(hDC);
      return;
    }

  ptPoints = malloc(sizeof(POINT) * iPoints);
  if (!ptPoints)
    {
      DeleteDC(hDC);
      return;
    }
  bTypes = malloc(sizeof(BYTE) * iPoints);
  if (!bTypes)
    {
      free(ptPoints);
      DeleteDC(hDC);
      return;
    }
  GetPath(hDC, ptPoints, bTypes, iPoints);

  // Now append the glyphs to the path
  i = 0;
  while (i < iPoints)
    {
      if (bTypes[i] == PT_MOVETO)
        {
          [path moveToPoint: NSMakePoint(ptPoints[i].x, h - ptPoints[i].y)];
          i++;
        }
      else if (bTypes[i] & PT_LINETO)
        {
          [path lineToPoint: NSMakePoint(ptPoints[i].x, h - ptPoints[i].y)];
          if (bTypes[i] & PT_CLOSEFIGURE)
            [path closePath];
          i++;
        }
      else if (bTypes[i] & PT_BEZIERTO)
        {
          // FIXME: We assume windows isn't lying here about the bezier points
          [path curveToPoint: NSMakePoint(ptPoints[i+2].x, h - ptPoints[i+2].y)
                controlPoint1: NSMakePoint(ptPoints[i].x, h - ptPoints[i].y)
                controlPoint2: NSMakePoint(ptPoints[i+1].x, h - ptPoints[i+1].y)];
          if ((bTypes[i] & PT_CLOSEFIGURE) || (bTypes[i+1] & PT_CLOSEFIGURE)
              || (bTypes[i+2] & PT_CLOSEFIGURE))
            [path closePath];
          i += 3;
        }
    }

  free(bTypes);
  free(ptPoints);
  DeleteDC(hDC);
}

@end

@implementation WIN32FontInfo (Private)

- (BOOL) setupAttributes
{
  HDC hdc;
  TEXTMETRICW metric;
  HFONT old;
  LOGFONTW logfont;
  NSRange range;

  //NSLog(@"Creating Font %@ of size %f", fontName, matrix[0]);
  ASSIGN(familyName, win32_font_family(fontName));
  memset(&logfont, 0, sizeof(LOGFONT));
  hdc = CreateCompatibleDC(NULL);
  // FIXME This hack gets the font size about right, but what is the real solution?
  logfont.lfHeight = (int)(matrix[0] * 4 / 3);
  //logfont.lfHeight = -MulDiv(matrix[0], GetDeviceCaps(hdc, LOGPIXELSY), 72);

  range = [fontName rangeOfString: @"Bold"];
  if (range.length)
    logfont.lfWeight = FW_BOLD;

  range = [fontName rangeOfString: @"Italic"];
  if (range.length)
    logfont.lfItalic = 1; 

  logfont.lfQuality = DEFAULT_QUALITY;

  if (familyName)
  {
    wcsncpy(logfont.lfFaceName,
      (const unichar*)[familyName cStringUsingEncoding: NSUnicodeStringEncoding],
      LF_FACESIZE);
  }

  hFont = CreateFontIndirectW(&logfont);
  if (!hFont)
    {
      NSLog(@"Could not create font %@", fontName);
      DeleteDC(hdc);
      return NO;
    }

  old = SelectObject(hdc, hFont);
  GetTextMetricsW(hdc, &metric);
  SelectObject(hdc, old);
  DeleteDC(hdc);

  // Fill the ivars
  isFixedPitch = TMPF_FIXED_PITCH & metric.tmPitchAndFamily;
  isBaseFont = NO;
  ascender = metric.tmAscent;
  //NSLog(@"Resulted in height %d and ascent %d", metric.tmHeight, metric.tmAscent);
  descender = -metric.tmDescent;
  /* TODO */
  xHeight = ascender * 0.5;
  maximumAdvancement = NSMakeSize((float)metric.tmMaxCharWidth, 0.0);

  fontBBox = NSMakeRect((float)(0),
			(float)(0 - metric.tmAscent),
			(float)metric.tmMaxCharWidth,
			(float)metric.tmHeight);

  weight = win32_font_weight(metric.tmWeight);

  traits = 0;
  if (weight >= 9)
    traits |= NSBoldFontMask;
  else
    traits |= NSUnboldFontMask;

  if (metric.tmItalic)
    traits |= NSItalicFontMask;
  else
    traits |= NSUnitalicFontMask;

  // FIXME Should come from metric.tmCharSet
  mostCompatibleStringEncoding = NSISOLatin1StringEncoding;

  return YES;
}
    
@end
