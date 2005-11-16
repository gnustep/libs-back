/* WIN32Server - Implements window handling for MSWindows

   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by: Tom MacSween <macsweent@sympatico.ca>
   Date August 2005
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
   */

#include <GNUstepGUI/GSDisplayServer.h>
#include "w32_events.h"

@implementation GSDisplayServer (GSDisplayServer_details)

- (int) eventQueCount
{
  return [event_queue count];
}

- (NSMutableString *) dumpQue:(int)acount
{
  NSMutableString * output=[NSMutableString stringWithCString:"Dumping "];
    
  int i=0;
  int c=[event_queue count];
  if (acount >=c || acount==0)
    acount=c;
  else
    c=acount;
       
  if (c==0)
    {
      [output appendString:@"0 Events Que is empty\n"];
      return output;
    }
            
  [output appendFormat:@"%d From the EventQue\n-> ",c];   
        
  for (i=0;i<c;i++)
    {
      [output appendFormat:@"%d EventType %d\n-> "
	      ,i,[(NSEvent *)[event_queue objectAtIndex:i] type]]; 
    }
  [output appendString:@"\n"];     
  return output;
        
}

- (void) clearEventQue
{
  [event_queue removeAllObjects];
}

@end
