/* Timers while a window is moved or sized (Source/win32/w32_movesize.m).
 *
 * Moving or sizing a window runs Windows' own modal loop inside
 * DefWindowProc until the drag ends, so the run loop doesn't run: timers
 * stopped and nothing was redisplayed for the whole drag.  The backend now
 * runs a Win32 timer for the length of the loop that fires the run loop's
 * due timers.  A timer that starts a nested event loop (a modal panel)
 * cancels the drag first, so the nested loop doesn't take the drag's input
 * from under Windows' loop.
 *
 * The test posts the window WM_SYSCOMMAND SC_MOVE (a keyboard move, so no
 * mouse is needed) from a second thread, which watches the GUI thread's
 * GUI_INMOVESIZE flag, counts a default-mode timer's ticks for a second
 * inside the loop, and ends the loop with Escape.  It skips when Windows
 * doesn't enter the loop (no interactive desktop).
 *
 * win32 backend only: it skips on every other backend.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_win32) \
  && BUILD_SERVER == SERVER_win32

#import <AppKit/AppKit.h>
#define WIN32_LEAN_AND_MEAN 1
#include <windows.h>

static HWND window = NULL;
static DWORD guiThread = 0;
static volatile LONG ticks = 0;
static volatile LONG done = 0;
static volatile LONG modalWanted = 0;
static volatile LONG modalRuns = 0;
static volatile LONG modalReturned = 0;

/* What the driving thread saw. */
static BOOL entered = NO;
static LONG ticksInLoop = 0;
static BOOL stillInAfterSecond = NO;
static BOOL dragOverAfterModal = NO;
static BOOL endedOnEscape = NO;

static BOOL
InMoveSize(void)
{
  GUITHREADINFO info;

  memset(&info, 0, sizeof(info));
  info.cbSize = sizeof(info);
  if (GetGUIThreadInfo(guiThread, &info) == 0)
    {
      return NO;
    }
  return (info.flags & GUI_INMOVESIZE) ? YES : NO;
}

static BOOL
WaitForMoveSize(BOOL wanted, int milliseconds)
{
  int i;

  for (i = 0; i < milliseconds / 10; i++)
    {
      if (InMoveSize() == wanted)
        {
          return YES;
        }
      Sleep(10);
    }
  return (InMoveSize() == wanted);
}

@interface Driver : NSObject
- (void) tick: (NSTimer *)timer;
- (void) stopPanel: (NSTimer *)timer;
- (void) drive: (id)modal;
@end

@implementation Driver

- (void) stopPanel: (NSTimer *)timer
{
  /* -stopModal takes effect when the modal loop next gets an event, so
     give it one. */
  [NSApp stopModal];
  [NSApp postEvent: [NSEvent otherEventWithType: NSApplicationDefined
                                       location: NSZeroPoint
                                  modifierFlags: 0
                                      timestamp: 0
                                   windowNumber: 0
                                        context: nil
                                        subtype: 0
                                          data1: 0
                                          data2: 0]
           atStart: NO];
}

- (void) tick: (NSTimer *)timer
{
  InterlockedIncrement(&ticks);
  /* Only from inside the move loop: without timers there, the panel
     would open after the drag instead and prove nothing. */
  if (modalWanted && modalRuns == 0 && InMoveSize())
    {
      NSPanel *panel;
      NSTimer *stop;

      InterlockedIncrement(&modalRuns);
      panel = [[NSPanel alloc] initWithContentRect: NSMakeRect(300, 300, 200, 80)
                                         styleMask: NSTitledWindowMask
                                           backing: NSBackingStoreBuffered
                                             defer: NO];
      stop = [NSTimer timerWithTimeInterval: 0.3
                                     target: self
                                   selector: @selector(stopPanel:)
                                   userInfo: nil
                                    repeats: NO];
      [[NSRunLoop currentRunLoop] addTimer: stop
                                   forMode: NSModalPanelRunLoopMode];
      [NSApp runModalForWindow: panel];
      [panel orderOut: nil];
      RELEASE(panel);
      InterlockedIncrement(&modalReturned);
    }
}

