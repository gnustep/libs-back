/* XIMInputServer - XIM Keyboard input handling

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Christian Gillot <cgillot@neo-rousseaux.org>
   Date: Nov 2001
   Author: Adam Fedor <fedor@gnu.org>
   Date: Jan 2002

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#include "config.h"

#include <Foundation/NSData.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <base/Unicode.h>
#include <AppKit/NSWindow.h>
#include <AppKit/GSFontInfo.h>

#include "x11/XGInputServer.h"
#include <X11/Xlocale.h>


@interface XIMInputServer (XIMPrivate)
- (BOOL) ximInit: (Display *)dpy;
- (void) ximClose;
- (int) ximStyleInit;
- (XIC) ximCreateIC: (Window)w;
- (unsigned long) ximXicGetMask: (XIC)xic;
@end

#define BUF_LEN 255

@implementation XIMInputServer

- (id) initWithDelegate: (id)aDelegate
		   name: (NSString *)name
{
  Display *dpy = [XGServer currentXDisplay];
  return [self initWithDelegate: aDelegate display: dpy name: name];
}

- (id) initWithDelegate: (id)aDelegate
		display: (Display *)dpy
		   name: (NSString *)name
{
  char *locale;
  delegate = aDelegate;
  ASSIGN(server_name, name);
  dbuf = RETAIN([NSMutableData dataWithCapacity: BUF_LEN]);

  /* Use X11 version of setlocale since many people just set the locale
     for X. Also just get CTYPE locale (which is typically the one that
     deals with character handling */
  locale = setlocale(LC_CTYPE, "");
  if (XSupportsLocale() != True) 
    {
      NSLog(@"Xlib does not support locale setting %s", locale);
      /* FIXME: Should we reset the locale or just hope that X 
	 can deal with it? */
    }
  encoding = GSEncodingFromLocale(locale);
#ifndef HAVE_UTF8
  if (encoding == NSUTF8StringEncoding)
    encoding = GSUndefinedEncoding;
#endif
  if (encoding == GSUndefinedEncoding)
    {
      encoding = [NSString defaultCStringEncoding];
    }
  NSDebugLLog(@"XIM", @"XIM locale encoding for %s is %@", locale,
	      GetEncodingName(encoding));

#ifdef USE_XIM
  if ([self ximInit: dpy] == NO)
    {
      NSLog(@"Unable to initialize XIM, using standard keyboard events");
    }
#endif
  return self;
}

- (void) dealloc
{
  DESTROY(server_name);
  DESTROY(dbuf);
  [self ximClose];
  [super dealloc];
}

/* ----------------------------------------------------------------------
   XInputFiltering protocol methods
*/
- (BOOL) filterEvent: (XEvent *)event
{
  if (XFilterEvent(event, None)) 
    {
      NSDebugLLog(@"NSKeyEvent", @"Event filtered by XIM\n");
      return YES;
    }
  return NO;
}

- (NSString *) lookupStringForEvent: (XKeyEvent *)event 
			     window: (gswindow_device_t *)windev
			     keysym: (KeySym *)keysymptr
{
  int count;
  Status status;
  NSString *keys;
  KeySym   keysym;
  XComposeStatus compose;
  char *buf = [dbuf mutableBytes];

  /* Process characters */
  keys = nil;
  if (windev->ic && event->type == KeyPress)
    {
      [dbuf setLength: BUF_LEN];
#ifdef HAVE_UTF8
      if (encoding == NSUTF8StringEncoding)
        count = Xutf8LookupString(windev->ic, event, buf, BUF_LEN, 
      		                  &keysym, &status);
      else 
#endif
        count = XmbLookupString(windev->ic, event, buf, BUF_LEN, 
			        &keysym, &status);

      if (status==XBufferOverflow)
	NSDebugLLog(@"NSKeyEvent",@"XmbLookupString buffer overflow\n");
      if (count)
	{
	  [dbuf setLength: count];
	  keys = [[NSString alloc] initWithData: dbuf encoding: encoding];
	}
    }
  else 
    {
      count = XLookupString (event, buf, BUF_LEN, &keysym, &compose);
      /* Make sure that the string is properly terminated */
      if (count > BUF_LEN)
	buf[BUF_LEN] = '\0';
      else
	{
	  if (count < 1) 
	    buf[0] = '\0';
	  else           
	    buf[count] = '\0';
	}
      if (count)
	keys = [NSString stringWithCString: buf];
    }

  if (keysymptr)
    *keysymptr = keysym;

  return keys;
}

