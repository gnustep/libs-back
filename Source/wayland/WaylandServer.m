/* 
   WaylandServer - Wayland Server Class

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author: Sergio L. Pascual <slp@sinrega.org>
   Rewrite: Riccardo Canalicchio <riccardo.canalicchio(at)gmail.com>
   Date: November 2021

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
#include <AppKit/AppKitExceptions.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/DPSOperators.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSMenu.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSValue.h>

#include <unistd.h>
#include <xkbcommon/xkbcommon.h>
#include <linux/input.h>
#include <sys/mman.h>

#include "wayland/WaylandServer.h"

extern const struct wl_output_listener output_listener;

extern const struct wl_seat_listener seat_listener;

static void
shm_format(void *data, struct wl_shm *wl_shm, uint32_t format)
{}

struct wl_shm_listener shm_listener = {shm_format};

extern const struct xdg_surface_listener xdg_surface_listener;

extern const struct xdg_toplevel_listener xdg_toplevel_listener;

extern const struct xdg_wm_base_listener wm_base_listener;

extern const struct zwlr_layer_surface_v1_listener layer_surface_listener;

extern const struct xdg_popup_listener xdg_popup_listener;

static void
handle_global(void *data, struct wl_registry *registry, uint32_t name,
	      const char *interface, uint32_t version)
{
  WaylandConfig *wlconfig = data;

  NSDebugLog(@"wayland: registering interface '%s'", interface);
  if (strcmp(interface, xdg_wm_base_interface.name) == 0)
    {
      wlconfig->wm_base
	= wl_registry_bind(registry, name, &xdg_wm_base_interface, 1);
      xdg_wm_base_add_listener(wlconfig->wm_base, &wm_base_listener, NULL);
      NSDebugLog(@"wayland: found wm_base interface");
    }
  else if (strcmp(interface, wl_shell_interface.name) == 0)
    {
      wlconfig->shell
	= wl_registry_bind(registry, name, &wl_shell_interface, 1);
      NSDebugLog(@"wayland: found shell interface");
    }
  else if (strcmp(interface, wl_compositor_interface.name) == 0)
    {
      wlconfig->compositor
	= wl_registry_bind(registry, name, &wl_compositor_interface, 1);
      NSDebugLog(@"wayland: found compositor interface");
    }
  else if (strcmp(interface, wl_shm_interface.name) == 0)
    {
      wlconfig->shm = wl_registry_bind(registry, name, &wl_shm_interface, 1);
      NSDebugLog(@"wayland: found shm interface");
      wl_shm_add_listener(wlconfig->shm, &shm_listener, wlconfig);
    }
  else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0)
    {
      wlconfig->layer_shell
	= wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, 1);
      NSDebugLog(@"wayland: found wlr-layer_shell interface");
    }
  else if (strcmp(interface, wl_output_interface.name) == 0)
    {
      struct output *output = (struct output *) malloc(sizeof(struct output));
      memset(output, 0, sizeof(struct output));
      output->wlconfig = wlconfig;
      output->scale = 1;
      output->output
	= wl_registry_bind(registry, name, &wl_output_interface, 2);
      output->server_output_id = name;
      NSDebugLog(@"wayland: found output interface");
      wl_list_insert(wlconfig->output_list.prev, &output->link);
      wlconfig->output_count++;
      wl_output_add_listener(output->output, &output_listener, output);
    }
  else if (strcmp(interface, wl_seat_interface.name) == 0)
    {
      wlconfig->pointer.wlpointer = NULL;
      wlconfig->seat_version = version;
      wlconfig->seat
	= wl_registry_bind(wlconfig->registry, name, &wl_seat_interface, 1);
      NSDebugLog(@"wayland: found seat interface");
      wl_seat_add_listener(wlconfig->seat, &seat_listener, wlconfig);
    }
}

static void handle_global_remove(void *data, struct wl_registry *registry,
                                 uint32_t name) {}

static const struct wl_registry_listener registry_listener = {
    handle_global, handle_global_remove};

struct window *get_window_with_id(WaylandConfig *wlconfig, int winid) {
  struct window *window;

  wl_list_for_each(window, &wlconfig->window_list, link) {
    if (window->window_id == winid) {
      return window;
    }
  }

  return NULL;
}

float
WaylandToNS(struct window *window, float wl_y)
{
  return (window->output->height - wl_y - window->height);
}

int
NSToWayland(struct window *window, int ns_y)
{
  return (window->output->height - ns_y - window->height);
}

@class NSMenuPanel;

@implementation WaylandServer

/* Initialize AppKit backend */
+ (void)initializeBackend
{
  NSDebugLog(@"Initializing GNUstep Wayland backend");
  [GSDisplayServer setDefaultServerClass:[WaylandServer class]];
}

