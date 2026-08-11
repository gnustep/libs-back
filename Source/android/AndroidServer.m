/*
   AndroidServer.m

   Copyright (C) 2026 Free Software Foundation, Inc.

   Author: Todd White <todd.white@thalion.global>
   Date: August 2026

   This file is part of the GNU Objective C Backend Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#include "config.h"

#include <signal.h>
#include <stdint.h>
#include <stdlib.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSScreen.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSGraphicsContext.h>
#include <AppKit/NSText.h>
#include <AppKit/NSWindow.h>
#include <AppKit/DPSOperators.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSValue.h>

#include "android/AndroidServer.h"
#include "cairo/CairoSurface.h"
#include "cairo/AndroidCairoSurface.h"

/* Terminate cleanly if we get a signal to do so. */
static void
terminate(int sig)
{
  if (nil != NSApp)
    {
      [NSApp terminate: NSApp];
    }
  else
    {
      exit(1);
    }
}

/* Parse "320x640" into a size, or NSZeroSize. */
static NSSize
sizeFromString(NSString *s)
{
  NSArray *parts;

  if (s == nil)
    {
      return NSZeroSize;
    }
  parts = [s componentsSeparatedByString: @"x"];
  if ([parts count] != 2)
    {
      return NSZeroSize;
    }
  return NSMakeSize([[parts objectAtIndex: 0] doubleValue],
		    [[parts objectAtIndex: 1] doubleValue]);
}

@implementation AndroidServer

+ (void) initializeBackend
{
  NSDebugLog(@"Initializing GNUstep android backend.");
  [GSDisplayServer setDefaultServerClass: [AndroidServer class]];
  signal(SIGTERM, terminate);
  signal(SIGINT, terminate);
}

- (id) initWithAttributes: (NSDictionary *)info
{
  self = [super initWithAttributes: info];
  if (self != nil)
    {
      _windows = NSCreateMapTable(NSIntegerMapKeyCallBacks,
				  NSNonOwnedPointerMapValueCallBacks, 8);
      _lastWindowId = 0;
      _screenBounds = NSZeroRect;
      _screenBoundsKnown = NO;
      _screenWarningIssued = NO;
      _mouseLocation = NSZeroPoint;
    }
  return self;
}

- (void) dealloc
{
  if (_windows != NULL)
    {
      NSFreeMapTable(_windows);
      _windows = NULL;
    }
  [super dealloc];
}

- (struct AndroidWindow *) _windowWithId: (int)win
{
  if (_windows == NULL || win <= 0)
    {
      return NULL;
    }
  return (struct AndroidWindow *) NSMapGet(_windows, (void *)(intptr_t)win);
}

/* The server draws no title bar, resize corner or border, so the gui library
 * has to draw them.  GSDisplayServer answers YES by default. */
- (BOOL) handlesWindowDecorations
{
  return NO;
}

/*
 * Screens
 */

- (NSArray *) screenList
{
  return [NSArray arrayWithObject: [NSNumber numberWithInt: 0]];
}

/* The screen size comes from the GSAndroidScreenSize default, because a process
 * with no Activity cannot ask Android for it: AConfiguration_getScreenWidthDp
 * needs an AConfiguration, whose only source other than AConfiguration_new is
 * AConfiguration_fromAssetManager, and the only documented way to obtain an
 * AAssetManager is AAssetManager_fromJava, which needs a JNIEnv and a Java
 * AssetManager.  ANativeWindow_getWidth has the same problem: the only
 * documented producer of an ANativeWindow is ANativeWindow_fromSurface, which
 * needs a Java Surface.
 *
 * When the default is not set this logs once and reports an empty screen.
 */
- (NSRect) boundsForScreen: (int)screen
{
  NSSize size;

  if (screen != 0)
    {
      return NSZeroRect;
    }
  if (_screenBoundsKnown)
    {
      return _screenBounds;
    }
  /* The activity knows the real size, so the default below is the answer only
   * for a process that has no activity at all -- which is every test but the
   * ones that make a window of their own, and no application. */
  if (_activityWindow != NULL)
    {
      int left, top, right, bottom;
      int width = ANativeWindow_getWidth(_activityWindow);
      int height = ANativeWindow_getHeight(_activityWindow);

      /* The screen a window may use is the surface less what the system bars
       * take, as the x11 server reports the work area rather than the whole
       * display.  A window laid out under a bar cannot be seen and cannot be
       * pressed, because the bar takes the press. */
      [self _systemBarInsets: &left : &top : &right : &bottom];
      _screenBounds = NSMakeRect(left, bottom,
	width - left - right, height - top - bottom);
      if (NSWidth(_screenBounds) <= 0.0 || NSHeight(_screenBounds) <= 0.0)
	{
	  _screenBounds = NSMakeRect(0, 0, width, height);
	}
      NSDebugLLog(@"NSEvent", @"android screen: surface %dx%d insets"
	@" %d,%d,%d,%d giving %@", width, height, left, top, right, bottom,
	NSStringFromRect(_screenBounds));
      /* The bars are not settled when the first window is made: the insets
       * arrive after the view has been laid out, so the answer is worked out
       * again each time rather than kept. */
      return _screenBounds;
    }

  size = sizeFromString([[NSUserDefaults standardUserDefaults]
			  stringForKey: @"GSAndroidScreenSize"]);
  if (NSEqualSizes(size, NSZeroSize))
    {
      if (NO == _screenWarningIssued)
	{
	  NSLog(@"AndroidServer: no screen size available. Set the "
		@"GSAndroidScreenSize default (for example 320x640); the "
		@"screen is reported as empty until then.");
	  _screenWarningIssued = YES;
	}
      return NSZeroRect;
    }

  _screenBounds = NSMakeRect(0, 0, size.width, size.height);
  _screenBoundsKnown = YES;
  return _screenBounds;
}

/* What the status bar, the navigation bar and a display cutout take from the
 * surface, in pixels.
 *
 * An activity is given the whole surface and the system draws its bars over
 * it, so anything drawn underneath one cannot be seen and a press on it never
 * arrives: the bar takes it.  The area left is what the platform calls the
 * system bar insets, and it is what a window may use.
 *
 * The NDK reports none of this, so the view the activity is given is asked
 * through JNI.  Everything answers zero without a JNI context or an activity,
 * which is what a test binary has.
 */