- (void) drive: (id)modal
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  LONG before;
  int i;

  Sleep(300);
  PostMessage(window, WM_SYSCOMMAND, SC_MOVE, 0);
  entered = WaitForMoveSize(YES, 2000);
  if (entered)
    {
      if (modal != nil)
        {
          modalWanted = 1;
          for (i = 0; i < 300 && modalReturned == 0; i++)
            {
              Sleep(10);
            }
          modalWanted = 0;
          Sleep(200);
          dragOverAfterModal = (InMoveSize() == NO);
        }
      else
        {
          before = ticks;
          Sleep(1000);
          ticksInLoop = ticks - before;
          stillInAfterSecond = InMoveSize();
        }
      PostMessage(window, WM_KEYDOWN, VK_ESCAPE, 0);
      PostMessage(window, WM_KEYUP, VK_ESCAPE, 0);
      endedOnEscape = WaitForMoveSize(NO, 2000);
      if (endedOnEscape == NO)
        {
          /* Leave no drag behind for the next set. */
          PostMessage(window, WM_CANCELMODE, 0, 0);
          WaitForMoveSize(NO, 2000);
        }
    }
  InterlockedExchange(&done, 1);
  PostMessage(window, WM_NULL, 0, 0);
  [pool drain];
}

@end

/* Runs one drag in the default mode, with a timer ticking every 20 ms. */
static void
RunDrag(Driver *driver, BOOL modal)
{
  NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 15.0];
  NSTimer *timer;

  ticks = 0;
  done = 0;
  modalWanted = 0;
  modalRuns = 0;
  modalReturned = 0;
  entered = NO;
  timer = [NSTimer timerWithTimeInterval: 0.02
                                  target: driver
                                selector: @selector(tick:)
                                userInfo: nil
                                 repeats: YES];
  [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSDefaultRunLoopMode];
  [NSThread detachNewThreadSelector: @selector(drive:)
                           toTarget: driver
                         withObject: (modal ? (id)@"modal" : nil)];
  while (done == 0 && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                               beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
  [timer invalidate];
}

int
main(void)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  Driver *driver;
  NSWindow *win;

  [NSApplication sharedApplication];
  guiThread = GetCurrentThreadId();
  driver = [Driver new];
  win = [[NSWindow alloc] initWithContentRect: NSMakeRect(200, 200, 300, 200)
                                    styleMask: (NSTitledWindowMask | NSResizableWindowMask)
                                      backing: NSBackingStoreBuffered
                                        defer: NO];
  [win setTitle: @"sizemove"];
  [win orderFront: nil];
  window = (HWND)(intptr_t)[win windowNumber];

  START_SET("timers during a move loop")
  RunDrag(driver, NO);
  if (entered == NO)
    {
      SKIP("Windows didn't enter the move loop (no interactive desktop?)")
    }
  PASS(stillInAfterSecond, "the window stays in the move loop for the second")
  PASS(ticksInLoop >= 25,
    "a 20 ms default-mode timer fires during the move loop (%ld ticks in 1 s)",
    (long)ticksInLoop)
  PASS(endedOnEscape, "Escape still ends the move loop")
  END_SET("timers during a move loop")

  START_SET("a modal panel started by a timer during a move loop")
  RunDrag(driver, YES);
  if (entered == NO)
    {
      SKIP("Windows didn't enter the move loop (no interactive desktop?)")
    }
  PASS(modalRuns == 1, "the timer runs the modal panel during the drag")
  PASS(modalReturned == 1, "the modal panel returns")
  PASS(dragOverAfterModal, "the drag has ended once the modal panel returns")
  PASS(endedOnEscape, "no move loop is left running")
  END_SET("a modal panel started by a timer during a move loop")

  [win close];
  RELEASE(driver);
  [pool drain];
  return 0;
}

#else

int
main(void)
{
  START_SET("timers during a move loop")
  SKIP("win32 backend tests: the win32 backend isn't being built")
  END_SET("timers during a move loop")
  return 0;
}

#endif
