
/*
   HeadlessGState.m

   Copyright (C) 2003 Free Software Foundation, Inc.

   August 31, 2003
   Written by Banlu Kemiyatorn <object at gmail dot com>
   Rewrite: Fred Kiefer <fredkiefer@gmx.de>
   Date: Jan 2006
 
   This file is part of GNUstep.

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

#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSGradient.h>
#include <AppKit/NSGraphics.h>
#include "headlesslib/HeadlessGState.h"
#include "headlesslib/HeadlessFontInfo.h"
#include "headlesslib/HeadlessSurface.h"
#include "headlesslib/HeadlessContext.h"
#include <math.h>


// Macro stolen from base/Header/Additions/GNUstepBase/GSObjRuntime.h
#ifndef	GS_MAX_OBJECTS_FROM_STACK
/**
 * The number of objects to try to get from varargs into an array on
 * the stack ... if there are more than this, use the heap.
 * NB. This MUST be a multiple of 2
 */
#define	GS_MAX_OBJECTS_FROM_STACK	128
#endif

// Macros stolen from base/Source/GSPrivate.h
/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of items.  Use this to start the block of code using
 * the array and GS_ENDITEMBUF() to end it.  The idea is to ensure that small
 * arrays are allocated on the stack (for speed), but large arrays are
 * allocated from the heap (to avoid stack overflow).
 */
#define	GS_BEGINITEMBUF(P, S, T) { \
  T _ibuf[(S) <= GS_MAX_OBJECTS_FROM_STACK ? (S) : 0]; \
  T *_base = ((S) <= GS_MAX_OBJECTS_FROM_STACK) ? _ibuf \
    : (T*)NSZoneMalloc(NSDefaultMallocZone(), (S) * sizeof(T)); \
  T *(P) = _base;

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of items.  Use GS_BEGINITEMBUF() to start the block of code using
 * the array and this macro to end it.
 */
#define	GS_ENDITEMBUF() \
  if (_base != _ibuf) \
    NSZoneFree(NSDefaultMallocZone(), _base); \
  }

@implementation HeadlessGState 

+ (void) initialize
{
  if (self == [HeadlessGState class])
    {
    }
}

- (void) dealloc
{
  RELEASE(_surface);

  [super dealloc];
}

- (NSString*) description
{
  NSMutableString *description = [[[super description] mutableCopy] autorelease];
  [description appendFormat: @" surface: %@",_surface];
  [description appendFormat: @" context: %p",_ct];
  return [[description copy] autorelease];
}

- (id) copyWithZone: (NSZone *)zone
{
  HeadlessGState *copy = (HeadlessGState *)[super copyWithZone: zone];
  return copy;
}

- (void) GSCurrentSurface: (HeadlessSurface **)surface : (int *)x : (int *)y
{
  if (x)
    *x = offset.x;
  if (y)
    *y = offset.y;
  if (surface)
    {
      *surface = _surface;
    }
}

- (void) GSSetSurface: (HeadlessSurface *)surface : (int)x : (int)y
{
  ASSIGN(_surface, surface);
  [self setOffset: NSMakePoint(x, y)];
  [self DPSinitgraphics];
}

- (void) setOffset: (NSPoint)theOffset
{
  [super setOffset: theOffset];
}

- (void) showPage
{
}

/*
 * Color operations
 */
- (void) GSSetPatterColor: (NSImage*)image 
{
  // FIXME: Create a cairo surface from the image and set it as source.
  [super GSSetPatterColor: image];
}

/*
 * Text operations
 */

- (void) _setPoint
{
}

- (void) DPScharpath: (const char *)s : (int)b
{
}

- (void) DPSshow: (const char *)s
{
}

- (void) GSSetFont: (GSFontInfo *)fontref
{
  [super GSSetFont: fontref];
}

- (void) GSSetFontSize: (CGFloat)size
{
}

- (void) GSShowText: (const char *)string : (size_t)length
{
}

- (void) GSShowGlyphsWithAdvances: (const NSGlyph *)glyphs : (const NSSize *)advances : (size_t) length
{
}

/*
 * GState operations
 */

- (void) DPSinitgraphics
{
  [super DPSinitgraphics];
}

- (void) DPScurrentflat: (CGFloat *)flatness
{
}

- (void) DPScurrentlinecap: (int *)linecap
{
}

- (void) DPScurrentlinejoin: (int *)linejoin
{
}

- (void) DPScurrentlinewidth: (CGFloat *)width
{
}

- (void) DPScurrentmiterlimit: (CGFloat *)limit
{
}

- (void) DPScurrentstrokeadjust: (int *)b
{
}

- (void) DPSsetdash: (const CGFloat *)pat : (NSInteger)size : (CGFloat)foffset
{
}

- (void) DPSsetflat: (CGFloat)flatness
{
  [super DPSsetflat: flatness];
}

- (void) DPSsetlinecap: (int)linecap
{
}

- (void) DPSsetlinejoin: (int)linejoin
{
}

- (void) DPSsetlinewidth: (CGFloat)width
{
}

- (void) DPSsetmiterlimit: (CGFloat)limit
{
}

- (void) DPSsetstrokeadjust: (int)b
{
}

/*
 * Path operations
 */

- (void) _setPath
{
}

- (void) DPSclip
{
}

- (void) DPSeoclip
{
}

- (void) DPSeofill
{
}

- (void) DPSfill
{
}

- (void) DPSinitclip
{
}

- (void) DPSstroke
{
}

- (NSDictionary *) GSReadRect: (NSRect)r
{
  return [NSDictionary dictionary];
}

- (void) DPSimage: (NSAffineTransform *)matrix : (NSInteger)pixelsWide
		 : (NSInteger)pixelsHigh : (NSInteger)bitsPerSample 
		 : (NSInteger)samplesPerPixel : (NSInteger)bitsPerPixel
		 : (NSInteger)bytesPerRow : (BOOL)isPlanar
		 : (BOOL)hasAlpha : (NSString *)colorSpaceName
		 : (const unsigned char *const[5])data
{
}

- (void) compositerect: (NSRect)aRect op: (NSCompositingOperation)op
{
}

- (void) compositeGState: (HeadlessGState *)source 
                fromRect: (NSRect)srcRect 
                 toPoint: (NSPoint)destPoint 
                      op: (NSCompositingOperation)op
                fraction: (CGFloat)delta
{
}

/** Unlike -compositeGState, -drawGSstate fully respects the AppKit CTM but 
doesn't support to use the receiver cairo target as the source. */
- (void) drawGState: (HeadlessGState *)source 
           fromRect: (NSRect)aRect 
            toPoint: (NSPoint)aPoint 
                 op: (NSCompositingOperation)op
           fraction: (CGFloat)delta
{
}

@end

@implementation HeadlessGState (PatternColor)

- (void *) saveClip
{
  return NULL;
}

- (void) restoreClip: (void *)savedClip
{
}

@end

@implementation HeadlessGState (NSGradient)

- (void) drawGradient: (NSGradient*)gradient
           fromCenter: (NSPoint)startCenter
               radius: (CGFloat)startRadius
             toCenter: (NSPoint)endCenter 
               radius: (CGFloat)endRadius
              options: (NSUInteger)options
{
}

- (void) drawGradient: (NSGradient*)gradient
            fromPoint: (NSPoint)startPoint
              toPoint: (NSPoint)endPoint
              options: (NSUInteger)options
{
}

@end
