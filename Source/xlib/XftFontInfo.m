/*
   XftFontInfo

   NSFont helper for GNUstep GUI X/GPS Backend

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Fred Kiefer <fredkiefer@gmx.de>
   Date: July 2001

   This file is part of the GNUstep GUI X/GPS Backend.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#include "config.h"
#include "xlib/XGContext.h"
#include "xlib/XGPrivate.h"
#include "xlib/XGGState.h"
#include "x11/XGServer.h"
#include <Foundation/NSData.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSValue.h>
// For the encoding functions
#include <base/Unicode.h>

#include "xlib/XftFontInfo.h"

/*
 * class global dictionary of existing fonts
 */
static NSMutableDictionary	*_globalFontDictionary = nil;

@interface XftFontInfo (Private)

- (BOOL) setupAttributes;
- (XGlyphInfo *)xGlyphInfo: (NSGlyph) glyph;

@end

@implementation XftFontInfo

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
  if (font_info != NULL)
    XftFontClose([XGServer currentXDisplay], (XftFont *)font_info);
  [super dealloc];
}

- (float) widthOfString: (NSString*)string
{
  XGlyphInfo extents;
  int len = [string length];
  XftChar16 str[len]; 

  [string getCharacters: (unichar*)str];
  XftTextExtents16 ([XGServer currentXDisplay],
		    font_info,
		    str, 
		    len,
		    &extents);

  return extents.width;
}

- (NSMultibyteGlyphPacking)glyphPacking
{
  return NSTwoByteGlyphPacking;
}

- (NSSize) advancementForGlyph: (NSGlyph)glyph
{
  XGlyphInfo *pc = [self xGlyphInfo: glyph];

  // if per_char is NULL assume max bounds
  if (!pc)
    return  NSMakeSize((float)(font_info)->max_advance_width, 0);

  return NSMakeSize((float)pc->xOff, (float)pc->yOff);
}

- (NSRect) boundingRectForGlyph: (NSGlyph)glyph
{
  XGlyphInfo *pc = [self xGlyphInfo: glyph];

  // if per_char is NULL assume max bounds
  if (!pc)
      return NSMakeRect(0.0, 0.0,
		    (float)font_info->max_advance_width,
		    (float)(font_info->ascent + font_info->descent));

  return NSMakeRect((float)pc->x, (float)-pc->y, 
		    (float)(pc->width), 
		    (float)(pc->height));
}

- (BOOL) glyphIsEncoded: (NSGlyph)glyph
{
  return XftGlyphExists([XGServer currentXDisplay],
			(XftFont *)font_info, glyph);
}

- (NSGlyph) glyphWithName: (NSString*)glyphName
{
  // FIXME: There is a mismatch between PS names and X names, that we should 
  // try to correct here
  KeySym k = XStringToKeysym([glyphName cString]);

  if (k == NoSymbol)
    return 0;
  else
    return (NSGlyph)k;
}

- (NSPoint) positionOfGlyph: (NSGlyph)curGlyph
	    precededByGlyph: (NSGlyph)prevGlyph
		  isNominal: (BOOL*)nominal
{
  if (nominal)
    *nominal = YES;

  if (curGlyph == NSControlGlyph || prevGlyph == NSControlGlyph)
    return NSZeroPoint;

//  if (curGlyph == NSNullGlyph)
    {
      NSSize advance = [self advancementForGlyph: prevGlyph];
      return NSMakePoint(advance.width, advance.height);
    }
}

/*
- (float) pointSize
{
  Display	*xdpy = [XGServer currentXDisplay];

  return XGFontPointSize(xdpy, font_info);
}
*/

- (void) drawString:  (NSString*)string
	  onDisplay: (Display*) xdpy drawable: (Drawable) draw
	       with: (GC) xgcntxt at: (XPoint) xp
{
  NSData *d = [string dataUsingEncoding: mostCompatibleStringEncoding
		      allowLossyConversion: YES];
  int length = [d length];
  const char *cstr = (const char*)[d bytes];
  XftDraw *xftdraw;
  XftColor xftcolor;
  XColor dummyc;
  XGCValues values;
  XGGState *state = [(XGContext *)GSCurrentContext() currentGState];
  Region xregion = [state xClipRegion];
  int defaultScreen = DefaultScreen(xdpy);
  Colormap colmap = DefaultColormap(xdpy, defaultScreen);

  /* ready to draw */
  xftdraw = XftDrawCreate(xdpy, draw,
                          DefaultVisual(xdpy, defaultScreen),
			  colmap);
  if(xftdraw == NULL) 
    return;

  /* sort out the drawing colour */
  XGetGCValues(xdpy, xgcntxt,
               GCForeground | GCBackground,
               &values);
       
  dummyc.pixel = values.foreground;
  XQueryColor(xdpy, colmap, &dummyc);
  xftcolor.color.red = dummyc.red;
  xftcolor.color.green = dummyc.green;
  xftcolor.color.blue = dummyc.blue;
  xftcolor.color.alpha =  0xffff;
  xftcolor.pixel = values.foreground;
  
  // set up clipping 
  if(xregion != None)
    {
      XftDrawSetClip(xftdraw, xregion);
      XDestroyRegion(xregion);
    }

  /* do it */
  XftDrawString16(xftdraw, &xftcolor, font_info, 
		  xp.x, xp.y, (XftChar16*)cstr, length);

  /* tidy up */
  XftDrawDestroy(xftdraw);
}

