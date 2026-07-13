/* Coverage for the Wayland EGL/OpenGL support (Source/wayland/
 * WaylandGLContext.m and WaylandGLPixelFormat.m): an NSOpenGLPixelFormat and
 * NSOpenGLContext are created, and an NSOpenGLView backs a window with a current
 * context that reports a GL version.  This exercises WaylandGLPixelFormat's EGL
 * config selection and WaylandGLContext's EGL context and wl_egl_window surface
 * (eglMakeCurrent).
 *
 * It guards on the wayland server with cairo and EGL, and skips when the backend
 * or a GL drawable cannot be reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(HAVE_EGL) && defined(BUILD_SERVER) && defined(SERVER_wayland) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_wayland && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <AppKit/NSOpenGL.h>
#import <AppKit/NSOpenGLView.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <GL/gl.h>
#include <string.h>

int
main(void)
{
  START_SET("Wayland EGL OpenGL context")
  ENTER_POOL

  GSDisplayServer *server = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      server = GSCurrentServer();
    }
  NS_HANDLER
    {
      server = nil;
    }
  NS_ENDHANDLER

  if (server == nil)
    {
      SKIP("no Wayland compositor available")
    }
  else
    {
      NSOpenGLPixelFormatAttribute attrs[] = {
	NSOpenGLPFAWindow,
	NSOpenGLPFADoubleBuffer,
	NSOpenGLPFADepthSize, 16,
	NSOpenGLPFAColorSize, 24,
	0
      };
      NSOpenGLPixelFormat *pf = [[[NSOpenGLPixelFormat alloc]
				   initWithAttributes: attrs] autorelease];
      NSOpenGLContext *ctx;
      BOOL             gotVersion = NO;

      PASS(pf != nil, "an NSOpenGLPixelFormat is created from attributes")

      ctx = [[[NSOpenGLContext alloc] initWithFormat: pf
					shareContext: nil] autorelease];
      PASS(ctx != nil, "an NSOpenGLContext is created from the pixel format")

      /* An NSOpenGLView binds an EGL context to a window; once current, the GL
       * implementation reports a version string. */
      NS_DURING
	{
	  NSOpenGLView *v = [[[NSOpenGLView alloc]
			       initWithFrame: NSMakeRect(0, 0, 64, 64)
				 pixelFormat: pf] autorelease];
	  NSWindow *win = [[NSWindow alloc]
			    initWithContentRect: NSMakeRect(50, 50, 64, 64)
				      styleMask: NSTitledWindowMask
					backing: NSBackingStoreBuffered
					  defer: NO];

	  [win setContentView: v];
	  [win orderFront: nil];
	  [[v openGLContext] makeCurrentContext];
	  {
	    const char *ver = (const char *) glGetString(GL_VERSION);

	    gotVersion = (ver != NULL && strlen(ver) > 0);
	  }
	  [win close];
	}
      NS_HANDLER
	{
	  gotVersion = NO;
	}
      NS_ENDHANDLER

      PASS(gotVersion == YES,
	"a current EGL context reports a GL version string")
    }

  LEAVE_POOL
  END_SET("Wayland EGL OpenGL context")
  return 0;
}

#else

int
main(void)
{
  START_SET("Wayland EGL OpenGL context")
    SKIP("back is not built with the wayland+cairo backend and EGL")
  END_SET("Wayland EGL OpenGL context")
  return 0;
}

#endif
