/*
   Copyright (C) 2002, 2003, 2004, 2005 Free Software Foundation, Inc.

   Author:  Alexander Malmberg <alexander@malmberg.org>

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#include <config.h>

#include <Foundation/NSUserDefaults.h>

#include "xheadless/XGServer.h"
#include "xheadless/XGServerWindow.h"
#include "xheadless/XWindowBuffer.h"

#include <math.h>
#include <sys/ipc.h>
#include <sys/shm.h>

#ifdef HAVE_XSHAPE
#include <X11/extensions/shape.h>
#endif

static XWindowBuffer **window_buffers;
static int num_window_buffers;


static int use_shape_hack = 0; /* this is an ugly hack : ) */

#ifdef XSHM

static int did_test_xshm = 0;
static int use_xshm = 1;
static Bool use_xshm_pixmaps = 0;
static int num_xshm_test_errors = 0;

static int test_xshm_error_handler(Display *d, XErrorEvent *ev)
{
  num_xshm_test_errors++;
  return 0;
}

static void test_xshm(Display *display, Visual *visual, int drawing_depth)
{
}
#endif

@implementation XWindowBuffer

+ (void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  use_shape_hack = [ud boolForKey: @"XWindowBuffer-shape-hack"];
}

+ windowBufferForWindow: (gswindow_device_t *)awindow
              depthInfo: (struct XWindowBuffer_depth_info_s *)aDI
{
  return AUTORELEASE([[XWindowBuffer alloc] init]);
}


extern int XShmGetEventBase(Display *d);

- (void) _gotShmCompletion
{
}

- (void) _exposeRect: (NSRect)rect
{
}

- (void) needsAlpha
{
}

- (void) dealloc
{
  [super dealloc];
}


+ (void) _gotShmCompletion: (Drawable)d
{
}

@end

