/* WIN32Server - Implements window handling for MSWindows

   Copyright (C) 2002,2005 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   Part of this code have been re-written by: 
   Tom MacSween <macsweent@sympatico.ca>
   Date August 2005
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */

#include "config.h"
#include <Foundation/NSDebug.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSException.h>
#include <AppKit/AppKitExceptions.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSText.h>
#include <AppKit/NSTextField.h>
#include <AppKit/DPSOperators.h>

#include "win32/WIN32Server.h"
#include "win32/WIN32Geometry.h"
#ifdef HAVE_WGL
#include "win32/WIN32OpenGL.h"
#endif 
#include "w32_config.h"

#ifdef __CYGWIN__
#include <sys/file.h>
#endif
static NSString * Version =@"(C) 2005 FSF gnustep-back 0.10.1";
// custom event notifications
static NSString *NSMenuWillTearOff = @"MenuWillTearOff";
static NSString *NSMenuwillPopUP =@"MenuwillPopUP";
static NSString *NSWindowDidCreateWindow =@"WindowDidCreateWindow";

static NSEvent *process_key_event(WIN32Server *svr,
  HWND hwnd, WPARAM wParam, LPARAM lParam, NSEventType eventType);
static NSEvent *process_mouse_event(WIN32Server *svr,
  HWND hwnd, WPARAM wParam, LPARAM lParam, NSEventType eventType);

//static BOOL HAVE_MAIN_MENU = NO;
static BOOL handlesWindowDecorations = NO;

static void 
validateWindow(WIN32Server *svr, HWND hwnd, RECT rect);
LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg,
			     WPARAM wParam, LPARAM lParam);

@implementation WIN32Server

// server opts

- (void) callback: (id) sender

{
  MSG msg;
  WINBOOL bRet; 

  while ((bRet = PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) != 0)
    { 
      if (msg.message == WM_QUIT)
	{
	  // Exit the program
	  return;
	}
      if (bRet == -1)
	{
	  // handle the error and possibly exit
	}
      else
	{
	  // Don't translate messages, as this would give extra character messages.
	  DispatchMessage(&msg); 
	} 
    } 
}

- (BOOL) hasEvent
{
  return (GetQueueStatus(QS_ALLEVENTS) != 0);
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
  if (type == ET_WINMSG)
    {
      MSG	*m = (MSG*)extra;

      if (m->message == WM_QUIT)
	{
	  [NSApp terminate: nil];
	  // Exit the program
	  return;
	}
      else
	{
	  DispatchMessage(m); 
	} 
    } 
  if (mode != nil)
    [self callback: mode];
}


- (NSEvent*) getEventMatchingMask: (unsigned)mask
		       beforeDate: (NSDate*)limit
			   inMode: (NSString*)mode
			  dequeue: (BOOL)flag
{
  [self callback: nil];
#ifdef __W32_debug_Event_loop 
  NSEvent * theEvent = [super getEventMatchingMask: mask
		beforeDate: limit
		inMode: mode
		dequeue: flag];
		
	printf("Got EventType %d\n",[theEvent type]);
    return theEvent;	
#else

  return [super getEventMatchingMask: mask
		beforeDate: limit
		inMode: mode
		dequeue: flag];
#endif
}

- (void) discardEventsMatchingMask: (unsigned)mask
		       beforeEvent: (NSEvent*)limit
{
  [self callback: nil];
  [super discardEventsMatchingMask: mask
			  beforeEvent: limit];
}


// server 

/* Initialize AppKit backend */
+ (void)initializeBackend
{

#ifdef __debugServer__
printf("\n\n##############################################################\n");  
printf("##############  + (void)initializeBackend ##########################\n");
printf("\n\n##############################################################\n");
#endif 

  NSUserDefaults	*defs;

  NSDebugLog(@"Initializing GNUstep win32 backend.\n");
  defs = [NSUserDefaults standardUserDefaults];
  if ([defs objectForKey: @"GSBackHandlesWindowDecorations"])
    {
      handlesWindowDecorations =
	[defs boolForKey: @"GSBackHandlesWindowDecorations"];
    }
  else
    {
      if ([defs objectForKey: @"GSWIN32HandlesWindowDecorations"])
	{
	  handlesWindowDecorations =
	    [defs boolForKey: @"GSWINHandlesWindowDecorations"];
	}
    }
  [GSDisplayServer setDefaultServerClass: [WIN32Server class]];
  //Flag to handle main menu window type -- parent of other menu windows 
}

- (void) _initWin32Context
{

#ifdef __debugServer__
printf("\n\n##############################################################\n");  
printf("############## - (void) _initWin32Context ##########################\n");
printf("\n\n##############################################################\n");
#endif
  WNDCLASSEX wc; 
  hinstance = (HINSTANCE)GetModuleHandle(NULL);


  // Register the main window class. 
  wc.cbSize = sizeof(wc);          
  //wc.style = CS_OWNDC; // | CS_HREDRAW | CS_VREDRAW; 
  wc.style = CS_HREDRAW | CS_VREDRAW; 
  wc.lpfnWndProc = (WNDPROC) MainWndProc; 
  wc.cbClsExtra = 0; 
  // Keep extra space for each window, for GS data
  wc.cbWndExtra = sizeof(WIN_INTERN); 
  wc.hInstance = hinstance; 
  wc.hIcon = NULL;//currentAppIcon;
  wc.hCursor = LoadCursor(NULL, IDC_ARROW);
  wc.hbrBackground = GetStockObject(WHITE_BRUSH); 
  wc.lpszMenuName =  NULL; 
  wc.lpszClassName = "GNUstepWindowClass"; 
  wc.hIconSm = NULL;//currentAppIcon;

  if (!RegisterClassEx(&wc)) 
       return; 

  // FIXME We should use GetSysColor to get standard colours from MS Window and 
  // use them in NSColor

  // Should we create a message only window here, so we can get events, even when
  // no windows are created?
}

- (void) setupRunLoopInputSourcesForMode: (NSString*)mode
{
  NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];

#ifdef __debugServer__
printf("\n\n##############################################################\n");  
printf("##- (void) setupRunLoopInputSourcesForMode: (NSString*)mode #######\n");
printf("\n\n##############################################################\n");
#endif

#ifdef    __CYGWIN__
  int fdMessageQueue;
#define WIN_MSG_QUEUE_FNAME    "/dev/windows"

  // Open a file descriptor for the windows message queue
  fdMessageQueue = open (WIN_MSG_QUEUE_FNAME, O_RDONLY);
  if (fdMessageQueue == -1)
    {
      NSLog(@"Failed opening %s\n", WIN_MSG_QUEUE_FNAME);
      exit(1);
    }
  [currentRunLoop addEvent: (void*)fdMessageQueue
                  type: ET_RDESC
                  watcher: (id<RunLoopEvents>)self
                  forMode: mode];
#else 
#if 0
  NSTimer *timer;

  timer = [NSTimer timerWithTimeInterval: 0.01
		   target: self
		   selector: @selector(callback:)
		   userInfo: nil
		   repeats: YES];
  [currentRunLoop addTimer: timer forMode: mode];
#else

/* OBSOLETE
  [currentRunLoop addMsgTarget: self
			withMethod: @selector(callback:)
			   forMode: mode];
*/
  [currentRunLoop addEvent: (void*)0
                  type: ET_WINMSG
                  watcher: (id<RunLoopEvents>)self
                  forMode: mode];
#endif
#endif
}

/**

*/
- (id) initWithAttributes: (NSDictionary *)info
{
#ifdef __debugServer__
printf("\n\n##############################################################\n");  
printf("##initWithAttributes: (NSDictionary *)info #######\n");
printf("\n\n##############################################################\n");
#endif
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];      
  
  [self _initWin32Context];
  [super initWithAttributes: info];

  [self setupRunLoopInputSourcesForMode: NSDefaultRunLoopMode]; 
  [self setupRunLoopInputSourcesForMode: NSConnectionReplyMode]; 
  [self setupRunLoopInputSourcesForMode: NSModalPanelRunLoopMode]; 
  [self setupRunLoopInputSourcesForMode: NSEventTrackingRunLoopMode]; 

  //flags.useWMTaskBar = YES;
  //flags.useWMStyles = YES;
  
  if ([[NSUserDefaults standardUserDefaults] stringForKey: @"GSUseWMTaskbar"]
    != nil)
    {
      flags.useWMTaskBar = [[NSUserDefaults standardUserDefaults] 
                                boolForKey: @"GSUseWMTaskbar"];
      flags.HAVE_SERVER_PREFS = YES; 
    }
  else
    {
       flags.HAVE_SERVER_PREFS = NO;
    }
    
  if ([[NSUserDefaults standardUserDefaults] stringForKey: @"GSUseWMStyles"]
    != nil)
    {
      flags.useWMStyles = [[NSUserDefaults standardUserDefaults] 
                                boolForKey: @"GSUseWMStyles"];
      flags.HAVE_SERVER_PREFS = YES;  
    }
  else
    {
      flags.HAVE_SERVER_PREFS = NO;
    }
    
  if (flags.useWMStyles == YES)
    {
      handlesWindowDecorations = YES;
    }
   
   /* the backend needs to be able to keep tabs on events that
    * are only produced by GNUstep so that it can make changes
    * or override behavior in favor of the real platform window server
    */ 
  [nc addObserver: self
	  selector: @selector(ApplicationDidFinishLaunching:)
	  name: NSApplicationDidFinishLaunchingNotification
	  object: nil];
	  
  [nc addObserver: self
	  selector: @selector(ApplicationWillFinishLaunching:)
	  name: NSApplicationWillFinishLaunchingNotification
	  object: nil];
	
  [nc addObserver: self
	  selector: @selector(ApplicationWillHideNotification:)
	  name: NSApplicationWillHideNotification
	  object: nil];
	  
  [nc addObserver: self
	  selector: @selector(WindowWillMiniaturizeNotification:)
	  name: NSWindowWillMiniaturizeNotification
	  object: nil];
	 
  // register for custom notifications
  [nc addObserver: self
	  selector: @selector(MenuWillTearOff:)
	  name: NSMenuWillTearOff
	  object: nil];
      
  [nc addObserver: self
	  selector: @selector(MenuwillPopUP:)
	  name: NSMenuwillPopUP
	  object: nil];
	  
  [nc addObserver: self
	 selector: @selector(WindowDidCreateWindow:)
	 name: NSWindowDidCreateWindow
	 object: nil];
	  
