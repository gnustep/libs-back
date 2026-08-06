/* A window manager for the offsets tests, forked by the test that needs one.
 *
 * It announces itself the way an EWMH window manager does and advertises
 * _NET_REQUEST_FRAME_EXTENTS.  What it does then depends on the mode:
 *
 * FakeWMDecorating answers that message with four zeros, which is what recent
 * Mutter releases do, and publishes the real extents as the window is mapped.
 *
 * FakeWMReparenting answers with zeros as well, and puts the window inside a
 * frame, publishing the real extents after the reparent, so a client reading
 * the property as soon as it sees the ReparentNotify reads the earlier answer.
 *
 * FakeWMUndecorated maps windows and decorates nothing, which is how a
 * rootless X server driving a native window manager can behave.
 */
#ifndef FAKE_WINDOW_MANAGER_H
#define FAKE_WINDOW_MANAGER_H

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>

/* The height of the window manager's title bar. */
#define FAKE_WM_TOP 37

enum
{
  /* Decorates, and publishes the extents as the window is mapped. */
  FakeWMDecorating = 0,
  /* Decorates by reparenting, and publishes the extents afterwards. */
  FakeWMReparenting = 1,
  /* Maps windows and decorates nothing at all. */
  FakeWMUndecorated = 2
};

/* The windows being probed are destroyed as soon as they have been measured,
 * so a request naming one can fail at any point.  Xlib's default handler
 * exits, which would take the window manager down in the middle of a run.
 */
static int
fakeWMIgnoreError(Display *d, XErrorEvent *e)
{
  return 0;
}

static void
fakeWMSetExtents(Display *dpy, Window w, long top)
{
  Atom	extents = XInternAtom(dpy, "_NET_FRAME_EXTENTS", False);
  long	v[4];

  v[0] = 0; v[1] = 0; v[2] = top; v[3] = 0;
  XChangeProperty(dpy, w, extents, XA_CARDINAL, 32, PropModeReplace,
    (unsigned char *)v, 4);
  XFlush(dpy);
}

/* Runs in the child and never returns. */
static void
fakeWMRun(int mode)
{
  Display	*dpy;
  Window	root;
  Window	check;
  Atom		supported[4];
  Atom		netCheck;
  Atom		netRequest;

  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      _exit(1);
    }
  XSetErrorHandler(fakeWMIgnoreError);
  root = DefaultRootWindow(dpy);
  netCheck = XInternAtom(dpy, "_NET_SUPPORTING_WM_CHECK", False);
  netRequest = XInternAtom(dpy, "_NET_REQUEST_FRAME_EXTENTS", False);

  check = XCreateSimpleWindow(dpy, root, -100, -100, 1, 1, 0, 0, 0);
  XChangeProperty(dpy, check, netCheck, XA_WINDOW, 32, PropModeReplace,
    (unsigned char *)&check, 1);
  XChangeProperty(dpy, check, XInternAtom(dpy, "_NET_WM_NAME", False),
    XInternAtom(dpy, "UTF8_STRING", False), 8, PropModeReplace,
    (unsigned char *)"testwm", 6);

  supported[0] = netCheck;
  supported[1] = netRequest;
  supported[2] = XInternAtom(dpy, "_NET_FRAME_EXTENTS", False);
  supported[3] = XInternAtom(dpy, "_NET_WM_NAME", False);
  XChangeProperty(dpy, root, XInternAtom(dpy, "_NET_SUPPORTED", False),
    XA_ATOM, 32, PropModeReplace, (unsigned char *)supported, 4);

  XSelectInput(dpy, root, SubstructureRedirectMask | SubstructureNotifyMask);
  /* Announced last, so a client that sees it finds the rest in place. */
  XChangeProperty(dpy, root, netCheck, XA_WINDOW, 32, PropModeReplace,
    (unsigned char *)&check, 1);
  XFlush(dpy);

  for (;;)
    {
      XEvent	e;

      XNextEvent(dpy, &e);
      if (e.type == ClientMessage && e.xclient.message_type == netRequest)
	{
	  /* One that decorates nothing has no extents to report. */
	  if (mode != FakeWMUndecorated)
	    {
	      fakeWMSetExtents(dpy, e.xclient.window, 0);
	    }
	}
      else if (e.type == MapRequest)
	{
	  if (mode == FakeWMUndecorated)
	    {
	      XMapWindow(dpy, e.xmaprequest.window);
	      XFlush(dpy);
	    }
	  else if (mode == FakeWMReparenting)
	    {
	      XWindowAttributes	wa;
	      Window		frame;

	      XGetWindowAttributes(dpy, e.xmaprequest.window, &wa);
	      frame = XCreateSimpleWindow(dpy, root, wa.x, wa.y,
		wa.width, wa.height + FAKE_WM_TOP, 0, 0, 0);
	      XReparentWindow(dpy, e.xmaprequest.window, frame,
		0, FAKE_WM_TOP);
	      XMapWindow(dpy, frame);
	      XMapWindow(dpy, e.xmaprequest.window);
	      XFlush(dpy);
	      usleep(200000);
	      fakeWMSetExtents(dpy, e.xmaprequest.window, FAKE_WM_TOP);
	    }
	  else
	    {
	      fakeWMSetExtents(dpy, e.xmaprequest.window, FAKE_WM_TOP);
	      XMapWindow(dpy, e.xmaprequest.window);
	      XFlush(dpy);
	    }
	}
      else if (e.type == MapNotify && mode == FakeWMDecorating
	&& e.xmap.window != check)
	{
	  fakeWMSetExtents(dpy, e.xmap.window, FAKE_WM_TOP);
	}
    }
}

/* Wait for the child to announce itself, so the backend finds a window
 * manager when it starts.  Answers NO if it never appears.
 */
static BOOL
fakeWMWait(void)
{
  Display	*dpy;
  Atom		netCheck;
  unsigned	i;

  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      return NO;
    }
  netCheck = XInternAtom(dpy, "_NET_SUPPORTING_WM_CHECK", False);
  for (i = 0; i < 200; i++)
    {
      Atom		type;
      int		format;
      unsigned long	nitems;
      unsigned long	after;
      unsigned char	*data = NULL;

      if (XGetWindowProperty(dpy, DefaultRootWindow(dpy), netCheck, 0, 1,
	    False, XA_WINDOW, &type, &format, &nitems, &after, &data)
	  == Success && data != NULL)
	{
	  XFree(data);
	  if (nitems == 1)
	    {
	      XCloseDisplay(dpy);
	      return YES;
	    }
	}
      usleep(50000);
    }
  XCloseDisplay(dpy);
  return NO;
}

/* Answers the process id of the window manager, or -1. */
static pid_t
fakeWMStart(int mode)
{
  pid_t	wm = fork();

  if (wm == 0)
    {
      fakeWMRun(mode);
      _exit(0);
    }
  if (wm < 0)
    {
      return -1;
    }
  if (fakeWMWait() == NO)
    {
      kill(wm, SIGKILL);
      return -1;
    }
  return wm;
}

#endif
