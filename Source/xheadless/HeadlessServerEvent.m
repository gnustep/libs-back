/*
   HeadlessServerEvent - Window/Event code for X11 backends.

   Copyright (C) 1998,2002,2023 Free Software Foundation, Inc.

   Re-written by: Gregory John Casamento <greg.casamento@gmail.com>
   Based on work by: Marcian Lytwyn <gnustep@advcsi.com> for Keysight
   Based on work Written by:  Adam Fedor <fedor@gnu.org>
   Date: 1998, Nov 1999, Aug 2023

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
*/

#include "config.h"

#include <AppKit/AppKitExceptions.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSWindow.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSDebug.h>

#include "xheadless/XHeadless.h"
#include "xheadless/HeadlessServerWindow.h"
#include "xheadless/HeadlessInputServer.h"
#include "xheadless/HeadlessGeneric.h"

#include "math.h"

#if LIB_FOUNDATION_LIBRARY
# include <Foundation/NSPosixFileDescriptor.h>
#elif defined(NeXT_PDO)
# include <Foundation/NSFileHandle.h>
# include <Foundation/NSNotification.h>
#endif

#define cWin ((gswindow_device_t*)generic.cachedWindow)

#if 0
// NumLock's mask (it depends on the keyboard mapping)
static unsigned int _num_lock_mask;

// Modifier state
static char _shift_pressed = 0;
static char _control_pressed = 0;
static char _command_pressed = 0;
static char _alt_pressed = 0;
static char _help_pressed = 0;

/*
Keys used for the modifiers (you may set them with user preferences).
Note that the first and second key sym for a modifier must be different.
Otherwise, the _*_pressed tracking will be confused.
*/
static KeySym _control_keysyms[2];
static KeySym _command_keysyms[2];
static KeySym _alt_keysyms[2];
static KeySym _help_keysyms[2];

static BOOL _is_keyboard_initialized = NO;
static BOOL _mod_ignore_shift = NO;

static BOOL next_event_is_a_keyrepeat;
#endif

void __objc_xgcontextevent_linking (void)
{
}


#ifdef XSHM
@interface NSGraphicsContext (SharedMemory)
-(void) gotShmCompletion: (Drawable)d;
@end
#endif

@interface HeadlessServer (Private)
- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode;
- (void) setupRunLoopInputSourcesForMode: (NSString*)mode;
- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode;
- (int) HeadlessErrorHandler: (Display*)display : (XErrorEvent*)err;
- (void) processEvent: (XEvent *) event;
- (NSEvent *)_handleTakeFocusAtom: (XEvent)xEvent
		       forContext: (NSGraphicsContext *)gcontext;
@end


int
HeadlessErrorHandler(Display *display, XErrorEvent *err)
{
  HeadlessServer *ctxt = (HeadlessServer*)GSCurrentServer();

  return [ctxt HeadlessErrorHandler: display : err];
}

#if 0
static NSEvent*process_key_event (XEvent* xEvent, HeadlessServer* ctxt,
  NSEventType eventType, NSMutableArray *event_queue);

static unichar process_char (KeySym keysym, unsigned *eventModifierFlags);

static unsigned process_modifier_flags(unsigned int state);

static void initialize_keyboard (void);

static void set_up_num_lock (void);

// checks whether a GNUstep modifier (key_sym) is pressed when we're only able
// to check whether X keycodes are pressed in xEvent->xkeymap;
static int check_modifier (XEvent *xEvent, KeySym key_sym)
{
  char *key_vector;
  int by,bi;
  int key_code = XKeysymToKeycode(xEvent->xkeymap.display, key_sym);

  if (key_code != NoSymbol)
    {
      by = key_code / 8;
      bi = key_code % 8;
      key_vector = xEvent->xkeymap.key_vector;
      return (key_vector[by] & (1 << bi));
    }
  return 0;
}
#endif

@interface HeadlessServer (WindowOps)
- (void) styleoffsets: (float *) l : (float *) r : (float *) t : (float *) b
		     : (unsigned int) style : (Window) win;
- (NSRect) _XWinRectToOSWinRect: (NSRect)r for: (void*)windowNumber;
@end

@implementation HeadlessServer (EventOps)

- (int) HeadlessErrorHandler: (Display*)display : (XErrorEvent*)err
{
  return 0;
}

- (void) setupRunLoopInputSourcesForMode: (NSString*)mode
{
}