#ifdef __APPNOTIFICATIONS__
  [self registerForWindowEvents];
  [self registerForViewEvents];
#endif
  flags.eventQueCount =0;
	  
  return self;
}

//  required Notification hooks back to the application

- (void) ApplicationDidFinishLaunching: (NSNotification*)aNotification
{
  [self subclassResponsibility: _cmd];
}

- (void) ApplicationWillFinishLaunching: (NSNotification*)aNotification
{
  [self subclassResponsibility: _cmd];
}

- (void) ApplicationWillHideNotification: (NSNotification*)aNotification
{
  [self subclassResponsibility: _cmd];
}

-(void) WindowWillMiniaturizeNotification: (NSNotification*)aNotification
{
  [self subclassResponsibility: _cmd];
}

-(void) MenuWillTearOff: (NSNotification*)aNotification
{
  [self subclassResponsibility: _cmd];
}

-(void) MenuwillPopUP: (NSNotification*)aNotification
{
  [self subclassResponsibility: _cmd];
}

// make a configure window for the backend
/* win32 is unique in that it can support both the win32 look and feel or
a openstep look and feel.

To make it easier to switch between the 2 I have added a small server inspector 
panel that will provide access to settings without recompile.

If main debug feature is on then I can also add access to some of the switches
to control debug output... or log specific event to a log panel.
*/
- (void) initConfigWindow
{
  unsigned int style = NSTitledWindowMask | NSClosableWindowMask;
  NSRect       rect;
  NSView      *content;
  NSTextField *theText;
  NSTextField *theText2;

  rect = NSMakeRect (715,800,236,182);
  configWindow = RETAIN([[NSWindow alloc] initWithContentRect: rect
                                              styleMask: style
                                                backing: NSBackingStoreBuffered
                                                  defer: YES]);
  [configWindow setTitle: @"server Preferences"];
  [configWindow setReleasedWhenClosed: NO];

  content = [configWindow contentView];
  theText = [[NSTextField alloc] initWithFrame: NSMakeRect (27,155,190,22)];
  [theText setStringValue: @"Win32 GNUStep Display Server"];
  [theText setEditable: NO];
  [theText setEnabled: NO];
  [theText setSelectable: NO];
  [[theText cell] setBackgroundColor: [NSColor lightGrayColor]];
  [[theText cell] setBordered: NO];
  [[theText cell] setBezeled: NO];
  [content addSubview: theText];
   
  /*
  NSTextField *theText1;

  theText1 = [[NSTextField alloc] initWithFrame: NSMakeRect (27,135,190,22)];
  [theText1 setStringValue: @"Revitalized By Tom MacSween"];
  [theText1 setEditable: NO];
  [theText1 setEnabled: NO];
  [theText1 setSelectable: NO];
  [[theText1 cell] setBackgroundColor: [NSColor lightGrayColor]];
  [[theText1 cell] setBordered: NO];
  [[theText1 cell] setBezeled: NO];
  [content addSubview: theText1];*/
   
  theText2 = [[NSTextField alloc] initWithFrame: NSMakeRect (17,115,200,22)];
  [theText2 setStringValue: Version];
  [theText2 setEditable: NO];
  [theText2 setEnabled: NO];
  [theText2 setSelectable: NO];
  [[theText2 cell] setBackgroundColor: [NSColor lightGrayColor]];
  [[theText2 cell] setBordered: NO];
  [[theText2 cell] setBezeled: NO];
  [content addSubview: theText2];
   
   // popup for style
  styleButton
    = [[NSPopUpButton  alloc] initWithFrame: NSMakeRect (30,80,171,22)];
  [styleButton setAutoenablesItems: YES];
  [styleButton setTarget: self];
  [styleButton setAction: @selector(setStyle:)];
  [styleButton setTitle: @"Select window Style"];
  [styleButton addItemWithTitle: @"GNUStep window Style"];
  [styleButton addItemWithTitle: @"MicroSoft window Style"];
  [content addSubview: styleButton];
   
  // set the tags on the items
  [[styleButton itemAtIndex: 0] setTag: 0];
  [[styleButton itemAtIndex: 1] setTag: 1];
  [[styleButton itemAtIndex: 2] setTag: 2];
  
  
  // check box for using taskbar
  taskbarButton = [[NSButton  alloc] initWithFrame: NSMakeRect (30,55,171,22)];
  [taskbarButton setButtonType: NSSwitchButton];
  [taskbarButton setTitle: @"Use Win Taskbar"];
  [taskbarButton setTarget: self];
  [taskbarButton setAction: @selector(setTaskBar:)];
  [content addSubview: taskbarButton];
  // save to defaults
  saveButton = [[NSButton  alloc] initWithFrame: NSMakeRect (30,25,171,22)];
  [saveButton setButtonType: NSMomentaryPushInButton];
  [saveButton setTitle: @"Save to defaults"];
  [saveButton setTarget: self];
  [saveButton setAction: @selector(setSave:)];
  [content addSubview: saveButton];
  [saveButton setEnabled: NO];


   // set the buttons to match the current state
  if (flags.useWMStyles == YES)
    [styleButton selectItemAtIndex: 2];
  else
    [styleButton selectItemAtIndex: 1];
    
  if (flags.useWMTaskBar == YES)
    [taskbarButton setState: NSOnState];
  else
    [taskbarButton setState: NSOffState]; 
}
   
 // config window actions
      
- (void) setStyle: (id)sender
{
  //defaults key: GSUseWMStyles
  // code flag: flags.useWMStyles
  [saveButton setEnabled: YES];
    
  if ([[sender selectedItem] tag] > 1)
    {
      flags.useWMStyles = YES;
      flags.useWMTaskBar = YES;
      [taskbarButton setState: NSOnState];
    }
  else
    {
      flags.useWMStyles = NO;
      flags.useWMTaskBar = NO;
      [taskbarButton setState: NSOffState];
    }
}

- (void) setTaskBar: (id)sender
{
  //defaults key: GSUseWMTaskbar
  // code flag: flags.useWMTaskBar
  [saveButton setEnabled: YES];
  flags.useWMTaskBar = [sender state];
}

- (void) setSave: (id)sender
{
  NSString *theValue = @"NO";
   //NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
   //printf("Save to defaults\n");
  if (flags.useWMTaskBar == YES)
    theValue = @"YES";
        
  [[NSUserDefaults standardUserDefaults] 
    setObject: theValue forKey: @"GSUseWMTaskbar"];
        
  theValue = @"NO";
  if (flags.useWMStyles == YES)
    theValue = @"YES";
        
  [[NSUserDefaults standardUserDefaults] 
     setObject: theValue forKey: @"GSUseWMStyles"];
    
    // user must restart application for changes
    
  NSRunInformationalAlertPanel(@"Server Preferences Changed",
                     @"Changes will take affect on the next restart",
                      @"OK",nil, nil);
  flags.HAVE_SERVER_PREFS = YES;
  [configWindow close];
  [saveButton setEnabled: NO];
  [[NSUserDefaults standardUserDefaults] synchronize]; 
}

- (void) showServerPrefs: (id)sender
{
  [configWindow makeKeyAndOrderFront: self];
}

