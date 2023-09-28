/*
   HwadlessFaceInfo.m
   Copyright (C) 2003, 2023 Free Software Foundation, Inc.
   August 17, 2023
   Re-written by Gregory Casamento <greg.casamento@gmail.com>
   Based on work Marcian Lytwyn <gnustep@advcsi.com>
   August 31, 2003
   Originally Written by Banlu Kemiyatorn <object at gmail dot com>
   Base on original code of Alex Malmberg
   Rewrite: Fred Kiefer <fredkiefer@gmx.de>
   Date: Jan 2006
   This file is part of GNUstep.
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.
   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#include "headless/HeadlessFaceInfo.h"

@implementation HeadlessFaceInfo

- (void) dealloc
{
  [super dealloc];
}

- (void *)fontFace
{
  return _fontFace;
}

@end