- (id)_initWaylandContext
{
  wlconfig = (WaylandConfig *) malloc(sizeof(WaylandConfig));
  memset(wlconfig, 0, sizeof(WaylandConfig));
  wlconfig->last_window_id = 1;
  wlconfig->mouse_scroll_multiplier = 1.0f;
  wl_list_init(&wlconfig->output_list);
  wl_list_init(&wlconfig->window_list);

  wlconfig->display = wl_display_connect(NULL);
  if (!wlconfig->display)
    {
      [NSException raise:NSWindowServerCommunicationException
		  format:@"Unable to connect Wayland Server"];
    }

  wlconfig->registry = wl_display_get_registry(wlconfig->display);
  if (!wlconfig->registry)
    {
      [NSException raise:NSWindowServerCommunicationException
		  format:@"Unable to get global registry"];
    }
  wl_registry_add_listener(wlconfig->registry, &registry_listener, wlconfig);

  wl_display_dispatch(wlconfig->display);
  wl_display_roundtrip(wlconfig->display);

  if (!wlconfig->compositor)
    {
      [NSException raise:NSWindowServerCommunicationException
		  format:@"Unable to get compositor"];
    }
  if (!wlconfig->wm_base)
    {
      /* Note: this was merged into Weston only as of Feb 2019, and is
	 probably in Weston only as of 6.0 release, therefore not in Weston
	 5.x present in Debian buster (current stable). See Weston merge request
	 !103. */
      [NSException
	 raise:NSWindowServerCommunicationException
	format:@"Unable to get xdg-shell / xdg_wm_base - your Wayland "
	       @"compositor must support the stable XDG Shell protocol"];
    }

  return self;
}

- (void)receivedEvent:(void *)data
		 type:(RunLoopEventType)type
		extra:(void *)extra
	      forMode:(NSString *)mode
{
  if (type == ET_RDESC)
    {
      //	NSDebugLog(@"receivedEvent ET_RDESC");
      if (wl_display_dispatch(wlconfig->display) == -1)
        {
        [NSException raise:NSWindowServerCommunicationException
                format:@"Connection to Wayland Server lost"];
        }
    }
}

- (void)setupRunLoopInputSourcesForMode:(NSString *)mode
{
  NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
  long	     fdWaylandHandle = wl_display_get_fd(wlconfig->display);

  [currentRunLoop addEvent:(void *) fdWaylandHandle
		      type:ET_RDESC
		   watcher:(id<RunLoopEvents>) self
		   forMode:mode];
}

- (id)initWithAttributes:(NSDictionary *)info
{
  NSDebugLog(@"WaylandServer initWithAttributes");
  [super initWithAttributes:info];
  [self _initWaylandContext];

  [self setupRunLoopInputSourcesForMode:NSDefaultRunLoopMode];
  [self setupRunLoopInputSourcesForMode:NSConnectionReplyMode];
  [self setupRunLoopInputSourcesForMode:NSModalPanelRunLoopMode];
  [self setupRunLoopInputSourcesForMode:NSEventTrackingRunLoopMode];

  return self;
}

- (void)dealloc
{
  NSDebugLog(@"Destroying Wayland Server");
  [super dealloc];
}

- (BOOL)handlesWindowDecorations
{
  return NO;
}

- (void)restrictWindow:(int)win toImage:(NSImage *)image
{
  NSDebugLog(@"restrictWindow");
}

- (NSRect)boundsForScreen:(int)screen
{
  NSDebugLog(@"boundsForScreen: %d", screen);
  struct output *output;

  wl_list_for_each(output, &wlconfig->output_list, link)
  {
    NSDebugLog(@"screen found: %dx%d", output->width, output->height);
    return NSMakeRect(0, 0, output->width, output->height);
  }

  NSDebugLog(@"can't find screen");
  return NSZeroRect;
}

