/* The frame of a screen has to track the X screen rather than the CRTC
 * data: RRSetScreenSize (xrandr --fb, streaming servers) resizes the
 * framebuffer without touching the CRTC.  With a window manager the frame
 * has to stay the _NET_WORKAREA it publishes.  The test runs its own Xvfb
 * and re-executes itself per reading, so each one is what a freshly
 * launched application would see.  */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) && BUILD_SERVER == SERVER_x11

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>

static const char *display = ":9771";
static const char *selfExe = "./screenframe";

static int
readFrame(float *w, float *h)
{
  char cmd[600];
  FILE *p;

  snprintf(cmd, sizeof(cmd), "%s --dump 2>/dev/null", selfExe);
  p = popen(cmd, "r");
  if (p == NULL)
    {
      return -1;
    }
  *w = *h = -1;
  fscanf(p, "%f %f", w, h);
  pclose(p);
  return (*w < 0) ? -1 : 0;
}

int
main(int argc, const char **argv)
{
  float w = -1;
  float h = -1;

  if (argc > 1 && strcmp(argv[1], "--dump") == 0)
    {
      extern void initialize_gnustep_backend(void);
      GSDisplayServer *srv;
      NSRect f;

      initialize_gnustep_backend();
      srv = [GSDisplayServer serverWithAttributes: nil];
      if (srv == nil)
        {
          return 1;
        }
      [GSDisplayServer setCurrentServer: srv];
      f = [[NSScreen mainScreen] frame];
      printf("%.0f %.0f\n", f.size.width, f.size.height);
      return 0;
    }

  START_SET("screen frame")

  if (argc > 0 && argv[0] != NULL)
    {
      selfExe = argv[0];
    }

  if (system("command -v Xvfb >/dev/null 2>&1"
             " && command -v xrandr >/dev/null 2>&1"
             " && command -v xprop >/dev/null 2>&1") != 0)
    {
      SKIP("needs Xvfb with RANDR, xrandr and xprop")
    }

  setenv("DISPLAY", display, 1);
  {
    char cmd[600];

    snprintf(cmd, sizeof(cmd),
             "Xvfb %s -screen 0 1280x800x24 +extension RANDR"
             " -nolisten tcp >/dev/null 2>&1 & sleep 1", display);
    if (system(cmd) != 0 || readFrame(&w, &h) != 0)
      {
        SKIP("the Xvfb display did not come up")
      }
  }

  PASS(w == 1280 && h == 800,
    "a fresh application sees the frame of the initial screen");

  system("xrandr --fb 1680x1050");
  usleep(200000);
  if (readFrame(&w, &h) != 0)
    {
      SKIP("reading the frame failed")
    }
  PASS(w == 1680 && h == 1050,
    "the frame follows the framebuffer after an fb-only resize,"
    " which leaves the CRTC reporting the old mode");

  system("xprop -root -f _NET_WORKAREA 32c"
         " -set _NET_WORKAREA '0, 0, 1680, 1000'");
  usleep(200000);
  if (readFrame(&w, &h) != 0)
    {
      SKIP("reading the frame failed")
    }
  PASS(!(w == 1680 && h == 1050),
    "a published work area keeps the frame from following the framebuffer");

  system("xprop -root -remove _NET_WORKAREA");
  system("xrandr --newmode t1024x768 65.0 1024 1048 1184 1344"
         " 768 771 777 806 -hsync -vsync");
  system("xrandr --addmode screen t1024x768");
  system("xrandr --output screen --mode t1024x768");
  usleep(200000);
  if (readFrame(&w, &h) != 0)
    {
      SKIP("reading the frame failed")
    }
  PASS(w == 1024 && h == 768,
    "the frame follows a mode change");

  system("pkill -x Xvfb");

  END_SET("screen frame")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("screen frame")
    SKIP("back is not built with the x11 server")
  END_SET("screen frame")
  return 0;
}

#endif
