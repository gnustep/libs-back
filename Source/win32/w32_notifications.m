/* WIN32Server - Implements window handling for MSWindows

   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by: Tom MacSween <macsweent@sympatico.ca>
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
   
 #include "w32_Events.h"

 static NSString *NSMenuWillTearOff = @"MenuWillTearOff";
 static NSString *NSMenuwillPopUP =@"MenuwillPopUP";
 static NSString *NSWindowDidCreateWindow=@"WindowDidCreateWindow";

@interface NSMenu (w32Menu)
 
- (void) _rightMouseDisplay: (NSEvent*)theEvent;
- (void) setTornOff: (BOOL)flag;
@end

@implementation NSMenu (w32Menu)

 // fixme to handle context menues better on win32
 // although it works better then it used to, it still
 // needs more work. 

- (void) _rightMouseDisplay: (NSEvent*)theEvent
{
   NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
   NSNotification * popped;
   //printf("my menu tarnsient method\n");
    
   // need to get hwnd for the window
   [self displayTransient];
   // post notification here
   popped = [NSNotification
      notificationWithName: NSMenuwillPopUP
      object: _bWindow
      userInfo: nil];
		 
   [nc postNotification: popped];

   [_view mouseDown: theEvent];
   [self closeTransient];
   [_bWindow orderOut:self];
}

- (void) setTornOff: (BOOL)flag
{

   NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
   NSNotification * torn;
   NSMenu	*supermenu;

   _is_tornoff = flag; 

   if (flag)
    {
      supermenu = [self supermenu];
      if (supermenu != nil)
        {
          [[supermenu menuRepresentation] setHighlightedItemIndex: -1];
          supermenu->_attachedMenu = nil;
        }
        
        torn = [NSNotification
		 notificationWithName: NSMenuWillTearOff
		 object: self
		 userInfo: nil];
		 
		 [nc postNotification: torn];
    }
  [_view update];
}

@end

@interface NSWindow (w32Window)

- (id) initWithContentRect: (NSRect)contentRect
		 styleMask: (unsigned int)aStyle
		   backing: (NSBackingStoreType)bufferingType
		     defer: (BOOL)flag;

@end

@implementation NSWindow (w32Window)

- (id) initWithContentRect: (NSRect)contentRect
		 styleMask: (unsigned int)aStyle
		   backing: (NSBackingStoreType)bufferingType
		     defer: (BOOL)flag
{

    NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
    NSNotification * createdWindow;
    id anObject=[self initWithContentRect: contentRect
			 styleMask: aStyle
			   backing: bufferingType
			     defer: flag
			    screen: nil];

    createdWindow = [NSNotification
		 notificationWithName: NSWindowDidCreateWindow
		 object: self
		 userInfo: nil];
		 
		 [nc postNotification: createdWindow];
		 
	return anObject;
  
}

@end

@implementation WIN32Server (w32_notifications)

/*
    Notification hook from application
    The default notification are:
    
           NSApplicationDidFinishLaunchingNotification
           NSApplicationWillFinishLaunchingNotification
           NSApplicationWillHideNotification
           NSWindowWillMiniaturizeNotification
           
           Custom Notifications:
           NSMenuWillTearOff
           NSMenuwillPopUP
           
    when these are received the Win32 server can now finalize its setup.
    other hook can also be set at this point
    
    syncronize the GS Env with The native Backend so we can use native calls to manage
    certain things directly.
 */
- (void) ApplicationWillFinishLaunching: (NSNotification*)aNotification;
 {
 
 }
 
