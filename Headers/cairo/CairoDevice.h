/*
 * CairoFontInfo.h
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 * September 10, 2003
 * Written by Banlu Kemiyatorn <id at project-ile dot net>
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


#ifndef WOOM_CairoDevice_h
#define WOOM_CairoDevice_h

#include "x11/XGServerWindow.h"
#include <cairo.h>

@interface CairoBuffer : NSObject
{
@public
	gswindow_device_t * _gsdevice;
	void *_deviceid;
	NSSize _pixmapSize;
	Pixmap _pixmap;
}
+ (CairoBuffer *) pixmapWithWindowDevice: (gswindow_device_t *)device;
- (id) initWithWindowDevice: (gswindow_device_t *)device;
- (Pixmap) pixmap;
- (gswindow_device_t *) device;
- (NSSize) size;
- (void) dealloc;
/*- (id) copyWithZone: (NSZone *)zone;*/
@end

@interface CairoType : NSObject
{
@public
	cairo_t *_cr;
}
@end

@interface CairoType (Ops)
- (void) save;
- (void) restore;
- (void) translateToPoint: (NSPoint)p;
- (void) scaleToSize:(NSSize)s;
- (void) rotateWithAngle:(float)angle;
- (void) setTargetBuffer:(CairoBuffer *)buffer;
- (void) setColorRGB:(float)r :(float)g :(float)b;
- (void) setColorGray:(float)gray;
- (void) clip;
- (void) newPath;
- (void) closePath;
- (void) rectangle:(NSRect)rect;
- (void) stroke;
- (void) moveToPoint:(NSPoint)p;
- (void) lineToPoint:(NSPoint)p;
- (void) relativeLineToPoint:(NSPoint)p;
- (void) relativeLineToSize:(NSSize)s;
- (void) fill;
- (NSAffineTransform *) CTM;
- (void) setCTM: (NSAffineTransform *)newctm;
- (void) concatCTM: (NSAffineTransform *)concatctm;
@end /* CairoType */

@interface CairoDevice : NSObject
{
@public
	CairoType *_ct;
	CairoBuffer *_buffer;
}
- (CairoType *) ct;
- (void) setDevice: (gswindow_device_t *)window;
@end

#endif