- (NSWindowDepth)windowDepthForScreen:(int)screen
{
  NSDebugLog(@"windowDepthForScreen: %d", screen);
  return (_GSRGBBitValue | 8);
}

- (const NSWindowDepth *)availableDepthsForScreen:(int)screen
{
  NSDebugLog(@"availableDepthsForScreen");
  return NULL;
}

- (NSArray *)screenList
{
  NSDebugLog(@"screenList");
  NSMutableArray *screens =
    [NSMutableArray arrayWithCapacity:wlconfig->output_count];
  struct output *output;

  wl_list_for_each(output, &wlconfig->output_list, link)
  {
    [screens addObject:[NSNumber numberWithInt:output->server_output_id]];
    NSDebugLog(@"adding screen with output_id=%d", output->server_output_id);
    NSDebugLog(@"output dimensions: %dx%d %dx%d", output->alloc_x,
	       output->alloc_y, output->width, output->height);
  }

  return screens;
}

- (void *)serverDevice
{
  NSDebugLog(@"serverDevice");
  return NULL;
}

- (void *)windowDevice:(int)win
{
  NSDebugLog(@"windowDevice");
  return NULL;
}

- (void)beep
{
  NSDebugLog(@"beep");
}

@end

@implementation
WaylandServer (WindowOps)

- (int)window:(NSRect)
	frame:(NSBackingStoreType)type
	     :(unsigned int)style
	     :(int)screen
{
  NSDebugLog(@"window: screen=%d frame=%@", screen, NSStringFromRect(frame));
  struct window *window;
  struct output *output;
  int		 width;
  int		 height;
  int		 altered = 0;

  /* We're not allowed to create a zero rect window */
  if (NSWidth(frame) <= 0 || NSHeight(frame) <= 0)
    {
      NSDebugLog(@"trying to create a zero rect window");
      frame.size.width = 2;
      frame.size.height = 2;
    }

  window = malloc(sizeof(struct window));
  memset(window, 0, sizeof(struct window));

  wl_list_for_each(output, &wlconfig->output_list, link)
  {
    if (output->server_output_id == screen)
      {
	window->output = output;
	break;
      }
  }

  if (!window->output)
    {
      NSDebugLog(@"can't find screen %d", screen);
      free(window);
      return 0;
    }

  window->wlconfig = wlconfig;
  window->instance = self;
  window->is_out = 0;
  window->width = width = NSWidth(frame);
  window->height = height = NSHeight(frame);
  window->pos_x = frame.origin.x;
  window->pos_y = NSToWayland(window, frame.origin.y);
  window->window_id = wlconfig->last_window_id;

  window->xdg_surface = NULL;
  window->toplevel = NULL;
  window->popup = NULL;
  window->layer_surface = NULL;
  window->configured = NO;

  window->buffer_needs_attach = NO;
  window->terminated = NO;

  window->moving = NO;
  window->resizing = NO;
  window->ignoreMouse = NO;

  // FIXME is this needed?
  if (window->pos_x < 0)
    {
      window->pos_x = 0;
      altered = 1;
    }

  NSDebugLog(@"creating new window with id=%d: pos=%fx%f, size=%fx%f",
	     window->window_id, window->pos_x, window->pos_y, window->width,
	     window->height);

  wl_list_insert(wlconfig->window_list.prev, &window->link);
  wlconfig->last_window_id++;
  wlconfig->window_count++;

  // creates a buffer for the window
  [self _setWindowOwnedByServer:(int) window->window_id];

  if (altered)
    {
      NSEvent *ev =
	[NSEvent otherEventWithType:NSAppKitDefined
			   location:NSZeroPoint
		      modifierFlags:0
			  timestamp:0
		       windowNumber:(int) window->window_id
			    context:GSCurrentContext()
			    subtype:GSAppKitWindowMoved
			      data1:window->pos_x
			      data2:WaylandToNS(window, window->pos_y)];
      [(GSWindowWithNumber(window->window_id)) sendEvent:ev];
      NSDebugLog(@"window: notifying of move=%fx%f", window->pos_x,
		 WaylandToNS(window, window->pos_y));
    }

  return window->window_id;
}

