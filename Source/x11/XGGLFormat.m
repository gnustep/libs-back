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
#include <Foundation/NSData.h>
#include <AppKit/GSDisplayServer.h>
#include "x11/XGServer.h"
#include "x11/XGOpenGL.h"

#include <X11/Xlib.h>

#define MAKE_DISPLAY(dpy) Display *dpy;\
  dpy = [(XGServer *)GSCurrentServer() xDisplay];\
  NSAssert(dpy != NULL, NSInternalInconsistencyException)


@implementation XGGLPixelFormat
- (void)getValues:(long *)vals 
     forAttribute:(NSOpenGLPixelFormatAttribute)attrib 
 forVirtualScreen:(int)screen
  /* FIXME:
     we assume that the ABI of NSOpenGLPixelFormatAttribute matches the ABI 
     of glX.
     Apparently, This is true for the most usefull attributes.
  */
{
  MAKE_DISPLAY(dpy);
  NSAssert(((GSglxMinorVersion (dpy) >= 3) 
	    ? (void *)conf.tab : (void *)conf.visual)
	   != NULL
	   && n_elem > 0, NSInternalInconsistencyException);

  if (GSglxMinorVersion (dpy) >= 3)
    glXGetFBConfigAttrib(dpy, conf.tab[0], attrib, (int *)vals);
  else
    glXGetConfig(dpy, conf.visual, attrib, (int *)vals);
}

- (id)initWithAttributes:(NSOpenGLPixelFormatAttribute *)attribs
{
  int v1, v2;
  NSOpenGLPixelFormatAttribute *ptr = attribs;
  NSMutableData *data = [NSMutableData data];
  MAKE_DISPLAY(dpy);

#define append(a, b) v1 = a;v2 = b;[data appendBytes: &v1 length: sizeof(v1)];\
  [data appendBytes: &v2 length: sizeof(v2)]
#define append1(a) v1 = a;[data appendBytes: &v1 length: sizeof(v1)]

  if (GSglxMinorVersion (dpy) < 3)
    append1 (GLX_RGBA);

  while(*ptr)
    {
      switch(*ptr)
	{
	  //	case  NSOpenGLPFAAllRenderers:
	case  NSOpenGLPFADoubleBuffer:
	  append(GLX_DOUBLEBUFFER, YES);
	  break;
	case NSOpenGLPFAStereo:
	  append(GLX_STEREO, YES);
	  break;
	case NSOpenGLPFAAuxBuffers:
	  ptr++;
	  append(GLX_AUX_BUFFERS, *ptr);
	  break;
	case NSOpenGLPFAColorSize:
	  ptr++;
	  append(GLX_RED_SIZE, *ptr);
	  append(GLX_GREEN_SIZE, *ptr);
	  append(GLX_BLUE_SIZE, *ptr);
	  break;
	case NSOpenGLPFAAlphaSize:
	  ptr++;
	  append(GLX_ALPHA_SIZE, *ptr);
	  break;
	case NSOpenGLPFADepthSize:
	  ptr++;
	  append(GLX_DEPTH_SIZE, *ptr);
	  break;
	case NSOpenGLPFAStencilSize:
	  ptr++;
	  append(GLX_STENCIL_SIZE, *ptr);
	  break;
	case NSOpenGLPFAAccumSize:
	  ptr++;
	  //FIXME?  I don't understand...
	  append(GLX_ACCUM_RED_SIZE, *ptr/3);
	  append(GLX_ACCUM_GREEN_SIZE, *ptr/3);
	  append(GLX_ACCUM_BLUE_SIZE, *ptr/3);
	  break;
	case NSOpenGLPFAMinimumPolicy:
	  //FIXME
	  break;
	case NSOpenGLPFAMaximumPolicy:
	  //FIXME	
	  break;

	  //FIXME all of this stuff...
	case NSOpenGLPFAOffScreen:
	case NSOpenGLPFAFullScreen:
	case NSOpenGLPFASampleBuffers:
	case NSOpenGLPFASamples:
	case NSOpenGLPFAAuxDepthStencil:
	case NSOpenGLPFARendererID:
	case NSOpenGLPFASingleRenderer:
	case NSOpenGLPFANoRecovery:
	case NSOpenGLPFAAccelerated:
	case NSOpenGLPFAClosestPolicy:
	case NSOpenGLPFARobust:
	case NSOpenGLPFABackingStore:
	case NSOpenGLPFAMPSafe:
	case NSOpenGLPFAWindow:
	case NSOpenGLPFAMultiScreen:
	case NSOpenGLPFACompliant:
	case NSOpenGLPFAScreenMask:
	case NSOpenGLPFAVirtualScreenCount:
	  break;
	}

      ptr ++;
    }

  append1(None);

  //FIXME, what screen number ?
  if (GSglxMinorVersion (dpy) >= 3)
    conf.tab = glXChooseFBConfig(dpy, DefaultScreen(dpy), [data mutableBytes],
				 &n_elem);
  else
    conf.visual = glXChooseVisual(dpy, DefaultScreen(dpy),
				  [data mutableBytes]);
  
  if ( ((GSglxMinorVersion (dpy) >= 3) 
	? (void *)conf.tab : (void *)conf.visual)
       == NULL )
    {
      NSDebugMLLog(@"GLX", @"no pixel format found matching what is required");
      RELEASE(self);
      return nil;
    }
  else
    {
      
      NSDebugMLLog(@"GLX", @"We found %d pixel formats", n_elem);
#if 0
      if (GSglxMinorVersion (dpy) >= 3)
	{	
	  int i;
	  for (i = 0; i < n_elem; ++i )
	    {
	      int val;
	      NSDebugMLLog(@"GLX", @"inspecting %dth", i+1);
	      glXGetFBConfigAttrib(dpy, conf.tab[i], GLX_BUFFER_SIZE, &val);
	      NSDebugMLLog(@"GLX", @"buffer size %d", val);
	      
	      
	      glXGetFBConfigAttrib(dpy, conf.tab[i], GLX_DOUBLEBUFFER, &val);
	      NSDebugMLLog(@"GLX", @"double buffer %d", val);
	      
	      glXGetFBConfigAttrib(dpy, conf.tab[i], GLX_DEPTH_SIZE, &val);
	      NSDebugMLLog(@"GLX", @"depth size %d", val);
	      
	    }
	}
      else
	{
	  glXGetConfig(dpy, conf.visual, GLX_BUFFER_SIZE, &val);
	  NSDebugMLLog(@"GLX", @"buffer size %d", val);
	  
	  
	  glXGetConfig(dpy, conf.visual, GLX_DOUBLEBUFFER, &val);
	  NSDebugMLLog(@"GLX", @"double buffer %d", val);
	  
	  glXGetConfig(dpy, conf.visual, GLX_DEPTH_SIZE, &val);
	  NSDebugMLLog(@"GLX", @"depth size %d", val);
	}
#endif      
      return self;
    }
}

- (void) dealloc
{
  //FIXME 	
  //are we sure that X Connection is still up here ?
  MAKE_DISPLAY(dpy);
  if (GSglxMinorVersion (dpy) >= 3)
    XFree (conf.tab);
  else
    XFree (conf.visual);
  NSDebugMLLog(@"GLX", @"deallocation");
  [super dealloc];
}

- (int)numberOfVirtualScreens
{
  //  [self notImplemented: _cmd];
  //FIXME
  //This looks like a reasonable value to return...
  return 1;
}

@end
#endif
