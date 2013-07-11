/*
   OpalSurface.m

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

#import "opal/OpalSurface.h"
#import "x11/XGServerWindow.h"

/* TODO: expose these from within opal */
extern CGContextRef OPX11ContextCreate(Display *display, Drawable drawable);
extern void OPContextSetSize(CGContextRef ctx, CGSize s);

@implementation OpalSurface

- (id) initWithDevice: (void *)device
{
  self = [super init];
  if (!self)
    return nil;

  // FIXME: this method and class presumes we are being passed
  // a window device.
  _gsWindowDevice = (gswindow_device_t *) device;

  Display * display = _gsWindowDevice->display;
  Window window = _gsWindowDevice->ident;

  _cgContext = OPX11ContextCreate(display, window);
  
  return self;
}

- (gswindow_device_t *) device
{
  return _gsWindowDevice;
}

- (void) dummyDraw
{

  NSLog(@"performing dummy draw");
  
  CGContextSaveGState(_cgContext);

  CGRect r = CGRectMake(0, 0, 1024, 1024);
  CGContextSetRGBFillColor(_cgContext, 1, 0, 0, 1);
  CGContextFillRect(_cgContext, r);

  CGContextRestoreGState(_cgContext);

}

@end
