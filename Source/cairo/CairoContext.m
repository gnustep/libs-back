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
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */
#include "cairo/CairoContext.h"
#include "cairo/CairoGState.h"
#include "cairo/CairoSurface.h"
#include "cairo/CairoFontInfo.h"
#include "cairo/CairoFontEnumerator.h"
#include "x11/XGServer.h"
#include "config.h"

#ifdef USE_GLITZ
#include "cairo/XGCairoGlitzSurface.h"
#else
#include "cairo/XGCairoSurface.h"
#include "cairo/XGCairoXImageSurface.h"
#endif

#define CGSTATE ((CairoGState *)gstate)


@implementation CairoContext

+ (void) initializeBackend
{
  //NSLog (@"CairoContext : Initializing cairo backend");
  [NSGraphicsContext setDefaultContextClass: self];

#ifdef USE_GLITZ
  [CairoSurface setDefaultSurfaceClass: [XGCairoGlitzSurface class]];
#else
//  [CairoSurface setDefaultSurfaceClass: [XGCairoSurface class]];
  [CairoSurface setDefaultSurfaceClass: [XGCairoXImageSurface class]];
#endif
  [GSFontEnumerator setDefaultClass: [CairoFontEnumerator class]];
  [GSFontInfo setDefaultClass: [CairoFontInfo class]];
}

- (id) initWithContextInfo: (NSDictionary *)info
{
  NSString *contextType;

  [super initWithContextInfo:info];

  contextType = [info objectForKey:
			 NSGraphicsContextRepresentationFormatAttributeName];
  if (contextType)
    {
      /* Most likely this is a PS or PDF context, so just return what
	 super gave us */
      return self;
    }

  gstate = [[CairoGState allocWithZone: [self zone]] initWithDrawContext: self];

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
  [CGSTATE GSCurrentDevice: device : x : y];
}

- (void) GSSetDevice: (void *)device : (int)x : (int)y
{
  [CGSTATE GSSetDevice: device : x : y];
}

@end