- (void)termwindow:(int)win
{
  NSDebugLog(@"termwindow: win=%d", win);
  struct window *window = get_window_with_id(wlconfig, win);

  [self destroyWindowShell:window];
  // FIXME should wait for buffer release before detroying it
  //
  // wl_buffer_destroy(window->buffer);
  wl_list_remove(&window->link);
  window->terminated = YES;
}

- (int)nativeWindow:(void *)
	     winref:(NSRect *)frame
		   :(NSBackingStoreType *)type
		   :(unsigned int *)style
		   :(int *)screen
{
  NSDebugLog(@"nativeWindow");
  return 0;
}

- (void)stylewindow:(unsigned int)style:(int)win
{
  NSDebugLog(@"stylewindow");
}

- (void)windowbacking:(NSBackingStoreType)type:(int)win
{
  NSDebugLog(@"windowbacking");
}

- (void)titlewindow:(NSString *)window_title:(int)win
{
  NSDebugLog(@"titlewindow: win=%d title=%@", win, window_title);
  if (window_title == @"Window")
    {
      return;
    }

  struct window *window = get_window_with_id(wlconfig, win);
  const char    *cString = [window_title UTF8String];

  if (window->toplevel)
    {
      xdg_toplevel_set_title(window->toplevel, cString);
      wl_surface_commit(window->surface);
      wl_display_flush(window->wlconfig->display);
    }
}

- (void)miniwindow:(int)win
{
  struct window *window = get_window_with_id(wlconfig, win);

  NSDebugLog(@"miniwindow");
  if (window->toplevel)
    {
      xdg_toplevel_set_minimized(window->toplevel);
    }
  else
    {
      NSDebugLog(@"trying to miniaturize a not toplevel window");
    }
}

- (void)setWindowdevice:(int)winId forContext:(NSGraphicsContext *)ctxt
{
  NSDebugLog(@"[%d] setWindowdevice", winId);
  struct window *window;

  window = get_window_with_id(wlconfig, winId);
  // FIXME we could resize the current surface instead of creating a new one
  if (window->wcs)
    {
      NSDebugLog(@"[%d] window has already a surface", winId);
    }
  GSSetDevice(ctxt, window, 0.0, window->height);
  DPSinitmatrix(ctxt);
  DPSinitclip(ctxt);
}

- (void)orderwindow:(int)op:(int)otherWin:(int)win
{
  struct window *window = get_window_with_id(wlconfig, win);

  if (op == NSWindowOut)
    {
      NSDebugLog(@"[%d] orderwindow: NSWindowOut", win);
      [self destroyWindowShell:window];
    }
  else
    { //  NSWindowAbove || NSWindowBelow,

      // currently it only creates a new shell for the window which results
      // in popping in front of the window manager
      NSDebugLog(@"[%d] orderwindow to: %fx%f", win, window->pos_x,
		 window->pos_y);
      if ([self windowSurfaceHasRole:window] == NO)
	{
	  [self createSurfaceShell:window];
	}
      NSRect rect = NSMakeRect(window->pos_x, window->pos_y, window->width,
			       window->height);
      [window->instance flushwindowrect:rect:window->window_id];
    }
  wl_display_dispatch_pending(window->wlconfig->display);
  wl_display_flush(window->wlconfig->display);
}

- (void)movewindow:(NSPoint)loc:(int)win
{
  NSDebugLog(@"movewindow");
}

- (NSRect) _OSFrameToWFrame: (NSRect)o for: (void*)win
{
  struct window *window = (struct window *) win;
  NSRect	 x;

  x.size.width = o.size.width;
  x.size.height = o.size.height;
  x.origin.x = o.origin.x;
  x.origin.y = o.origin.y + o.size.height;
  x.origin.y = window->output->height - x.origin.y;
  return x;
}