- (BOOL) _systemBarInsets: (int *)left : (int *)top : (int *)right
			 : (int *)bottom
{
  JNIEnv	*env = _jniEnv;
  jobject	 decor = NULL;
  jobject	 insets = NULL;
  jobject	 bars = NULL;
  jclass	 cls;
  BOOL		 ok = NO;

  *left = *top = *right = *bottom = 0;
  if (env == NULL || _activity == NULL || _activity->clazz == NULL)
    {
      return NO;
    }

  cls = (*env)->GetObjectClass(env, _activity->clazz);
  {
    jmethodID	getWindow = (*env)->GetMethodID(env, cls,
      "getWindow", "()Landroid/view/Window;");
    jobject	window = (getWindow != NULL)
      ? (*env)->CallObjectMethod(env, _activity->clazz, getWindow) : NULL;

    if (window != NULL)
      {
	jclass	  wcls = (*env)->GetObjectClass(env, window);
	jmethodID getDecor = (*env)->GetMethodID(env, wcls,
	  "getDecorView", "()Landroid/view/View;");

	if (getDecor != NULL)
	  {
	    decor = (*env)->CallObjectMethod(env, window, getDecor);
	  }
	(*env)->DeleteLocalRef(env, wcls);
	(*env)->DeleteLocalRef(env, window);
      }
  }
  (*env)->DeleteLocalRef(env, cls);

  if (decor != NULL)
    {
      jclass	 vcls = (*env)->GetObjectClass(env, decor);
      jmethodID	 getRoot = (*env)->GetMethodID(env, vcls,
	"getRootWindowInsets", "()Landroid/view/WindowInsets;");

      if (getRoot != NULL)
	{
	  insets = (*env)->CallObjectMethod(env, decor, getRoot);
	}
      (*env)->DeleteLocalRef(env, vcls);
    }

  if (insets != NULL)
    {
      jclass	types = (*env)->FindClass(env, "android/view/WindowInsets$Type");
      jint	mask = 0;

      if (types != NULL)
	{
	  jmethodID systemBars = (*env)->GetStaticMethodID(env, types,
	    "systemBars", "()I");
	  jmethodID ime = (*env)->GetStaticMethodID(env, types, "ime", "()I");

	  if (systemBars != NULL)
	    {
	      mask = (*env)->CallStaticIntMethod(env, types, systemBars);
	    }
	  /* The input method covers the foot of the surface while it is up, and
	   * a window laid out under it cannot be seen. */
	  if (ime != NULL)
	    {
	      mask |= (*env)->CallStaticIntMethod(env, types, ime);
	    }
	  (*env)->DeleteLocalRef(env, types);
	}

      if (mask != 0)
	{
	  jclass     icls = (*env)->GetObjectClass(env, insets);
	  jmethodID  get = (*env)->GetMethodID(env, icls,
	    "getInsets", "(I)Landroid/graphics/Insets;");

	  if (get != NULL)
	    {
	      bars = (*env)->CallObjectMethod(env, insets, get, mask);
	    }
	  (*env)->DeleteLocalRef(env, icls);
	}
    }

  if (bars != NULL)
    {
      jclass bcls = (*env)->GetObjectClass(env, bars);

      *left = (*env)->GetIntField(env, bars,
	(*env)->GetFieldID(env, bcls, "left", "I"));
      *top = (*env)->GetIntField(env, bars,
	(*env)->GetFieldID(env, bcls, "top", "I"));
      *right = (*env)->GetIntField(env, bars,
	(*env)->GetFieldID(env, bcls, "right", "I"));
      *bottom = (*env)->GetIntField(env, bars,
	(*env)->GetFieldID(env, bcls, "bottom", "I"));
      ok = YES;
      (*env)->DeleteLocalRef(env, bcls);
      (*env)->DeleteLocalRef(env, bars);
    }

  if (insets != NULL) (*env)->DeleteLocalRef(env, insets);
  if (decor != NULL)  (*env)->DeleteLocalRef(env, decor);
  (*env)->ExceptionClear(env);

  return ok;
}

/* Tell the gui library when the screen a window may use has changed.
 *
 * The bars are not settled when the first window is made, so the screen the
 * application laid itself out to is not the screen it ends up with; a rotation
 * changes it again.  A window that has already been placed is not moved by
 * anything else, so it keeps a position worked out for a screen that is gone.
 *
 * This is what the x11 server does when RandR reports the screen changed: the
 * cached screens are dropped and the notification is posted, and NSWindow
 * moves itself onto the new frame.
 */
- (void) _noticeScreenChange
{
  NSRect now;

  if (_activityWindow == NULL || _inScreenChange == YES)
    {
      return;
    }
  now = [self boundsForScreen: 0];
  if (NSEqualRects(now, _announcedScreen))
    {
      return;
    }

  /* Moving the windows orders them, which arrives back here. */
  _inScreenChange = YES;
  _announcedScreen = now;
  NSDebugLLog(@"NSEvent", @"android screen changed to %@",
    NSStringFromRect(now));
  [NSScreen resetScreens];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSApplicationDidChangeScreenParametersNotification
		  object: NSApp];

  /* A window is only moved by that notice, never resized, so a screen that has
   * shrunk at the foot moves nothing: the origin rises by what the height
   * falls.  The window that has the screen is given the new one. */
  {
    struct AndroidWindow *window = [self _windowWithId: _boundWindow];

    if (window != NULL && NSWidth(now) > 0.0 && NSHeight(now) > 0.0
      && !NSEqualRects(window->frame, now))
      {
	[self placewindow: now : _boundWindow];
      }
  }
  _inScreenChange = NO;
}

/* The image surface is 32 bits per pixel with 8 bits per component in three
 * components, which is what NSBestDepth is asked for here. */
- (NSWindowDepth) windowDepthForScreen: (int)screen
{
  if (screen != 0)
    {
      return 0;
    }
  return NSBestDepth(NSCalibratedRGBColorSpace, 8, 24, NO, NULL);
}

/* The caller owns the returned list and frees it with NSZoneFree, which is what
 * the x11 server does, so this must be allocated and not static: freeing a
 * static array aborts the process with "Scudo ERROR: misaligned pointer when
 * deallocating" on Android. */
- (const NSWindowDepth *) availableDepthsForScreen: (int)screen
{
  NSWindowDepth *depths;

  if (screen != 0)
    {
      return NULL;
    }
  depths = NSZoneMalloc(NSDefaultMallocZone(), sizeof(NSWindowDepth) * 2);
  depths[0] = NSBestDepth(NSCalibratedRGBColorSpace, 8, 24, NO, NULL);
  depths[1] = 0;   /* zero-terminated */
  return depths;
}

/* The gui library scales the whole interface by this value, so the device's real
 * density would rescale every window.  The x11 server also reports 72. */
- (NSSize) resolutionForScreen: (int)screen
{
  return NSMakeSize(72, 72);
}

- (NSImage *) contentsOfScreen: (int)screen inRect: (NSRect)rect
{
  return nil;
}

/*
 * Windows
 */

- (int) window: (NSRect)frame
	      : (NSBackingStoreType)type
	      : (unsigned int)style
	      : (int)screen
{
  struct AndroidWindow *window;

  /* A window always has an extent.  X refuses a zero-area window and clamps,
   * and the rest of the gui library assumes a window it created can be drawn
   * into; a 0x0 frame would also leave the cairo surface unmade. */
  if (frame.size.width < 1.0)
    {
      frame.size.width = 1.0;
    }
  if (frame.size.height < 1.0)
    {
      frame.size.height = 1.0;
    }

  window = (struct AndroidWindow *)
    NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(struct AndroidWindow));
  window->window_id = ++_lastWindowId;
  window->frame = frame;
  window->backing = type;
  window->style = style;
  window->screen = screen;
  window->level = NSNormalWindowLevel;
  window->mapped = NO;
  window->surface = nil;

  NSMapInsert(_windows, (void *)(intptr_t)window->window_id, window);
  [self _setWindowOwnedByServer: window->window_id];
  return window->window_id;
}

