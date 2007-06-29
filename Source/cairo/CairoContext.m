/*
 * CairoContext.m

 * Copyright (C) 2003 Free Software Foundation, Inc.
 * August 31, 2003
 * Written by Banlu Kemiyatorn <object at gmail dot com>
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
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02111 USA.
 */
#include "cairo/CairoContext.h"
#include "cairo/CairoGState.h"
#include "cairo/CairoSurface.h"
#include "cairo/CairoPSSurface.h"
#include "cairo/CairoFontInfo.h"
#include "cairo/CairoFontEnumerator.h"
#include "x11/XGServer.h"
#include "config.h"

#ifdef USE_GLITZ
#include "cairo/XGCairoGlitzSurface.h"
#else
#include "cairo/XGCairoSurface.h"
#include "cairo/XGCairoXImageSurface.h"
#include "x11/XGServerWindow.h"
#include "x11/XWindowBuffer.h"
#endif

#define CGSTATE ((CairoGState *)gstate)

@class XWindowBuffer;

@implementation CairoContext

+ (void) initializeBackend
{
  [NSGraphicsContext setDefaultContextClass: self];

  [GSFontEnumerator setDefaultClass: [CairoFontEnumerator class]];
  [GSFontInfo setDefaultClass: [CairoFontInfo class]];
}

- (id) initWithContextInfo: (NSDictionary *)info
{
  NSString *contextType;

  contextType = [info objectForKey:
			 NSGraphicsContextRepresentationFormatAttributeName];
  // Don't allow super to handle PS case.
  self = [super initWithContextInfo: nil];
  if (!self)
    return self;

  gstate = [[CairoGState allocWithZone: [self zone]] initWithDrawContext: self];

  if (contextType)
    {
      CairoSurface *surface;
      NSSize size;

      surface = [[CairoPSSurface alloc] initWithDevice: info];
      // This strange setting is needed because of the way GUI handles offset.
      size = [surface size];
      [CGSTATE GSSetSurface: surface : 0.0 : size.height];
      RELEASE(surface);
    }

  return self;
}

- (void) flushGraphics
{
  XFlush([(XGServer *)server xDisplay]);
}

/* Private backend methods */
+(void) handleExposeRect: (NSRect)rect forDriver: (void *)driver
{
  [(XWindowBuffer *)driver _exposeRect: rect];
}

#ifdef XSHM

+(void) _gotShmCompletion: (Drawable)d
{
  [XWindowBuffer _gotShmCompletion: d];
}

-(void) gotShmCompletion: (Drawable)d
{
  [XWindowBuffer _gotShmCompletion: d];
}

#endif

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

#ifdef USE_GLITZ
  surface = [[XGCairoGlitzSurface alloc] initWithDevice: device];
#else
  //surface = [[XGCairoSurface alloc] initWithDevice: device];
  surface = [[XGCairoXImageSurface alloc] initWithDevice: device];
#endif

  [CGSTATE GSSetSurface: surface : x : y];
}

- (void) beginPrologueBBox: (NSRect)boundingBox
              creationDate: (NSString*)dateCreated
                 createdBy: (NSString*)anApplication
                     fonts: (NSString*)fontNames
                   forWhom: (NSString*)user
                     pages: (int)numPages
                     title: (NSString*)aTitle
{
  [CGSTATE setSize: boundingBox.size];
}

- (void) showPage
{
  [CGSTATE showPage];
}

@end