- (void) draw: (const char*) s lenght: (int) len 
    onDisplay: (Display*) xdpy drawable: (Drawable) draw
	 with: (GC) xgcntxt at: (XPoint) xp
{
  int length = strlen(s);
  XftDraw *xftdraw;
  XftColor xftcolor;
  XColor dummyc;
  XGCValues values;
  XGGState *state = [(XGContext *)GSCurrentContext() currentGState];
  Region xregion = [state xClipRegion];
  int defaultScreen = DefaultScreen(xdpy);
  Colormap colmap = DefaultColormap(xdpy, defaultScreen);

  /* ready to draw */
  xftdraw = XftDrawCreate(xdpy, draw,
                          DefaultVisual(xdpy, defaultScreen),
			  colmap);
  if(xftdraw == NULL) 
    return;

  /* sort out the drawing colour */
  XGetGCValues(xdpy, xgcntxt,
               GCForeground | GCBackground,
               &values);
       
  dummyc.pixel = values.foreground;
  XQueryColor(xdpy, colmap, &dummyc);
  xftcolor.color.red = dummyc.red;
  xftcolor.color.green = dummyc.green;
  xftcolor.color.blue = dummyc.blue;
  xftcolor.color.alpha =  0xffff;
  xftcolor.pixel = values.foreground;
  
  // set up clipping 
  if(xregion != None)
    {
      XftDrawSetClip(xftdraw, xregion);
      XDestroyRegion(xregion);
    }

  /* do it */
  if (NSUTF8StringEncoding == mostCompatibleStringEncoding)
    {
      XftDrawStringUtf8(xftdraw, &xftcolor, font_info,
                        xp.x, xp.y, (XftChar8 *)s, length);
    }
  else
    {
      XftDrawString8(xftdraw, &xftcolor, font_info, 
                   xp.x, xp.y, (XftChar8*)s, length);
    }

  /* tidy up */
  XftDrawDestroy(xftdraw);
}

- (float) widthOf: (const char*) s lenght: (int) len
{
  XGlyphInfo extents;

  if (mostCompatibleStringEncoding == NSUTF8StringEncoding)
    XftTextExtentsUtf8([XGServer currentXDisplay],
                       font_info,
                       (XftChar8 *)s,
                       len,
                       &extents);
  else
    XftTextExtents8([XGServer currentXDisplay],
                    font_info,
                    (XftChar8*)s, 
                    len,
                    &extents);

  return extents.width;
}

- (void) setActiveFor: (Display*) xdpy gc: (GC) xgcntxt
{
}

@end

@implementation XftFontInfo (Private)

