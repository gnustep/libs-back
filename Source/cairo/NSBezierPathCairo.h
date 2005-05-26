/*
 * NSBezierPathCairo.m

 * Copyright (C) 2003 Free Software Foundation, Inc.
 * April 10, 2004
 * Written by Banlu Kemiyatorn <object at gmail dot com>
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.

 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/NSBezierPath.h>
#include <cairo.h>

@interface NSBezierPath (Cairo) 
+ (void) initializeCairoBezierPath;
+ (NSBezierPath *) bezierPathFromCairo: (cairo_t *)ct;
- (void) appendBezierPathToCairo: (cairo_t *)ct;
- (BOOL) containsFillPoint: (NSPoint)p;
- (BOOL) containsStrokePoint: (NSPoint)p;
@end 