- (void) termwindow: (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  if (window == NULL)
    {
      return;
    }
  window->surface = nil;
  NSMapRemove(_windows, (void *)(intptr_t)win);
  NSZoneFree(NSDefaultMallocZone(), window);
}

- (void *) windowDevice: (int)win
{
  return (void *)[self _windowWithId: win];
}

- (void *) serverDevice
{
  return NULL;
}

- (NSRect) windowbounds: (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  return (window == NULL) ? NSZeroRect : window->frame;
}

/* A move or a resize sends the window an AppKit-defined event, as the x11 server
 * does.  There is no server round trip, so the new frame is final and the event
 * is sent immediately. */
- (void) placewindow: (NSRect)frame : (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];
  NSWindow		*nswin;
  NSEvent		*e;
  BOOL			 resized, moved;

  if (window == NULL)
    {
      NSLog(@"AndroidServer: placing invalid window %d", win);
      return;
    }
  if (NSEqualRects(frame, window->frame))
    {
      return;
    }

  resized = !NSEqualSizes(frame.size, window->frame.size);
  moved = !NSEqualPoints(frame.origin, window->frame.origin);
  window->frame = frame;

  if (window->surface != nil && resized)
    {
      [window->surface setSize: frame.size];
    }

  nswin = GSWindowWithNumber(win);
  if (resized)
    {
      e = [NSEvent otherEventWithType: NSAppKitDefined
			     location: frame.origin
			modifierFlags: 0
			    timestamp: 0
			 windowNumber: win
			      context: GSCurrentContext()
			      subtype: GSAppKitWindowResized
				data1: frame.size.width
				data2: frame.size.height];
      [nswin sendEvent: e];
    }
  else if (moved)
    {
      e = [NSEvent otherEventWithType: NSAppKitDefined
			     location: NSZeroPoint
			modifierFlags: 0
			    timestamp: 0
			 windowNumber: win
			      context: GSCurrentContext()
			      subtype: GSAppKitWindowMoved
				data1: frame.origin.x
				data2: frame.origin.y];
      [nswin sendEvent: e];
    }
}

- (void) movewindow: (NSPoint)loc : (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  if (window == NULL)
    {
      return;
    }
  window->frame.origin = loc;
}

- (void) orderwindow: (int)op : (int)otherWin : (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  if (window == NULL)
    {
      return;
    }
  window->mapped = (op != NSWindowOut);
  if (window->mapped == YES)
    {
      window->ordered = ++_orderSeq;
      [self _noticeScreenChange];
    }

  /* An activity is given one surface and an application makes as many windows
   * as it likes, so the surface goes to the one being shown.  A menu and an
   * application icon are windows too and carry no title bar, which is what
   * separates them from the window a person means by the application's. */
  if (_activityWindow != NULL)
    {
      if (win != _boundWindow && [self _isCandidate: window] == YES)
	{
	  [self _bindActivityTo: window];
	}
      else if (window->mapped == NO && win == _boundWindow)
	{
	  struct AndroidWindow	*next = [self _frontmostCandidate];

	  [self setNativeWindow: NULL forWindow: win];
	  _boundWindow = 0;
	  /* A panel takes the surface from the window under it, so taking the
	   * panel off has to give it back: an activity holding a surface
	   * nothing draws into shows whatever was on it when the panel went. */
	  if (next != NULL)
	    {
	      [self _bindActivityTo: next];
	    }
	}
    }
}

/* Back to front: the lowest level first, and within a level the one ordered in
 * longest ago.  This is the order the windows are written in. */
static int
compare_windows(const void *a, const void *b)
{
  struct AndroidWindow *l = *(struct AndroidWindow **)a;
  struct AndroidWindow *r = *(struct AndroidWindow **)b;

  if (l->level != r->level)
    {
      return (l->level < r->level) ? -1 : 1;
    }
  if (l->ordered != r->ordered)
    {
      return (l->ordered < r->ordered) ? -1 : 1;
    }
  return 0;
}

/* Write every window that is on screen into the activity's surface.
 *
 * An activity is given one surface, so a window cannot be given one of its
 * own.  The region is locked once and each window on screen is written into it
 * in turn, back to front, which is what puts a menu or a panel over the window
 * it belongs to.  What no window covers is black.
 *
 * The rectangle is in screen coordinates, y up from the bottom.
 */
- (void) _compositeRect: (NSRect)rect
{
  ANativeWindow_Buffer	  buffer;
  ARect			  dirty;
  struct AndroidWindow	**order;
  NSMapEnumerator	  e;
  void			 *key, *value;
  unsigned		  count = 0;
  unsigned		  i;
  int			  screenHeight;
  int			  x, y, x0, y0, x1, y1;

  if (_activityWindow == NULL)
    {
      return;
    }
  screenHeight = ANativeWindow_getHeight(_activityWindow);
  if (screenHeight <= 0)
    {
      return;
    }

  /* The buffer counts its rows from the top, the screen from the bottom. */
  dirty.left = (int32_t)floor(NSMinX(rect));
  dirty.top = (int32_t)(screenHeight - ceil(NSMaxY(rect)));
  dirty.right = (int32_t)ceil(NSMaxX(rect));
  dirty.bottom = (int32_t)(screenHeight - floor(NSMinY(rect)));
  if (dirty.right <= dirty.left || dirty.bottom <= dirty.top)
    {
      return;
    }

  if (ANativeWindow_lock(_activityWindow, &buffer, &dirty) != 0)
    {
      NSDebugLLog(@"AndroidCairoSurface",
	@"the activity's window would not lock");
      return;
    }

  /* The window widens the region to what this buffer has to have written,
   * which is more than what changed: it hands out one of several buffers in
   * turn, so the one locked here holds a frame from some time ago. */
  x0 = dirty.left;
  y0 = dirty.top;
  x1 = dirty.right;
  y1 = dirty.bottom;
  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > buffer.width) x1 = buffer.width;
  if (y1 > buffer.height) y1 = buffer.height;

  NSDebugLLog(@"AndroidCairoSurface",
    @"composite: buffer %dx%d stride %d bits %p region %d,%d %d,%d",
    buffer.width, buffer.height, buffer.stride, buffer.bits,
    x0, y0, x1, y1);

  if (buffer.bits == NULL || buffer.stride < buffer.width)
    {
      ANativeWindow_unlockAndPost(_activityWindow);
      return;
    }

  for (y = y0; y < y1; y++)
    {
      uint32_t *d = (uint32_t *)((unsigned char *)buffer.bits
	+ (size_t)y * buffer.stride * 4);

      for (x = x0; x < x1; x++)
	{
	  d[x] = 0xff000000;
	}
    }

  order = (struct AndroidWindow **)
    NSZoneMalloc(NSDefaultMallocZone(),
      sizeof(struct AndroidWindow *) * (NSCountMapTable(_windows) + 1));
  e = NSEnumerateMapTable(_windows);
  while (NSNextMapEnumeratorPair(&e, &key, &value))
    {
      struct AndroidWindow *w = (struct AndroidWindow *)value;

      if (w != NULL && w->mapped == YES && w->surface != nil)
	{
	  order[count++] = w;
	}
    }
  NSEndMapTableEnumeration(&e);
  qsort(order, count, sizeof(struct AndroidWindow *), compare_windows);

  for (i = 0; i < count; i++)
    {
      GSAndroidBlitWindow(&buffer, [order[i]->surface surface],
	order[i]->frame, screenHeight, x0, y0, x1, y1);
    }
  NSZoneFree(NSDefaultMallocZone(), order);

  ANativeWindow_unlockAndPost(_activityWindow);
}

