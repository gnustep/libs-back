/*
   CairoFontEnumerator.m
 
   Copyright (C) 2003 Free Software Foundation, Inc.

   August 31, 2003
   Written by Banlu Kemiyatorn <object at gmail dot com>
   Base on original code of Alex Malmberg
   Rewrite: Fred Kiefer <fredkiefer@gmx.de>
   Date: Jan 2006
   Rewrite: Isaiah Beerbower <public@ipaqah.com>
   Date: Dec 2007
 
   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

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

#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSDebug.h>
#include <GNUstepGUI/GSFontInfo.h>
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>

#include "gsc/GSGState.h"
#include "cairo/CairoFontEnumerator.h"
#include "cairo/CairoFontInfo.h"

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_TYPE1_TABLES_H
#include FT_TRUETYPE_TABLES_H
#include FT_BDF_H
#include FT_SFNT_NAMES_H
#include FT_TRUETYPE_IDS_H


@implementation CairoFontEnumerator 

NSMutableDictionary * __allFonts;


void mergeFontInfo(NSMutableDictionary *fontInfo, NSMutableArray *fontCache)
{
	NSString *primaryFile;
	int i;
	int count = [fontCache count];
	
	primaryFile = [[fontInfo objectForKey: @"Files"] objectAtIndex: 0];
	
	for (i = 0; i < count; i++)
		{
			NSDictionary *prevFontInfo = [fontCache objectAtIndex: i];
			NSArray *files = [prevFontInfo objectForKey: @"Files"];
		
			if (files != nil && [files count] > 0)
				{
					int f_i;
					int f_count = [files count];
			
					for (f_i = 0; f_i < f_count; f_i++)
						{
							if ([[[files objectAtIndex: f_i] stringByExpandingTildeInPath]
							    isEqual: primaryFile])
								{
									[fontInfo addEntriesFromDictionary: prevFontInfo];
									[fontCache replaceObjectAtIndex: i withObject: fontInfo];
									
									return;
								}
						}
				}
		}
	
	[fontCache addObject: fontInfo];
}

BOOL cacheNFontBundle(NSString *path,
                      NSMutableArray *fontCache,
											BOOL mergeCache)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSString *fontInfoPath =
		[path stringByAppendingPathComponent: @"FontInfo.plist"];
	NSDictionary *fontInfo;
	NSArray *faces;
	
	if (! [fm fileExistsAtPath: fontInfoPath])
		return NO;
	
	fontInfo = [NSDictionary dictionaryWithContentsOfFile: fontInfoPath];
	if (fontInfo == nil)
		return NO;
	
	faces = [fontInfo objectForKey: @"Faces"];
	if (faces == nil || [faces isKindOfClass: [NSArray class]] == NO)
		return NO;
	
	int i;
	int count = [faces count];
	
	for (i = 0; i < count; i++)
	{
		NSMutableDictionary *face = [faces objectAtIndex: i];
		
		NSMutableArray *files = [face objectForKey: @"Files"];
		if (files == nil || [files count] == 0)
			continue;
		
		int f_i;
		int f_count = [files count];
		
		for (f_i = 0; f_i < f_count; f_i++)
		{
			NSString *fontFilePath =
				[path stringByAppendingPathComponent: [files objectAtIndex: f_i]];

			[files replaceObjectAtIndex: f_i withObject: fontFilePath];
		}
		
		if ([fontInfo objectForKey: @"Family"] == nil)
		{
			NSString *familyName =
				[[path lastPathComponent] stringByDeletingPathExtension];
			
			[face setObject: familyName forKey: @"Family"];
		}
		else
		{
			[face setObject: [fontInfo objectForKey: @"Family"] forKey: @"Family"];
		}

		if ([fontInfo objectForKey: @"Foundry"] != nil)
		{
			[face setObject: [fontInfo objectForKey: @"Foundry"] forKey: @"Foundry"];
		}

		if ([fontInfo objectForKey: @"FontLicense"] != nil)
		{
			[face setObject: [fontInfo objectForKey: @"FontLicense"]
			         forKey: @"FontLicense"];
		}

		if ([fontInfo objectForKey: @"FontCopyright"] != nil)
		{
			[face setObject: [fontInfo objectForKey: @"FontCopyright"]
			         forKey: @"FontCopyright"];
		}
		
		if (mergeCache)
			mergeFontInfo(face, fontCache);
		else
			[fontCache addObject: face];
	}
	
	return YES;
}

void cacheFont(NSString *path,
               NSMutableArray *fontCache,
							 BOOL mergeCache,
							 FT_Library library)
{
	const char *cPath;
	int i;
	int facesCount;
	
	path = [path stringByExpandingTildeInPath];
	cPath = [path UTF8String];
	
	facesCount = 1;
	for (i = 0; i < facesCount; ++i)
		{
			FT_Face face;
			PS_FontInfoRec PSInfo;
			TT_Postscript *TTPSTable;
			TT_OS2 *TTOS2Table;
			int weight = 5;
			NSFontTraitMask traits = 0;
			NSMutableString *style;
			NSMutableArray *files;
			
			if (FT_New_Face(library, cPath, 0, &face) == 0)
		{
			facesCount = face->num_faces;
			
			if (!FT_IS_SCALABLE(face))
				{
					FT_Done_Face(face);
					continue;
				}
		
			NSMutableDictionary *faceInfo = [[NSMutableDictionary alloc] init];
			const char *cString;
			
			files = [NSMutableArray arrayWithObject: path];
			[faceInfo setObject: files forKey: @"Files"];
			
			NSArray *f_extensions = [[NSArray alloc]
				initWithObjects: @"pfa", @"PFA", @"pfb", @"PFB", nil];
			if ([f_extensions containsObject: [path pathExtension]]
					/*FIXME: This would be a better way to check the
			      font type, but it requires a later version of
						FreeType than I currently have installed - ipaqah*/
			    /*strcmp(FT_Get_X11_Font_Format(face), "Type 1") == 0*/)
				{
					NSFileManager *fm = [NSFileManager defaultManager];
					NSArray *extensions = [[NSArray alloc]
						initWithObjects: @"afm", @"AFM", @"pfm", @"PFM", nil];
					
					int m_i;
					int m_count = [extensions count];
					
					for (m_i = 0; m_i < m_count; ++m_i)
						{
							NSString *metricsPath;
					
							metricsPath = [[path stringByDeletingPathExtension]
								stringByAppendingPathExtension: [extensions objectAtIndex: m_i]];
					
							cString = [metricsPath UTF8String];
							
							if ([fm fileExistsAtPath: metricsPath] == NO)
								continue;
					
							if (FT_Attach_File(face, cString) == 0)
								{
									[files addObject: metricsPath];
								}
						}
				}
					
			[faceInfo setObject: [NSNumber numberWithInt: i]
			             forKey: @"Index"];
					
			[faceInfo setObject: [NSString stringWithUTF8String: face->family_name]
			             forKey: @"Family"];
			
			if ((face->style_flags | FT_STYLE_FLAG_ITALIC) == face->style_flags)
				traits |= NSItalicFontMask;
			
			if ((face->style_flags | FT_STYLE_FLAG_BOLD) == face->style_flags)
				{
					traits |= NSBoldFontMask;
					weight = 8;
				}
			
			if (FT_Get_PS_Font_Info(face, &PSInfo) == 0)
				{
					[faceInfo setObject: [NSString stringWithUTF8String: PSInfo.full_name]
					             forKey: @"FullName"];
					
					[faceInfo setObject:
						[NSNumber numberWithFloat: (float)(PSInfo.italic_angle)]
					             forKey: @"ItalicAngle"];
					
					if (PSInfo.is_fixed_pitch)
						traits |= NSFixedPitchFontMask;
				}
			
			if ((TTOS2Table = FT_Get_Sfnt_Table(face, ft_sfnt_os2)) != 0 &&
			    TTOS2Table->version != 0xFFFF)
				{
					[faceInfo setObject:
						[NSString stringWithCString: (char *)TTOS2Table->achVendID
						                     length: 4]
					             forKey: @"Foundry"];
				
					if (TTOS2Table->usWeightClass == 0)
						weight = 5;
					else
						weight = (TTOS2Table->usWeightClass / 100) + 1;
					
					if (TTOS2Table->usWidthClass > 0 && TTOS2Table->usWidthClass < 5)
						traits |= NSCondensedFontMask;
					else if (TTOS2Table->usWidthClass > 5)
						traits |= NSExpandedFontMask;
				}
			
			if ((TTPSTable = FT_Get_Sfnt_Table(face, ft_sfnt_post)) != 0)
				{
					[faceInfo setObject: [NSNumber numberWithFloat:
					                     ((float)(TTPSTable->italicAngle) / 65536.0)]
					             forKey: @"ItalicAngle"];
					
					if (TTPSTable->isFixedPitch)
						traits |= NSFixedPitchFontMask;
				}
			
			if (face->style_name != NULL)
				{
					style = [NSString stringWithUTF8String: face->style_name];
				}
			else
				{
					style = [[NSMutableString alloc] init];
					
					if ((traits | NSCondensedFontMask) == traits)
						{
							if ([style length] > 0)
								[style appendString: @" "];
							[style appendString: @"Condensed"];
						}
					else if ((traits | NSExpandedFontMask) == traits)
						{
							if ([style length] > 0)
								[style appendString: @" "];
							[style appendString: @"Expanded"];
						}
					
					if ((traits | NSBoldFontMask) == traits)
						{
							if ([style length] > 0)
								[style appendString: @" "];
							[style appendString: @"Bold"];
						}
					
					if ((traits | NSItalicFontMask) == traits)
						{
							if ([style length] > 0)
								[style appendString: @" "];
							[style appendString: @"Italic"];
						}
					
					if (!([style length] > 0))
						[style appendString: @"Regular"];
				}
			[faceInfo setObject: style forKey: @"Name"];
			
			if ((cString = FT_Get_Postscript_Name(face)) != NULL)
				[faceInfo setObject: [NSString stringWithUTF8String: cString]
				             forKey: @"PostScriptName"];
			else
				[faceInfo setObject: [NSString stringWithFormat: @"%s-%@",
				                                                 face->family_name,
																												 style]
				             forKey: @"PostScriptName"];
			
			[faceInfo setObject: [NSNumber numberWithInt: weight]
			             forKey: @"Weight"];
			
			[faceInfo setObject: [NSNumber numberWithUnsignedLong: traits]
			             forKey: @"Traits"];
			
			FT_Done_Face(face);
			
			if (mergeCache)
				mergeFontInfo(faceInfo, fontCache);
			else
				[fontCache addObject: faceInfo];
		}
		}
}

