/* -*- mode:ObjC -*-
   XGGLContext - backend implementation of NSOpenGLContext

   Copyright (C) 1998,2002 Free Software Foundation, Inc.

   Written by:  Frederic De Jaeger
   Date: Nov 2002
   
   This file is part of the GNU Objective C User Interface Library.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */


#include "config.h"
#ifdef HAVE_GLX
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <AppKit/GSDisplayServer.h>
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
  Window 	winid;
  NSView	*attached;
}
- (void) update;
+ subwindowOnView: (NSView *) view;
@end

@implementation XGXSubWindow 
/*We assume that the current context is the same and is an XGServer
 */
- initWithView: (NSView *) view
{
  NSRect rect;
  gswindow_device_t *win_info;
  XGServer *server;
  NSWindow *win;
  int x, y, width, height;
  [super init];

  win = [view window];
  NSAssert(win, @"request of an X window attachment on a view that is not on a NSWindow");

  if ( [view isRotatedOrScaledFromBase] )
    [NSException raise: NSInvalidArgumentException
		 format: @"Cannot attach an Xwindow to a view that is rotated or scaled"];
  
  server = (XGServer *)GSServerForWindow(win);
  NSAssert(server != nil, NSInternalInconsistencyException);

  NSAssert([server isKindOfClass: [XGServer class]], 
	   NSInternalInconsistencyException);

  win_info = [XGServer _windowWithTag: [win windowNumber]];
  NSAssert(win_info, NSInternalInconsistencyException);

  rect = [view convertRect: [view bounds] toView: nil];

  x = NSMinX(rect);
  y = NSHeight(win_info->xframe) - NSMaxY(rect);
  width = NSWidth(rect);
  height = NSHeight(rect);

  
//   winid = XCreateWindow(win_info->display, DefaultRootWindow(win_info->display),
// 			x, y, width, height, 0, 
// 			CopyFromParent, InputOutput, CopyFromParent, 0, NULL);

  winid = XCreateWindow(win_info->display, win_info->ident,
			x, y, width, height, 0, 
			CopyFromParent, InputOutput, CopyFromParent, 0, NULL);


//   winid = XCreateSimpleWindow(win_info->display, win_info->ident,
// 			x, y, width, height, 2, 
// 			0, 1);


  XMapWindow(win_info->display, winid);
  

  attached = view;
  return self;
}

- (void) map
{
  MAKE_DISPLAY(dpy);
  XMapWindow(dpy, winid);
}

- (void) detach
{
  //FIXME
  //I assume that the current server is correct. 
  MAKE_DISPLAY(dpy);
  attached = nil;
  XDestroyWindow(dpy, winid);
}

- (void) update
{
  NSRect rect;
  gswindow_device_t *win_info;
  GSDisplayServer *server;
  NSWindow *win;
  int x, y, width, height;
  NSAssert(attached, NSInternalInconsistencyException);

  win = [attached window];
  NSAssert1(win, @"%@'s window is nil now!", attached);

  NSAssert1(![attached isRotatedOrScaledFromBase],
	    @"%@ is rotated or scaled, now!", attached);
  
  server = GSServerForWindow(win);
  NSAssert(server != nil, NSInternalInconsistencyException);

  NSAssert([server isKindOfClass: [XGServer class]], 
	   NSInternalInconsistencyException);

  //FIXME
  //we should check that the window hasn't changed, maybe.

  win_info = [XGServer _windowWithTag: [win windowNumber]];
  NSAssert(win_info, NSInternalInconsistencyException);

  rect = [attached convertRect: [attached bounds] toView: nil];

  x = NSMinX(rect);
  y = NSHeight(win_info->xframe) - NSMaxY(rect);
  width = NSWidth(rect);
  height = NSHeight(rect);

  
  XMoveResizeWindow(win_info->display, winid,x, y, width, height);
}

- (void) dealloc
{
  NSDebugMLLog(@"GLX", @"deallocating");
  [self detach];
  [super dealloc];
}

+ subwindowOnView: (NSView *) view
{
  XGXSubWindow *win = [[self alloc] initWithView: view];

  return AUTORELEASE(win);
}
@end

//FIXME:
//should be on per thread basis.
static XGGLContext *currentGLContext;


@implementation XGGLContext

+ (void)clearCurrentContext
{
  MAKE_DISPLAY(dpy);

  if (GSglxMinorVersion (dpy) >= 3)
    glXMakeContextCurrent(dpy, None, None, NULL);
  else
    glXMakeCurrent(dpy, None, NULL);

  currentGLContext = nil;
}

+ (NSOpenGLContext *)currentContext
{
  return currentGLContext;
}