/* The window a person would be looking at: the highest level among those on
 * screen, and among those the one ordered in most recently. */
- (struct AndroidWindow *) _frontmostCandidate
{
  NSMapEnumerator	 e = NSEnumerateMapTable(_windows);
  struct AndroidWindow	*best = NULL;
  struct AndroidWindow	*window;
  void			*key;

  while (NSNextMapEnumeratorPair(&e, &key, (void **)&window) == YES)
    {
      if ([self _isCandidate: window] == NO)
	{
	  continue;
	}
      if (best == NULL
	|| window->level > best->level
	|| (window->level == best->level && window->ordered > best->ordered))
	{
	  best = window;
	}
    }
  NSEndMapTableEnumeration(&e);

  return best;
}

- (void) setwindowlevel: (int)level : (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  if (window != NULL)
    {
      window->level = level;
    }
}

- (int) windowlevel: (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  return (window == NULL) ? 0 : window->level;
}

- (int) windowdepth: (int)win
{
  return NSBestDepth(NSCalibratedRGBColorSpace, 8, 24, NO, NULL);
}

/* No decorations are drawn, so there are no insets.  -handlesWindowDecorations
 * answers NO, so the gui library draws its own and knows not to expect any. */
- (void) styleoffsets: (float *)l : (float *)r : (float *)t : (float *)b
		     : (unsigned int)style
{
  *l = *r = *t = *b = 0.0;
}

- (void) stylewindow: (unsigned int)style : (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  if (window != NULL)
    {
      window->style = style;
    }
}

- (void) windowbacking: (NSBackingStoreType)type : (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  if (window != NULL)
    {
      window->backing = type;
    }
}

/* Give the context a surface for this window.  GSSetDevice hands the window
 * record to the cairo context, which allocates the surface class the backend
 * was built with; the y offset is the window height because cairo's y axis
 * points down and AppKit's points up. */
- (void) setWindowdevice: (int)win forContext: (NSGraphicsContext *)ctxt
{
  struct AndroidWindow *window = [self _windowWithId: win];

  if (window == NULL)
    {
      NSLog(@"AndroidServer: setWindowdevice for unknown window %d", win);
      return;
    }

  GSSetDevice(ctxt, window, 0.0, NSHeight(window->frame));
  DPSinitmatrix(ctxt);
  DPSinitclip(ctxt);
}

/* Without an activity there is nothing to post to: the image surface the
 * context drew into is already the destination.  With one, the region that
 * changed is composited, which writes every window that covers it and not just
 * this one, because they share the activity's surface. */
- (void) flushwindowrect: (NSRect)rect : (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  if (window == NULL || window->surface == nil)
    {
      return;
    }

  if (_activityWindow == NULL)
    {
      [window->surface flush];
      return;
    }

  /* The rect arrives in the window's own coordinates; the composite works in
   * the screen's, and both count y up from the bottom. */
  [self _compositeRect: NSOffsetRect(rect,
    NSMinX(window->frame), NSMinY(window->frame))];
}

- (void) setNativeWindow: (ANativeWindow *)native forWindow: (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  if (window == NULL)
    {
      return;
    }

  window->native = native;
  if (window->surface != nil)
    {
      [(AndroidCairoSurface *)window->surface setNativeWindow: native];
    }

  /* The screen is whatever the window says it is once there is one, so the
   * cached answer has to be given up. */
  _screenBoundsKnown = NO;
}

- (ANativeWindow *) nativeWindowForWindow: (int)win
{
  struct AndroidWindow *window = [self _windowWithId: win];

  return (window == NULL) ? NULL : window->native;
}

/* Give the surface to one window and ask for it to be drawn again: whatever is
 * on that window was drawn before it had a surface, so none of it has reached
 * the screen. */
- (void) _bindActivityTo: (struct AndroidWindow *)window
{
  _boundWindow = window->window_id;

  /* The platform gives an application the screen, so the window that has the
   * surface is given the screen too: one smaller than it would sit in a corner
   * with black around it and no way for a person to move it.  This is what a
   * window manager does when it fullscreens a window, and -placewindow: is the
   * road that reaches AppKit, resizes the surface and lets the application lay
   * itself out again. */
  {
    NSRect screen = [self boundsForScreen: 0];

    if (NSWidth(screen) > 0.0 && NSHeight(screen) > 0.0
      && !NSEqualRects(window->frame, screen))
      {
	[self placewindow: screen : window->window_id];
      }
  }

  [self postEvent: [NSEvent otherEventWithType: NSAppKitDefined
				      location: NSZeroPoint
				 modifierFlags: 0
				     timestamp:
    [[NSDate date] timeIntervalSinceReferenceDate]
				  windowNumber: window->window_id
				       context: GSCurrentContext()
				       subtype: GSAppKitRegionExposed
					 data1: (int)NSWidth(window->frame)
					 data2: (int)NSHeight(window->frame)]
	 atStart: NO];
}

/* A window a person would call the application's: on screen, and carrying a
 * title bar, which a menu and an application icon do not. */
- (BOOL) _isCandidate: (struct AndroidWindow *)window
{
  return (window != NULL && window->mapped == YES
    && (window->style & NSTitledWindowMask) != 0) ? YES : NO;
}