/* 

 when debug is active (#define __W32_debug__) the following
 additional notifications are registered for in the backend server.
 Helps to show where appevents and server
 events are happening relitive to each other


NSWindowDidBecomeKeyNotification
    Posted whenever an NSWindow becomes the key window.
    The notification object is the NSWindow that has become key.
    This notification does not contain a userInfo dictionary.

NSWindowDidBecomeMainNotification
    Posted whenever an NSWindow becomes the main window.
    The notification object is the NSWindow that has become main.
    This notification does not contain a userInfo dictionary.
    
NSWindowDidChangeScreenNotification
    Posted whenever a portion of an NSWindow’s frame moves onto
    or off of a screen.
    The notification object is the NSWindow that has changed screens.
    This notification does not contain a userInfo dictionary.
    This notification is not sent in Mac OS X versions earlier than 10.4.

NSWindowDidChangeScreenProfileNotification
    Posted whenever the display profile for the screen containing the window 
    changes.
    This notification is sent only if the window returns YES from
    displaysWhenScreenProfileChanges. This notification may be sent
    when a majority of the window is moved to a different screen
    (whose profile is also different from the previous screen) or when
    the ColorSync profile for the current screen changes.  The
    notification object is the NSWindow whose profile changed. This
    notification does not contain a userInfo dictionary.


NSWindowDidDeminiaturizeNotification
    Posted whenever an NSWindow is deminiaturized.
    The notification object is the NSWindow that has been deminiaturized. This 
    notification does not contain a userInfo dictionary.

NSWindowDidEndSheetNotification
    Posted whenever an NSWindow closes an attached sheet.
    The notification object is the NSWindow that contained the sheet. This 
    notification does not contain a userInfo dictionary.

NSWindowDidExposeNotification
    Posted whenever a portion of a nonretained NSWindow is exposed,
    whether by being ordered in front of other windows or by other
    windows being removed from in front of it.  The notification
    object is the NSWindow that has been exposed. The userInfo
    dictionary contains the following information: Key
    @"NSExposedRect" Value The rectangle that has been exposed
    (NSValue containing an NSRect).

NSWindowDidMiniaturizeNotification
    Posted whenever an NSWindow is miniaturized.
    The notification object is the NSWindow that has been miniaturized. This 
    notification does not contain a userInfo dictionary.
    
NSWindowDidMoveNotification
    Posted whenever an NSWindow is moved.
    The notification object is the NSWindow that has moved. This
    notification does not contain a userInfo dictionary.

NSWindowDidResignKeyNotification
    Posted whenever an NSWindow resigns its status as key window.
    The notification object is the NSWindow that has resigned its key window 
    status. This notification does not contain a userInfo dictionary.
    
NSWindowDidResignMainNotification
    Posted whenever an NSWindow resigns its status as main window.
    The notification object is the NSWindow that has resigned its main window 
    status. This notification does not contain a userInfo dictionary.

NSWindowDidResizeNotification
    Posted whenever an NSWindow’s size changes.
    The notification object is the NSWindow whose size has changed. This 
    notification does not contain a userInfo dictionary.

NSWindowDidUpdateNotification
    Posted whenever an NSWindow receives an update message.
    The notification object is the NSWindow that received the update
    message. This notification does not contain a userInfo dictionary.

NSWindowWillBeginSheetNotification
    Posted whenever an NSWindow is about to open a sheet.
    The notification object is the NSWindow that is about to open the
    sheet. This notification does not contain a userInfo dictionary.

NSWindowWillCloseNotification
    Posted whenever an NSWindow is about to close.
    The notification object is the NSWindow that is about to close. This 
    notification does not contain a userInfo dictionary.

NSWindowWillMiniaturizeNotification
    Posted whenever an NSWindow is about to be miniaturized.
    The notification object is the NSWindow that is about to be
    miniaturized. This notification does not contain a userInfo
    dictionary.

NSWindowWillMoveNotification
    Posted whenever an NSWindow is about to move.
    The notification object is the NSWindow that is about to move. This 
    notification does not contain a userInfo dictionary.  
*/

- (void) registerForWindowEvents
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
        
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidDeminiaturizeNotification
	   object: nil];
	  
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidMiniaturizeNotification
	   object: nil];
	  
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidBecomeKeyNotification
	   object: nil];
	  
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidBecomeMainNotification
	   object: nil]; 

  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidChangeScreenNotification
	   object: nil];
    
  /*
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidChangeScreenProfileNotification
	   object: nil];
  */

  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidExposeNotification
	   object: nil];

  /*
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidEndSheetNotification
	   object: nil];
  */
	  
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidMoveNotification
	   object: nil];

  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidResignKeyNotification
	   object: nil];
	  
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidResignMainNotification
	   object: nil];
	  
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidResizeNotification
	   object: nil];
	  
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowDidUpdateNotification
	   object: nil];

  /*
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowWillBeginSheetNotification
	   object: nil];
  */
    
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowWillCloseNotification
	   object: nil];

  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSWindowWillMoveNotification
	   object: nil];    
}

/*
NSViewBoundsDidChangeNotification
    Posted whenever the NSView’s bounds rectangle changes
    independently of the frame rectangle, if the NSView is configured
    using setPostsBoundsChangedNotifications: to post such
    notifications.  The notification object is the NSView whose bounds
    rectangle has changed. This notification does not contain a
    userInfo dictionary.  The following methods can result in
    notification posting: 

        setBounds: 
        setBoundsOrigin: 
        setBoundsRotation: 
        setBoundsSize: 
        translateOriginToPoint: 
        scaleUnitSquareToSize: 
        rotateByAngle: 

    Note that the bounds rectangle resizes automatically to track the
    frame rectangle. Because the primary change is that of the frame
    rectangle, however, setFrame: and setFrameSize: don’t result in
    a bounds-changed notification.

    
NSViewFocusDidChangeNotification
    Deprecated notification that was posted for an NSView and each of
    its descendents (recursively) whenever the frame or bounds
    geometry of the view changed.  
*/
- (void) registerForViewEvents
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
        
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSViewBoundsDidChangeNotification
	   object: nil];

  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: NSViewFocusDidChangeNotification
	   object: nil];
}


- (void) _destroyWin32Context
{

#ifdef __debugServer__
printf("\n\n##############################################################\n");  
printf("- (void) _destroyWin32Context\n");
printf("\n\n##############################################################\n");
#endif

  UnregisterClass("GNUstepWindowClass", hinstance);
}

/**

*/
- (void) dealloc
{

#ifdef __debugServer__
printf("\n\n##############################################################\n");  
printf("- (void) dealloc\n");
printf("\n\n##############################################################\n");
#endif
  [self _destroyWin32Context];
  [super dealloc];
}

- (void) restrictWindow: (int)win toImage: (NSImage*)image
{
    #ifdef __debugServer__
printf("\n\n##############################################################\n");  
printf("restrictWindow\n");
printf("\n\n##############################################################\n");
#endif

  //[self subclassResponsibility: _cmd];
}

- (int) findWindowAt: (NSPoint)screenLocation 
           windowRef: (int*)windowRef 
           excluding: (int)win
{
  HWND hwnd;
  POINT p;

  p = GSScreenPointToMS(screenLocation);
  hwnd = WindowFromPoint(p);
  if ((int)hwnd == win)
    {
      /*
       * If the window at the point we want is excluded,
       * we must look through ALL windows at a lower level
       * until we find one which contains the same point.
       */
      while (hwnd != 0)
	{
	  RECT	r;

	  hwnd = GetWindow(hwnd, GW_HWNDNEXT);
	  GetWindowRect(hwnd, &r);
	  if (PtInRect(&r, p) && IsWindowVisible(hwnd))
	    {
	      break;
	    }
	}
    }

  *windowRef = (int)hwnd;	// Any windows

  return (int)hwnd;
}

// FIXME: The following methods wont work for multiple screens
/* Screen information */
- (NSSize) resolutionForScreen: (int)screen
{
  int xres, yres;
  HDC hdc;

  hdc = GetDC(NULL);
  xres = GetDeviceCaps(hdc, LOGPIXELSX);
  yres = GetDeviceCaps(hdc, LOGPIXELSY);
  ReleaseDC(NULL, hdc);
  
  return NSMakeSize(xres, yres);
}

- (NSRect) boundsForScreen: (int)screen
{
  return NSMakeRect(0, 0, GetSystemMetrics(SM_CXSCREEN), 
		    GetSystemMetrics(SM_CYSCREEN));
}

- (NSWindowDepth) windowDepthForScreen: (int)screen
{
  HDC hdc;
  int bits;
  //int planes;
      
  hdc = GetDC(NULL);
  bits = GetDeviceCaps(hdc, BITSPIXEL) / 3;
  //planes = GetDeviceCaps(hdc, PLANES);
  //NSLog(@"bits %d planes %d", bits, planes);
  ReleaseDC(NULL, hdc);
  
  return (_GSRGBBitValue | bits);
}

- (const NSWindowDepth *) availableDepthsForScreen: (int)screen
{
  int		 ndepths = 1;
  NSZone	*defaultZone = NSDefaultMallocZone();
  NSWindowDepth	*depths = 0;

  depths = NSZoneMalloc(defaultZone, sizeof(NSWindowDepth)*(ndepths + 1));
  // FIXME
  depths[0] = [self windowDepthForScreen: screen];
  depths[1] = 0;

  return depths;
}

