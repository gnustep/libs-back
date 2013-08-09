/*
   OpalGState.h

   Copyright (C) 2013 Free Software Foundation, Inc.

   Author: Ivan Vucica <ivan@vucica.net>
   Date: June 2013

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

#import "gsc/GSGState.h"

@class OpalSurface;

@interface OpalGState : GSGState
{
  OpalSurface * _opalSurface;
}

- (void) DPSinitclip;
- (void) DPSinitgraphics;
- (void) DPSclip;
- (void) DPSfill;
- (void) DPSimage: (NSAffineTransform *)matrix
                 : (NSInteger)pixelsWide
		 : (NSInteger)pixelsHigh
                 : (NSInteger)bitsPerSample 
		 : (NSInteger)samplesPerPixel
                 : (NSInteger)bitsPerPixel
		 : (NSInteger)bytesPerRow
                 : (BOOL)isPlanar
		 : (BOOL)hasAlpha
                 : (NSString *)colorSpaceName
		 : (const unsigned char *const[5])data;
- (void) compositeGState: (OpalGState *)source
                fromRect: (NSRect)srcRect 
                 toPoint: (NSPoint)destPoint 
                      op: (NSCompositingOperation)op
                fraction: (CGFloat)delta;
- (void) compositerect: (NSRect)aRect
                    op: (NSCompositingOperation)op;
- (void) GSSetSurface: (OpalSurface *)opalSurface
                     : (int)x
                     : (int)y;
@end

@interface OpalGState (Accessors)
- (CGContextRef) cgContext;
@end
