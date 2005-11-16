/*
 * CairoDevice.m
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

#include "Foundation/NSValue.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSDictionary.h"
#include <AppKit/NSAffineTransform.h>
#include "cairo/CairoDevice.h"
#include <cairo.h>
#include <X11/Xlib.h>

NSAffineTransform * WMCairoMatrixToNSAffine (cairo_matrix_t *cairo_mp)
{
	double af[6];
	NSAffineTransformStruct ats;
	NSAffineTransform *aCTM = [NSAffineTransform transform];
	cairo_matrix_get_affine(cairo_mp,&af[0],&af[1],&af[2],&af[3],&af[4],&af[5]);
	ats.m11 = af[0];
	ats.m12 = af[1];
	ats.m21 = af[2];
	ats.m22 = af[3];
	ats.tx = af[4];
	ats.ty = af[5];
	[aCTM setTransformStruct:ats];
	return aCTM;
}


@implementation CairoType
- (id) init
{
	// FIXME: first we need to create the dummy instance
	// by returning a trapper ok, CairoTypeDummy
	// and recording invocations into stack
	// and when we know device's size, we'll apply
	// all invocations to the real one.
	_cr = cairo_create();
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
	cairo_scale(_cr,1,-1);
	return self;
}
- (void) dealloc
{
	cairo_destroy(_cr);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
	[super dealloc];
	NSLog (@"done CT dealloc");
}
- (id) retain
{
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
	return [super retain];
}
- (void) release
{
	NSLog (@":::FIXME::: %@ %s cairo %d",[self description], sel_get_name(_cmd),_cr);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
	[super release];
}
- (id) copyWithZone: (NSZone *)zone
{
	CairoType *aCT = (CairoType *)NSCopyObject(self, 0, zone);
	NSLog (@":::FIXME::: %@ %s copy %0x to %0x",[self description], sel_get_name(_cmd), self, aCT);
	aCT->_cr = cairo_create();
	cairo_copy(aCT->_cr,_cr);
NSLog(@"cairo_copy %d to %d [%s]",_cr,aCT->_cr,cairo_status_string(_cr));
	return aCT;
}

@end

@implementation CairoType (Ops)
- (void) save
{
//	cairo_save(_cr);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) restore
{
//	cairo_restore(_cr);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) translateToPoint: (NSPoint)p
{
	cairo_translate(_cr,p.x,p.y);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) scaleToSize:(NSSize)s
{
	cairo_scale(_cr,s.width,s.height);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) rotateWithAngle:(float)angle
{
//	cairo_rotate(_cr,angle);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) setTargetBuffer:(CairoBuffer *)buffer
{
//	cairo_set_target_drawable(_cr, buffer->_gsdevice->display, buffer->_pixmap);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) setColorRGB:(float)r :(float)g :(float)b
{
//	cairo_set_rgb_color(_cr,r,g,b);
}
- (void) setAlpha:(float)alpha
{
	cairo_set_alpha(_cr, alpha);
}
- (float) currentAlpha
{
	return cairo_current_alpha(_cr);
}
- (float) currentGray
{
	return _currentGray;
}
- (void) clip
{
//	cairo_clip(_cr);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) newPath
{
//	cairo_new_path(_cr);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) closePath
{
//	cairo_close_path(_cr);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) rectangle:(NSRect)rect
{
//	cairo_rectangle(_cr,NSMinX(rect),NSMinY(rect),NSWidth(rect),NSHeight(rect));
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) stroke
{
//	cairo_stroke(_cr);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) moveToPoint:(NSPoint)p
{
//	cairo_move_to(_cr,p.x,p.y);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) lineToPoint:(NSPoint)p
{
//	cairo_line_to(_cr,p.x,p.y);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) relativeLineToPoint:(NSPoint)p
{
//	cairo_rel_line_to(_cr,p.x,p.y);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) relativeLineToSize:(NSSize)s
{
//	cairo_rel_line_to(_cr,s.width,s.height);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}
- (void) fill
{
//	cairo_fill(_cr);
	NSLog (@":::FIXME::: %@ %s cairo %d [%s]",[self description], sel_get_name(_cmd),_cr,cairo_status_string(_cr));
}

/* What is the Matrix? */

- (NSAffineTransform *) CTM
{
	cairo_matrix_t *cairo_ctm;
	cairo_ctm = cairo_matrix_create();
	cairo_current_matrix(_cr, cairo_ctm);
	id retMe = WMCairoMatrixToNSAffine(cairo_ctm);
	cairo_matrix_destroy(cairo_ctm);
	return retMe;
}

- (void) setCTM: (NSAffineTransform *)newctm
{
	NSAffineTransformStruct ats = [newctm transformStruct];
	cairo_matrix_t *cairo_mp = cairo_matrix_create();
	cairo_matrix_set_affine(cairo_mp,ats.m11,ats.m12,ats.m21,ats.m22,ats.tx,ats.ty);
	cairo_set_matrix(_cr, cairo_mp);
	cairo_matrix_destroy(cairo_mp);
}

- (void) concatCTM: (NSAffineTransform *)concatctm
{
	NSAffineTransformStruct ats = [concatctm transformStruct];
	cairo_matrix_t *cairo_mp = cairo_matrix_create();
	cairo_matrix_set_affine(cairo_mp,ats.m11,ats.m12,ats.m21,ats.m22,ats.tx,ats.ty);
	cairo_concat_matrix(_cr, cairo_mp);
	cairo_matrix_destroy(cairo_mp);
}

@end /* CairoType */

@implementation CairoBuffer

NSMapTable * buffermap;

+ (void) initialize
{
	buffermap = NSCreateMapTable(NSIntMapKeyCallBacks,NSNonRetainedObjectMapValueCallBacks,10);
}