- (NSArray *) screenList
{
  return [NSArray arrayWithObject: [NSNumber numberWithInt: 0]];
}

/**
   Returns the handle of the module instance.  */
- (void *) serverDevice
{
  return hinstance;
}

/**
   As the number of the window is actually is handle we return this.  */
- (void *) windowDevice: (int)win
{
  return (void *)win;
}

- (void) beep
{
  Beep(400, 500);
}  

/*  stubs for window server events note other stubs should be 
    declared for mouse and keyboards
    these should be implmented in a subclass or a catagory
*/
- (LRESULT) decodeWM_ACTIVEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (LRESULT) decodeWM_ACTIVEAPPParams: (HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) decodeWM_NCACTIVATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (LRESULT) decodeWM_SIZEParams: (HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) decodeWM_SIZINGParams: (HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
   [self subclassResponsibility: _cmd];
}

- (LRESULT) decodeWM_MOVINGParams: (HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
   [self subclassResponsibility: _cmd];
   return 0;
}

- (LRESULT) decodeWM_MOVEParams: (HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) decodeWM_NCCALCSIZEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_WINDOWPOSCHANGINGParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_WINDOWPOSCHANGEDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (LRESULT) decodeWM_GETMINMAXINFOParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
  return 0;
}


- (LRESULT) decodeWM_NCCREATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
  return 0;
}


- (LRESULT) decodeWM_CREATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (DWORD) windowStyleForGSStyle: (unsigned int) style
{
  [self subclassResponsibility: _cmd];
  return 0;
}


- (void) decodeWM_SHOWWINDOWParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_NCPAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (LRESULT) decodeWM_ERASEBKGNDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
  return 0;
}


- (void) decodeWM_PAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_SYNCPAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_CAPTURECHANGEDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}

//- (HICON) decodeWM_GETICONParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
//{
 //[self subclassResponsibility: _cmd]; 
 //return nil;
//}

- (void) resizeBackingStoreFor: (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


//- (LRESULT) decodeWM_SETTEXTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
//{
 //[self subclassResponsibility: _cmd];
 
 //return 0;
//}


- (LRESULT) decodeWM_SETFOCUSParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
  return 0;
}


- (void) decodeWM_KILLFOCUSParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_GETTEXTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_CLOSEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_DESTROYParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_NCDESTROYParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_QUERYOPENParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}


- (void) decodeWM_SYSCOMMANDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}

- (void) decodeWM_COMMANDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
   [self subclassResponsibility: _cmd];

}

- (BOOL) displayEvent: (unsigned int)uMsg;   // diagnotic filter
{
  [self subclassResponsibility: _cmd];
  return YES;
}

- (LRESULT) decodeWM_EXITSIZEMOVEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
  return 0;
}


// main event loop


- (NSString *) getNativeClassName: (HWND)hwnd
{
  char * windowType[80];
  UINT wsize =80;
  
  if (RealGetWindowClass(hwnd,(LPTSTR)windowType,wsize)>0)
    {
      return [NSString stringWithCString: (char *)windowType length: wsize+1];
    }
  
  return nil;
}

- (NSString *) getWindowtext: (HWND)hwnd
{
  char * windowText[80];
  int wsize = 80;
  
  if (GetWindowText(hwnd,(LPTSTR)windowText,wsize) > 0)
    return [NSString stringWithCString: (char *)windowText length: wsize + 1];
  
  return nil;
}


/*
 * Reset all of our flags before the next run through the event switch
 *
 */
- (void) setFlagsforEventLoop: (HWND)hwnd
{
  flags._eventHandled = NO;

  flags._is_menu = NO;
  if ((HWND)flags.menuRef == hwnd && flags.HAVE_MAIN_MENU == YES)
    flags._is_menu = YES;
  // note some cache windows are needed..... just get the zeros 
  flags._is_cache = [[EVENT_WINDOW(hwnd) className] isEqual: @"GSCacheW"];
  
  flags._hasGSClassName = NO;
  if ([EVENT_WINDOW(hwnd) className] != nil)
    flags._hasGSClassName = YES;
    
  // future house keeping can go here

}