- (void) setActivityWindow: (ANativeWindow *)native
{
  _activityWindow = native;
  /* The surface and the bars over it are both new, so what a window may use
   * has to be worked out again. */
  _screenBoundsKnown = NO;
  if (native != NULL)
    {
      [self _noticeScreenChange];
    }

  /* The composite writes 4 bytes for every pixel, so the surface has to hold
   * 4: an activity is given whatever format it was configured with, and a
   * narrower one is overrun by the row arithmetic rather than merely drawn
   * wrongly. */
  if (native != NULL)
    {
      ANativeWindow_setBuffersGeometry(native, 0, 0, WINDOW_FORMAT_RGBA_8888);
    }

  if (native == NULL)
    {
      /* The activity is giving its surface up.  Nothing may be posted to it
       * after this returns, so the binding goes now rather than when the
       * window is next ordered out. */
      if (_boundWindow != 0)
	{
	  [self setNativeWindow: NULL forWindow: _boundWindow];
	  _boundWindow = 0;
	}
      return;
    }

  /* A surface arriving is the other half: on a resume the application orders
   * nothing, so the window that was on screen has to be found again. */
  {
    struct AndroidWindow *window = [self _windowWithId: _boundWindow];
    NSMapEnumerator	  e;
    void		 *key;
    void		 *value;

    if ([self _isCandidate: window] == YES)
      {
	[self _bindActivityTo: window];
	return;
      }
    _boundWindow = 0;
    e = NSEnumerateMapTable(_windows);
    while (NSNextMapEnumeratorPair(&e, &key, &value) == YES)
      {
	if ([self _isCandidate: (struct AndroidWindow *)value] == YES)
	  {
	    [self _bindActivityTo: (struct AndroidWindow *)value];
	    break;
	  }
      }
    NSEndMapTableEnumeration(&e);
  }
}

- (ANativeWindow *) activityWindow
{
  return _activityWindow;
}

- (int) windowBoundToActivity
{
  return _boundWindow;
}

- (void) setJavaEnvironment: (JNIEnv *)env
{
  _jniEnv = env;
}

/* The activity reports a touch in the surface's own pixels, counted down from
 * its top; a window sits somewhere in that surface and its own coordinates
 * count up from its bottom.  The surface is not scaled to the window, so this
 * is a move of the origin and a flip, with no factor in it.
 */
- (NSPoint) _locationFor: (const AInputEvent *)event
		inWindow: (struct AndroidWindow *)window
{
  NSPoint point = [self _screenLocationFor: event];

  if (window == NULL)
    {
      return NSZeroPoint;
    }
  return NSMakePoint(point.x - NSMinX(window->frame),
    point.y - NSMinY(window->frame));
}

/* A key with no character of its own.  The platform's table answers nothing
 * for these and AppKit names them. */
static unichar
android_special_key(int32_t code)
{
  switch (code)
    {
      case AKEYCODE_DEL:         return NSBackspaceCharacter;
      case AKEYCODE_FORWARD_DEL: return NSDeleteCharacter;
      case AKEYCODE_ENTER:       return NSCarriageReturnCharacter;
      case AKEYCODE_TAB:         return NSTabCharacter;
      case AKEYCODE_ESCAPE:      return 0x1b;
      case AKEYCODE_DPAD_UP:     return NSUpArrowFunctionKey;
      case AKEYCODE_DPAD_DOWN:   return NSDownArrowFunctionKey;
      case AKEYCODE_DPAD_LEFT:   return NSLeftArrowFunctionKey;
      case AKEYCODE_DPAD_RIGHT:  return NSRightArrowFunctionKey;
      default:                   return 0;
    }
}

static NSUInteger
android_modifiers(int32_t meta)
{
  NSUInteger flags = 0;

  if (meta & AMETA_SHIFT_ON) flags |= NSShiftKeyMask;
  if (meta & AMETA_ALT_ON)   flags |= NSAlternateKeyMask;
  if (meta & AMETA_CTRL_ON)  flags |= NSControlKeyMask;
  return flags;
}

/* The flag a key of its own carries, or 0 for a key that is not a modifier. */
static NSUInteger
android_modifier_key(int32_t code)
{
  switch (code)
    {
      case AKEYCODE_SHIFT_LEFT:
      case AKEYCODE_SHIFT_RIGHT:  return NSShiftKeyMask;
      case AKEYCODE_ALT_LEFT:
      case AKEYCODE_ALT_RIGHT:    return NSAlternateKeyMask;
      case AKEYCODE_CTRL_LEFT:
      case AKEYCODE_CTRL_RIGHT:   return NSControlKeyMask;
      case AKEYCODE_META_LEFT:
      case AKEYCODE_META_RIGHT:   return NSCommandKeyMask;
      case AKEYCODE_CAPS_LOCK:    return NSAlphaShiftKeyMask;
      default:                    return 0;
    }
}

/* AppKit numbers the buttons 0 for the left, 1 for the right and 2 upwards for
 * the rest.  A touch reports no button, which is the left one. */
static int
android_button(int32_t state)
{
  if (state & AMOTION_EVENT_BUTTON_SECONDARY)      return 1;
  if (state & AMOTION_EVENT_BUTTON_STYLUS_PRIMARY) return 1;
  if (state & AMOTION_EVENT_BUTTON_TERTIARY)       return 2;
  return 0;
}

- (void) setActivity: (ANativeActivity *)activity
{
  _activity = activity;
}

/* Whether what has the keyboard's attention is something a person types into.
 *
 * Editing a text field makes the field editor the first responder, and the
 * field editor is itself an NSTextView, so both a field and a text view answer
 * to the one test.  A responder that is not editable is reading matter and
 * wants no keyboard.
 */
- (BOOL) _wantsKeyboard
{
  NSResponder *responder = [[NSApp keyWindow] firstResponder];

  if (NO == [responder isKindOfClass: [NSText class]])
    {
      return NO;
    }
  return [(NSText *)responder isEditable];
}

/* A device with no keyboard of its own has one on the screen, and it is shown
 * only while something is being edited.
 *
 * AppKit says when a responder starts and stops being the first, but says it to
 * nothing outside the gui library: -[NSTextInputContext activate] is where that
 * would arrive and it is an empty method that nothing calls.  So the question
 * is asked again after each event, which is the point at which the answer can
 * have changed: a press moves the first responder, and so does a key that
 * ends editing.
 */
/* Whether the press that has just been handled landed in the view being
 * edited.  hitTest: wants the point in the window's own coordinates, which is
 * what a press is given.
 */
- (BOOL) _pressWasInEditor
{
  NSWindow	*window = [NSApp keyWindow];
  NSResponder	*responder = [window firstResponder];
  NSView	*hit;

  if (NO == [responder isKindOfClass: [NSText class]]
    || NO == [(NSText *)responder isEditable])
    {
      return NO;
    }
  hit = [[window contentView] hitTest: _mouseLocation];
  if (hit == nil)
    {
      return NO;
    }

  if (hit == (NSView *)responder || [hit isDescendantOf: (NSView *)responder])
    {
      return YES;
    }

  /* Editing a field makes the field editor the first responder, and a press
   * lands on the field rather than on the editor inside it.  A field editor
   * names the control it is editing as its delegate. */
  {
    id owner = [(NSText *)responder delegate];

    if ([owner isKindOfClass: [NSView class]]
      && (hit == (NSView *)owner || [hit isDescendantOf: (NSView *)owner]))
      {
	return YES;
      }
  }
  return NO;
}