NSDate *bundleModificationDate(NSString *path)
{
	NSDate *date;
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir;
	
	NSArray *ls = [fm directoryContentsAtPath: path];
	int i;
	int count = [ls count];
		
	date = [[fm fileAttributesAtPath: path
		                    traverseLink: YES] fileModificationDate];
	
	for (i = 0; i < count; i++)
	{
		NSString *subPath =
			[path stringByAppendingPathComponent: [ls objectAtIndex: i]];
			
		if ([fm fileExistsAtPath: subPath isDirectory: &isDir] && isDir == YES)
		{
			date = [date laterDate: bundleModificationDate(subPath)];
		}
	}
	
	return date;
}

void cacheFolder(NSString *path,
                 NSMutableArray *fontCache,
								 NSMutableDictionary *cachedDirs,
								 BOOL mergeCache,
								 FT_Library library)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir;
	
	if (! ([fm fileExistsAtPath: path isDirectory: &isDir] && isDir == YES))
		return;
	
	NSDate *dateLastCached;
	NSDate *modificationDate;

	dateLastCached = [cachedDirs objectForKey: path];
	if (dateLastCached == nil)
		dateLastCached = [NSDate distantPast];

	if (mergeCache)
		modificationDate = [[fm fileAttributesAtPath: path
		                    traverseLink: YES] fileModificationDate];
	else
		modificationDate = [NSDate distantFuture];
	
	int i;
	NSArray *ls = [fm directoryContentsAtPath: path];
	int count = [ls count];
	
	for (i = 0; i < count; i++)
		{
			NSString *fontPath =
				[path stringByAppendingPathComponent: [ls objectAtIndex: i]];
				
			if ([fm fileExistsAtPath: fontPath isDirectory: &isDir] && isDir == YES)
				{
					if ([[fontPath pathExtension] isEqual: @"nfont"])
				{
					if ([dateLastCached earlierDate: bundleModificationDate(fontPath)] ==
					    dateLastCached)
						{
							cacheNFontBundle(fontPath, fontCache, mergeCache);
						}
				}
					else
				{
					cacheFolder(fontPath,
					            fontCache,
					            cachedDirs,
					            mergeCache,
					            library);
				}
				}
			else if ([dateLastCached earlierDate: modificationDate] ==
		           dateLastCached)
				{
					cacheFont(fontPath, fontCache, mergeCache, library);
				}
		}
		
	[cachedDirs setObject: [NSDate date] forKey: path];
}

