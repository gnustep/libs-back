/* Win32FontEnumerator - Implements font enumerator for MSWindows

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   
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

#include "Foundation/NSValue.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSDictionary.h"

#include "winlib/WIN32FontEnumerator.h"

@implementation WIN32FontEnumerator

- (void) enumerateFontsAndFamilies
{
  /*
    int CALLBACK EnumFontFamProc(
  ENUMLOGFONT *lpelf,    // logical-font data
  NEWTEXTMETRIC *lpntm,  // physical-font data
  DWORD FontType,        // type of font
  LPARAM lParam          // application-defined data
);

  EnumFontFamilies(hdc, (LPCTSTR) NULL, 
		   (FONTENUMPROC) EnumFamCallBack, (LPARAM) aFontCount); 

  if (cache == nil)
    {
      if (load_cache(cache_name(), NO))
        {
	  allFontNames = [[cache objectForKey: @"AllFontNames"] allObjects];
	  allFontFamilies = [cache objectForKey: @"AllFontFamilies"];
	  // This dictionary stores the XLFD for each font
	  creationDictionary = [cache objectForKey: @"CreationDictionary"];
	}
    }
  */
  static BOOL done = NO;

  if (!done)
    {
      NSArray *fontDef;
      NSMutableArray *fontDefs;

      ASSIGN(allFontNames, [NSArray arrayWithObject: @"Helvetica"]);
      allFontFamilies = [[NSMutableDictionary alloc] init];

      fontDefs = [NSMutableArray arrayWithCapacity: 10];
      [allFontFamilies setObject: fontDefs forKey: @"Helvetica"];
      
      
      fontDef = [NSArray arrayWithObjects: @"Helvetica", @"", 
			 [NSNumber numberWithInt: 6],
			 [NSNumber numberWithUnsignedInt: 0], nil];
      [fontDefs addObject: fontDef];

      done = YES;
    }
}

@end