- (void) _updateKeyboard: (NSNumber *)afterPress
{
  BOOL wants;

  if (_activity == NULL)
    {
      return;
    }
  wants = [self _wantsKeyboard];

  /* A press outside the view being edited ends the editing, which is what a
   * person means by it: the keyboard goes and the window grows back.  Without
   * this a field stays the first responder for as long as the application
   * lives, because AppKit does not resign one for a press on nothing. */
  if (wants == YES && [afterPress boolValue] == YES
    && NO == [self _pressWasInEditor])
    {
      NSWindow *window = [NSApp keyWindow];

      [window makeFirstResponder: window];
      wants = [self _wantsKeyboard];
    }

  /* The platform hides the keyboard itself on the back gesture and says
   * nothing, so what was last asked for is not what is on the screen.  A press
   * in the view being edited is the moment a person expects it back. */
  if (wants == _keyboardShown
    && NO == (wants && [afterPress boolValue]))
    {
      return;
    }
  _keyboardShown = wants;
  NSDebugLLog(@"NSEvent", @"android keyboard: %@",
    (wants ? @"shown" : @"hidden"));
  [self _setKeyboardVisible: wants];

  /* The keyboard takes its place over a moment rather than at once, so the
   * screen is looked at again after it has. */
  [self performSelector: @selector(_noticeScreenChange)
	     withObject: nil
	     afterDelay: 0.4];
}

/* Show or hide the input method.
 *
 * ANativeActivity_showSoftInput does not do this: it names the activity's
 * content view, and the view the input method is serving is the window's
 * decor view, so the request is refused with "Ignoring showSoftInput() as
 * view=... is not served".  InputMethodManager is asked directly instead,
 * naming the view it is serving.
 */
- (void) _setKeyboardVisible: (BOOL)visible
{
  JNIEnv	*env = _jniEnv;
  jobject	 activity;
  jclass	 activityCls = NULL;
  jobject	 window = NULL;
  jobject	 decor = NULL;
  jobject	 manager = NULL;
  jstring	 name = NULL;

  if (env == NULL || _activity == NULL || _activity->clazz == NULL)
    {
      return;
    }
  activity = _activity->clazz;
  activityCls = (*env)->GetObjectClass(env, activity);

  {
    jmethodID getWindow = (*env)->GetMethodID(env, activityCls,
      "getWindow", "()Landroid/view/Window;");

    if (getWindow != NULL)
      {
	window = (*env)->CallObjectMethod(env, activity, getWindow);
      }
  }
  if (window != NULL)
    {
      jclass	 windowCls = (*env)->GetObjectClass(env, window);
      jmethodID	 getDecorView = (*env)->GetMethodID(env, windowCls,
	"getDecorView", "()Landroid/view/View;");

      if (getDecorView != NULL)
	{
	  decor = (*env)->CallObjectMethod(env, window, getDecorView);
	}
      (*env)->DeleteLocalRef(env, windowCls);
    }

  name = (*env)->NewStringUTF(env, "input_method");
  {
    jmethodID getSystemService = (*env)->GetMethodID(env, activityCls,
      "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;");

    if (getSystemService != NULL && name != NULL)
      {
	manager = (*env)->CallObjectMethod(env, activity, getSystemService,
	  name);
      }
  }

  if (manager != NULL && decor != NULL)
    {
      jclass managerCls = (*env)->GetObjectClass(env, manager);

      if (visible)
	{
	  jmethodID show = (*env)->GetMethodID(env, managerCls,
	    "showSoftInput", "(Landroid/view/View;I)Z");

	  if (show != NULL)
	    {
	      (*env)->CallBooleanMethod(env, manager, show, decor, 0);
	    }
	}
      else
	{
	  jclass	viewCls = (*env)->GetObjectClass(env, decor);
	  jmethodID	token = (*env)->GetMethodID(env, viewCls,
	    "getWindowToken", "()Landroid/os/IBinder;");
	  jmethodID	hide = (*env)->GetMethodID(env, managerCls,
	    "hideSoftInputFromWindow", "(Landroid/os/IBinder;I)Z");

	  if (token != NULL && hide != NULL)
	    {
	      jobject binder = (*env)->CallObjectMethod(env, decor, token);

	      if (binder != NULL)
		{
		  (*env)->CallBooleanMethod(env, manager, hide, binder, 0);
		  (*env)->DeleteLocalRef(env, binder);
		}
	    }
	  (*env)->DeleteLocalRef(env, viewCls);
	}
      (*env)->DeleteLocalRef(env, managerCls);
    }

  if (name != NULL)    (*env)->DeleteLocalRef(env, name);
  if (manager != NULL) (*env)->DeleteLocalRef(env, manager);
  if (decor != NULL)   (*env)->DeleteLocalRef(env, decor);
  if (window != NULL)  (*env)->DeleteLocalRef(env, window);
  (*env)->DeleteLocalRef(env, activityCls);
  (*env)->ExceptionClear(env);
}

/* How long after a press a second one still counts as part of the same click,
 * taken from android.view.ViewConfiguration so that a person who has changed
 * the platform's setting gets what they asked for.  The NDK reports no click
 * count of its own.  Without a JNI context the platform's own default stands.
 */
- (NSTimeInterval) _doubleTapTimeout
{
  if (_doubleTapTimeout > 0.0)
    {
      return _doubleTapTimeout;
    }
  _doubleTapTimeout = 0.3;

  if (_jniEnv != NULL)
    {
      jclass	cls;

      cls = (*_jniEnv)->FindClass(_jniEnv, "android/view/ViewConfiguration");
      if (cls != NULL)
	{
	  jmethodID m = (*_jniEnv)->GetStaticMethodID(_jniEnv, cls,
	    "getDoubleTapTimeout", "()I");

	  if (m != NULL)
	    {
	      jint ms = (*_jniEnv)->CallStaticIntMethod(_jniEnv, cls, m);

	      if (ms > 0)
		{
		  _doubleTapTimeout = (NSTimeInterval)ms / 1000.0;
		}
	    }
	  (*_jniEnv)->DeleteLocalRef(_jniEnv, cls);
	}
      (*_jniEnv)->ExceptionClear(_jniEnv);
    }
  return _doubleTapTimeout;
}

/* A press close enough to the one before it, and soon enough after it, carries
 * the count on.  AppKit counts this way and the NDK reports no count. */
- (void) _countClickAt: (NSPoint)location atTime: (NSTimeInterval)now
{
  CGFloat dx = location.x - _lastClickLocation.x;
  CGFloat dy = location.y - _lastClickLocation.y;

  if (_clickCount > 0
    && now - _lastClickTime <= [self _doubleTapTimeout]
    && (dx * dx + dy * dy) <= (CGFloat)(GS_ANDROID_CLICK_SLOP
      * GS_ANDROID_CLICK_SLOP))
    {
      _clickCount++;
    }
  else
    {
      _clickCount = 1;
    }
  _lastClickTime = now;
  _lastClickLocation = location;
}

/* android.view.KeyEvent holds the mapping from a key to a character; the NDK
 * reports the code and the meta state and offers no character at all. */