- (LRESULT) windowEventProc: (HWND)hwnd : (UINT)uMsg 
		       : (WPARAM)wParam : (LPARAM)lParam
{ 
  NSEvent *ev = nil;

  [self setFlagsforEventLoop: hwnd];
 
#ifdef __W32_debug__        
  if ([self displayEvent: uMsg]== YES)
    {     
      printf("\n\n\n+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
      printf("+++                NEW EVENT CYCLE %u                        +++\n",uMsg);
      printf("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
#ifdef __W32_debug_Event_loop 
      printf("Events Posted = %d\n",flags.eventQueCount);
      printf("EVENT Que Count = %d\n",(int)[GSCurrentServer() eventQueCount]);
      printf("%s",[[GSCurrentServer() dumpQue: 10] cString]);
#endif   
    }
#endif

  switch (uMsg) 
    { 
      case WM_SIZING: 
	 [self decodeWM_SIZINGParams: hwnd : wParam : lParam];
      case WM_NCCREATE: 
	return [self decodeWM_NCCREATEParams: wParam : lParam : hwnd];
	break;
      case WM_NCCALCSIZE: 
	[self decodeWM_NCCALCSIZEParams: wParam : lParam : hwnd]; 
	break;
      case WM_NCACTIVATE: 
	[self decodeWM_NCACTIVATEParams: wParam : lParam : hwnd]; 
	break;
      case WM_NCPAINT: 
	if (flags.useWMStyles == NO)
	[self decodeWM_NCPAINTParams: wParam : lParam : hwnd]; 
	break;
     //case WM_SHOWWINDOW: 
	//[self decodeWM_SHOWWINDOWParams: wParam : lParam : hwnd]; 
	//break;
      case WM_NCDESTROY: 
	[self decodeWM_NCDESTROYParams: wParam : lParam : hwnd]; 
	break;
      case WM_GETTEXT: 
	[self decodeWM_GETTEXTParams: wParam : lParam : hwnd]; 
	break;
      case WM_STYLECHANGING: 
	break;
      case WM_STYLECHANGED: 
	break;
      case WM_GETMINMAXINFO: 
	return [self decodeWM_GETMINMAXINFOParams: wParam : lParam : hwnd];
	break;
      case WM_CREATE: 
	return [self decodeWM_CREATEParams: wParam : lParam : hwnd];
	break;
      case WM_WINDOWPOSCHANGING: 
	[self decodeWM_WINDOWPOSCHANGINGParams: wParam : lParam : hwnd]; 
	break;
      case WM_WINDOWPOSCHANGED: 
	[self decodeWM_WINDOWPOSCHANGEDParams: wParam : lParam : hwnd]; 
	break;
      case WM_MOVE: 
	return [self decodeWM_MOVEParams: hwnd : wParam : lParam];
	break;
      case WM_MOVING: 
	return [self decodeWM_MOVINGParams: hwnd : wParam : lParam];
	break;
      case WM_SIZE: 
	return [self decodeWM_SIZEParams: hwnd : wParam : lParam];
	break;
      case WM_ENTERSIZEMOVE: 
	break;
      case WM_EXITSIZEMOVE: 
	//return [self decodeWM_EXITSIZEMOVEParams: wParam : lParam : hwnd];
	return DefWindowProc(hwnd, uMsg, wParam, lParam); 
	break; 
      case WM_ACTIVATE: 
	if ((int)lParam !=0)
	   [self decodeWM_ACTIVEParams: wParam : lParam : hwnd]; 
	break;
      case WM_ACTIVATEAPP: 
	//if (_is_cache == NO) 
	return [self decodeWM_ACTIVEAPPParams: hwnd : wParam : lParam];
	break;
      case WM_SETFOCUS: 
	return [self decodeWM_SETFOCUSParams: wParam : lParam : hwnd]; 
	break;
      case WM_KILLFOCUS: 
	if (wParam == (int)hwnd)
	  return 0;
	else
	  [self decodeWM_KILLFOCUSParams: wParam : lParam : hwnd]; 
	break;
      case WM_SETCURSOR: 
	break;
      case WM_QUERYOPEN: 
	[self decodeWM_QUERYOPENParams: wParam : lParam : hwnd]; 
	break;
      case WM_CAPTURECHANGED: 
	[self decodeWM_CAPTURECHANGEDParams: wParam : lParam : hwnd]; 
	break;
      case WM_ERASEBKGND: 
	return [self decodeWM_ERASEBKGNDParams: wParam : lParam : hwnd];
	break;
      case WM_PAINT: 
	[self decodeWM_PAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd]; 
      case WM_SYNCPAINT: 
	if (flags.useWMStyles == NO)
	[self decodeWM_SYNCPAINTParams: wParam : lParam : hwnd]; 
	break;
      case WM_CLOSE: 
	[self decodeWM_CLOSEParams: wParam : lParam : hwnd]; 
	break;
      case WM_DESTROY: 
	[self decodeWM_DESTROYParams: wParam : lParam : hwnd];
	break;
      case WM_QUIT: 
	break;
      case WM_USER: 
	break;
      case WM_APP: 
	break;  
      case WM_ENTERMENULOOP: 
	break;
      case WM_EXITMENULOOP: 
	break;
      case WM_INITMENU: 
	break;
      case WM_MENUSELECT: 
	break;
      case WM_ENTERIDLE: 
	break;
      case WM_COMMAND: 
	[self decodeWM_COMMANDParams: wParam : lParam : hwnd];
	break;
      case WM_SYSKEYDOWN: 
	break;
      case WM_SYSKEYUP: 
	break;
      case WM_SYSCOMMAND: 
	[self decodeWM_SYSCOMMANDParams: wParam : lParam : hwnd];
	break;
      case WM_HELP: 
	break;
     //case WM_GETICON: 
	//return [self decodeWM_GETICONParams: wParam : lParam : hwnd];
	//break;
     //case WM_SETICON: 
	//return [self decodeWM_SETICONParams: wParam : lParam : hwnd];
	//break;
     case WM_CANCELMODE:  // new added by Tom MacSween
	break;
      case WM_ENABLE: 
      case WM_CHILDACTIVATE: 
	break;
      case WM_NULL: 
	break; 
	
   /* resued from WIN32EventServer.m (now removed from this project) */        
      case WM_NCHITTEST: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCHITTEST", hwnd);
	break;
      case WM_NCMOUSEMOVE: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCMOUSEMOVE", hwnd);
	break;
      case WM_NCLBUTTONDOWN:  //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCLBUTTONDOWN", hwnd);
	break;
      case WM_NCLBUTTONUP: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCLBUTTONUP", hwnd);
	break;
      case WM_MOUSEACTIVATE: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOUSEACTIVATE", hwnd);
	break;
      case WM_MOUSEMOVE: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOUSEMOVE", hwnd);
	ev = process_mouse_event(self, hwnd, wParam, lParam, NSMouseMoved);
	break;
      case WM_LBUTTONDOWN: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "LBUTTONDOWN", hwnd);
	//[self decodeWM_LBUTTONDOWNParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd];
	ev = process_mouse_event(self, hwnd, wParam, lParam, NSLeftMouseDown);
	break;
      case WM_LBUTTONUP: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "LBUTTONUP", hwnd);
	ev = process_mouse_event(self, hwnd, wParam, lParam, NSLeftMouseUp);
	break;
      case WM_LBUTTONDBLCLK: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "LBUTTONDBLCLK", hwnd);
	break;
      case WM_MBUTTONDOWN: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MBUTTONDOWN", hwnd);
	ev = process_mouse_event(self, hwnd, wParam, lParam, NSOtherMouseDown);
	break;
      case WM_MBUTTONUP: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MBUTTONUP", hwnd);
	ev = process_mouse_event(self, hwnd, wParam, lParam, NSOtherMouseUp);
	break;
      case WM_MBUTTONDBLCLK: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MBUTTONDBLCLK", hwnd);
	break;
      case WM_RBUTTONDOWN: //MOUSE
	{
	  NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "RBUTTONDOWN", hwnd);
	  ev = process_mouse_event(self, hwnd, wParam, lParam, NSRightMouseDown);
	}
	break;
      case WM_RBUTTONUP: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "RBUTTONUP", hwnd);
	{
	  ev = process_mouse_event(self, hwnd, wParam, lParam, NSRightMouseUp);
	}
	break;
      case WM_RBUTTONDBLCLK: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "RBUTTONDBLCLK", hwnd);
	break;
      case WM_MOUSEWHEEL: //MOUSE
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOUSEWHEEL", hwnd);
	ev = process_mouse_event(self, hwnd, wParam, lParam, NSScrollWheel);
	break;
	
	case WM_KEYDOWN:  //KEYBOARD
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "KEYDOWN", hwnd);
	ev = process_key_event(self, hwnd, wParam, lParam, NSKeyDown);
	break;
      case WM_KEYUP:  //KEYBOARD
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "KEYUP", hwnd);
	ev = process_key_event(self, hwnd, wParam, lParam, NSKeyUp);
	break;

      case WM_POWERBROADCAST: //SYSTEM
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "POWERBROADCAST", hwnd);
	break;
      case WM_TIMECHANGE:  //SYSTEM
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "TIMECHANGE", hwnd);
	break;
      case WM_DEVICECHANGE: //SYSTEM
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "DEVICECHANGE", hwnd);
	break;
	
      default: 
	// Process all other messages.
  #ifdef __W32_debug__      
	printf("Uhandled message: %d on window %s\n",uMsg,[[GSWindowWithNumber((int)hwnd) className] cString]);
  #endif      
	NSDebugLLog(@"NSEvent", @"Got unhandled Message %d for %d", uMsg, hwnd);
	break;
    } 
    
    /*
     * see if the event was handled in the the main loop or in the
     * menu loop.  if eventHandled = YES then we are done and need to
     * tell the windows event handler we are finished 
     */
  if (flags._eventHandled == YES)
    return 0;
  
  if (ev != nil)
    {		
      [GSCurrentServer() postEvent: ev atStart: NO];
      flags.eventQueCount++;
#ifdef __W32_debug__      
      if ([ev type]== NSAppKitDefined)
	{
	  printf("uMsg %d ",uMsg);
	  printf("Post event %s ",[[ev eventNameWithSubtype: YES] cString]);
	  printf("on window %s\n",[[[ev window] className] cString]);
	}
#endif	    
      return 0;
    }
  /*
   * We did not care about the event return it back to the windows
   * event handler 
   */
  return DefWindowProc(hwnd, uMsg, wParam, lParam); 
}

- glContextClass
{
#ifdef HAVE_WGL
  return [Win32GLContext class];
#else
  return nil;
#endif
}

- glPixelFormatClass
{
#ifdef HAVE_WGL
  return [Win32GLPixelFormat class];
#else
  return nil;
#endif
}


@end



@implementation WIN32Server (WindowOps)

-(BOOL) handlesWindowDecorations
{
  return handlesWindowDecorations;
}


/*
  styleMask specifies the receiver's style. It can either be
  NSBorderlessWindowMask, or it can contain any of the following
  options, combined using the C bitwise OR operator: Option Meaning

    NSTitledWindowMask          The NSWindow displays a title bar.
    NSClosableWindowMask        The NSWindow displays a close button.
    NSMiniaturizableWindowMask  The NSWindow displays a miniaturize button. 
    NSResizableWindowMask       The NSWindow displays a resize bar or border.
    NSBorderlessWindowMask
    
    NSUtilityWindowMask         16
    NSDocModalWindowMask        32
    NSBorderlessWindowMask      0
    NSTitledWindowMask          1
    NSClosableWindowMask        2
    NSMiniaturizableWindowMask  4
    NSResizableWindowMask       8
    NSIconWindowMask            64
    NSMiniWindowMask            128

  Borderless windows display none of the usual peripheral elements and
  are generally useful only for display or caching purposes; you
  should normally not need to create them. Also, note that an
  NSWindow's style mask should include NSTitledWindowMask if it
  includes any of the others.

  backingType specifies how the drawing done in the receiver is
  buffered by the object's window device: NSBackingStoreBuffered
  NSBackingStoreRetained NSBackingStoreNonretained


  flag determines whether the Window Server creates a window device
  for the new object immediately. If flag is YES, it defers creating
  the window until the receiver is moved on screen. All display
  messages sent to the NSWindow or its NSViews are postponed until the
  window is created, just before it's moved on screen.  Deferring the
  creation of the window improves launch time and minimizes the
  virtual memory load on the Window Server.  The new NSWindow creates
  an instance of NSView to be its default content view.  You can
  replace it with your own object by using the setContentView: method.

*/

- (int) window: (NSRect)frame : (NSBackingStoreType)type : (unsigned int)style
	      : (int) screen
{
  HWND hwnd; 
  RECT r;
  DWORD wstyle;
  DWORD estyle;

  flags.currentGS_Style = style;
    
   wstyle = [self windowStyleForGSStyle: style] | WS_CLIPCHILDREN;

  if ((style & NSMiniaturizableWindowMask) == NSMiniaturizableWindowMask)
    {
      if (flags.useWMTaskBar == YES)
	estyle = WS_EX_APPWINDOW;
      else
	estyle = WS_EX_TOOLWINDOW;
    }
  else
    {
      estyle = WS_EX_TOOLWINDOW;
    } 

  r = GSScreenRectToMS(frame, style, self);

#ifdef __debugServer__  
  printf("\n\n##############################################################\n"); 
  printf("handlesWindowDecorations %s\n",handlesWindowDecorations ? "YES" : "NO");
  printf("checking for NSMiniaturizableWindowMask %u\n",(style & NSMiniaturizableWindowMask));
  printf("GS Window Style %u\n",style);
  printf("Extended Style %d  [hex] %X\n",(int)estyle,(UINT)estyle);     
   printf("Win32 Style picked %ld [hex] %X\n",wstyle,(unsigned int)wstyle); 
  printf("\n##############################################################\n");    
#endif

  /* 
   * from here down is reused and unmodified from WIN32EventServer.m 
   * which has been removed form the subproject 
   */
  NSDebugLLog(@"WTrace", @"window: %@ : %d : %d : %d", NSStringFromRect(frame),
	      type, style, screen);
  NSDebugLLog(@"WTrace", @"         device frame: %d, %d, %d, %d", 
	      r.left, r.top, r.right - r.left, r.bottom - r.top);
  hwnd = CreateWindowEx(estyle,
			"GNUstepWindowClass",
			"GNUstepWindow",
			wstyle, 
			r.left, 
			r.top, 
			r.right - r.left, 
			r.bottom - r.top,
			(HWND)NULL,
			(HMENU)NULL,
			hinstance,
			(void*)type);
  NSDebugLLog(@"WTrace", @"         num/handle: %d", hwnd);

  [self _setWindowOwnedByServer: (int)hwnd];
  return (int)hwnd;
}

