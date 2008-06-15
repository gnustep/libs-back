/*
   CairoContext.m

   Copyright (C) 2003 Free Software Foundation, Inc.

   August 31, 2003
   Written by Banlu Kemiyatorn <object at gmail dot com>

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

#include "cairo/CairoContext.h"
#include "cairo/CairoGState.h"
#include "cairo/CairoSurface.h"
#include "cairo/CairoPSSurface.h"
#include "cairo/CairoPDFSurface.h"
#include "cairo/CairoFontInfo.h"
#include "cairo/CairoFontEnumerator.h"
#include "config.h"

#define CGSTATE ((CairoGState *)gstate)

#if BUILD_SERVER == SERVER_x11
#  include "x11/XGServer.h"
#  ifdef USE_GLITZ
#    define _CAIRO_SURFACE_CLASSNAME XGCairoGlitzSurface
#    include "cairo/XGCairoGlitzSurface.h"
#  else
//#    define _CAIRO_SURFACE_CLASSNAME XGCairoSurface
//#    include "cairo/XGCairoSurface.h"
#    define _CAIRO_SURFACE_CLASSNAME XGCairoXImageSurface
#    include "cairo/XGCairoXImageSurface.h"
#  endif /* USE_GLITZ */
#  include "x11/XGServerWindow.h"
#  include "x11/XWindowBuffer.h"
#elif BUILD_SERVER == SERVER_win32
#  include <windows.h>
#  ifdef USE_GLITZ
#    define _CAIRO_SURFACE_CLASSNAME Win32CairoGlitzSurface
#    include "cairo/Win32CairoGlitzSurface.h"
#  else
#    define _CAIRO_SURFACE_CLASSNAME Win32CairoSurface
#    include "cairo/Win32CairoSurface.h"
#  endif /* USE_GLITZ */
#else
#  error Invalid server for Cairo backend : non implemented
#endif /* BUILD_SERVER */


@implementation CairoContext

+ (void) initializeBackend
{
  [NSGraphicsContext setDefaultContextClass: self];

  [GSFontEnumerator setDefaultClass: [CairoFontEnumerator class]];
  [GSFontInfo setDefaultClass: [CairoFontInfo class]];
}

+ (Class) GStateClass
{
  return [CairoGState class];
}

+ (BOOL) handlesPS
{
  return YES;
}

- (void) flushGraphics
{
#if BUILD_SERVER == SERVER_x11
  XFlush([(XGServer *)server xDisplay]);
#endif // BUILD_SERVER = SERVER_x11
}

#if BUILD_SERVER == SERVER_x11

/* Private backend methods */
+ (void) handleExposeRect: (NSRect)rect forDriver: (void *)driver
{
  [(XWindowBuffer *)driver _exposeRect: rect];
}

#ifdef XSHM

+ (void) _gotShmCompletion: (Drawable)d
{
  [XWindowBuffer _gotShmCompletion: d];
}

- (void) gotShmCompletion: (Drawable)d
{
  [XWindowBuffer _gotShmCompletion: d];
}

#endif // XSHM

#endif // BUILD_SERVER = SERVER_x11

@end 

@implementation CairoContext (Ops) 

- (void) GSCurrentDevice: (void **)device : (int *)x : (int *)y
{
  CairoSurface *surface;

  [CGSTATE GSCurrentSurface: &surface : x : y];
  if (device)
    {
      *device = surface->gsDevice;
    }
}

- (void) GSSetDevice: (void *)device : (int)x : (int)y
{
  CairoSurface *surface;

  surface = [[_CAIRO_SURFACE_CLASSNAME alloc] initWithDevice: device];

  [CGSTATE GSSetSurface: surface : x : y];
  [surface release];
}

- (void) beginPrologueBBox: (NSRect)boundingBox
              creationDate: (NSString*)dateCreated
                 createdBy: (NSString*)anApplication
                     fonts: (NSString*)fontNames
                   forWhom: (NSString*)user
                     pages: (int)numPages
                     title: (NSString*)aTitle
{
  CairoSurface *surface;
  NSSize size;
  NSString *contextType;

  contextType = [context_info objectForKey:
			 NSGraphicsContextRepresentationFormatAttributeName];

  if (contextType)
    {
      if ([contextType isEqual: NSGraphicsContextPSFormat])
        {
          size = boundingBox.size;
          surface = [[CairoPSSurface alloc] initWithDevice: context_info];
          [surface setSize: size];
          // This strange setting is needed because of the way GUI handles offset.
          [CGSTATE GSSetSurface: surface : 0.0 : size.height];
          RELEASE(surface);
        }
      else if ([contextType isEqual: NSGraphicsContextPDFFormat])
        {
          size = boundingBox.size;
          surface = [[CairoPDFSurface alloc] initWithDevice: context_info];
          [surface setSize: size];
          // This strange setting is needed because of the way GUI handles offset.
          [CGSTATE GSSetSurface: surface : 0.0 : size.height];
          RELEASE(surface);
        }
    }
}

- (void) showPage
{
  [CGSTATE showPage];
}

@end

#undef _CAIRO_SURFACE_CLASSNAME
