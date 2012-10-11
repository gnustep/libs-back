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


static cairo_user_data_key_t SurfaceHWND;
static cairo_user_data_key_t SurfaceWindow;

static void CairoSurfaceDestroyCallback(void *surfacePtr)
{
  if (surfacePtr)
    {
      cairo_surface_t *surface = (cairo_surface_t*)surfacePtr;

      // We did a GetDC on the window handle - which requires a ReleaseDC...
      // Not sure what would happen if we don't do this so we are going to
      // release the device context from the window surface ourselves...
      if (cairo_win32_surface_get_dc(surface))
        {
          HWND whandle = (HWND)cairo_surface_get_user_data(surface, &SurfaceHWND);
          if (whandle == NULL)
            {
              NSLog(@"%s:Window handle is NULL - leaking DC: %p\n", __PRETTY_FUNCTION__,
                    cairo_win32_surface_get_dc(surface));
            }
          else
            {
              // Release the DC for the window surface...
              ReleaseDC(whandle, cairo_win32_surface_get_dc(surface));
      
              // Clear any user setting...
              cairo_surface_set_user_data(surface, &SurfaceHWND, NULL, NULL);
            }
        }
      
      // Destroy the associated surface...
      cairo_surface_destroy(surface);
    }
}

- (id) initWithDevice: (void *)device
{
  // Save/set initial state...
  gsDevice = device;
  _surface = NULL;
  
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong(GSWINDEVICE, GWL_USERDATA);
  HDC         hDC = GetDC(GSWINDEVICE);

  if (!hDC)
    {
      NSLog(@"%s:Win32CairoSurface line: %d : no device context", __PRETTY_FUNCTION__, __LINE__);
      exit(1);
    }
  
  // Create the cairo surfaces...
  // NSBackingStoreRetained works like Buffered since 10.5 (See apple docs)...
  // NOTE: According to Apple docs NSBackingStoreBuffered should be the only one
  //       ever used anymore....others are NOT recommended...
  if (win && (win->type == NSBackingStoreNonretained))
    {
      // This is the raw DC surface...
      _surface = cairo_win32_surface_create(hDC);
      NSLog(@"%s:NSBackingStoreNonretained", __PRETTY_FUNCTION__);

      // Check for error...
      if (cairo_surface_status(_surface) != CAIRO_STATUS_SUCCESS)
        {
          // Output the surface create error...
          cairo_status_t status = cairo_surface_status(_surface);
          NSLog(@"%s:surface create FAILED - status: %s\n", __PRETTY_FUNCTION__,
                cairo_status_to_string(status));
          
          // And deallocate ourselves...
          DESTROY(self);
        }
    }
  else
    {
      RECT crect;
      
      // Get the client rectangle information...
      GetClientRect(GSWINDEVICE, &crect);

      // This is the raw DC surface...
      cairo_surface_t *window = cairo_win32_surface_create(hDC);
      
      // Check for error...
      if (cairo_surface_status(window) != CAIRO_STATUS_SUCCESS)
        {
          // Output the surface create error...
          cairo_status_t status = cairo_surface_status(window);
          NSLog(@"%s:surface create FAILED - status: %s\n", __PRETTY_FUNCTION__,
                cairo_status_to_string(status));
                
          // Destroy the initial surface created...
          cairo_surface_destroy(window);
          
          // And deallocate ourselves...
          DESTROY(self);
        }
      else
        {
          // and this is the in-memory DC surface...surface owns its DC...
          // NOTE: For some reason we get an init sequence with zero width/height,
          //       which creates problems in the cairo layer.  It tries to clear
          //       the 'similar' surface it's creating, and with a zero width/height
          //       it incorrectly thinks the clear failed...so we will init with
          //       a minimum size of 1 for width/height...
          _surface = cairo_surface_create_similar(window, CAIRO_CONTENT_COLOR_ALPHA,
                                                  MAX(1, crect.right - crect.left),
                                                  MAX(1, crect.bottom - crect.top));

          // Check for error...
          if (cairo_surface_status(_surface) != CAIRO_STATUS_SUCCESS)
            {
              // Output the surface create error...
              cairo_status_t status = cairo_surface_status(_surface);
              NSLog(@"%s:surface create FAILED - status: %s\n", __PRETTY_FUNCTION__,
                    cairo_status_to_string(status));
                    
              // Destroy the initial surface created...
              cairo_surface_destroy(window);
              
              // And deallocate ourselves...
              DESTROY(self);
            }
          else
            {
              // We need the window handle in the destroy callback to properly
              // release the DC...
              cairo_surface_set_user_data(window, &SurfaceHWND, device, NULL);

              // Save the raw DC surface as user data on in-memory surface...
              // It will be used during handleExposeRect invocations...
              cairo_surface_set_user_data(_surface, &SurfaceWindow, window,
                                          (cairo_destroy_func_t)CairoSurfaceDestroyCallback);
            }
        }
    }
      
  if (self)
    {
      // We need this for handleExposeEvent in WIN32Server...
      win->surface = (void*)self;
    }
  else
    {
      // Release the device context...
      ReleaseDC(GSWINDEVICE, hDC);
    }
    
  return self;
}