- (void)placewindow:(NSRect)rect:(int)win
{
  struct window *window = get_window_with_id(wlconfig, win);

  NSDebugLog(@"[%d] placewindow: %@", win, NSStringFromRect(rect));
  WaylandConfig *config = window->wlconfig;

  NSRect frame;
  NSRect wframe;
  BOOL	 resize = NO;
  BOOL	 move = NO;

  frame = [(GSWindowWithNumber(window->window_id)) frame];
  if (NSEqualRects(rect, frame) == YES)
    return;
  if (NSEqualSizes(rect.size, frame.size) == NO)
    {
      resize = YES;
      move = YES;
    }
  if (NSEqualPoints(rect.origin, frame.origin) == NO)
    {
      move = YES;
    }

	wframe = [self _OSFrameToWFrame: rect for: window];

	if (config->pointer.focus
	    && config->pointer.focus->window_id == window->window_id)
	  {
	    config->pointer.y -= (wframe.origin.y - window->pos_y);
	    config->pointer.x -= (wframe.origin.x - window->pos_x);
	  }

	NSDebugLog(@"[%d] placewindow: oldpos=%fx%f", win, window->pos_x,
		   window->pos_y);
	window->width = rect.size.width;
	window->height = rect.size.height;
	window->pos_x = rect.origin.x;
	window->pos_y = NSToWayland(window, rect.origin.y);

	[window->instance flushwindowrect:rect:window->window_id];
	if (window->xdg_surface)
	  {
	    xdg_surface_set_window_geometry(window->xdg_surface, 0, 0,
					    window->width, window->height);
	    wl_surface_commit(window->surface);
	  }

	if (resize == YES)
	  {
	    NSDebugLog(@"[%d] placewindow: newsize=%fx%f", win, window->width,
		       window->height);
	    NSEvent *ev = [NSEvent otherEventWithType:NSAppKitDefined
					     location:rect.origin
					modifierFlags:0
					    timestamp:0
					 windowNumber:win
					      context:GSCurrentContext()
					      subtype:GSAppKitWindowResized
						data1:rect.size.width
						data2:rect.size.height];
	    NSDebugLog(@"notify resize=%fx%f", rect.size.width,
		       rect.size.height);
	    [(GSWindowWithNumber(window->window_id)) sendEvent:ev];
	    NSDebugLog(@"notified resize=%fx%f", rect.size.width,
		       rect.size.height);
	    // we have a new buffer
	  }
	else if (move == YES)
	  {
	    NSDebugLog(@"[%d] placewindow: newpos=%fx%f", win, window->pos_x,
		       window->pos_y);
	  }
	wl_display_dispatch_pending(window->wlconfig->display);
	wl_display_flush(window->wlconfig->display);
}

- (NSRect)windowbounds:(int)win
{
  struct window *window = get_window_with_id(wlconfig, win);
  NSDebugLog(@"windowbounds: win=%d, pos=%dx%d size=%dx%d", window->window_id,
	     window->pos_x, window->pos_y, window->width, window->height);

  return NSMakeRect(window->pos_x, window->output->height - window->pos_y,
		    window->width, window->height);
}

- (void)setParentWindow:(int)parentWin forChildWindow:(int)childWin
{
  if (parentWin == 0)
    {
      return;
    }
  NSDebugLog(@"setParentWindow: parent=%d child=%d", parentWin, childWin);
  struct window *parent = get_window_with_id(wlconfig, parentWin);
  struct window *child = get_window_with_id(wlconfig, childWin);

  [self createPopupShell:child withParentShell:parent];
}

- (void)setwindowlevel:(int)level:(int)win
{
  struct window *window = get_window_with_id(wlconfig, win);
  window->level = level;

  NSDebugLog(@"setwindowlevel: level=%d win=%d", level, win);
}

- (int)windowlevel:(int)win
{
  NSDebugLog(@"windowlevel: %d", win);
  struct window *window = get_window_with_id(wlconfig, win);
  return window->level;
}

- (int)windowdepth:(int)win
{
  NSDebugLog(@"windowdepth");
  return 0;
}

- (void)setmaxsize:(NSSize)size:(int)win
{
  // NSDebugLog(@"setmaxsize");
}

- (void)setminsize:(NSSize)size:(int)win
{
  // NSDebugLog(@"setminsize");
}

- (void)setresizeincrements:(NSSize)size:(int)win
{
  // NSDebugLog(@"setresizeincrements");
}