- (void) termwindow: (int) winNum
{
  NSDebugLLog(@"WTrace", @"termwindow: %d", winNum);
  DestroyWindow((HWND)winNum); 
}

- (void) stylewindow: (unsigned int)style : (int) winNum
{
  DWORD wstyle = [self windowStyleForGSStyle: style];

  NSAssert(handlesWindowDecorations,
	   @"-stylewindow: : called when handlesWindowDecorations == NO");

  NSDebugLLog(@"WTrace", @"stylewindow: %d : %d", style, winNum);
  SetWindowLong((HWND)winNum, GWL_STYLE, wstyle);
}

- (void) setbackgroundcolor: (NSColor *)color : (int)win
{
}

/** Changes window's the backing store to type */
- (void) windowbacking: (NSBackingStoreType)type : (int) winNum
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)winNum, GWL_USERDATA);

  NSDebugLLog(@"WTrace", @"windowbacking: %d : %d", type, winNum);
  if (win->useHDC)
    {
      HGDIOBJ old;

      old = SelectObject(win->hdc, win->old);
      DeleteObject(old);
      DeleteDC(win->hdc);
      win->hdc = NULL;
      win->old = NULL;
      win->useHDC = NO;
    }

  if (type != NSBackingStoreNonretained)
    {
      HDC hdc, hdc2;
      HBITMAP hbitmap;
      RECT r;

      GetClientRect((HWND)winNum, &r);
      hdc = GetDC((HWND)winNum);
      hdc2 = CreateCompatibleDC(hdc);
      hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, r.bottom - r.top);
      win->old = SelectObject(hdc2, hbitmap);
      win->hdc = hdc2;
      win->useHDC = YES;

      ReleaseDC((HWND)winNum, hdc);
    }
}

- (void) titlewindow: (NSString*)window_title : (int) winNum
{
  NSDebugLLog(@"WTrace", @"titlewindow: %@ : %d", window_title, winNum);
  SetWindowText((HWND)winNum, [window_title cString]);
}

- (void) miniwindow: (int) winNum
{
  NSDebugLLog(@"WTrace", @"miniwindow: %d", winNum);
  ShowWindow((HWND)winNum, SW_MINIMIZE); 
}

/** Returns NO as we don't provide mini windows on MS Windows */ 
- (BOOL) appOwnsMiniwindow
{
  return NO;
}

- (void) windowdevice: (int) winNum
{
  NSGraphicsContext *ctxt;
  RECT rect;
  float h, l, r, t, b;
  NSWindow *window;

  NSDebugLLog(@"WTrace", @"windowdevice: %d", winNum);
  ctxt = GSCurrentContext();
  window = GSWindowWithNumber(winNum);
  GetClientRect((HWND)winNum, &rect);
  h = rect.bottom - rect.top;
  [self styleoffsets: &l : &r : &t : &b : [window styleMask]];
  GSSetDevice(ctxt, (void*)winNum, l, h + b);
  DPSinitmatrix(ctxt);
  DPSinitclip(ctxt);
}

- (void) orderwindow: (int) op : (int) otherWin : (int) winNum
{
  NSDebugLLog(@"WTrace", @"orderwindow: %d : %d : %d", op, otherWin, winNum);

  if (flags.useWMTaskBar)
    {
      /* When using this policy, we make these changes: 
         - don't show the application icon window
	 - Never order out the main menu, just minimize it, so that
	 when the user clicks on it in the taskbar it will activate the
	 application.
      */
      int special;
      special = [[NSApp iconWindow] windowNumber];
      if (winNum == special)
	{
	  return;
	}
      special = [[[NSApp mainMenu] window] windowNumber];
      if (winNum == special && op == NSWindowOut)
	{
	  ShowWindow((HWND)winNum, SW_MINIMIZE); 
	  return;
	}
    }

  if (op != NSWindowOut)
    {
      int flag = SW_SHOW;

      if (IsIconic((HWND)winNum))
        flag = SW_RESTORE;
      ShowWindow((HWND)winNum, flag); 
    }

  switch (op)
    {
      case NSWindowOut: 
	SetWindowPos((HWND)winNum, NULL, 0, 0, 0, 0, 
		     SWP_HIDEWINDOW | SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER);
	break;
      case NSWindowBelow: 
	if (otherWin == 0)
	  otherWin = (int)HWND_BOTTOM;
	SetWindowPos((HWND)winNum, (HWND)otherWin, 0, 0, 0, 0, 
		     SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
	break;
      case NSWindowAbove: 
	if (otherWin <= 0)
	  {
	    /* FIXME: Need to find the current key window (otherWin == 0
	       means keep the window below the current key.)  */
	    otherWin = winNum;
	    winNum = (int)HWND_TOP;
	  }
	SetWindowPos((HWND) otherWin, (HWND)winNum, 0, 0, 0, 0, 
		     SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
	break;
    }
}

- (void) movewindow: (NSPoint)loc : (int)winNum
{
  POINT p;

  NSDebugLLog(@"WTrace", @"movewindow: %@ : %d", NSStringFromPoint(loc), 
	      winNum);
  p = GSWindowOriginToMS((HWND)winNum, loc);

  SetWindowPos((HWND)winNum, NULL, p.x, p.y, 0, 0, 
	       SWP_NOZORDER | SWP_NOSIZE);
}

- (void) placewindow: (NSRect)frame : (int) winNum
{
  RECT r;
  RECT r2;
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)winNum, GWL_USERDATA);
  NSWindow *window = GSWindowWithNumber(winNum);

  NSDebugLLog(@"WTrace", @"placewindow: %@ : %d", NSStringFromRect(frame), 
	      winNum);
  r = GSScreenRectToMS(frame, [window styleMask], self);
  GetWindowRect((HWND)winNum, &r2);

  SetWindowPos((HWND)winNum, NULL,
    r.left, r.top, r.right - r.left, r.bottom - r.top, SWP_NOZORDER); 

  if ((win->useHDC)
    && (r.right - r.left != r2.right - r2.left)
    && (r.bottom - r.top != r2.bottom - r2.top))
    {
      HDC hdc, hdc2;
      HBITMAP hbitmap;
      HGDIOBJ old;
      
      old = SelectObject(win->hdc, win->old);
      DeleteObject(old);
      DeleteDC(win->hdc);
      win->hdc = NULL;
      win->old = NULL;
      
      GetClientRect((HWND)winNum, &r);
      hdc = GetDC((HWND)winNum);
      hdc2 = CreateCompatibleDC(hdc);
      hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, r.bottom - r.top);
      win->old = SelectObject(hdc2, hbitmap);
      win->hdc = hdc2;
      
      ReleaseDC((HWND)winNum, hdc);
    }
}

- (BOOL) findwindow: (NSPoint)loc : (int) op : (int) otherWin 
		   : (NSPoint *)floc : (int*) winFound
{
  return NO;
}

- (NSRect) windowbounds: (int) winNum
{
  RECT r;
  NSWindow *window = GSWindowWithNumber(winNum);

  GetWindowRect((HWND)winNum, &r);
  return MSScreenRectToGS(r, [window styleMask], self);
}

- (void) setwindowlevel: (int) level : (int) winNum
{
  NSDebugLLog(@"WTrace", @"setwindowlevel: %d : %d", level, winNum);
}

- (int) windowlevel: (int) winNum
{
  return 0;
}

- (NSArray *) windowlist
{
  NSMutableArray	*list = [NSMutableArray arrayWithCapacity: 100];
  HWND			w;
  HWND			next;

  w = GetForegroundWindow();	// Try to start with frontmost window
  if (w == NULL)
    {
      w = GetDesktopWindow();	// This should always succeed.
    }

  /* Step up to the frontmost window.
   */
  while ((next = GetNextWindow(w, GW_HWNDPREV)) != NULL)
    {
      w = next;
    }
  
  /* Now walk down the window list populating the array.
   */
  while (w != NULL)
    {
      /* Only add windows we own.
       * FIXME We should improve the API to support all windows on server.
       */
      if (GSWindowWithNumber((int)w) != nil)
	{
	  [list addObject: [NSNumber numberWithInt: (int)w]];
	}
      w = GetNextWindow(w, GW_HWNDNEXT);
    }

  return list;
}