- (void) dealloc
{
  //NSLog(@"%s:self: %@\n", __PRETTY_FUNCTION__, self);
  if ((_surface == NULL) || (cairo_surface_status(_surface) != CAIRO_STATUS_SUCCESS))
    {
      NSLog(@"%s:null surface or bad status\n", __PRETTY_FUNCTION__);
    }
  else
    {
      if (cairo_win32_surface_get_dc(_surface) == NULL)
        {
          NSLog(@"%s:HDC is NULL for surface: %@\n", __PRETTY_FUNCTION__, self);
        }
      else
        {
          ReleaseDC(GSWINDEVICE, cairo_win32_surface_get_dc(_surface));
        }
    }
  [super dealloc];
}

- (NSString*) description
{
  HDC hdc = NULL;
  if (_surface)
    hdc = cairo_win32_surface_get_dc(_surface);
  NSMutableString *description = [[[super description] mutableCopy] autorelease];
  [description appendFormat: @" _surface: %p",_surface];
  [description appendFormat: @" dc: %p",hdc];
  return [[description copy] autorelease];
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
  
  // If the surface is buffered then it will have the main surface set as user data...
  cairo_surface_t *window = cairo_surface_get_user_data(_surface, &SurfaceWindow);
  
#if 0
  NSWindow *nswindow = GSWindowWithNumber(gsDevice);
  if ([[nswindow title] isEqualToString: @"GSToolTips"])
  {
    NSLog(@"%s:title: %@ _surface: %p window: %p rect: %@\n", __PRETTY_FUNCTION__,
          [nswindow title], _surface, window,
          NSStringFromRect(rect));
  }
#endif

  // If the surface is buffered then...
  if (window)
    {
      // First check the current status of the foreground surface...
      if (cairo_surface_status(window) != CAIRO_STATUS_SUCCESS)
        {
          NSLog(@"%s:cairo initial window error status: %s\n", __PRETTY_FUNCTION__,
                cairo_status_to_string(cairo_surface_status(window)));
          return;
        }
      
      cairo_t *context = cairo_create(window);

      if (cairo_status(context) != CAIRO_STATUS_SUCCESS)
        {
          NSLog(@"%s:cairo context create error - status: _surface: %s window: %s windowCtxt: %s (%d)",
                __PRETTY_FUNCTION__,
                cairo_status_to_string(cairo_surface_status(_surface)),
                cairo_status_to_string(cairo_surface_status(window)),
                cairo_status_to_string(cairo_status(context)), cairo_get_reference_count(context));
        }
      else
        {
          double  backupOffsetX = 0;
          double  backupOffsetY = 0;
          RECT    msRect        = GSWindowRectToMS((WIN32Server*)GSCurrentServer(), GSWINDEVICE, rect);

          // Flush source surface...
          cairo_surface_flush(_surface);
          
          // Need to save the device offset context...
          cairo_surface_get_device_offset(_surface, &backupOffsetX, &backupOffsetY);
          cairo_surface_set_device_offset(_surface, 0, 0);

          cairo_rectangle(context, msRect.left, msRect.top, rect.size.width, rect.size.height);
          cairo_clip(context);
          cairo_set_source_surface(context, _surface, 0, 0);
          cairo_set_operator(context, CAIRO_OPERATOR_SOURCE);
          cairo_paint(context);
          
          if (cairo_status(context) != CAIRO_STATUS_SUCCESS)
          {
            NSLog(@"%s:cairo expose error - status: _surface: %s window: %s windowCtxt: %s",
                  __PRETTY_FUNCTION__,
                  cairo_status_to_string(cairo_surface_status(_surface)),
                  cairo_status_to_string(cairo_surface_status(window)),
                  cairo_status_to_string(cairo_status(context)));
          }

          // Cleanup...
          cairo_destroy(context);

          // Restore device offset
          cairo_surface_set_device_offset(_surface, backupOffsetX, backupOffsetY);
        }
    }
}

@end
