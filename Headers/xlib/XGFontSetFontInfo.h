/*
    XGFontSetFontInfo.h

    NSFont helper for GNUstep X/GPS Backend

    Author: Kazunobu Kuriyama <kazunobu.kuriyama@nifty.com>
    Date: July 2003

 */

#ifndef __XGFontSetFontInfo_h
#define __XGFontSetFontInfo_h

#include <X11/Xlib.h>
#include <AppKit/GSFontInfo.h>

#ifdef X_HAVE_UTF8_STRING

#if 0 // Commented out till the implementation completes.
// ----------------------------------------------------------------------------
//  XGFontSetEnumerator
// ----------------------------------------------------------------------------
@interface XGFontSetEnumerator : GSFontEnumerator
{
}

- (void) enumerateFontsAndFamilies;

@end // XGFontSetEnumerator : GSFontEnumerator
#endif // #if 0


// ----------------------------------------------------------------------------
//  XGFontSetFontInfo
// ----------------------------------------------------------------------------
@interface XGFontSetFontInfo : GSFontInfo
{
    XFontSet	_font_set;
    XFontStruct	**_fonts;
    int		_num_fonts;
}

- (id) initWithFontName: (NSString *)name
		 matrix: (const float *)matrix
	     screenFont: (BOOL)screenFont;
- (void) dealloc;
- (NSSize) advancementForGlyph: (NSGlyph)glyph;
- (NSRect) boundingRectForGlyph: (NSGlyph)glyph;
- (BOOL) glyphIsEncoded: (NSGlyph)glyph;
- (NSGlyph) glyphWithName: (NSString *)glyphName;
- (void) drawGlyphs: (const NSGlyph *)glyphs
             lenght: (int)len
          onDisplay: (Display *)dpy
	   drawable: (Drawable)win
	       with: (GC)gc
	         at: (XPoint)xp;
- (float) widthOfGlyphs: (const NSGlyph *)glyphs
                 lenght: (int)len;
- (void) setActiveFor: (Display *)dpy
                   gc: (GC)gc;

@end // XGFontSetFontInfo : GSFontInfo

#endif // X_HAVE_UTF8_STRING defined
#endif // __XGFontSetFontInfo_h