- (int) windowdepth: (int) winNum
{
  return 0;
}

/** Set the maximum size of the window */
- (void) setmaxsize: (NSSize)size : (int) winNum
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)winNum, GWL_USERDATA);
  POINT p;

  p.x = size.width;
  p.y = size.height;
  win->minmax.ptMaxTrackSize = p;
}

/** Set the minimum size of the window */
- (void) setminsize: (NSSize)size : (int) winNum
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)winNum, GWL_USERDATA);
  POINT p;

  p.x = size.width;
  p.y = size.height;
  win->minmax.ptMinTrackSize = p;
}

/** Set the resize incremenet of the window */
- (void) setresizeincrements: (NSSize)size : (int) winNum
{
}

/** Causes buffered graphics to be flushed to the screen */
- (void) flushwindowrect: (NSRect)rect : (int) winNum
{
  RECT r = GSWindowRectToMS(self, (HWND)winNum, rect);
  validateWindow(self, (HWND)winNum, r);
}

- (void) styleoffsets: (float *) l : (float *) r : (float *) t : (float *) b
		     : (unsigned int) style 
{
  if (handlesWindowDecorations)
    {
      DWORD wstyle = [self windowStyleForGSStyle: style];
      RECT rect = {100, 100, 200, 200};
      
      AdjustWindowRectEx(&rect, wstyle, NO, 0);

      *l = 100 - rect.left;
      *r = rect.right - 200;
      *t = 100 - rect.top;
      *b = rect.bottom - 200;
      //NSLog(@"Style %d offset %f %f %f %f", wstyle, *l, *r, *t, *b);
    }
  else
    {
      /*
	If we don't handle decorations, all our windows are going to be
	border- and decorationless. In that case, -gui won't call this method,
	but we still use it internally.
      */
      *l = *r = *t = *b = 0.0;
    }
}

- (void) docedited: (int) edited : (int) winNum
{
}

- (void) setinputstate: (int)state : (int)winNum
{
  if (handlesWindowDecorations == NO)
    {
      return;
    }
  if (state == GSTitleBarKey)
    {
      SetActiveWindow((HWND)winNum);
    }
}

/** Forces focus to the window so that all key events are sent to this
    window */
- (void) setinputfocus: (int) winNum
{
  NSDebugLLog(@"WTrace", @"setinputfocus: %d", winNum);
  NSDebugLLog(@"Focus", @"Setting input focus to %d", winNum);
  if (winNum == 0)
    {
      NSDebugLLog(@"Focus", @" invalid focus window");
      return;
    }
  if (currentFocus == (HWND)winNum)
    {
      NSDebugLLog(@"Focus", @" window already has focus");
      return;
    }
  desiredFocus = (HWND)winNum;
  SetFocus((HWND)winNum);
}

- (NSPoint) mouselocation
{
  POINT p;

  if (!GetCursorPos(&p))
    {  
      NSLog(@"GetCursorPos failed with %d", GetLastError());
      return NSZeroPoint;
    }

  return MSScreenPointToGS(p.x, p.y);
}

- (NSPoint) mouseLocationOnScreen: (int)screen window: (int *)win
{
  return [self mouselocation];
}

- (BOOL) capturemouse: (int) winNum
{
  NSDebugLLog(@"WTrace", @"capturemouse: %d", winNum);
  SetCapture((HWND)winNum);
  return YES;
}

- (void) releasemouse
{
  NSDebugLLog(@"WTrace", @"releasemouse");
  ReleaseCapture();
}

- (void) hidecursor
{
  NSDebugLLog(@"WTrace", @"hidecursor");
  ShowCursor(NO);
}

- (void) showcursor
{
  ShowCursor(YES);
}

- (void) standardcursor: (int)style : (void **)cid
{
  HCURSOR hCursor = 0;

  NSDebugLLog(@"WTrace", @"standardcursor: %d", style);
  switch (style)
    {
      case GSArrowCursor: 
	hCursor = LoadCursor(NULL, IDC_ARROW);
	break;
      case GSIBeamCursor: 
	hCursor = LoadCursor(NULL, IDC_IBEAM);
	break;
      case GSCrosshairCursor: 
	hCursor = LoadCursor(NULL, IDC_CROSS);
	break;
      case GSPointingHandCursor: 
	hCursor = LoadCursor(NULL, IDC_HAND);
	break;
      case GSResizeLeftRightCursor: 
	hCursor = LoadCursor(NULL, IDC_SIZEWE);
	break;
      case GSResizeUpDownCursor: 
	hCursor = LoadCursor(NULL, IDC_SIZENS);
	break;
      default: 
	return;
    }
  *cid = (void*)hCursor;
}

- (void) imagecursor: (NSPoint)hotp : (int) w :  (int) h 
		    : (int)colors : (const unsigned char *)image : (void **)cid
{
  /*
    HCURSOR cur;
    BYTE *and;
    BYTE *xor;

    xor = image;
    cur = CreateCursor(hinstance, (int)hotp.x, (int)hotp.y,  (int)w, (int)h, and, xor);
    *cid = (void*)hCursor;
    */
}

- (void) setcursorcolor: (NSColor *)fg : (NSColor *)bg : (void*) cid
{
  /* FIXME The colour is currently ignored
     if (fg != nil)
     {
     ICONINFO iconinfo;

     if (GetIconInfo((HCURSOR)cid, &iconinfo))
     {
     iconinfo.hbmColor = ; 
     }
     }
  */

  SetCursor((HCURSOR)cid);
}


@end
// static keyboard/mouse methods >into a subclass some day

static unichar 
process_char(WPARAM wParam, unsigned *eventModifierFlags)
{
  switch (wParam)
    {
      case VK_RETURN: return NSCarriageReturnCharacter;
      case VK_TAB:    return NSTabCharacter;
      case VK_ESCAPE:  return 0x1b;
      case VK_BACK:   return NSBackspaceCharacter;

	/* The following keys need to be reported as function keys */
  #define WIN_FUNCTIONKEY \
  *eventModifierFlags = *eventModifierFlags | NSFunctionKeyMask;
      case VK_F1: WIN_FUNCTIONKEY return NSF1FunctionKey;
      case VK_F2: WIN_FUNCTIONKEY return NSF2FunctionKey;
      case VK_F3: WIN_FUNCTIONKEY return NSF3FunctionKey;
      case VK_F4: WIN_FUNCTIONKEY return NSF4FunctionKey;
      case VK_F5: WIN_FUNCTIONKEY return NSF5FunctionKey;
      case VK_F6: WIN_FUNCTIONKEY return NSF6FunctionKey;
      case VK_F7: WIN_FUNCTIONKEY return NSF7FunctionKey;
      case VK_F8: WIN_FUNCTIONKEY return NSF8FunctionKey;
      case VK_F9: WIN_FUNCTIONKEY return NSF9FunctionKey;
      case VK_F10: WIN_FUNCTIONKEY return NSF10FunctionKey;
      case VK_F11: WIN_FUNCTIONKEY return NSF12FunctionKey;
      case VK_F12: WIN_FUNCTIONKEY return NSF12FunctionKey;
      case VK_F13: WIN_FUNCTIONKEY return NSF13FunctionKey;
      case VK_F14: WIN_FUNCTIONKEY return NSF14FunctionKey;
      case VK_F15: WIN_FUNCTIONKEY return NSF15FunctionKey;
      case VK_F16: WIN_FUNCTIONKEY return NSF16FunctionKey;
      case VK_F17: WIN_FUNCTIONKEY return NSF17FunctionKey;
      case VK_F18: WIN_FUNCTIONKEY return NSF18FunctionKey;
      case VK_F19: WIN_FUNCTIONKEY return NSF19FunctionKey;
      case VK_F20: WIN_FUNCTIONKEY return NSF20FunctionKey;
      case VK_F21: WIN_FUNCTIONKEY return NSF21FunctionKey;
      case VK_F22: WIN_FUNCTIONKEY return NSF22FunctionKey;
      case VK_F23: WIN_FUNCTIONKEY return NSF23FunctionKey;
      case VK_F24: WIN_FUNCTIONKEY return NSF24FunctionKey;

      case VK_DELETE:      WIN_FUNCTIONKEY return NSDeleteFunctionKey;
      case VK_HOME:        WIN_FUNCTIONKEY return NSHomeFunctionKey;
      case VK_LEFT:        WIN_FUNCTIONKEY return NSLeftArrowFunctionKey;
      case VK_RIGHT:       WIN_FUNCTIONKEY return NSRightArrowFunctionKey;
      case VK_UP:          WIN_FUNCTIONKEY return NSUpArrowFunctionKey;
      case VK_DOWN:        WIN_FUNCTIONKEY return NSDownArrowFunctionKey;
      case VK_PRIOR:       WIN_FUNCTIONKEY return NSPrevFunctionKey;
      case VK_NEXT:        WIN_FUNCTIONKEY return NSNextFunctionKey;
      case VK_END:         WIN_FUNCTIONKEY return NSEndFunctionKey;
	//case VK_BEGIN:       WIN_FUNCTIONKEY return NSBeginFunctionKey;
      case VK_SELECT:      WIN_FUNCTIONKEY return NSSelectFunctionKey;
      case VK_PRINT:       WIN_FUNCTIONKEY return NSPrintFunctionKey;
      case VK_EXECUTE:     WIN_FUNCTIONKEY return NSExecuteFunctionKey;
      case VK_INSERT:      WIN_FUNCTIONKEY return NSInsertFunctionKey;
      case VK_HELP:        WIN_FUNCTIONKEY return NSHelpFunctionKey;
      case VK_CANCEL:      WIN_FUNCTIONKEY return NSBreakFunctionKey;
	//case VK_MODECHANGE:  WIN_FUNCTIONKEY return NSModeSwitchFunctionKey;
      case VK_SCROLL:      WIN_FUNCTIONKEY return NSScrollLockFunctionKey;
      case VK_PAUSE:       WIN_FUNCTIONKEY return NSPauseFunctionKey;
      case VK_OEM_CLEAR:   WIN_FUNCTIONKEY return NSClearDisplayFunctionKey;
  #undef WIN_FUNCTIONKEY
      default: 
	return 0;
    }
}