- (unichar) _characterForKey: (int32_t)code meta: (int32_t)meta
{
  static jclass    cls = NULL;
  static jmethodID ctor = NULL;
  static jmethodID unicode = NULL;
  jobject	   event;
  jint		   ch;

  if (_jniEnv == NULL)
    {
      return 0;
    }
  if (cls == NULL)
    {
      jclass local = (*_jniEnv)->FindClass(_jniEnv, "android/view/KeyEvent");

      if (local == NULL)
	{
	  (*_jniEnv)->ExceptionClear(_jniEnv);
	  return 0;
	}
      cls = (*_jniEnv)->NewGlobalRef(_jniEnv, local);
      ctor = (*_jniEnv)->GetMethodID(_jniEnv, cls, "<init>", "(II)V");
      unicode = (*_jniEnv)->GetMethodID(_jniEnv, cls, "getUnicodeChar", "(I)I");
    }
  if (ctor == NULL || unicode == NULL)
    {
      return 0;
    }
  event = (*_jniEnv)->NewObject(_jniEnv, cls, ctor,
    (jint)AKEY_EVENT_ACTION_DOWN, (jint)code);
  if (event == NULL)
    {
      (*_jniEnv)->ExceptionClear(_jniEnv);
      return 0;
    }
  ch = (*_jniEnv)->CallIntMethod(_jniEnv, event, unicode, (jint)meta);
  (*_jniEnv)->DeleteLocalRef(_jniEnv, event);
  return (unichar)ch;
}

/* The point an event names, in the screen's coordinates: the activity reports
 * it in the surface's own pixels, counted down from the top, and the screen
 * counts up from the bottom.
 */
- (NSPoint) _screenLocationFor: (const AInputEvent *)event
{
  float screenHeight;

  if (_activityWindow == NULL)
    {
      return NSZeroPoint;
    }
  screenHeight = (float)ANativeWindow_getHeight(_activityWindow);
  return NSMakePoint(AMotionEvent_getX(event, 0),
    screenHeight - AMotionEvent_getY(event, 0));
}

/* The window a person is pointing at: the front-most one on screen whose frame
 * holds the point.  Front-most is the highest level, and within a level the
 * one ordered in most recently, which is the order the windows are written in
 * reversed.
 */
- (struct AndroidWindow *) _windowUnderPoint: (NSPoint)point
{
  NSMapEnumerator	 e = NSEnumerateMapTable(_windows);
  struct AndroidWindow	*best = NULL;
  void			*key, *value;

  while (NSNextMapEnumeratorPair(&e, &key, &value))
    {
      struct AndroidWindow *w = (struct AndroidWindow *)value;

      if (w == NULL || w->mapped == NO
	|| NO == NSPointInRect(point, w->frame))
	{
	  continue;
	}
      if (best == NULL
	|| w->level > best->level
	|| (w->level == best->level && w->ordered > best->ordered))
	{
	  best = w;
	}
    }
  NSEndMapTableEnumeration(&e);

  return best;
}

