/* Coverage for the win32 WGL OpenGL support (Source/win32/w32_GLcontext.m and
 * w32_GLformat.m): an NSOpenGLPixelFormat and NSOpenGLContext are created, and
 * an NSOpenGLView backs a window with a current WGL context that reports a GL
 * version.  This exercises Win32GLPixelFormat, Win32GLContext and the subwindow
 * that binds the WGL context (wglCreateContext / wglMakeCurrent).
 *
 * It guards on the winlib graphics backend with WGL available, and skips when
 * the backend or a GL drawable cannot be reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(HAVE_WGL) && defined(BUILD_GRAPHICS) && defined(GRAPHICS_winlib) \
  && BUILD_GRAPHICS == GRAPHICS_winlib

#import <AppKit/AppKit.h>
#import <AppKit/NSOpenGL.h>
#import <AppKit/NSOpenGLView.h>
#include <GL/gl.h>
#include <string.h>

int
main(void)
{
  START_SET("win32 WGL OpenGL context")
  ENTER_POOL

  BOOL haveApp = NO;

  NS_DURING
    {
      [NSApplication sharedApplication];
      haveApp = YES;
    }
  NS_HANDLER
    {
      haveApp = NO;
    }
  NS_ENDHANDLER

  if (haveApp == NO)
    {
      SKIP("no win32 gui available")
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

      /* An NSOpenGLView binds a WGL context to a window; once current, the GL
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
	"a current WGL context reports a GL version string")
    }

  LEAVE_POOL
  END_SET("win32 WGL OpenGL context")
  return 0;
}

#else

int
main(void)
{
  START_SET("win32 WGL OpenGL context")
    SKIP("back is not built with the winlib graphics backend and WGL")
  END_SET("win32 WGL OpenGL context")
  return 0;
}

#endif