- (void) enumerateFontsAndFamilies
{
	int i;
	NSFileManager *fm = [NSFileManager defaultManager];
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	NSMutableArray *fontCache;
	NSMutableDictionary *cachedDirs;
	BOOL mergeCache = YES;
	
	/*
	 * Open font cache:
	 */
	
	NSString *cachePath =
		[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
																				  NSUserDomainMask,
																				  YES) objectAtIndex: 0]
		stringByAppendingPathComponent: @"FontInfo/FontCache.plist"];
	
	switch ([fm fileExistsAtPath: cachePath])
		{
		case YES:
			if (!(fontCache = [NSMutableArray arrayWithContentsOfFile: cachePath]))
				{
					NSLog(@"Couldn't open font cache: %@", cachePath);
					return;
				}
			break;
		default:
			fontCache = [[NSMutableArray alloc] init];
			mergeCache = NO;
		}
	
	NSString *dirsPath =
		[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
																				  NSUserDomainMask,
																				  YES) objectAtIndex: 0]
		stringByAppendingPathComponent: @"FontInfo/CachedDirs.plist"];
	
	switch ([fm fileExistsAtPath: cachePath])
		{
		case YES:
			if ((cachedDirs =
			     [NSMutableDictionary dictionaryWithContentsOfFile: dirsPath]))
				break;
		default:
			cachedDirs = [[NSMutableDictionary alloc] init];
		}
	
	/*
	 * Make sure all fonts are cached:
	 */
	
	NSMutableArray *searchPaths = [[NSMutableArray alloc] initWithArray:
		NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
		                                    NSAllDomainsMask,
		                                    YES)];
	
	int count = [searchPaths count];
	for (i = 0; i < count; i++)
		{
			NSString *path = [[searchPaths objectAtIndex: i]
				stringByAppendingPathComponent: @"Fonts"];
				
			[searchPaths replaceObjectAtIndex: i withObject: path];
		}
	
	if ([ud objectForKey: @"GSAdditionalFontPaths"] != nil)
		[searchPaths addObjectsFromArray:
			[ud objectForKey: @"GSAdditionalFontPaths"]];
	
	FT_Library library;
	FT_Init_FreeType(&library);
	
	count = [searchPaths count];
	for (i = 0; i < count; i++)
		{
		
			cacheFolder([searchPaths objectAtIndex: i],
			            fontCache,
			            cachedDirs,
			            mergeCache,
			            library);
		}
	
	FT_Done_FreeType(library);
	
	/*
	 * Enumerate fonts and families:
	 */
	
	NSMutableDictionary *mutableAllFonts = [[NSMutableDictionary alloc] init];
	NSMutableArray *mutableAllFontNames = [[NSMutableArray alloc] init];
	NSMutableDictionary *mutableAllFontFamilies =
		[[NSMutableDictionary alloc] init];
	
	count = [fontCache count];
	for (i = 0; i < count; i++)
		{
			NSDictionary *face = [fontCache objectAtIndex: i];
			CairoFaceInfo *faceInfo = [CairoFaceInfo alloc];
		
			NSString *family;
			NSString *postScriptName;
			NSString *name;
			NSString *fullName;
			NSArray *files;
			int weight;
			int index;
			NSFontTraitMask traits;
			float italicAngle;
		
			if ([face objectForKey: @"Family"] == nil ||
					[face objectForKey: @"PostScriptName"] == nil ||
					[face objectForKey: @"Name"] == nil ||
					[face objectForKey: @"Files"] == nil ||
					[[face objectForKey: @"Files"] count] < 1)
				continue;

			family = [face objectForKey: @"Family"];
			postScriptName = [face objectForKey: @"PostScriptName"];
			name = [face objectForKey: @"Name"];
			files = [face objectForKey: @"Files"];
			
			if ([mutableAllFontNames containsObject: postScriptName])
				continue;
			else
				[mutableAllFontNames addObject: postScriptName];
		
			if ([face objectForKey: @"Index"] == nil)
				index = 0;
			else
				index = [[face objectForKey: @"Index"] intValue];
		
			if ([face objectForKey: @"FullName"] == nil)
				fullName = [NSString stringWithFormat: @"%@ %@", family, name];
			else
				fullName = [face objectForKey: @"FullName"];
		
			if ([face objectForKey: @"Weight"] == nil)
				weight = 5;
			else
				weight = [[face objectForKey: @"Weight"] intValue];
		
			if ([face objectForKey: @"Traits"] == nil)
				traits = 0;
			else
				traits = [[face objectForKey: @"Traits"] unsignedIntValue];
		
			if ([face objectForKey: @"ItalicAngle"] == nil)
				italicAngle = 0.0;
			else
				italicAngle = [[face objectForKey: @"ItalicAngle"] floatValue];

			faceInfo = [faceInfo initWithfamilyName: family
			                               fullName: fullName
			                                 weight: weight
			                            italicAngle: italicAngle
			                                 traits: traits
			                                  files: files
			                                  index: index];
																			
			[mutableAllFonts setObject: faceInfo forKey: postScriptName];
		
			NSArray *familyFace = [[NSArray alloc]
				initWithObjects: postScriptName,
				                 name,
				                 [NSNumber numberWithInt: weight],
				                 [NSNumber numberWithUnsignedInt: traits], nil];
		
			NSMutableArray *familyFaceArray =
				[mutableAllFontFamilies objectForKey: family];

			if (familyFaceArray == nil)
				{
					familyFaceArray = [[NSMutableArray alloc] init];
					[mutableAllFontFamilies setObject: familyFaceArray forKey: family];
				}
		
			[familyFaceArray addObject: familyFace];
		}
	
	allFontNames = mutableAllFontNames;
	allFontFamilies = mutableAllFontFamilies;
	__allFonts = mutableAllFonts;
	
	/*
	 * Write cache back to file:
	 */
	
	NSString * fontInfoDir = [cachePath stringByDeletingLastPathComponent];
	
	if (! [fm fileExistsAtPath: fontInfoDir])
		{
			[fm createDirectoryAtPath: fontInfoDir attributes: nil];
		}
	
	if ([fontCache writeToFile: cachePath atomically: YES] == NO)
		{
			NSLog(@"Couldn't write font cache.");
		}
	
	if ([cachedDirs writeToFile: dirsPath atomically: YES] == NO)
		{
			NSLog(@"Couldn't write cached directory info.");
		}
}

