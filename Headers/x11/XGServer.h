/* <title>XGServer</title>

   <abstract>Backend server using the X11.</abstract>

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Adam Fedor <fedor@gnu.org>
   Date: Mar 2002
   
   This file is part of the GNUstep Backend.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#ifndef _XGServer_h_INCLUDE
#define _XGServer_h_INCLUDE

#include <AppKit/GSDisplayServer.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include "x11/XGGeneric.h"

/*
 * Enumerated type to say how we should draw pixels to the X display - used
 * to select different drawing mechanisms to try to optimise.
 */
typedef enum {
  XGDM_FAST15,
  XGDM_FAST16,
  XGDM_FAST32,
  XGDM_FAST32_BGR,
  XGDM_PORTABLE
} XGDrawMechanism;

@interface XGServer : GSDisplayServer
{
@public
  void			*context;
  Window		grabWindow;
  XGDrawMechanism	drawMechanism;
  struct XGGeneric	generic;
  id                    inputServer;
}

+ (Display*) currentXDisplay;
- (XGDrawMechanism) drawMechanism;
- (Display*)xDisplay;
- (Window)xDisplayRootWindow;
- (Window)xAppRootWindow;

- (XColor)xColorFromColor: (XColor)color;

- (void *) xrContext;

+ (void) waitAllContexts;
@end

/*
 * Synchronize with X event queue - soak up events.
 * Waits for up to 1 second for event.
 */
@interface XGServer (XSync)
- (BOOL) xSyncMap: (void*)window;
@end

@interface XGServer (XGGeneric)
- (NSRect) _OSFrameToXFrame: (NSRect)o for: (void*)window;
- (NSRect) _OSFrameToXHints: (NSRect)o for: (void*)window;
- (NSRect) _XFrameToOSFrame: (NSRect)x for: (void*)window;
@end

#endif /* _XGServer_h_INCLUDE */