+ (CairoBuffer *) pixmapWithWindowDevice: (gswindow_device_t *)device
{
	id buff = [[self alloc] initWithWindowDevice: device];
	AUTORELEASE(buff);
	return buff;
}

+ (CairoBuffer *) bufferForDevice: (gswindow_device_t *)device
{
	CairoBuffer *_b = (CairoBuffer *) NSMapGet(buffermap, (void*)(device->ident));
	if (_b == nil)
	{
		_b = [[self alloc] initWithWindowDevice: device];
	}
	return _b;
}

- (void) handleExposeRect:(NSRect)er
{
	XCopyArea(_gsdevice->display, _pixmap, _gsdevice->ident,_gsdevice->gc, NSMinX(er), NSMinY(er), NSWidth(er), NSHeight(er), NSMinX(er), NSMinY(er));
	/*
	XClearWindow(_gsdevice->display, _gsdevice->ident);
	XClearArea(_gsdevice->display, _gsdevice->ident, NSMinX(er), NSMinY(er), NSWidth(er), NSHeight(er), NO);
	*/
}

- (id) init
{
	RELEASE(self);
	return nil;
}


- (id) initWithWindowDevice: (gswindow_device_t *)device
{
	NSLog (@":::FIXME::: %@ %s",[self description], sel_get_name(_cmd));
	_gsdevice = device;
	id oldbuffer = NSMapGet(buffermap, (const void*)(device->ident));
	if (oldbuffer != nil)
	{
		ASSIGN(self, oldbuffer);
		if (!NSEqualSizes(_pixmapSize, device->xframe.size))
		{
			_pixmapSize = device->xframe.size;
			_pixmap = XCreatePixmap(device->display,
					device->ident,
					NSWidth(device->xframe),
					NSHeight(device->xframe),
					device->depth);
		}
	}
	else
	{
		_deviceid = (void *)(device->ident);
		_pixmapSize = device->xframe.size;
		_pixmap = XCreatePixmap(device->display,
				device->ident,
				NSWidth(device->xframe),
				NSHeight(device->xframe),
				device->depth);

		NSMapInsert(buffermap, _deviceid, (const void*)self);
	}

	/*
	XSetWindowAttributes attr;
	attr.event_mask = KeyPressMask |
		KeyReleaseMask | ButtonPressMask |
		ButtonReleaseMask | ButtonMotionMask |
		StructureNotifyMask | PointerMotionMask |
		EnterWindowMask | LeaveWindowMask |
		FocusChangeMask | PropertyChangeMask |
		ColormapChangeMask | KeymapStateMask |
		VisibilityChangeMask;
	XChangeWindowAttributes(device->display, device->ident, CWEventMask, &attr);
	*/
#ifdef CAIRO_USE_BACKGROUND_PIXMAP
	XSetWindowBackgroundPixmap(device->display, device->ident,_pixmap);
	XClearWindow(device->display, device->ident);
#endif

	return self;
}

/*
- (id) copyWithZone: (NSZone *)zone
{
	CairoDevice *aCP = (CairoBuffer *)NSCopyObject(self, 0, zone);
}
*/

- (Pixmap) pixmap
{
	return _pixmap;
}

- (NSSize) size
{
	return _pixmapSize;
}

- (gswindow_device_t *) device
{
	return _gsdevice;
}

- (void) dealloc
{
	NSLog (@":::FIXME::: %@ %s",[self description], sel_get_name(_cmd));
	if (_deviceid)
		NSMapRemove(buffermap, _deviceid);
	if (_pixmap)
		XFreePixmap([XGServer currentXDisplay], _pixmap);
	[super dealloc];
	NSLog(@"done CBF dealloc");
}
@end /* CairoBuffer */

@implementation CairoDevice
- (id) init
{
	NSLog (@":::FIXME::: %@ %s",[self description], sel_get_name(_cmd));
	_ct = [[CairoType alloc] init];

	return self;
}
- (void) setDevice: (gswindow_device_t *)window
{
	NSLog (@":::FIXME::: %@ %s %0x",[self description], sel_get_name(_cmd) ,_ct);
	_buffer = RETAIN([CairoBuffer pixmapWithWindowDevice:window]);
	XSetWindowAttributes attr;
	[_ct setTargetBuffer:_buffer];
	[_ct translateToPoint:NSMakePoint(0,-NSHeight(window->xframe))];
	attr.event_mask = KeyPressMask |
		KeyReleaseMask | ButtonPressMask |
		ButtonReleaseMask | ButtonMotionMask |
		StructureNotifyMask | PointerMotionMask |
		EnterWindowMask | LeaveWindowMask |
		FocusChangeMask | PropertyChangeMask |
		ColormapChangeMask | KeymapStateMask |
		VisibilityChangeMask;
	XChangeWindowAttributes(window->display, window->ident, CWEventMask, &attr);

}
- (CairoType *) ct
{
	NSLog (@":::FIXME::: %@ %s %0x",[self description], sel_get_name(_cmd) ,_ct);
	return _ct;
}

- (void) dealloc
{
	NSLog (@":::FIXME::: %@ %s %0x",[self description], sel_get_name(_cmd) ,_ct);
	[_ct release];
	if (_buffer)
	{
		[_buffer release];
	}
	[super dealloc];
	NSLog(@"done CD dealloc");
}

- (id) copyWithZone: (NSZone *)zone
{
	CairoDevice *aCD = (CairoDevice *)NSCopyObject(self, 0, zone);
	NSLog (@":::FIXME::: %@ %s copy to %0x",[self description], sel_get_name(_cmd), aCD);
	aCD->_ct = [_ct copyWithZone:zone];
//	aCD->_buffer = [_buffer copy];
	RETAIN(_buffer);
	return aCD;
}
@end

