/* -*- mode:ObjC -*-
   XGGLContext - backend implementation of NSOpenGLContext

   Copyright (C) 1998,2002 Free Software Foundation, Inc.

   Written by:  Frederic De Jaeger
   Date: Nov 2002
   
   This file is part of the GNU Objective C User Interface Library.

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

#include "config.h"
#ifdef HAVE_GLX
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDictionary.h>
#include <GNUstepGUI/GSDisplayServer.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>
#include "x11/XGServerWindow.h"
#include "x11/XGOpenGL.h"
#include <X11/Xlib.h>

//FIXME
//should I store the display ?
#define MAKE_DISPLAY(dpy) Display *dpy;\
  dpy = [(XGServer *)GSCurrentServer() xDisplay];\
  NSAssert(dpy != NULL, NSInternalInconsistencyException)

@interface XGXSubWindow : NSObject
{
  @public
  Window  xwindowid;
  NSView *attached;
}

+ subwindowOnView:(NSView *)view visualinfo:(XVisualInfo *)xVisualInfo;

- (void) update;

@end

@implementation XGXSubWindow

//We assume that the current context is the same and is an XGServer
- initWithView: (NSView *)view visualinfo: (XVisualInfo *)xVisualInfo
{
  attached = view;

  return self;
}

- (void) map
{
}

- (void) detach
{
  //FIXME
  //I assume that the current server is correct. 
  attached = nil;
}

- (void) update
{
}

- (void) dealloc
{
  NSDebugMLLog(@"GLX", @"Deallocating");

  [self detach];
  [super dealloc];
}

+ subwindowOnView:(NSView *)view visualinfo:(XVisualInfo *)xVisualInfo
{
  XGXSubWindow *win = [[self alloc] initWithView: view visualinfo: xVisualInfo];

  return AUTORELEASE(win);
}

@end

//FIXME:
//should be on per thread basis.
static XGGLContext *currentGLContext;

@implementation XGGLContext

+ (void)clearCurrentContext
{
}

+ (NSOpenGLContext *)currentContext
{
  return currentGLContext;
}

- (void) _detach
{
}

- (GLXContext)glxcontext
{
  return glx_context;
}

- (void *)CGLContextObj
{
  // FIXME: Until we have a wrapper library
  // return the underlying context directly
  return (void*)glx_context;
}

- (void)clearDrawable
{
  [self _detach];
}

- (void)copyAttributesFromContext:(NSOpenGLContext *)context 
			 withMask:(unsigned long)mask
{
}

- (void)createTexture:(unsigned long)target 
	     fromView:(NSView*)view 
       internalFormat:(unsigned long)format
{
  [self notImplemented: _cmd];
}


- (int)currentVirtualScreen
{
  [self notImplemented: _cmd];

  return 0;
}

- (void)flushBuffer
{
  MAKE_DISPLAY(dpy);

  glXSwapBuffers(dpy, glx_drawable);
}

- (void)getValues:(long *)vals 
     forParameter:(NSOpenGLContextParameter)param
{
  //  TODO
  [self notImplemented: _cmd];
}

- (id)initWithCGLContextObj: (void *)context
{
  self = [super init];

  if (!self)
    {
      return nil;
    }

  // FIXME: Need to set the pixelFormat ivar
  glx_context = context;
  return self;
}

- (id)initWithFormat: (NSOpenGLPixelFormat *)_format 
	    shareContext: (NSOpenGLContext *)share
{
  self = [super init];

  if (!self)
    {
      return nil;
    }

  glx_context = None;
  
  return self;
}

- (void) dealloc
{
  NSDebugMLLog(@"GLX", @"Deallocating");

  [self _detach];
  [super dealloc];
}

- (void) makeCurrentContext
{
  currentGLContext = self;
}

- (void)setCurrentVirtualScreen:(int)screen
{
  [self notImplemented: _cmd];
}

- (void)setFullScreen
{
  [self notImplemented: _cmd];
}

- (void)setOffScreen:(void *)baseaddr 
               width:(long)width 
              height:(long)height 
            rowbytes:(long)rowbytes
{
  [self notImplemented: _cmd];
}

- (void)setValues:(const long *)vals 
     forParameter:(NSOpenGLContextParameter)param
{
  [self notImplemented: _cmd];
}

- (void)setView:(NSView *)view
{
}

- (void)update
{
  [xSubWindow update];
}

- (NSView *)view
{
  return nil;
}

@end
#endif