+ (CairoFaceInfo *) fontWithName: (NSString *) name
{
  CairoFaceInfo *face;

  face = [__allFonts objectForKey: name];
  if (!face)
    {
      NSDebugLog(@"Font not found %@", name);
    }
  return face;
}

- (NSString *) defaultSystemFontName
{
  if ([allFontNames containsObject: @"Bitstream Vera Sans"])
    return @"Bitstream Vera Sans";
  if ([allFontNames containsObject: @"BitstreamVeraSans-Roman"])
    return @"BitstreamVeraSans-Roman";
  if ([allFontNames containsObject: @"FreeSans"])
    return @"FreeSans";
  return @"Helvetica";
}

- (NSString *) defaultBoldSystemFontName
{
  if ([allFontNames containsObject: @"Bitstream Vera Sans-Bold"])
    return @"Bitstream Vera Sans-Bold";
  if ([allFontNames containsObject: @"BitstreamVeraSans-Bold"])
    return @"BitstreamVeraSans-Bold";
  if ([allFontNames containsObject: @"FreeSans-Bold"])
    return @"FreeSans-Bold";
  return @"Helvetica-Bold";
}

- (NSString *) defaultFixedPitchFontName
{
  if ([allFontNames containsObject: @"Bitstream Vera Sans Mono"])
    return @"Bitstream Vera Sans Mono";
  if ([allFontNames containsObject: @"BitstreamVeraSansMono-Roman"])
    return @"BitstreamVeraSansMono-Roman";
  if ([allFontNames containsObject: @"FreeMono"])
    return @"FreeMono";
  return @"Courier";
}

@end