- (void)flushwindowrect:(NSRect)rect:(int)win
{
  NSDebugLog(@"[%d] flushwindowrect: %f,%f %fx%f", win, NSMinX(rect),
	     NSMinY(rect), NSWidth(rect), NSHeight(rect));
  struct window *window = get_window_with_id(wlconfig, win);

  [[GSCurrentContext() class] handleExposeRect:rect forDriver:window->wcs];
}

- (void)styleoffsets:(float *)
		   l:(float *)r
		    :(float *)t
		    :(float *)b
		    :(unsigned int)style
{
  NSDebugLog(@"styleoffsets");
  /* XXX - Assume we don't decorate */
  *l = *r = *t = *b = 0.0;
}

- (void)docedited:(int)edited:(int)win
{
  // NSDebugLog(@"docedited");
}

- (void)setinputstate:(int)state:(int)win
{
  // NSDebugLog(@"setinputstate");
}

- (void)setinputfocus:(int)win
{
  // NSDebugLog(@"setinputfocus");
}

- (void)setalpha:(float)alpha:(int)win
{
  // NSDebugLog(@"setalpha");
}

- (void)setShadow:(BOOL)hasShadow:(int)win
{
  // NSDebugLog(@"setshadow");
}

@end

@implementation
WaylandServer (SurfaceRoles)
- (void)createSurfaceShell:(struct window *)window
{
  int win = window->window_id;
  NSDebugLog(@"[%d] createSurfaceShell", win);

  switch (window->level)
    {
    case NSMainMenuWindowLevel:
      NSDebugLog(@"[%d] NSMainMenuWindowLevel", win);
      [self createLayerShell:window
	       withLayerType:ZWLR_LAYER_SHELL_V1_LAYER_TOP
	       withNamespace:@"gnustep-mainmenu"];
      break;
    case NSSubmenuWindowLevel:
      NSDebugLog(@"[%d] NSSubmenuWindowLevel", win);
      [self createSubMenuShell:window];
      break;
    case NSDesktopWindowLevel:
      NSDebugLog(@"[%d] NSDesktopWindowLevel", win);
      [self createLayerShell:window
	       withLayerType:ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND
	       withNamespace:@"gnustep-desktop"];
      break;
    case NSPopUpMenuWindowLevel:
      NSDebugLog(@"[%d] NSPopUpMenuWindowLevel", win);
      [self createPopup:window];
      break;
    case NSScreenSaverWindowLevel:
      NSDebugLog(@"[%d] NSScreenSaverWindowLevel", win);
      [self createLayerShell:window
	       withLayerType:ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY
	       withNamespace:@"gnustep-screensaver"];
      break;
    case NSStatusWindowLevel:
      NSDebugLog(@"[%d] NSStatusWindowLevel", win);
    case NSFloatingWindowLevel:
      NSDebugLog(@"[%d] NSFloatingWindowLevel", win);
    case NSModalPanelWindowLevel:
      NSDebugLog(@"[%d] NSModalPanelWindowLevel", win);
    case NSNormalWindowLevel:
      NSDebugLog(@"[%d] NSNormalWindowLevel", win);
      [self createTopLevel:window];

      break;
    }
  window->is_out = 0;
}

- (BOOL)windowSurfaceHasRole:(struct window *)window
{
  return window->toplevel != NULL || window->layer_surface != NULL
	 || window->popup != NULL;
}

- (void)createTopLevel:(struct window *)window
{
  int win = window->window_id;
  NSDebugLog(@"[%d] createTopLevel", win);

  if ([self windowSurfaceHasRole:window])
    {
      // if the role is already assigned skip
      return;
    }

  if (window->surface)
    {
      wl_surface_destroy(window->surface);
    }
  window->surface = wl_compositor_create_surface(wlconfig->compositor);

  if (!window->surface)
    {
      NSDebugLog(@"can't create wayland surface");
      free(window);
      return;
    }

  wl_surface_set_user_data(window->surface, window);
  if (window->xdg_surface == NULL)
    {
      window->xdg_surface
	= xdg_wm_base_get_xdg_surface(wlconfig->wm_base, window->surface);
      window->toplevel = xdg_surface_get_toplevel(window->xdg_surface);

      xdg_toplevel_add_listener(window->toplevel, &xdg_toplevel_listener,
				window);
      xdg_surface_add_listener(window->xdg_surface, &xdg_surface_listener,
			       window);

      xdg_surface_set_window_geometry(window->xdg_surface, 0, 0, window->width,
				      window->height);
    }

  wl_surface_commit(window->surface);
  wl_display_dispatch_pending(window->wlconfig->display);
  wl_display_flush(window->wlconfig->display);
}

