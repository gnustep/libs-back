/* -*- mode:ObjC -*-
   WaylandGLPixelFormat - backend implementation of NSOpenGLPixelFormat

   Copyright (C) 2026 Free Software Foundation, Inc.

   This file is part of the GNUstep Backend.

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

#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <Foundation/NSZone.h>
#include <string.h>
#include <EGL/egl.h>

#include "wayland/WaylandOpenGL.h"

@implementation WaylandGLPixelFormat

static BOOL
_isAttributeWithValue(NSOpenGLPixelFormatAttribute attr)
{
  switch (attr)
    {
      case NSOpenGLPFAAuxBuffers:
      case NSOpenGLPFAColorSize:
      case NSOpenGLPFAAlphaSize:
      case NSOpenGLPFADepthSize:
      case NSOpenGLPFAStencilSize:
      case NSOpenGLPFAAccumSize:
      case NSOpenGLPFARendererID:
      case NSOpenGLPFAScreenMask:
      case NSOpenGLPFASamples:
      case NSOpenGLPFAAuxDepthStencil:
      case NSOpenGLPFASampleBuffers:
        return YES;
      default:
        return NO;
    }
}

- (id)initWithAttributes:(NSOpenGLPixelFormatAttribute *)attribs
{
  NSOpenGLPixelFormatAttribute *ptr;

  self = [super init];
  if (self == nil)
    {
      return nil;
    }

  if (attribs == NULL)
    {
      _attributeCount = 1;
      _attributes = NSZoneMalloc(NSDefaultMallocZone(),
                                 sizeof(NSOpenGLPixelFormatAttribute));
      _attributes[0] = (NSOpenGLPixelFormatAttribute)0;
      return self;
    }

  _attributeCount = 1;
  for (ptr = attribs; *ptr != 0; ptr++)
    {
      _attributeCount++;
      if (_isAttributeWithValue(*ptr))
        {
          if (*(ptr + 1) != 0)
            {
              ptr++;
              _attributeCount++;
            }
        }
    }

  _attributes = NSZoneMalloc(NSDefaultMallocZone(),
                             _attributeCount * sizeof(NSOpenGLPixelFormatAttribute));
  memcpy(_attributes, attribs,
         _attributeCount * sizeof(NSOpenGLPixelFormatAttribute));

  return self;
}

- (EGLConfig)eglConfigForDisplay:(EGLDisplay)eglDisplay
{
  EGLint redSize = 8;
  EGLint greenSize = 8;
  EGLint blueSize = 8;
  EGLint alphaSize = 8;
  EGLint depthSize = 24;
  EGLint stencilSize = 8;
  EGLint sampleBuffers = 0;
  EGLint samples = 0;
  EGLint renderableType = EGL_OPENGL_BIT;
#ifdef EGL_OPENGL_ES2_BIT
  renderableType |= EGL_OPENGL_ES2_BIT;
#endif
  EGLConfig config = NULL;
  EGLint configCount = 0;
  NSUInteger i;

  if (_attributes != NULL)
    {
      for (i = 0; i < _attributeCount; i++)
        {
          NSOpenGLPixelFormatAttribute attr = _attributes[i];
          if (_isAttributeWithValue(attr) == NO)
            {
              continue;
            }

          if (i + 1 >= _attributeCount)
            {
              break;
            }

          switch (attr)
            {
              case NSOpenGLPFAColorSize:
                redSize = greenSize = blueSize = ((EGLint)_attributes[i + 1] / 3);
                if (redSize < 1)
                  {
                    redSize = greenSize = blueSize = 1;
                  }
                break;
              case NSOpenGLPFAAlphaSize:
                alphaSize = _attributes[i + 1];
                break;
              case NSOpenGLPFADepthSize:
                depthSize = _attributes[i + 1];
                break;
              case NSOpenGLPFAStencilSize:
                stencilSize = _attributes[i + 1];
                break;
              case NSOpenGLPFASampleBuffers:
                sampleBuffers = _attributes[i + 1];
                break;
              case NSOpenGLPFASamples:
                samples = _attributes[i + 1];
                break;
              default:
                break;
            }

          i++;
        }
    }

  {
    EGLint attrs[] = {
      EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
      EGL_RENDERABLE_TYPE, renderableType,
      EGL_RED_SIZE, redSize,
      EGL_GREEN_SIZE, greenSize,
      EGL_BLUE_SIZE, blueSize,
      EGL_ALPHA_SIZE, alphaSize,
      EGL_DEPTH_SIZE, depthSize,
      EGL_STENCIL_SIZE, stencilSize,
      EGL_SAMPLE_BUFFERS, sampleBuffers,
      EGL_SAMPLES, samples,
      EGL_NONE
    };

    if (eglChooseConfig(eglDisplay, attrs, &config, 1, &configCount) == EGL_FALSE
        || configCount == 0)
      {
        NSDebugMLLog(@"OpenGL", @"No EGL config matched requested NSOpenGL attributes");
        return NULL;
      }
  }

  return config;
}

- (void)getValues:(int *)vals
     forAttribute:(NSOpenGLPixelFormatAttribute)attrib
 forVirtualScreen:(int)screen
{
  NSUInteger i;

  (void)screen;

  if (vals == NULL)
    {
      return;
    }

  *vals = 0;
  if (_attributes == NULL)
    {
      return;
    }

  for (i = 0; i + 1 < _attributeCount; i++)
    {
      if (_attributes[i] == attrib)
        {
          if (_isAttributeWithValue(attrib))
            {
              *vals = _attributes[i + 1];
            }
          else
            {
              *vals = 1;
            }
          return;
        }
    }
}

- (void)dealloc
{
  if (_attributes != NULL)
    {
      NSZoneFree(NSDefaultMallocZone(), _attributes);
      _attributes = NULL;
    }

  [super dealloc];
}

@end
