/*
   Win32CairoSurface.m

   Copyright (C) 2008 Free Software Foundation, Inc.

   Author: Xavier Glattard <xavier.glattard@online.fr>
   Based on the work of:
     Banlu Kemiyatorn <object at gmail dot com>

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

#include "cairo/Win32CairoSurface.h"
#include "win32/WIN32Geometry.h"
#include <cairo-win32.h>

#define GSWINDEVICE ((HWND)gsDevice)

@implementation Win32CairoSurface


//#define RELEASE_DC_FROM_WINDOW


static cairo_user_data_key_t WindowSurface;

- (id) initWithDevice: (void *)device
{
  HDC hDC;
  WIN_INTERN *win;
  gsDevice = device;

  win = (WIN_INTERN *)GetWindowLong(GSWINDEVICE, GWL_USERDATA);
  hDC = GetDC(GSWINDEVICE);

  if (!hDC)
    {
      NSLog(@"Win32CairoSurface : %d : no device context",__LINE__);
      exit(1);
    }

  RECT rect;
  GetClientRect(GSWINDEVICE, &rect);
  
  // Create the cairo surfaces...
  // This is the raw DC surface...
  cairo_surface_t *window = cairo_win32_surface_create(hDC);
  
  // and this is the in-memory DC surface...
  _surface = cairo_surface_create_similar(window, CAIRO_CONTENT_COLOR_ALPHA,
                                          rect.right - rect.left,
                                          rect.bottom - rect.top);
                                          
  // Save the raw DC surface as user data on in-memory surface...
  // It will be used during handleExposeRect invocations...
#if defined(RELEASE_DC_FROM_WINDOW)
  cairo_surface_set_user_data(_surface, &WindowSurface, window, NULL);
#else
  cairo_surface_set_user_data(_surface, &WindowSurface, window, (cairo_destroy_func_t)cairo_surface_destroy);
#endif

  if (cairo_surface_status(_surface) != CAIRO_STATUS_SUCCESS)
    {
      cairo_status_t status = cairo_surface_status(_surface);
      NSLog(@"%s:surface create FAILED - status: %s\n", __PRETTY_FUNCTION__,
            cairo_status_to_string(status));
      DESTROY(self);
    }
  else
    {
      // We need this hack (for now) for handleExposeEvent in WIN32Server...
      win->hdc = (HDC)self;
    }
    
  return self;
}

- (void) dealloc
{
#if defined(RELEASE_DC_FROM_WINDOW)
  // We did a GetDC on the window handle - which requires a ReleaseDC...
  // Not sure what would happen if we don't do this  so we are going to
  // release the device context from the window surface ourselves...
  cairo_surface_t *window = cairo_surface_get_user_data(_surface, &WindowSurface);
  cairo_surface_set_user_data(_surface, &WindowSurface, NULL, NULL);
  ReleaseDC(GSWINDEVICE, cairo_win32_surface_get_dc(window));
  cairo_surface_destroy(window);
#endif
  [super dealloc];
}

- (NSString*) description
{
  HDC hdc = NULL;
  if (_surface)
    hdc = cairo_win32_surface_get_dc(_surface);
  NSMutableString *description = [[super description] mutableCopy];
  [description appendFormat: @" _surface: %p",_surface];
  [description appendFormat: @" dc: %p",hdc];
  return [description copy];
}

- (NSSize) size
{
  RECT sz;

  GetClientRect(GSWINDEVICE, &sz);
  return NSMakeSize(sz.right - sz.left, sz.top - sz.bottom);
}

- (void) setSize: (NSSize)newSize
{
  NSDebugLLog(@"Win32CairoSurface",
              @"%s:size: %@\n", __PRETTY_FUNCTION__,
              NSStringFromSize(newSize));
}

- (void) handleExposeRect: (NSRect)rect
{
  NSDebugLLog(@"Win32CairoSurface",
              @"%s:rect: %@\n", __PRETTY_FUNCTION__,
              NSStringFromRect(rect));
  
#if defined(EXPOSE_USES_BITBLT_SURFACE_RENDERING)
  // Use old fashioned BitBlt'ing methodology...
  cairo_surface_t *window = cairo_surface_get_user_data(_surface, &WindowSurface);
  HDC              dhdc   = cairo_win32_surface_get_dc(window);
  HDC              shdc   = cairo_win32_surface_get_dc(_surface);
  RECT             r      = GSWindowRectToMS((WIN32Server*)GSCurrentServer(), GSWINDEVICE, rect);
  
  // Ensure that surface context is flushed...
  cairo_surface_flush(window);
  
  // Do the BitBlt...
  WINBOOL result = BitBlt(dhdc, r.left, r.top, rect.size.width, rect.size.height, 
                          shdc, r.left, r.top, SRCCOPY);
  if (!result)
      NSLog(@"%s:BitBlt failed - error: %d", __PRETTY_FUNCTION__, GetLastError());
              
  // Inform surface that we've done something...
  cairo_surface_mark_dirty(window);
#else
  double backupOffsetX = 0;
  double backupOffsetY = 0;
  cairo_surface_get_device_offset(_surface, &backupOffsetX, &backupOffsetY);
  cairo_surface_set_device_offset(_surface, 0, 0);

  cairo_surface_t *window  = cairo_surface_get_user_data(_surface, &WindowSurface);
  cairo_t         *context = cairo_create(window);
  RECT             r       = GSWindowRectToMS((WIN32Server*)GSCurrentServer(), GSWINDEVICE, rect);

  cairo_rectangle(context, r.left, r.top, rect.size.width, rect.size.height);
  cairo_clip(context);
  cairo_set_source_surface(context, _surface, 0, 0);
  cairo_set_operator(context, CAIRO_OPERATOR_SOURCE);
  cairo_paint(context);
  
  // Cleanup...
  cairo_destroy(context);

  // Restore device offset
  cairo_surface_set_device_offset(_surface, backupOffsetX, backupOffsetY);
#endif
}

@end
