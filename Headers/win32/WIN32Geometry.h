/* WIN32Geometry - Implements coordinate transformations for MSWindows

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: April 2002
   
   This file is part of the GNU Objective C User Interface Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _WIN32Geometry_h_INCLUDE
#define _WIN32Geometry_h_INCLUDE

#include <Foundation/NSGeometry.h>

#include <windows.h>

static inline
NSPoint MSWindowPointToGS(HWND hwnd,  int x, int y)
{
  NSPoint p1;
  RECT rect;
  int h;

  GetClientRect(hwnd, &rect);
  h = rect.bottom - rect.top;

  p1.x = x;
  p1.y = h - y;
  return p1;
}

static inline
POINT GSWindowPointToMS(HWND hwnd, NSPoint p)
{
  POINT p1;
  RECT rect;
  int h;

  GetClientRect(hwnd, &rect);
  h = rect.bottom - rect.top;

  p1.x = p.x;
  p1.y = h -p.y;

  return p1;
}

static inline
NSRect MSWindowRectToGS(HWND hwnd,  RECT r)
{
  NSRect r1;
  RECT rect;
  int h;

  GetClientRect(hwnd, &rect);
  h = rect.bottom - rect.top;

  r1.origin.x = r.left;
  r1.origin.y = h - r.bottom;
  r1.size.width = r.right - r.left;
  r1.size.height = r.bottom -r.top;

  return r1;
}

static inline
RECT GSWindowRectToMS(HWND hwnd, NSRect r)
{
  RECT r1;
  RECT rect;
  int h;

  GetClientRect(hwnd, &rect);
  h = rect.bottom - rect.top;

  r1.left = r.origin.x;
  r1.bottom = h - r.origin.y;
  r1.right = r.origin.x + r.size.width;
  r1.top = h - r.origin.y - r.size.height;

  return r1;
}


static inline
NSPoint MSWindowOriginToGS(HWND hwnd, int x, int y)
{
  NSPoint p1;
  RECT rect;
  int h;
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  GetWindowRect(hwnd, &rect);
  h = rect.bottom - rect.top;

  p1.x = x;
  p1.y = screen_height - y - h;
  return p1;
}

static inline
POINT GSWindowOriginToMS(HWND hwnd, NSPoint p)
{
  POINT p1;
  RECT rect;
  int h;
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  GetWindowRect(hwnd, &rect);
  h = rect.bottom - rect.top;

  p1.x = p.x;
  p1.y = screen_height - p.y + h;
  return p1;
}

static inline
NSPoint MSScreenPointToGS(int x, int y)
{
  NSPoint p1;
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  p1.x = x;
  p1.y = screen_height - y;
  return p1;
}

static inline
NSRect MSScreenRectToGS(RECT r)
{
  NSRect r1;
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  r1.origin.x = r.left;
  r1.origin.y = screen_height - r.bottom;
  r1.size.width = r.right - r.left;
  r1.size.height = r.bottom - r.top;

  return r1;
}

static inline
POINT GSScreenPointToMS(NSPoint p)
{
  POINT p1;
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  p1.x = p.x;
  p1.y = screen_height - p.y;
  return p1;
}

static inline
RECT GSScreenRectToMS(NSRect r)
{
  RECT r1;
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  r1.left = r.origin.x;
  r1.bottom = screen_height - r.origin.y;
  r1.right = r.origin.x + r.size.width;
  r1.top = screen_height - r.origin.y - r.size.height;

  return r1;
}


#endif /* _WIN32Geometry_h_INCLUDE */