- (void) ApplicationDidFinishLaunching: (NSNotification*)aNotification  
{
  NSMenu * theMenu = [NSApp mainMenu];
  NSMenu * subMenu;
  NSMenuItem * anItem;
  LONG result;
  // Get our MainMenu  window refference:

  flags.menuRef = [[theMenu window] windowNumber];
  flags.HAVE_MAIN_MENU = YES;
    
  // add an entry in the main menu to bring up the config window
    
  [self initConfigWindow];
  // if info does not exist add it and create a submenu for it
  if ([theMenu itemWithTitle:@"Info"] == nil)
    {
      anItem = [NSMenuItem new];
      [anItem setTitle: @"Info"];
      [theMenu insertItem: anItem atIndex: 0];            
      subMenu = [NSMenu new];
      [theMenu setSubmenu: subMenu forItem: anItem];
      [anItem setEnabled: YES];
    }
    
  // add 'Server Preference' to the 'Info' item submenu
  subMenu = [[theMenu itemWithTitle: @"Info"] submenu];
  [subMenu addItemWithTitle: @"Server Preferences" 
		     action: @selector(showServerPrefs:) 
	      keyEquivalent: nil];
                            
  anItem = (NSMenuItem *)[subMenu itemWithTitle: @"Server Preferences"];
  [anItem setTarget: self];
  [anItem setEnabled: YES];
        
  if (flags.HAVE_SERVER_PREFS == NO)
    {
      NSRunInformationalAlertPanel(@"Server Preferences Not Set", 
        @"Please set server Preferences\nlook in "
	@"[info]->[Server Preferences]\nto change settings", 
	@"OK", nil, nil);

      [configWindow makeKeyAndOrderFront: self];
    }
    
/*
 * reset the style on the main menu panel so when it hides it will
 * go the the task bar. I will use WS_EX_Left for this.
 * Note that this is native code mixed with GNUStep
 */
  if (flags.useWMStyles == YES)
    {
      ShowWindow((HWND)flags.menuRef, SW_HIDE);
      SetLastError(0);
      result = SetWindowLong((HWND)flags.menuRef, GWL_EXSTYLE, (LONG)WS_EX_LEFT);
      // should check error here...
      result = SetWindowTextW((HWND)flags.menuRef, 
	(const unichar*)[[theMenu title]
	cStringUsingEncoding: NSUnicodeStringEncoding]);

      ShowWindow((HWND)flags.menuRef, SW_SHOWNORMAL);
        
      // set app icon image for win32      
   }
    
    
    // future implimentation 
        
   #ifdef __WM_ACTIVE__
   printf("reseting menu style\n");
   if (result==0)
    {
        printf("setting mainMenu Style: Error %ld\n", GetLastError());
    }
   fflush(stdout);
   #endif
}

- (void) ApplicationWillHideNotification: (NSNotification*)aNotification
{        
   flags.HOLD_MENU_FOR_MOVE=TRUE;
   flags.HOLD_MENU_FOR_SIZE=TRUE;
        
   ReleaseCapture(); // if the mouse is 'stuck' release it
    
   #ifdef __WM_ACTIVE__
   printf("UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU\n");
   printf("got Notification: %s\n", 
   [[aNotification name] cString]);
   fflush(stdout);
   #endif
}

-(void) WindowWillMiniaturizeNotification:(NSNotification*)aNotification
{
   flags.HOLD_MINI_FOR_SIZE=TRUE;
   flags.HOLD_MINI_FOR_MOVE=TRUE;
}

- (void) MenuWillTearOff:(NSNotification*)aNotification
{
  LONG result;
  NSMutableString * iconTitle =[NSMutableString stringWithString:@"MENU "];
  NSMenu * theMenu=[aNotification object];
  int windowNum =[[theMenu window] windowNumber];
    
  ShowWindow((HWND)windowNum, SW_HIDE);
  SetLastError(0);
  result = SetWindowLong((HWND)windowNum, GWL_EXSTYLE, (LONG)WS_EX_LEFT);
  // should check error here...
    
  // set the icon title
  [iconTitle appendString: [theMenu title]];
  result = SetWindowTextW((HWND)windowNum, (const unichar*)[iconTitle
    cStringUsingEncoding: NSUnicodeStringEncoding]); 
  ShowWindow((HWND)windowNum, SW_SHOWNORMAL);

  #ifdef __APPNOTIFICATIONS__
  printf("got menu tear off Notification\n");
  printf("menu title is: %s\n", [[theMenu title] cString]);
  #endif
}

- (void) MenuwillPopUP:(NSNotification*)aNotification
{
  LONG result;
  int windowNum=[[aNotification object] windowNumber]; 

  ShowWindow((HWND)windowNum, SW_HIDE);
  SetLastError(0);
  result=SetWindowLong((HWND)windowNum, GWL_EXSTYLE, (LONG)WS_EX_RIGHT);
  // should check error here...
    
  // set the icon title
  result = SetWindowText((HWND)windowNum, "Context menu"); 
  ShowWindow((HWND)windowNum, SW_SHOWNORMAL);

  flags.HOLD_TRANSIENT_FOR_SIZE=TRUE;
  flags.HOLD_TRANSIENT_FOR_MOVE=TRUE;
    
  #ifdef __APPNOTIFICATIONS__
  printf("got menu Popup Notification\n");
  printf("window title is: %s\n", [[[aNotification object] title] cString]);
  #endif
}

- (void) WindowDidCreateWindow:(NSNotification*)aNotification
{
   unsigned int GSStyle;
    
   NSString * GSClass=[[aNotification object] className];
   // FIXME: Implement this in NSWindow first...
   //[[aNotification object] setShowsResizeIndicator:NO];
   // set window style
   if ([GSClass isEqual:@"NSMenuPanel"]==YES)
   {
      GSStyle= [[aNotification object] styleMask];
      //windowNum=[[aNotification object] windowNumber];
      //[self resetForGSWindowStyle:(HWND)windowNum w32Style:w32style];
      //printf("GSClassName %s GS Style %u  w32 Style %X\n", [GSClass cString], GSStyle, (UINT)w32style);
    }
}
@end