- (void)createLayerShell:(struct window *)window
	   withLayerType:(enum zwlr_layer_shell_v1_layer)layerType
	   withNamespace:(NSString *)namespace
{
  int win = window->window_id;
  NSDebugLog(@"[%d] createLayerShell: %@", win, namespace);

  if ([self windowSurfaceHasRole:window])
    {
      // if the role is already assigned skip
      return;
    }

  if (!wlconfig->layer_shell)
    {
      NSDebugLog(@"layer shell not supported, fallback to xdg toplevel");
      [self createTopLevel:window];
      return;
    }

  if (window->surface)
    {
      wl_surface_destroy(window->surface);
    }

  window->surface = wl_compositor_create_surface(wlconfig->compositor);
  wl_surface_set_user_data(window->surface, window);

  const char *cString = [namespace UTF8String];
  window->layer_surface
    = zwlr_layer_shell_v1_get_layer_surface(wlconfig->layer_shell,
					    window->surface,
					    window->output->output, layerType,
					    cString);
  assert(window->layer_surface);
  zwlr_layer_surface_v1_set_size(window->layer_surface, window->width,
				 window->height);

  zwlr_layer_surface_v1_set_anchor(window->layer_surface,
				   ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP
				     | ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT);

  zwlr_layer_surface_v1_set_exclusive_zone(window->layer_surface, 1);

  zwlr_layer_surface_v1_set_margin(window->layer_surface, window->pos_y, 0, 0,
				   window->pos_x);

  NSDebugLog(@"layer margins: %f,%f,%f,%f", window->pos_y, 0.0f, 0.0f,
	     window->pos_x);
  zwlr_layer_surface_v1_add_listener(window->layer_surface,
				     &layer_surface_listener, window);

  wl_surface_commit(window->surface);
  wl_display_dispatch_pending(window->wlconfig->display);
  wl_display_flush(window->wlconfig->display);
}
- (struct window *)getSuperMenuWindow:(struct window *)window
{
  NSMenuPanel *nswin = (GSWindowWithNumber(window->window_id));
  if (!nswin)
    {
      NSDebugLog(@"makeSubmenu can't find nswin");
      return NULL;
    }
  NSMenu *menu = [nswin _menu];
  if (!menu)
    {
      NSDebugLog(@"makeSubmenu can't find menu");
      return NULL;
    }
  NSMenu *supermenu = [menu supermenu];
  if (!supermenu)
    {
      NSDebugLog(@"makeSubmenu can't find supermenu");
      return NULL;
    }
  NSWindow *parent = [supermenu window];
  if (!parent)
    {
      NSDebugLog(@"makeSubmenu can't find the parent");
      return NULL;
    }

  struct window *parentwindow
    = get_window_with_id(wlconfig, [parent windowNumber]);

  return parentwindow;
}

- (void)createSubMenuShell:(struct window *)window
{
  int win = window->window_id;

  if ([self windowSurfaceHasRole:window])
    {
      // if the role is already assigned skip
      return;
    }

  if (wlconfig->layer_shell)
    {
      // the preferred way to create a submenu is to use an overlay
      [self createLayerShell:window
	       withLayerType:ZWLR_LAYER_SHELL_V1_LAYER_TOP
	       withNamespace:@"gnustep-submenu"];
      return;
    }
  else
    {
      NSDebugLog(@"layer shell not supported, fallback to xdg popup");
    }
  // if the layer shell is not available then we use the xdg popup
  // for that we need a parent toplevel window

  struct window *rootwindow = window;
  struct window *parentwindow = rootwindow;
  while (rootwindow = [self getSuperMenuWindow:parentwindow])
    {
      parentwindow = rootwindow;
    }
  if (!parentwindow)
    {
      return;
    }
  NSDebugLog(@"new popup: %d parent id: %d", win, parentwindow->window_id);
  NSDebugLog(@"parent: %d [%f,%f %fx%f]", parentwindow->window_id,
	     parentwindow->pos_x, parentwindow->pos_y, parentwindow->width,
	     parentwindow->height);

  [self createPopupShell:window withParentShell:parentwindow];
}