#if LIB_FOUNDATION_LIBRARY
- (void) activity: (NSPosixFileActivities)activity
posixFileDescriptor: (NSPosixFileDescriptor*)fileDescriptor
{
  [self receivedEvent: 0 type: 0 extra: 0 forMode: nil];
}
#elif defined(NeXT_PDO)
- (void) activityOnFileHandle: (NSNotification*)notification
{
  id fileDescriptor = [notification object];
  id runLoopMode = [[NSRunLoop currentRunLoop] currentMode];

  [fileDescriptor waitForDataInBackgroundAndNotifyForModes:
	[NSArray arrayWithObject: runLoopMode]];
  [self receivedEvent: 0 type: 0 extra: 0 forMode: nil];
}
#endif

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  *trigger = YES;        //  Should trigger this event
  return YES;
}

- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
}

/*
 */
- (NSPoint) _XPointToOSPoint: (NSPoint)x for: (void*)window
{
  return NSMakePoint(0, 0);
}


- (void) processEvent: (XEvent *) event
{
  return;
}

/*
 * WM is asking us to take the keyboard focus
 */
- (NSEvent *)_handleTakeFocusAtom: (XEvent)xEvent
		       forContext: (NSGraphicsContext *)gcontext
{
  return nil;
}

#if 0
// Return the key_sym corresponding to the user defaults string given,
// or fallback if no default is registered.
static KeySym key_sym_from_defaults (Display *display, NSUserDefaults *defaults,
		       NSString *keyDefaultKey, KeySym fallback)
{
  return fallback;
}

// This function should be called before any keyboard event is dealed with.
static void initialize_keyboard (void)
{
  _is_keyboard_initialized = YES;
}


static void set_up_num_lock (void)
{
  return;
}

static BOOL keysym_is_X_modifier (KeySym keysym)
{
  return NO;
}

static NSEvent* process_key_event (XEvent* xEvent, HeadlessServer* context, NSEventType eventType, NSMutableArray *event_queue)
{
  return nil;
}

static unichar process_char (KeySym keysym, unsigned *eventModifierFlags)
{
  return 0;
}

// process_modifier_flags() determines which modifier keys (Command, Control,
// Shift,  and so forth) were held down while the event occured.
static unsigned int process_modifier_flags(unsigned int state)
{
  return 0;
}
#endif

- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode
{
  return nil;
}

/* Drag and Drop */
- (id <NSDraggingInfo>)dragInfo
{
  return nil;
}

@end

@implementation HeadlessServer (XSync)
- (BOOL) xSyncMap: (void*)windowHandle
{
  return NO;
}
@end

@implementation HeadlessServer (X11Ops)

/*
 * Return mouse location in base coords ignoring the event loop
 */
- (NSPoint) mouselocation
{
  return [self mouseLocationOnScreen: defScreen window: NULL];
}

- (NSPoint) mouseLocationOnScreen: (int)screen window: (int *)win
{
  return NSMakePoint(0, 0);
}

- (NSEvent*) getEventMatchingMask: (unsigned)mask
		       beforeDate: (NSDate*)limit
			   inMode: (NSString*)mode
			  dequeue: (BOOL)flag
{
  [self receivedEvent: 0 type: 0 extra: 0 forMode: nil];
  return [super getEventMatchingMask: mask
			  beforeDate: limit
			      inMode: mode
			     dequeue: flag];
}

- (void) discardEventsMatchingMask: (unsigned)mask
		       beforeEvent: (NSEvent*)limit
{
  [self receivedEvent: 0 type: 0 extra: 0 forMode: nil];
  [super discardEventsMatchingMask: mask
		       beforeEvent: limit];
}

@end

@implementation HeadlessServer (TimeKeeping)
// Sync time with X server every 10 seconds
#define MAX_TIME_DIFF 10
// Regard an X time stamp as valid for half a second
#define OUT_DATE_TIME_DIFF 0.5

- (void) setLastTime: (Time)last
{
  if (generic.lastTimeStamp == 0
      || generic.baseXServerTime + MAX_TIME_DIFF * 1000 < last)
    {
      // We have not sync'ed with the clock for at least
      // MAX_TIME_DIFF seconds ... so we do it now.
      generic.lastTimeStamp = [NSDate timeIntervalSinceReferenceDate];
      generic.baseXServerTime = last;
    }
  else
    {
      // Optimisation to compute the new time stamp instead.
      generic.lastTimeStamp += (last - generic.lastTime) / 1000.0;
    }

  generic.lastTime = last;
}

- (Time) lastTime
{
  // In the case of activation via DO the lastTime is outdated and cannot be used.
  if (generic.lastTimeStamp == 0
      || ((generic.lastTimeStamp + OUT_DATE_TIME_DIFF)
	  < [NSDate timeIntervalSinceReferenceDate]))
    {
      return [[NSDate date] timeIntervalSince1970];
    }
  else
    {
      return generic.lastTime;
    }
}

@end