- (BOOL) setupAttributes
{
  Display *xdpy = [XGServer currentXDisplay];
  int defaultScreen = DefaultScreen(xdpy);
  NSString *weightString;
  NSString *reg;
  long height;      
  XftPattern *pattern;
  XftResult result;
  NSString *xfontname;

  char *xftTypeString;
  int xftTypeInt;
  NSArray *encoding;

  if (!xdpy)
    return NO;

  // Retrieve the XLFD matching the given fontName. DPS->X.
  xfontname = XGXFontName(fontName, matrix[0]);

  // Load Xft font and get font info structure.
  if ((xfontname == nil) ||
      (font_info = XftFontOpenXlfd(xdpy, defaultScreen, [xfontname cString])) == NULL)
    {
      NSLog(@"Selected font: %@ (%@) is not available.\n"
	    @"Using system default font instead", fontName, xfontname);

      if ((font_info = XftFontOpen(xdpy, defaultScreen, 0)) == NULL)
        {
	  NSLog(@"Unable to open fixed font");
	  return NO;
	}
    }
  else
    NSDebugLog(@"Loaded font: %@", xfontname);

  // Fill the afmDitionary and ivars
  [fontDictionary setObject: fontName forKey: NSAFMFontName];

  pattern = font_info->pattern;
  result = XftPatternGetString(pattern, XFT_FAMILY, 0, &xftTypeString);
  if (result != XftResultTypeMismatch)
    {
      ASSIGN(familyName,
         [NSString stringWithCString: (const char*)xftTypeString]);
      [fontDictionary setObject: familyName forKey: NSAFMFamilyName];
    }
  result = XftPatternGetInteger(pattern, XFT_SPACING, 0, &xftTypeInt);
  if (result != XftResultTypeMismatch)
    {
      isFixedPitch = (weight != 0);
    }

  isBaseFont = NO;
  ascender = font_info->ascent;
  [fontDictionary setObject: [NSNumber numberWithFloat: ascender] 
		  forKey: NSAFMAscender];
  descender = -(font_info->descent);
  [fontDictionary setObject: [NSNumber numberWithFloat: descender]
		  forKey: NSAFMDescender];
  fontBBox = NSMakeRect(
    (float)(0),
    (float)(0 - font_info->ascent),
    (float)(font_info->max_advance_width),
    (float)(font_info->ascent + font_info->descent));
  maximumAdvancement = NSMakeSize(font_info->max_advance_width,
    (font_info->ascent + font_info->descent));
  minimumAdvancement = NSMakeSize(0,0);

  result = XftPatternGetInteger(pattern, XFT_WEIGHT, 0, &xftTypeInt);
  if (result != XftResultTypeMismatch)
    {
      switch (xftTypeInt)
        {
        case 0:
          weight = 3;
          weightString = @"light";
          break;
        case 100:
          weight = 6;
          weightString = @"medium";
          break;
        case 180:
          weight = 7;
          weightString = @"demibold";
          break;
        case 200:
          weight = 9;
          weightString = @"bold";
          break;
        case 210:
          weight = 12;
          weightString = @"black";
          break;
        default:
          // Don't know
            weight = 6;;
        }
      if (weightString != nil)
        {
          [fontDictionary setObject: weightString forKey: NSAFMWeight];
        }
    }

  if (weight >= 9)
    traits |= NSBoldFontMask;
  else
    traits |= NSUnboldFontMask;

  if (isFixedPitch)
    traits |= NSFixedPitchFontMask;

  result = XftPatternGetInteger(pattern, XFT_SLANT, 0, &xftTypeInt);
  if (result != XftResultTypeMismatch)
    {
      if (xftTypeInt != 0)
        traits |= NSItalicFontMask;
      else
        traits |= NSUnitalicFontMask;
    }

  XftPatternGetString (pattern, XFT_ENCODING, 0, &xftTypeString);
  encodingScheme = [NSString stringWithCString: xftTypeString];
  encoding = [encodingScheme componentsSeparatedByString: @"-"];
  reg = [encoding objectAtIndex: 0];
  if (reg != nil)
    { 
      NSString *enc = [encoding lastObject];

      if (enc != nil)
        {
	  mostCompatibleStringEncoding = [GSFontInfo encodingForRegistry: reg
						     encoding: enc];
          if (mostCompatibleStringEncoding == NSUnicodeStringEncoding)
            mostCompatibleStringEncoding = NSUTF8StringEncoding;

	  encodingScheme = [NSString stringWithFormat: @"%@-%@", 
				     reg, enc];
	  //NSLog(@"Found encoding %d for %@", mostCompatibleStringEncoding, encodingScheme);
	  RETAIN(encodingScheme);
	  [fontDictionary setObject: encodingScheme
			  forKey: NSAFMEncodingScheme];
	}
    }
/*
  height = XGFontPropULong(xdpy, font_info, XA_X_HEIGHT);
  if (height != 0)
    {
      xHeight = (float)height;
      [fontDictionary setObject: [NSNumber numberWithFloat: xHeight]
		      forKey: NSAFMXHeight];
    }

  height = XGFontPropULong(xdpy, font_info, XA_CAP_HEIGHT);
  if (height != 0)
    {
      capHeight = (float)height;
      [fontDictionary setObject: [NSNumber numberWithFloat: capHeight]
		      forKey: NSAFMCapHeight];
    }
*/  
  // FIXME: italicAngle, underlinePosition, underlineThickness are not set.
  // Should use XA_ITALIC_ANGLE, XA_UNDERLINE_POSITION, XA_UNDERLINE_THICKNESS
  return YES;
}

- (XGlyphInfo *)xGlyphInfo: (NSGlyph) glyph
{
  static XGlyphInfo glyphInfo;

  XftTextExtents32 ([XGServer currentXDisplay],
                    (XftFont *)font_info,
                    &glyph,
                    1,
                    &glyphInfo);

  return &glyphInfo;
}

@end
