/*
   HeadlessGState.m
   Copyright (C) 2003, 2023 Free Software Foundation, Inc.
   August 17, 2023
   Re-wrtten by Gregory Casamento <greg.casamento@gmail.com>
   Based on work by Marcian Lytwyn <gnustep@advcsi.com>
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

#include "headless/HeadlessGState.h"

@implementation HeadlessGState

- (void) DPSclip
{
}

- (void) DPSfill
{
}

- (void) DPSsetlinewidth: (CGFloat)width
{
}

- (void) DPSsetdash: (const CGFloat *)pat : (NSInteger)size : (CGFloat)foffset
{
}

- (void) DPSimage: (NSAffineTransform *)matrix : (NSInteger)pixelsWide
		 : (NSInteger)pixelsHigh : (NSInteger)bitsPerSample
		 : (NSInteger)samplesPerPixel : (NSInteger)bitsPerPixel
		 : (NSInteger)bytesPerRow : (BOOL)isPlanar
		 : (BOOL)hasAlpha : (NSString *)colorSpaceName
		 : (const unsigned char *const[5])data
{
}

- (void) DPSstroke
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

@end