/* ----------------------------------------------------------------------
   NSInputServiceProvider protocol methods
*/
- (void) activeConversationChanged: (id)sender
		 toNewConversation: (long)newConversation
{
  NSWindow *window;
  gswindow_device_t *windev;

  [super activeConversationChanged: sender
	         toNewConversation: newConversation];

  if ([sender respondsToSelector: @selector(window)] == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTextInput sender does not respond to window"];
    }
  window = [sender window];
  windev = [XGServer _windowWithTag: [window windowNumber]];
  if (windev == NULL)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTextInput sender has invalid window"];
    }

  [self ximFocusICWindow: windev];
}

- (void) activeConversationWillChange: (id)sender
		  fromOldConversation: (long)oldConversation
{
  [super activeConversationWillChange: sender
	          fromOldConversation: oldConversation];
}

/* ----------------------------------------------------------------------
   XIM private methods
*/
- (BOOL) ximInit: (Display *)dpy
{
  XClassHint class_hints;

  if (!XSetLocaleModifiers (""))
    NSDebugLLog(@"XIM", @"can not set locale modifiers\n");

  /* FIXME: Get these */
  class_hints.res_name = class_hints.res_class = NULL;
  xim = XOpenIM(dpy, NULL, class_hints.res_name, class_hints.res_class);
  if (xim == NULL) 
    {
      NSDebugLLog(@"XIM", @"Can't open XIM.\n");
      return NO;
    }

  if (![self ximStyleInit])
    {
      [self ximClose];
      return NO;
    }

  NSDebugLLog(@"XIM", @"Initialized XIM\n");
  return YES;
}

- (int) ximStyleInit
{
  /* FIXME: Right now we only support this style *but*
     this is only temporary */
  XIMStyle xim_supported_style=XIMPreeditNothing|XIMStatusNothing;
  XIMStyles *styles;
  char *failed_arg;
  int i;

  failed_arg = XGetIMValues(xim,XNQueryInputStyle,&styles,NULL);
  if (failed_arg!=NULL)
    {
      NSDebugLLog(@"XIM", @"Can't getting the following IM value :%s",
		  failed_arg);
      return 0;
    } 

  for (i=0;i<styles->count_styles;i++)
    {
      if (styles->supported_styles[i]==xim_supported_style)
	{
	  xim_style=xim_supported_style;
	  XFree(styles);
	  return 1;
	}
    }

  XFree(styles);
  return 0;
}

- (void) ximClose
{
  int i;
  for (i=0;i<num_xics;i++)
    {
      XDestroyIC(xics[i]);
    }
  free(xics);
  num_xics=0;
  xics=NULL;

  NSDebugLLog(@"XIM", @"Closed XIM\n");

  if (xim)
    XCloseIM(xim);
  xim=NULL;
}

- (void) ximFocusICWindow: (gswindow_device_t *)windev
{
  if (xim == NULL)
    return;

  /* Make sure we have an ic for this window */
#ifdef USE_XIM
  if (windev->ic == NULL)
    {
      windev->ic = [self ximCreateIC: windev->ident];
      if (windev->ic == NULL) 
	{
	  [self ximClose];
	}
    }
#endif
  
  /* Now set focus to this window */
  if (windev->ic)
    {
      NSDebugLLog(@"XIM", @"XSetICFocus to window %p", 
		  windev->ident);
      XSetICFocus(windev->ic);
    }
}

- (XIC) ximCreateIC: (Window)w
{
  XIC xic;
  xic = XCreateIC(xim, XNClientWindow, w, XNInputStyle,
		  xim_style, NULL);
  if (xic==NULL)
    NSDebugLLog(@"XIM", @"Can't create the input context.\n");

  xics = realloc(xics, sizeof(XIC) * (num_xics + 1));
  xics[num_xics++] = xic;
  return xic;
}

- (unsigned long) ximXicGetMask: (XIC)xic
{
  unsigned long xic_xmask = 0;
  if (XGetICValues(xic,XNFilterEvents,&xic_xmask,NULL)!=NULL)
    NSDebugLLog(@"XIM", @"Can't get the event mask for that input context");

  return xic_xmask;
}

- (void) ximCloseIC: (XIC)xic
{
  int i;
  for (i = 0; i < num_xics; i++)
    {
      if (xics[i] == xic)
        break;
    }
  if (i == num_xics)
    {
      NSLog(@"internal error in ximCloseIC: can't find XIC in list");
      abort();
    }
  for (i++; i < num_xics; i++)
    xics[i - 1] = xics[i];
  num_xics--;

  XDestroyIC(xic);
}

@end