- (BOOL) handleInputEvent: (const AInputEvent *)event
{
  struct AndroidWindow	*window;
  NSTimeInterval	 now;

  if (event == NULL || _activityWindow == NULL)
    {
      return NO;
    }

  /* A press goes to the window it lands in; a key goes to the window that has
   * the screen, because a key names no place. */
  if (AInputEvent_getType(event) == AINPUT_EVENT_TYPE_MOTION)
    {
      window = [self _windowUnderPoint: [self _screenLocationFor: event]];
    }
  else
    {
      window = [self _windowWithId: _boundWindow];
    }
  if (window == NULL)
    {
      return NO;
    }
  now = [[NSDate date] timeIntervalSinceReferenceDate];

  if (AInputEvent_getType(event) == AINPUT_EVENT_TYPE_MOTION)
    {
      NSEventType	type;
      NSPoint		location;
      NSUInteger	flags = android_modifiers(AMotionEvent_getMetaState(event));
      int32_t		action;
      int		button;

      action = AMotionEvent_getAction(event) & AMOTION_EVENT_ACTION_MASK;
      location = [self _locationFor: event inWindow: window];

      /* A wheel, which a mouse has and a touchscreen does not.  Android counts
       * a detent as 1 along the axis, which is what AppKit's delta counts. */
      if (action == AMOTION_EVENT_ACTION_SCROLL)
	{
	  _mouseLocation = location;
	  NSDebugLLog(@"NSEvent", @"android scroll: at %@ by %g,%g",
	    NSStringFromPoint(location),
	    (double)AMotionEvent_getAxisValue(event,
	      AMOTION_EVENT_AXIS_HSCROLL, 0),
	    (double)AMotionEvent_getAxisValue(event,
	      AMOTION_EVENT_AXIS_VSCROLL, 0));
	  [self postEvent:
	    [NSEvent mouseEventWithType: NSScrollWheel
			       location: location
			  modifierFlags: flags
			      timestamp: now
			   windowNumber: window->window_id
				context: GSCurrentContext()
			    eventNumber: 0
			     clickCount: 0
			       pressure: 1.0
			   buttonNumber: 0
				 deltaX: AMotionEvent_getAxisValue(event,
				   AMOTION_EVENT_AXIS_HSCROLL, 0)
				 deltaY: AMotionEvent_getAxisValue(event,
				   AMOTION_EVENT_AXIS_VSCROLL, 0)
				 deltaZ: 0.0]
		 atStart: NO];
	  return YES;
	}

      /* A pointer moving with nothing held down.  A touchscreen reports this
       * only from a stylus near the glass; a mouse reports it whenever it
       * moves, and it is what a tracking rect and a cursor rect need. */
      if (action == AMOTION_EVENT_ACTION_HOVER_MOVE
	|| action == AMOTION_EVENT_ACTION_HOVER_ENTER
	|| action == AMOTION_EVENT_ACTION_HOVER_EXIT)
	{
	  _mouseLocation = location;
	  NSDebugLLog(@"NSEvent", @"android hover: at %@ flags %lx",
	    NSStringFromPoint(location), (unsigned long)flags);
	  [self postEvent:
	    [NSEvent mouseEventWithType: NSMouseMoved
			       location: location
			  modifierFlags: flags
			      timestamp: now
			   windowNumber: window->window_id
				context: GSCurrentContext()
			    eventNumber: 0
			     clickCount: 0
			       pressure: 0.0
			   buttonNumber: 0
				 deltaX: 0.0
				 deltaY: 0.0
				 deltaZ: 0.0]
		 atStart: NO];
	  return YES;
	}

      switch (action)
	{
	  case AMOTION_EVENT_ACTION_DOWN:
	    /* A touch reports no button at all, and a mouse reports the one it
	     * is holding; the button a drag and an up belong to is the one that
	     * went down, because the state is clear again by the up. */
	    _mouseButton = android_button(AMotionEvent_getButtonState(event));
	    [self _countClickAt: location atTime: now];
	    button = _mouseButton;
	    type = (button == 1) ? NSRightMouseDown
	      : (button > 1) ? NSOtherMouseDown : NSLeftMouseDown;
	    break;

	  case AMOTION_EVENT_ACTION_UP:
	  case AMOTION_EVENT_ACTION_CANCEL:
	    button = _mouseButton;
	    type = (button == 1) ? NSRightMouseUp
	      : (button > 1) ? NSOtherMouseUp : NSLeftMouseUp;
	    _mouseButton = 0;
	    break;

	  case AMOTION_EVENT_ACTION_MOVE:
	    button = _mouseButton;
	    type = (button == 1) ? NSRightMouseDragged
	      : (button > 1) ? NSOtherMouseDragged : NSLeftMouseDragged;
	    break;

	  /* A second finger down or up.  AppKit has one pointer, so the first
	   * finger goes on driving it and this is not passed on. */
	  case AMOTION_EVENT_ACTION_POINTER_DOWN:
	  case AMOTION_EVENT_ACTION_POINTER_UP:
	  default:
	    return NO;
	}

      _mouseLocation = location;
      NSDebugLLog(@"NSEvent", @"android motion: type %d at %@ button %d"
	@" clicks %d flags %lx", (int)type, NSStringFromPoint(location),
	button, _clickCount, (unsigned long)flags);
      [self postEvent: [NSEvent mouseEventWithType: type
					  location: location
				     modifierFlags: flags
					 timestamp: now
				      windowNumber: window->window_id
					   context: GSCurrentContext()
				       eventNumber: 0
					clickCount: _clickCount
					  pressure: 1.0
				      buttonNumber: button
					    deltaX: 0.0
					    deltaY: 0.0
					    deltaZ: 0.0]
	     atStart: NO];
      /* The press moves the first responder when the gui library takes the
       * event off the queue, which is after this returns, so the keyboard is
       * asked about once that has happened. */
      [self performSelector: @selector(_updateKeyboard:)
		 withObject: [NSNumber numberWithBool: YES]
		 afterDelay: 0.0];
      return YES;
    }

  if (AInputEvent_getType(event) == AINPUT_EVENT_TYPE_KEY)
    {
      NSEventType	 type;
      int32_t		 code = AKeyEvent_getKeyCode(event);
      int32_t		 meta = AKeyEvent_getMetaState(event);
      unichar		 ch;
      NSString		*characters;

      /* The back key is the platform's own gesture. */
      if (code == AKEYCODE_BACK)
	{
	  return NO;
	}
      switch (AKeyEvent_getAction(event))
	{
	  case AKEY_EVENT_ACTION_DOWN: type = NSKeyDown; break;
	  case AKEY_EVENT_ACTION_UP:   type = NSKeyUp;   break;
	  default:                     return NO;
	}

      /* A modifier has no character, so it is reported as the change in the
       * flags rather than as a key.  The state Android reports is the one
       * before the key it is reporting, so the key's own bit is set or cleared
       * here. */
      if (android_modifier_key(code) != 0)
	{
	  NSUInteger flags = android_modifiers(meta);

	  if (type == NSKeyDown)
	    {
	      flags |= android_modifier_key(code);
	    }
	  else
	    {
	      flags &= ~android_modifier_key(code);
	    }
	  NSDebugLLog(@"NSEvent", @"android flags changed: key %d flags %lx",
	    (int)code, (unsigned long)flags);
	  [self postEvent: [NSEvent keyEventWithType: NSFlagsChanged
					    location: _mouseLocation
				       modifierFlags: flags
					   timestamp: now
					windowNumber: window->window_id
					     context: GSCurrentContext()
					  characters: @""
			 charactersIgnoringModifiers: @""
					   isARepeat: NO
					     keyCode: (unsigned short)code]
	     atStart: NO];
	  return YES;
	}

      ch = android_special_key(code);
      if (ch == 0)
	{
	  ch = [self _characterForKey: code meta: meta];
	}
      if (ch == 0)
	{
	  return NO;
	}
      characters = [NSString stringWithCharacters: &ch length: 1];
      [self postEvent: [NSEvent keyEventWithType: type
					location: NSZeroPoint
				   modifierFlags: android_modifiers(meta)
				       timestamp: now
				    windowNumber: window->window_id
					 context: GSCurrentContext()
				      characters: characters
		     charactersIgnoringModifiers: characters
				       isARepeat:
	  (AKeyEvent_getRepeatCount(event) > 0)
					 keyCode: (unsigned short)code]
	     atStart: NO];
      /* A key can end editing, and a tab can move it somewhere else. */
      [self performSelector: @selector(_updateKeyboard:)
		 withObject: nil
		 afterDelay: 0.0];
      return YES;
    }

  return NO;
}

/* Nothing shows a title, a document-edited mark, an input state, an alpha or a
 * shadow while the surface is offscreen.  These are present because the other
 * servers have them and the gui library calls them on every window. */
- (void) titlewindow: (NSString *)title : (int)win { }
- (void) docedited: (int)edited : (int)win { }
- (void) setinputstate: (int)state : (int)win { }
- (void) setinputfocus: (int)win { }
- (void) setalpha: (float)alpha : (int)win { }
- (void) setShadow: (BOOL)hasShadow : (int)win { }
- (void) setmaxsize: (NSSize)size : (int)win { }
- (void) setminsize: (NSSize)size : (int)win { }
- (void) setresizeincrements: (NSSize)size : (int)win { }
- (void) miniwindow: (int)win { }
- (void) setParentWindow: (int)parentWin forChildWindow: (int)childWin { }
- (void) restrictWindow: (int)win toImage: (NSImage *)image { }
- (void) beep { }

/* Android has no window this process did not make, so there is no foreign
 * window to adopt. */
- (int) nativeWindow: (void *)winref
		    : (NSRect *)frame
		    : (NSBackingStoreType *)type
		    : (unsigned int *)style
		    : (int *)screen
{
  return 0;
}

/*
 * Pointer and cursor
 *
 * No pointer device exists while the surface is offscreen, so the server owns
 * the location: -setMouseLocation:onScreen: sets it and -mouselocation reports
 * it back.  x11, win32 and wayland all answer these.
 */

- (NSPoint) mouselocation
{
  return _mouseLocation;
}

- (NSPoint) mouseLocationOnScreen: (int)aScreen window: (int *)win
{
  if (win != NULL)
    {
      *win = 0;
    }
  return (aScreen == 0) ? _mouseLocation : NSZeroPoint;
}

- (void) setMouseLocation: (NSPoint)mouseLocation onScreen: (int)aScreen
{
  if (aScreen == 0)
    {
      _mouseLocation = mouseLocation;
    }
}

- (BOOL) capturemouse: (int)win { return NO; }
- (void) releasemouse { }
- (void) hidecursor { }
- (void) showcursor { }
- (void) standardcursor: (int)style : (void **)cid { *cid = NULL; }
- (void) imagecursor: (NSPoint)hotp : (NSImage *)image : (void **)cid { *cid = NULL; }
- (void) recolorcursor: (NSColor *)fg : (NSColor *)bg : (void *)cid { }
- (void) setcursor: (void *)cid { }
- (void) freecursor: (void *)cid { }

@end
