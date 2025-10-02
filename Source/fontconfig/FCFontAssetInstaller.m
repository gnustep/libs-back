/* Implementation of class FCFontAssetInstaller
   Copyright (C) 2024 Free Software Foundation, Inc.

   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: September 5, 2025

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import <Foundation/Foundation.h>
#import "fontconfig/FCFontAssetInstaller.h"

@implementation FCFontAssetInstaller

- (instancetype) initWithFontPath: (NSString *)path
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_fontPath, path);
    }
  return self;
}

- (instancetype) init
{
  return [self initWithFontPath: nil];
}

- (BOOL) validateFontError: (NSError **)error
{
  if (_fontPath == nil)
    {
      if (error != NULL)
	{
	  NSDictionary *userInfo = [NSDictionary dictionaryWithObject: @"Font path is nil"
							       forKey: NSLocalizedDescriptionKey];
	  *error = [NSError errorWithDomain: @"FCFontAssetInstallerErrorDomain"
				       code: -3001
				   userInfo: userInfo];
	}
      return NO;
    }

  // Check if file exists
  if (![[NSFileManager defaultManager] fileExistsAtPath: _fontPath])
    {
      if (error != NULL)
	{
	  NSDictionary *userInfo = [NSDictionary dictionaryWithObject: @"Font file does not exist"
							       forKey: NSLocalizedDescriptionKey];
	  *error = [NSError errorWithDomain: @"FCFontAssetInstallerErrorDomain"
				       code: -3002
				   userInfo: userInfo];
	}
      return NO;
    }

  // Basic validation - check file size and magic bytes
  NSData *fontData = [NSData dataWithContentsOfFile: _fontPath];
  if (fontData == nil || [fontData length] < 12)
    {
      if (error != NULL)
	{
	  NSDictionary *userInfo = [NSDictionary dictionaryWithObject: @"Font file is too small or unreadable"
							       forKey: NSLocalizedDescriptionKey];
	  *error = [NSError errorWithDomain: @"FCFontAssetInstallerErrorDomain"
				       code: -3003
				   userInfo: userInfo];
	}
      return NO;
    }

  // Check for common font file signatures (TTF, OTF, WOFF, WOFF2)
  const unsigned char *bytes = [fontData bytes];

  // TTF signature: 0x00, 0x01, 0x00, 0x00 or 'true'
  // OTF signature: 'OTTO'
  // WOFF signature: 'wOFF'
  // WOFF2 signature: 'wOF2'
  if ((bytes[0] == 0x00 && bytes[1] == 0x01 && bytes[2] == 0x00 && bytes[3] == 0x00) ||
      (bytes[0] == 't' && bytes[1] == 'r' && bytes[2] == 'u' && bytes[3] == 'e') ||
      (bytes[0] == 'O' && bytes[1] == 'T' && bytes[2] == 'T' && bytes[3] == 'O') ||
      (bytes[0] == 'w' && bytes[1] == 'O' && bytes[2] == 'F' && bytes[3] == 'F') ||
      (bytes[0] == 'w' && bytes[1] == 'O' && bytes[2] == 'F' && bytes[3] == '2'))
    {
      return YES;
    }

  if (error != NULL)
    {
      NSDictionary *userInfo = [NSDictionary dictionaryWithObject: @"Font file does not have a valid font signature"
							   forKey: NSLocalizedDescriptionKey];
      *error = [NSError errorWithDomain: @"FCFontAssetInstallerErrorDomain"
				   code: -3004
			       userInfo: userInfo];
    }
  return NO;
}

- (BOOL) installFontError: (NSError **)error
{
  if (_fontPath == nil)
    {
      if (error != NULL)
	{
	  NSDictionary *userInfo = [NSDictionary dictionaryWithObject: @"Font path is nil"
							       forKey: NSLocalizedDescriptionKey];
	  *error = [NSError errorWithDomain: @"FCFontAssetInstallerErrorDomain"
				       code: -4001
				   userInfo: userInfo];
	}
      return NO;
    }

  NSString *filename = [_fontPath lastPathComponent];
  NSString *destinationDir;

  // Determine installation directory based on options
  destinationDir = [self systemFontsDirectory];
  if (destinationDir == nil)
    {
      destinationDir = [self userFontsDirectory];
    }

  if (destinationDir == nil)
    {
      if (error != NULL)
	{
	  NSDictionary *userInfo = [NSDictionary dictionaryWithObject: @"Cannot determine font installation directory"
							       forKey: NSLocalizedDescriptionKey];
	  *error = [NSError errorWithDomain: @"FCFontAssetInstallerErrorDomain"
				       code: -4002
				   userInfo: userInfo];
	}
      return NO;
    }

  // Create destination directory if needed
  NSError *dirError = nil;
  if (![[NSFileManager defaultManager] createDirectoryAtPath: destinationDir
				 withIntermediateDirectories: YES
						  attributes: nil
						       error: &dirError])
    {
      if (error != NULL)
	{
	  NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
						   @"Failed to create font installation directory", NSLocalizedDescriptionKey,
						 [dirError localizedDescription], NSLocalizedFailureReasonErrorKey,
						 nil];
	  *error = [NSError errorWithDomain: @"FCFontAssetInstallerErrorDomain"
				       code: -4003
				   userInfo: userInfo];
	}
      return NO;
    }

  // Copy font to destination
  NSString *destinationPath = [destinationDir stringByAppendingPathComponent: filename];
  NSError *copyError = nil;

  // Remove existing font file if present
  if ([[NSFileManager defaultManager] fileExistsAtPath: destinationPath])
    {
      [[NSFileManager defaultManager] removeItemAtPath: destinationPath error: nil];
    }

  if (![[NSFileManager defaultManager] copyItemAtPath: _fontPath
					       toPath: destinationPath
						error: &copyError])
    {
      if (error != NULL)
	{
	  NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
						   @"Failed to copy font to installation directory", NSLocalizedDescriptionKey,
						 [copyError localizedDescription], NSLocalizedFailureReasonErrorKey,
						 nil];
	  *error = [NSError errorWithDomain: @"FCFontAssetInstallerErrorDomain"
				       code: -4004
				   userInfo: userInfo];
	}
      return NO;
    }

  // Notify system of new font (platform-specific)
#ifdef __APPLE__
  // On macOS, fonts are automatically detected when placed in font directories
  NSLog(@"Font installed to: %@", destinationPath);
#else
  NS_DURING
    {
      NSTask *task = [[NSTask alloc] init];
      [task setLaunchPath: @"/usr/bin/fc-cache"];
      [task setArguments: [NSArray arrayWithObject: @"-f"]];
      [task launch];
      [task waitUntilExit];
      if ([task terminationStatus] == 0)
	{
	  NSLog(@"Font installed and cache updated: %@", destinationPath);
	}
      else
	{
	  NSLog(@"Font installed, but fc-cache failed with status: %d", [task terminationStatus]);
	}
    }
  NS_HANDLER
    {
      NSLog(@"Font installed, but failed to run fc-cache: %@", localException);
    }
  NS_ENDHANDLER;  
#endif

  return YES;
}

- (NSString *) systemFontsDirectory
{
  return @"/usr/local/share/fonts";
}

- (NSString *) userFontsDirectory
{
  NSString *homeDir = NSHomeDirectory();

  // Generic Unix/other systems
  return [homeDir stringByAppendingPathComponent: @".fonts"];
}

@end