- (void) _detach
{
  if( xsubwin )
    {
      MAKE_DISPLAY(dpy);
      if ( currentGLContext == self )
	{
	  [XGGLContext clearCurrentContext];
	}
      //      glXDestroyWindow(dpy, glx_drawable);
      glx_drawable = None;
      DESTROY(xsubwin);
    }
}

- (void)clearDrawable
{
  [self _detach];
}

- (void)copyAttributesFromContext:(NSOpenGLContext *)context 
			 withMask:(unsigned long)mask
{
  GLXContext other;
  MAKE_DISPLAY(dpy);
  if( context == nil ||  ![context isKindOfClass: [XGGLContext class]] )
    [NSException raise: NSInvalidArgumentException
		 format: @"%@ is an invalid context", context];
  other = ((XGGLContext *)context)->glx_context;
  glXCopyContext(dpy, other, glx_context, mask);
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


- (id)initWithFormat:(NSOpenGLPixelFormat *)_format 
	shareContext:(NSOpenGLContext *)share
{
  [super init];
  glx_context = None;
  
  if( _format && [_format isKindOfClass: [XGGLPixelFormat class]])
    {
      MAKE_DISPLAY(dpy);
      ASSIGN(format, (XGGLPixelFormat *)_format);
      //FIXME: allow index mode and sharing

      if (GSglxMinorVersion (dpy) >= 3)
	glx_context = glXCreateNewContext(dpy, format->conf.tab[0], 
					  GLX_RGBA_TYPE, NULL, YES);
      else
	glx_context = glXCreateContext(dpy, format->conf.visual, 0, GL_TRUE);

      return self;
    }
  else
    {
      NSDebugMLLog(@"GLX", @"invalid format %@", _format);
      RELEASE(self);
      return nil;
    }
}


- (void) dealloc
{
  NSDebugMLLog(@"GLX", @"deallocating");
  [self _detach];
  RELEASE(format);
  if( glx_context != None )
    {
      MAKE_DISPLAY(dpy);
      glXDestroyContext(dpy, glx_context);
    }
  [super dealloc];
}

- (void) makeCurrentContext
{
  MAKE_DISPLAY(dpy);
  if( xsubwin == nil )
    [NSException raise: NSGenericException
		 format: @"GL Context is not bind, cannot be made current"];
  
  NSAssert(glx_context != None && glx_drawable != None,
	   NSInternalInconsistencyException);

  if (GSglxMinorVersion (dpy) >= 3)
    {
      NSDebugMLLog(@"GLX", @"before glXMakeContextCurrent");
      glXMakeContextCurrent(dpy, glx_drawable, glx_drawable, glx_context);
      NSDebugMLLog(@"GLX", @"after glXMakeContextCurrent");
    }
  else
    {
      NSDebugMLLog(@"GLX", @"before glXMakeCurrent");
      glXMakeCurrent(dpy, glx_drawable, glx_context);
      NSDebugMLLog(@"GLX", @"after glXMakeCurrent");
    }

//   NSAssert(glx_context != None,   NSInternalInconsistencyException);

//   glXMakeCurrent(dpy, xsubwin->winid, glx_context);

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
  XGXSubWindow *win;
  MAKE_DISPLAY(dpy);
  if( !view )
    [NSException raise: NSInvalidArgumentException
		 format: @"setView called with a nil value"];

  NSAssert(format, NSInternalInconsistencyException);
  win = [XGXSubWindow subwindowOnView: view];
  ASSIGN(xsubwin, win);
  glx_drawable = xsubwin->winid;

//   {
//     GLXFBConfig  *conf_tab;
//     int		n_elem;
//     int attrs[] = { 
//       GLX_DOUBLEBUFFER, 1,
//       GLX_DEPTH_SIZE, 16,
//       GLX_RED_SIZE, 1,
//       GLX_BLUE_SIZE, 1,
//       GLX_GREEN_SIZE, 1,
//       None
//     };    
  
//     conf_tab = glXChooseFBConfig(dpy, DefaultScreen(dpy), attrs,  &n_elem);
//     if ( n_elem > 0 )
//       {
// 	printf("found %d context\n", n_elem);
// // 	win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 10, 10,
// // 				  800, 600, 1, 0, 1);
// 	glx_drawable = glXCreateWindow(dpy, *conf_tab, xsubwin->winid,  NULL);
      
//       }
//     else
//       puts("no context found");


//   }	

//FIXME
//The following line should be the good one.  But it crashes my X server...

//   glx_drawable = glXCreateWindow(dpy, *format->conf_tab, xsubwin->winid,
// 				 NULL);
  NSDebugMLLog(@"GLX", @"glx_window : %u", glx_drawable);
}


- (void)update
{
  [xsubwin update];
}


- (NSView *)view
{
  if(xsubwin)
    return xsubwin->attached;
  else
    return nil;
}

@end
#endif
