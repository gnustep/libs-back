/*
   OpalFontEnumerator.m

   Copyright (C) 2013 Free Software Foundation, Inc.

   Author: Ivan Vucica <ivan@vucica.net>
   Date: June 2013

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

#import "opal/OpalFontEnumerator.h"

#import <Foundation/Foundation.h>

@interface OpalFaceInfo : NSObject
/* DUMMY interface */
{
  NSString * _familyName;
  int _weight;
  unsigned int _traits;
}
- (id) initWithFamilyName: (NSString *)familyName 
                   weight: (int)weight 
                   traits: (unsigned int)traits;

- (unsigned int) cacheSize;

- (int) weight;
- (void) setWeight: (int)weight;
- (unsigned int) traits;
- (void) setTraits: (unsigned int)traits;

- (NSString *) familyName;
- (void) setFamilyName: (NSString *)name;

- (NSCharacterSet*)characterSet;
@end
@implementation OpalFaceInfo
/* DUMMY implementation */
- (id) initWithFamilyName: (NSString *)familyName 
                   weight: (int)weight 
                   traits: (unsigned int)traits 
{
  self = [super init];
  if (!self)
    return nil;
  
  _familyName = [familyName retain];
  _weight = weight;
  _traits = traits;
  
  return self;
}
- (int) weight { NSLog(@"OpalFontEnumerator: Weight %d", _weight); return _weight; }
- (void) setWeight: (int)weight { _weight = weight; }
- (unsigned int) traits { return _traits; }
- (void) setTraits: (unsigned int)traits { _traits = traits; }
- (NSString *)familyName { return _familyName; }
- (void) setFamilyName: (NSString *)name { [_familyName release]; _familyName = [name retain]; }

- (NSCharacterSet *) characterSet {  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
 return [NSCharacterSet alphanumericCharacterSet]; }
@end



@implementation OpalFontEnumerator

+ (OpalFaceInfo *) fontWithName: (NSString *) name
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  NSLog(@"Font with name %@", name);
  return [[[OpalFaceInfo alloc] initWithFamilyName:name weight:1 traits:0] autorelease];
}

- (void) enumerateFontsAndFamilies
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  allFontNames = [[NSArray arrayWithObjects: @"FreeSans", 
                   @"FreeSans-Bold", @"FreeMono", nil] retain];
  allFontFamilies = [[NSDictionary dictionaryWithObjectsAndKeys:
                      @"FreeSans", @"FreeSans",
                      @"FreeMono", @"FreeMono",
                      nil] retain];
  
}

- (NSString *) defaultSystemFontName
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  return @"FreeSans";
}
- (NSString *) defaultBoldSystemFontName
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  return @"FreeSans-Bold";
}
- (NSString *) defaultFixedPitchFontName
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  return @"FreeMono";
}
- (NSArray *) matchingFontDescriptorsFor: (NSDictionary *)attributes
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  return [NSArray arrayWithObject:[NSFontDescriptor fontDescriptorWithName:@"FreeSans" size: 10]];
}
@end