- (void)createPopup:(struct window *)window
{
  NSDebugLog(@"createPopup noop");
}

- (void)createPopupShell:(struct window *)child
	 withParentShell:(struct window *)parent
{
  NSDebugLog(@"createPopupShell");

  if (parent->toplevel == NULL && parent->layer_surface == NULL)
    {
      NSDebugLog(@"parent surface %d is not toplevel", parent->window_id);
      return;
    }
  if ([self windowSurfaceHasRole:child])
    {
      [self destroySurfaceRole:child];
    }

  child->surface = wl_compositor_create_surface(wlconfig->compositor);
  wl_surface_set_user_data(child->surface, child);

  NSWindow *nswin = (GSWindowWithNumber(child->window_id));
  CGFloat   x = nswin.frame.origin.x;
  CGFloat   y = nswin.frame.origin.y;
  CGFloat   width = nswin.frame.size.width;
  CGFloat   height = nswin.frame.size.height;

  child->xdg_surface
    = xdg_wm_base_get_xdg_surface(wlconfig->wm_base, child->surface);
  struct xdg_positioner *positioner
    = xdg_wm_base_create_positioner(wlconfig->wm_base);

  xdg_positioner_set_size(positioner, child->width, child->height);

  xdg_positioner_set_anchor_rect(positioner, 0.0, 0.0, parent->width,
				 parent->height);
  xdg_positioner_set_anchor(positioner, XDG_POSITIONER_ANCHOR_TOP_LEFT);
  xdg_positioner_set_gravity(positioner, XDG_POSITIONER_GRAVITY_BOTTOM_RIGHT);

  xdg_positioner_set_offset(positioner, (child->pos_x - parent->pos_x),
			    (child->pos_y - parent->pos_y));

  child->popup = xdg_surface_get_popup(child->xdg_surface, parent->xdg_surface,
				       positioner);

  if (parent->layer_surface)
    {
      zwlr_layer_surface_v1_get_popup(parent->layer_surface, child->popup);
    }

  xdg_popup_add_listener(child->popup, &xdg_popup_listener, child);
  xdg_surface_add_listener(child->xdg_surface, &xdg_surface_listener, child);

  xdg_surface_set_window_geometry(child->xdg_surface, 0, 0, child->width,
				  child->height);

  NSDebugLog(@"child_geometry : %f,%f %fx%f", child->pos_x - parent->pos_x,
	     child->pos_y - parent->pos_y, child->width, child->height);
  wl_surface_commit(child->surface);
  wl_display_roundtrip(wlconfig->display);
  xdg_positioner_destroy(positioner);
}

- (void)destroySurfaceRole:(struct window *)window
{
  NSDebugLog(@"[%d] destroySurfaceRole", window->window_id);

  if (window == NULL)
    {
      return;
    }
  if (window->layer_surface)
    {
      zwlr_layer_surface_v1_destroy(window->layer_surface);
      window->layer_surface = NULL;
    }
  if (window->xdg_surface)
    {
      if (window->toplevel)
	{
	  xdg_toplevel_destroy(window->toplevel);
	  window->toplevel = NULL;
	}
      if (window->popup)
	{
	  xdg_popup_destroy(window->popup);
	  window->popup = NULL;
	}
      xdg_surface_destroy(window->xdg_surface);
      window->xdg_surface = NULL;
    }
  if (window->wcs)
    {
      [window->wcs destroySurface];
    }
  window->configured = NO;
}

- (void)destroyWindowShell:(struct window *)window
{
  NSDebugLog(@"[%d] destroyWindowShell", window->window_id);

  [self destroySurfaceRole:window];

  window->is_out = 1;

  wl_display_dispatch_pending(window->wlconfig->display);
  wl_display_flush(window->wlconfig->display);
}

@end