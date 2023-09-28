/* HeadlessContext.m - Headless Context
 * 
 *  Copyright (c) 2023 Keysight Technologies
 * 
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *  
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *  
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include "config.h"

#include "headless/HeadlessContext.h"
#include "headless/HeadlessFontInfo.h"
#include "headless/HeadlessFontEnumerator.h"
#include "headless/HeadlessGState.h"

@implementation HeadlessContext

+ (void) initializeBackend
{
  [NSGraphicsContext setDefaultContextClass: self];

  [GSFontEnumerator setDefaultClass: [HeadlessFontEnumerator class]];
  [GSFontInfo setDefaultClass: [HeadlessFontInfo class]];
}

+ (Class) GStateClass
{
  return [HeadlessGState class];
}

@end