static NSEvent*
process_key_event(WIN32Server *svr, HWND hwnd, WPARAM wParam, LPARAM lParam, 
		  NSEventType eventType)
{
  NSEvent *event;
  BOOL repeat;
  DWORD pos;
  NSPoint eventLocation;
  unsigned int eventFlags;
  NSTimeInterval time;
  LONG ltime;
  unichar unicode[5];
  unsigned int scan;
  int result;
  BYTE keyState[256];
  NSString *keys, *ukeys;
  NSGraphicsContext *gcontext;
  unichar uChar;

  /* FIXME: How do you guarentee a context is associated with an event? */
  gcontext = GSCurrentContext();

  repeat = (lParam & 0xFFFF) != 0;

  pos = GetMessagePos();
  eventLocation
    = MSWindowPointToGS(svr, hwnd,  GET_X_LPARAM(pos), GET_Y_LPARAM(pos));

  ltime = GetMessageTime();
  time = ltime / 1000;

  GetKeyboardState(keyState);
  eventFlags = 0;
  if (keyState[VK_CONTROL] & 128)
    eventFlags |= NSControlKeyMask;
  if (keyState[VK_SHIFT] & 128)
    eventFlags |= NSShiftKeyMask;
  if (keyState[VK_CAPITAL] & 128)
    eventFlags |= NSShiftKeyMask;
  if (keyState[VK_MENU] & 128)
    eventFlags |= NSAlternateKeyMask;
  if (keyState[VK_HELP] & 128)
    eventFlags |= NSHelpKeyMask;
  if ((keyState[VK_LWIN] & 128) || (keyState[VK_RWIN] & 128))
    eventFlags |= NSCommandKeyMask;


  switch(wParam)
    {
      case VK_SHIFT: 
      case VK_CAPITAL: 
      case VK_CONTROL: 
      case VK_MENU: 
      case VK_HELP: 
      case VK_NUMLOCK: 
	eventType = NSFlagsChanged;
	break;
      case VK_NUMPAD0: 
      case VK_NUMPAD1: 
      case VK_NUMPAD2: 
      case VK_NUMPAD3: 
      case VK_NUMPAD4: 
      case VK_NUMPAD5: 
      case VK_NUMPAD6: 
      case VK_NUMPAD7: 
      case VK_NUMPAD8: 
      case VK_NUMPAD9: 
	eventFlags |= NSNumericPadKeyMask;
	break;
      default: 
	break;
    }


  uChar = process_char(wParam, &eventFlags);
  if (uChar)
    {
      keys = [NSString  stringWithCharacters: &uChar  length: 1];
      ukeys = [NSString  stringWithCharacters: &uChar  length: 1];
    }
  else
    {
      scan = ((lParam >> 16) & 0xFF);
      //NSLog(@"Got key code %d %d", scan, wParam);
      result = ToUnicode(wParam, scan, keyState, unicode, 5, 0);
      //NSLog(@"To Unicode resulted in %d with %d", result, unicode[0]);
      if (result == -1)
	{
	  // A non spacing accent key was found, we still try to use the result 
	  result = 1;
	}
      keys = [NSString  stringWithCharacters: unicode  length: result];
      // Now switch modifiers off
      keyState[VK_LCONTROL] = 0;
      keyState[VK_RCONTROL] = 0;
      keyState[VK_LMENU] = 0;
      keyState[VK_RMENU] = 0;
      result = ToUnicode(wParam, scan, keyState, unicode, 5, 0);
      //NSLog(@"To Unicode resulted in %d with %d", result, unicode[0]);
      if (result == -1)
	{
	  // A non spacing accent key was found, we still try to use the result 
	  result = 1;
	}
      ukeys = [NSString  stringWithCharacters: unicode  length: result];
    }

  event = [NSEvent keyEventWithType: eventType
			   location: eventLocation
		      modifierFlags: eventFlags
			  timestamp: time
		       windowNumber: (int)hwnd
			    context: gcontext
			 characters: keys
		   charactersIgnoringModifiers: ukeys
			  isARepeat: repeat
			    keyCode: wParam];

  return event;
}

static NSEvent*
process_mouse_event(WIN32Server *svr, HWND hwnd, WPARAM wParam, LPARAM lParam, 
		    NSEventType eventType)
{
  NSEvent *event;
  NSPoint eventLocation;
  unsigned int eventFlags;
  NSTimeInterval time;
  LONG ltime;
  DWORD tick;
  NSGraphicsContext *gcontext;
  short deltaY = 0;
  static int clickCount = 1;
  static LONG lastTime = 0;

  gcontext = GSCurrentContext();
  eventLocation = MSWindowPointToGS(svr, hwnd,  GET_X_LPARAM(lParam), 
				    GET_Y_LPARAM(lParam));
  ltime = GetMessageTime();
  time = ltime / 1000;
  tick = GetTickCount();
  eventFlags = 0;
  if (wParam & MK_CONTROL)
    {
      eventFlags |= NSControlKeyMask;
    }
  if (wParam & MK_SHIFT)
    {
      eventFlags |= NSShiftKeyMask;
    }
  if (GetKeyState(VK_MENU) < 0) 
    {
      eventFlags |= NSAlternateKeyMask;
    }
  if (GetKeyState(VK_HELP) < 0) 
    {
      eventFlags |= NSHelpKeyMask;
    }
  // What about other modifiers?

  if (eventType == NSScrollWheel)
    {
      deltaY = GET_WHEEL_DELTA_WPARAM(wParam) / 120;
      //NSLog(@"Scroll event with delat %d", deltaY);
    }
  else if (eventType == NSMouseMoved)
    {
      if (wParam & MK_LBUTTON)
	{
	  eventType = NSLeftMouseDragged;
	}
      else if (wParam & MK_RBUTTON)
	{
	  eventType = NSRightMouseDragged;
	}
      else if (wParam & MK_MBUTTON)
	{
	  eventType = NSOtherMouseDragged;
	}
    }
  else if ((eventType == NSLeftMouseDown)
    || (eventType == NSRightMouseDown)
    || (eventType == NSOtherMouseDown))
    {
      if (lastTime + GetDoubleClickTime() > ltime)
	{
	  clickCount += 1;
	}
      else 
	{
	  clickCount = 1;
	  lastTime = ltime;
	}
    }

  event = [NSEvent mouseEventWithType: eventType
			     location: eventLocation
			modifierFlags: eventFlags
			    timestamp: time
			 windowNumber: (int)hwnd
			      context: gcontext
			  eventNumber: tick
			   clickCount: clickCount
			     pressure: 1.0
			 buttonNumber: 0 /* FIXME */
			       deltaX: 0.
			       deltaY: deltaY
			       deltaZ: 0.];
            
  return event;
}


LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg,
			     WPARAM wParam, LPARAM lParam)
{
  WIN32Server	*ctxt = (WIN32Server *)GSCurrentServer();

  return [ctxt windowEventProc: hwnd : uMsg : wParam : lParam];
}
// end static Keyboard mouse



static void 
validateWindow(WIN32Server *svr, HWND hwnd, RECT rect)
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)hwnd, GWL_USERDATA);

  if (win->useHDC)
    {
      HDC hdc = GetDC((HWND)hwnd);
      WINBOOL result;

      result = BitBlt(hdc, rect.left, rect.top, 
		      (rect.right - rect.left), (rect.bottom - rect.top), 
		      win->hdc, rect.left, rect.top, SRCCOPY);
      if (!result)
        {
	  NSLog(@"validated window %d %@", hwnd, 
		NSStringFromRect(MSWindowRectToGS(svr, (HWND)hwnd, rect)));
	  NSLog(@"validateWindow failed %d", GetLastError());
	}
      ReleaseDC((HWND)hwnd, hdc);
    }
}
