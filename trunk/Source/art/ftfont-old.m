/*
   Copyright (C) 2002 Free Software Foundation, Inc.

   Author:  Alexander Malmberg <alexander@malmberg.org>

   This file is part of GNUstep.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <math.h>

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

//#include "gsc/GSContext.h"
#include "gsc/GSGState.h"

#include "ftfont.h"

#include "blit.h"


#define DI (*di)


/** font handling interface **/

#include FT_CACHE_H

#include FT_CACHE_IMAGE_H
#include FT_CACHE_SMALL_BITMAPS_H
#include FT_CACHE_CHARMAP_H

#include FT_OUTLINE_H

#if (FREETYPE_MAJOR==2) && ((FREETYPE_MINOR<1) || ((FREETYPE_MINOR==1) && (FREETYPE_PATCH<=2)))
#define FT212_STUFF
#endif


/* TODO: finish screen font handling */


/*
from the back-art-subpixel-text defaults key
0: normal rendering
1: subpixel, rgb
2: subpixel, bgr
*/
static int subpixel_text;


static BOOL anti_alias_by_default;


@class FTFaceInfo;

#define CACHE_SIZE 257

@interface FTFontInfo : GSFontInfo <FTFontInfo>
{
@public
#ifdef FT212_STUFF
  FTC_ImageDesc imgd;

  FTC_ImageDesc advancementImgd;
#else
  FTC_ImageTypeRec imgd;

  FTC_ImageTypeRec advancementImgd;
#endif

  FTFaceInfo *face_info;

  BOOL screenFont;


  /*
  Profiling (2003-11-14) shows that calls to -advancementForGlyph: accounted
  for roughly 20% of layout time. This cache reduces it to (currently)
  insignificant levels.
  */
  unsigned int cachedGlyph[CACHE_SIZE];
  NSSize cachedSize[CACHE_SIZE];


  /* Glyph generation */
  NSGlyph ligature_ff,ligature_fi,ligature_fl,ligature_ffl,ligature_ffi;


  float lineHeight;
}
@end


@interface FTFontInfo_subpixel : FTFontInfo
@end


static NSMutableArray *fcfg_allFontNames;
static NSMutableDictionary *fcfg_allFontFamilies;
static NSMutableDictionary *fcfg_all_fonts;


static NSMutableSet *families_seen, *families_pending;


@interface FTFaceInfo : NSObject
{
@public
  NSString *familyName;

  /* the following two are localized */
  NSString *faceName;
  NSString *displayName;

  NSArray *files;
  struct
  {
    int pixel_size;
    NSArray *files;
  } *sizes;
  int num_sizes;

  int weight;
  unsigned int traits;

  /*
  hinting hints
    0: 1 to use the auto-hinter
    1: 1 to use hinting
  byte 0 and 1 contain hinting hints for un-antialiased and antialiased
  rendering, respectively.

   16: 0=un-antialiased by default, 1=antialiased by default
  */
  unsigned int render_hints_hack;
}
@end

@implementation FTFaceInfo

-(NSString *) description
{
  return [NSString stringWithFormat: @"<FTFaceInfo %p: '%@' %@ %i %i>",
    self, displayName, files, weight, traits];
}

/* FTFaceInfo:s should never be deallocated */
-(void) dealloc
{
  NSLog(@"Warning: -dealloc called on %@",self);
}

@end


#if 0

/*
This is a list of "standard" face names. It is here so make_strings can pick
it up and generate .strings files with them.
*/

NSLocalizedStringFromTable(@"Book", @"nfontFaceNames", @"")
NSLocalizedStringFromTable(@"Regular", @"nfontFaceNames", @"")
NSLocalizedStringFromTable(@"Roman", @"nfontFaceNames", @"")
NSLocalizedStringFromTable(@"Medium", @"nfontFaceNames", @"")
NSLocalizedStringFromTable(@"Demi", @"nfontFaceNames", @"")
NSLocalizedStringFromTable(@"Demibold", @"nfontFaceNames", @"")
NSLocalizedStringFromTable(@"Bold", @"nfontFaceNames", @"")
NSLocalizedStringFromTable(@"Heavy", @"nfontFaceNames", @"")

NSLocalizedStringFromTable(@"Italic", @"nfontFaceNames", @"")
NSLocalizedStringFromTable(@"Oblique", @"nfontFaceNames", @"")

NSLocalizedStringFromTable(@"Bold Italic", @"nfontFaceNames", @"")
NSLocalizedStringFromTable(@"Bold Oblique", @"nfontFaceNames", @"")

#endif


static int traits_from_string(NSString *s, unsigned int *traits, unsigned int *weight)
{
static struct
{
  NSString *str;
  unsigned int trait;
  int weight;
} suffix[] = {
/* TODO */
{@"Normal"         ,0                         ,-1},

{@"Ultralight"     ,0                         , 1},
{@"Thin"           ,0                         , 2},
{@"Light"          ,0                         , 3},
{@"Extralight"     ,0                         , 3},
{@"Book"           ,0                         , 4},
{@"Regular"        ,0                         , 5},
{@"Plain"          ,0                         , 5},
{@"Display"        ,0                         , 5},
{@"Roman"          ,0                         , 5},
{@"Semilight"      ,0                         , 5},
{@"Medium"         ,0                         , 6},
{@"Demi"           ,0                         , 7},
{@"Demibold"       ,0                         , 7},
{@"Semi"           ,0                         , 8},
{@"Semibold"       ,0                         , 8},
{@"Bold"           ,NSBoldFontMask            , 9},
{@"Extra"          ,NSBoldFontMask            ,10},
{@"Extrabold"      ,NSBoldFontMask            ,10},
{@"Heavy"          ,NSBoldFontMask            ,11},
{@"Heavyface"      ,NSBoldFontMask            ,11},
{@"Ultrabold"      ,NSBoldFontMask            ,12},
{@"Black"          ,NSBoldFontMask            ,12},
{@"Ultra"          ,NSBoldFontMask            ,13},
{@"Ultrablack"     ,NSBoldFontMask            ,13},
{@"Fat"            ,NSBoldFontMask            ,13},
{@"Extrablack"     ,NSBoldFontMask            ,14},
{@"Obese"          ,NSBoldFontMask            ,14},
{@"Nord"           ,NSBoldFontMask            ,14},

{@"Italic"         ,NSItalicFontMask          ,-1},
{@"Oblique"        ,NSItalicFontMask          ,-1},

{@"Cond"           ,NSCondensedFontMask       ,-1},
{@"Condensed"      ,NSCondensedFontMask       ,-1},
{nil,0,-1}
};
  int i;

  *traits = 0;
//  printf("do '%@'\n", s);
  while ([s length] > 0)
    {
//      printf("  got '%@'\n", s);
      if ([s hasSuffix: @"-"] || [s hasSuffix: @" "])
	{
//	  printf("  do -\n");
	  s = [s substringToIndex: [s length] - 1];
	  continue;
	}
      for (i = 0; suffix[i].str; i++)
	{
	  if (![s hasSuffix: suffix[i].str])
	    continue;
//	  printf("  found '%@'\n", suffix[i].str);
	  if (suffix[i].weight != -1)
	    *weight = suffix[i].weight;
	  (*traits) |= suffix[i].trait;
	  s = [s substringToIndex: [s length] - [suffix[i].str length]];
	  break;
	}
      if (!suffix[i].str)
	break;
    }
//  printf("end up with '%@'\n", s);
  return [s length];
}


static NSArray *fix_path(NSString *path, NSArray *files)
{
  int i, c = [files count];
  NSMutableArray *nfiles;

  if (!files)
    return nil;

  nfiles = [[NSMutableArray alloc] init];
  for (i = 0; i < c; i++)
    {
      if ([[files objectAtIndex: i] isAbsolutePath])
	[nfiles addObject: [files objectAtIndex: i]];
      else
	[nfiles addObject: [path stringByAppendingPathComponent:
	  [files objectAtIndex: i]]];
    }
  return nfiles;
}

/* TODO: handling of .font packages needs to be reworked */
static void add_face(NSString *family, int family_weight,
	unsigned int family_traits, NSDictionary *d, NSString *path,
	BOOL from_nfont)
{
  FTFaceInfo *fi;
  int weight;
  unsigned int traits;

  NSString *fontName;
  NSString *faceName, *rawFaceName;


  fontName = [d objectForKey: @"PostScriptName"];
  if (!fontName)
    {
      NSLog(@"Warning: Face in %@ has no PostScriptName!",path);
      return;
    }

  if ([fcfg_allFontNames containsObject: fontName])
    return;

  fi = [[FTFaceInfo alloc] init];
  fi->familyName = [family copy];

  if ([d objectForKey: @"LocalizedNames"])
    {
      NSDictionary *l;
      NSArray *lang;
      int i;

      l = [d objectForKey: @"LocalizedNames"];
      lang = [NSUserDefaults userLanguages];
      faceName = nil;
      rawFaceName = [l objectForKey: @"English"];
      for (i = 0; i < [lang count] && !faceName; i++)
	{
	  faceName = [l objectForKey: [lang objectAtIndex: i]];
	}
      if (!faceName)
	faceName = rawFaceName;
      if (!faceName)
	{
	  faceName = @"<unknown face>";
	  NSLog(@"Warning: couldn't find localized face name or fallback for %@",
	    fontName);
	}
    }
  else if ((faceName = [d objectForKey: @"Name"]))
    {
      rawFaceName = faceName;
      /* TODO: Smarter localization? Parse space separated parts and
      translate individually? */
      /* TODO: Need to define the strings somewhere, and make sure the
      strings files get created.  */
      faceName = [NSLocalizedStringFromTableInBundle(faceName,@"nfontFaceNames",
			[NSBundle bundleForClass: [fi class]],nil) copy];
      fi->faceName = faceName;
    }
  else if (!from_nfont)
    { /* try to guess something for .font packages */
      int dummy;
      int split = traits_from_string(family,&dummy,&dummy);
      rawFaceName = faceName = [family substringFromIndex: split];
      family = [family substringToIndex: split];
      faceName = [NSLocalizedStringFromTableInBundle(faceName,@"nfontFaceNames",
			[NSBundle bundleForClass: [fi class]],nil) copy];
      fi->faceName = faceName;
    }
  else
    {
      NSLog(@"Warning: Can't find name for face %@ in %@!",fontName,path);
      return;
    }

  fi->displayName = [[family stringByAppendingString: @" "]
			     stringByAppendingString: faceName];


  weight = family_weight;
  if (rawFaceName)
    traits_from_string(rawFaceName, &traits, &weight);

  {
    NSDictionary *sizes;
    NSEnumerator *e;
    NSString *size;
    int i;

    sizes = [d objectForKey: @"ScreenFonts"];

    fi->num_sizes = [sizes count];
    if (fi->num_sizes)
      {
	fi->sizes = malloc(sizeof(fi->sizes[0])*[sizes count]);
	e = [sizes keyEnumerator];
	i = 0;
	while ((size = [e nextObject]))
	  {
	    fi->sizes[i].pixel_size = [size intValue];
	    fi->sizes[i].files = fix_path(path,[sizes objectForKey: size]);
	    NSDebugLLog(@"ftfont",@"%@ size %i files |%@|\n",
	      fontName,fi->sizes[i].pixel_size,fi->sizes[i].files);
	    i++;
          }
      }
  }

  fi->files = fix_path(path,[d objectForKey: @"Files"]);

  if ([d objectForKey: @"Weight"])
    weight = [[d objectForKey: @"Weight"] intValue];
  fi->weight = weight;

  if ([d objectForKey: @"Traits"])
    traits = [[d objectForKey: @"Traits"] intValue];
  traits |= family_traits;
  fi->traits = traits;

  if ([d objectForKey: @"RenderHints_hack"])
    fi->render_hints_hack=strtol([[d objectForKey: @"RenderHints_hack"] cString],NULL,0);
  else
    {
      if (anti_alias_by_default)
	fi->render_hints_hack=0x10202;
      else
	fi->render_hints_hack=0x00202;
    }

  NSDebugLLog(@"ftfont", @"adding '%@' '%@'", fontName, fi);

  [fcfg_all_fonts setObject: fi forKey: fontName];
  [fcfg_allFontNames addObject: fontName];

    {
      NSArray *a;
      NSMutableArray *ma;
      a = [NSArray arrayWithObjects:
	fontName,
	faceName,
	[NSNumber numberWithInt: weight],
	[NSNumber numberWithUnsignedInt: traits],
	nil];
      ma = [fcfg_allFontFamilies objectForKey: family];
      if (!ma)
	{
	  ma = [[NSMutableArray alloc] init];
	  [fcfg_allFontFamilies setObject: ma forKey: family];
	  [ma release];
	}
      [ma addObject: a];
    }

  DESTROY(fi);
}


static void load_font_configuration(void)
{
  int i, j, k, c;
  NSArray *paths;
  NSString *path, *font_path;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *files;
  NSDictionary *d;
  NSArray *faces;

  fcfg_all_fonts = [[NSMutableDictionary alloc] init];
  fcfg_allFontFamilies = [[NSMutableDictionary alloc] init];
  fcfg_allFontNames = [[NSMutableArray alloc] init];

  families_seen = [[NSMutableSet alloc] init];
  families_pending = [[NSMutableSet alloc] init];

  paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
  for (i = 0; i < [paths count]; i++)
    {
      path = [paths objectAtIndex: i];
      path = [path stringByAppendingPathComponent: @"Fonts"];
      files = [fm directoryContentsAtPath: path];
      c = [files count];

      for (j = 0; j < c; j++)
	{
	  NSString *family;
	  NSDictionary *face_info;
	  NSString *font_info_path;

	  int weight;
	  unsigned int traits;

	  font_path = [files objectAtIndex: j];
	  if (![[font_path pathExtension] isEqual: @"nfont"])
	    continue;

	  family = [font_path stringByDeletingPathExtension];

	  if ([families_seen member: family])
	    {
	      NSDebugLLog(@"ftfont", @"'%@' already seen, skipping", family);
	      continue;
	    }
	  [families_seen addObject: family];

	  font_path = [path stringByAppendingPathComponent: font_path];

	  NSDebugLLog(@"ftfont",@"loading %@",font_path);

	  font_info_path = [font_path stringByAppendingPathComponent: @"FontInfo.plist"];
	  if (![fm fileExistsAtPath: font_info_path])
	    continue;
	  d = [NSDictionary dictionaryWithContentsOfFile: font_info_path];
	  if (!d)
	    continue;

	  if ([d objectForKey: @"Family"])
	    family = [d objectForKey: @"Family"];

	  if ([d objectForKey: @"Weight"])
	    weight = [[d objectForKey: @"Weight"] intValue];
	  else
	    weight = 5;

	  if ([d objectForKey: @"Traits"])
	    traits = [[d objectForKey: @"Traits"] intValue];
	  else
	    traits = 0;

	  faces = [d objectForKey: @"Faces"];
	  if (![faces isKindOfClass: [NSArray class]])
	    {
	      NSLog(@"Warning: %@ isn't a valid .nfont package, ignoring.",
 	        font_path);
	      if ([faces isKindOfClass: [NSDictionary class]])
	        NSLog(@"(it looks like an old-style .nfont package)");
	      continue;
	    }

	  for (k = 0; k < [faces count]; k++)
	    {
	      face_info = [faces objectAtIndex: k];
	      add_face(family, weight, traits, face_info, font_path, YES);
	    }
	}

      for (j = 0; j < c; j++)
	{
	  NSString *family;

	  font_path = [files objectAtIndex: j];
	  if (![[font_path pathExtension] isEqual: @"font"])
	    continue;

	  family = [font_path stringByDeletingPathExtension];
	  font_path = [path stringByAppendingPathComponent: font_path];
	  d = [NSDictionary dictionaryWithObjectsAndKeys:
	    [NSArray arrayWithObjects:
	      family,
	      [family stringByAppendingPathExtension: @"afm"],
	      nil],
	    @"Files",
	    family,@"PostScriptName",
	    nil];
	  add_face(family, 5, 0, d, font_path, NO);
	}
      [families_seen unionSet: families_pending];
      [families_pending removeAllObjects];
    }

  NSDebugLLog(@"ftfont", @"got %i fonts in %i families",
    [fcfg_allFontNames count], [fcfg_allFontFamilies count]);

  if (![fcfg_allFontNames count])
    {
      NSLog(@"No fonts found!");
      exit(1);
    }

  DESTROY(families_seen);
  DESTROY(families_pending);
}


@interface FTFontEnumerator : GSFontEnumerator
@end

@implementation FTFontEnumerator
-(void) enumerateFontsAndFamilies
{
  ASSIGN(allFontNames, fcfg_allFontNames);
  ASSIGN(allFontFamilies, fcfg_allFontFamilies);
}

-(NSString *) defaultSystemFontName
{
  if ([fcfg_allFontNames containsObject: @"BitstreamVeraSans-Roman"])
    return @"BitstreamVeraSans-Roman";
  if ([fcfg_allFontNames containsObject: @"FreeSans"])
    return @"FreeSans";
  return @"Helvetica";
}

-(NSString *) defaultBoldSystemFontName
{
  if ([fcfg_allFontNames containsObject: @"BitstreamVeraSans-Bold"])
    return @"BitstreamVeraSans-Bold";
  if ([fcfg_allFontNames containsObject: @"FreeSansBold"])
    return @"FreeSansBold";
  return @"Helvetica-Bold";
}

-(NSString *) defaultFixedPitchFontName
{
  if ([fcfg_allFontNames containsObject: @"BitstreamVeraSansMono-Roman"])
    return @"BitstreamVeraSansMono-Roman";
  if ([fcfg_allFontNames containsObject: @"FreeMono"])
    return @"FreeMono";
  return @"Courier";
}

@end


static FT_Library ft_library;
static FTC_Manager ftc_manager;
static FTC_ImageCache ftc_imagecache;
static FTC_SBitCache ftc_sbitcache;
static FTC_CMapCache ftc_cmapcache;


static FT_Error ft_get_face(FTC_FaceID fid, FT_Library lib, FT_Pointer data, FT_Face *pface)
{
  FT_Error err;
  NSArray *rfi = (NSArray *)fid;
  int i, c = [rfi count];

//  NSLog(@"ft_get_face: %@ '%s'", rfi, [[rfi objectAtIndex: 0] cString]);

  err = FT_New_Face(lib, [[rfi objectAtIndex: 0] cString], 0, pface);
  if (err)
    {
      NSLog(@"Error when loading '%@' (%08x)", [rfi objectAtIndex: 0], err);
      return err;
    }

  for (i = 1; i < c; i++)
    {
//		NSLog(@"   do '%s'", [[rfi objectAtIndex: i] cString]);
      err = FT_Attach_File(*pface, [[rfi objectAtIndex: i] cString]);
      if (err)
	{
	  NSLog(@"Error when loading '%@' (%08x)", [rfi objectAtIndex: i], err);
	  /* pretend it's alright */
	}
    }
  return 0;
}


@implementation FTFontInfo
- initWithFontName: (NSString *)name
	matrix: (const float *)fmatrix
	screenFont: (BOOL)p_screenFont
{
  FT_Face face;
  FT_Size size;
  NSArray *rfi;
  FTFaceInfo *font_entry;

  FT_Error error;


  if (subpixel_text)
    {
      [self release];
      self = [FTFontInfo_subpixel alloc];
    }

  self = [super init];

  screenFont = p_screenFont;

  NSDebugLLog(@"ftfont", @"[%@ -initWithFontName: %@  matrix: (%g %g %g %g %g %g)] %i\n",
	      self, name,
	      fmatrix[0], fmatrix[1], fmatrix[2],
	      fmatrix[3], fmatrix[4], fmatrix[5],
	      p_screenFont);

  font_entry = [fcfg_all_fonts objectForKey: name];
  if (!font_entry)
    {
      [self release];
      return nil;
    }

  face_info = font_entry;

  weight = font_entry->weight;
  traits = font_entry->traits;

  fontName = [name copy];
  familyName = [face_info->familyName copy];
  memcpy(matrix, fmatrix, sizeof(matrix));

  /* TODO: somehow make gnustep-gui send unicode our way. utf8? ugly, but it works */
  mostCompatibleStringEncoding = NSUTF8StringEncoding;
  encodingScheme = @"iso10646-1";

  if (screenFont)
    {
      /* Round up; makes the text more legible. */
      matrix[0] = ceil(matrix[0]);
      if (matrix[3] < 0.0)
	matrix[3] = floor(matrix[3]);
      else
	matrix[3] = ceil(matrix[3]);
    }

  imgd.font.pix_width = fabs(matrix[0]);
  imgd.font.pix_height = fabs(matrix[3]);

  rfi = font_entry->files;
  if (screenFont && font_entry->num_sizes &&
      imgd.font.pix_width == imgd.font.pix_height)
    {
      int i;
      for (i = 0; i < font_entry->num_sizes; i++)
	{
	  if (font_entry->sizes[i].pixel_size == imgd.font.pix_width)
	    {
	      rfi = font_entry->sizes[i].files;
	      break;
	    }
	}
    }

  imgd.font.face_id = (FTC_FaceID)rfi;

  if ((error=FTC_Manager_Lookup_Size(ftc_manager, &imgd.font, &face, &size)))
    {
      NSLog(@"FTC_Manager_Lookup_Size() failed for '%@', error %08x!\n", name, error);
      return self;
    }

//	xHeight = size->metrics.height / 64.0;
/* TODO: these are _really_ messed up when fonts are flipped */
  /* TODO: need to look acrefully at these and make sure they are correct */
  ascender = fabs(((int)size->metrics.ascender) / 64.0);
  descender = fabs(((int)size->metrics.descender) / 64.0);
  lineHeight = (int)size->metrics.height / 64.0;
  xHeight = ascender * 0.5; /* TODO */
  maximumAdvancement = NSMakeSize((size->metrics.max_advance / 64.0), ascender + descender);

  fontBBox = NSMakeRect(0, descender, maximumAdvancement.width, ascender + descender);
  descender = -descender;

/*	printf("(%@) h=%g  a=%g d=%g  max=(%g %g)  (%g %g)+(%g %g)\n",name,
		xHeight, ascender, descender,
		maximumAdvancement.width, maximumAdvancement.height,
		fontBBox.origin.x, fontBBox.origin.y,
		fontBBox.size.width, fontBBox.size.height);*/

  {
    FTC_CMapDescRec cmap;
    cmap.face_id = imgd.font.face_id;
    cmap.u.encoding = ft_encoding_unicode;
    cmap.type = FTC_CMAP_BY_ENCODING;
    ligature_ff = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, 0xfb00);
    ligature_fi = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, 0xfb01);
    ligature_fl = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, 0xfb02);
    ligature_ffi = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, 0xfb03);
    ligature_ffl = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, 0xfb04);
/*    printf("ligatures %04x %04x %04x %04x %04x | %02x %02x %02x for |%@|\n",
      ligature_ff,ligature_fi,ligature_fl,ligature_ffi,ligature_ffl,
      FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, 'f'),
      FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, 'l'),
      FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, 'i'),
      fontName);*/
  }

    {
      float xx, yy;
#ifdef FT212_STUFF
      FTC_ImageDesc cur;
#else
      FTC_ImageTypeRec cur;
#endif

      cur = imgd;

      xx = matrix[0];
      yy = matrix[3];

	if (xx == yy && xx < 16 && xx >= 8)
	  {
	    int rh = face_info->render_hints_hack;
	    if (rh & 0x10000)
	      {
#ifdef FT212_STUFF
		cur.type = ftc_image_grays;
#else
		cur.flags = FT_LOAD_TARGET_NORMAL;
#endif
		rh = (rh >> 8) & 0xff;
	      }
	    else
	      {
#ifdef FT212_STUFF
		cur.type = ftc_image_mono;
#else
		cur.flags = FT_LOAD_TARGET_MONO;
#endif
		rh = rh & 0xff;
	      }
	    if (rh & 1)
#ifdef FT212_STUFF
	      cur.type |= ftc_image_flag_autohinted;
#else
	      cur.flags |= FT_LOAD_FORCE_AUTOHINT;
#endif
	    if (!(rh & 2))
#ifdef FT212_STUFF
	      cur.type |= ftc_image_flag_unhinted;
#else
	      cur.flags |= FT_LOAD_NO_HINTING;
#endif
	  }
	else if (xx < 8)
#ifdef FT212_STUFF
	  cur.type = ftc_image_grays | ftc_image_flag_unhinted;
#else
	  cur.flags = FT_LOAD_TARGET_NORMAL | FT_LOAD_NO_HINTING;
#endif
	else
#ifdef FT212_STUFF
	  cur.type = ftc_image_grays;
#else
	  cur.flags = FT_LOAD_TARGET_NORMAL;
#endif
      advancementImgd = cur;
    }

  /*
  Here, we simply need to make sure that we don't get any false matches
  the first time a particular cache entry is used. Thus, we only need to
  initialize the first entry. For all other entries, cachedGlyph[i] will
  be 0, and that's a glyph that can't possibly hash to any entry except
  entry #0, so it won't cause any false matches.
  */
  cachedGlyph[0] = 1;

  return self;
}

-(void) set
{
  NSLog(@"ignore -set method of font '%@'\n", fontName);
}


-(float) defaultLineHeightForFont
{
  return lineHeight;
}


#include <GNUstepBase/Unicode.h>

/* TODO: the current point probably needs updating after drawing is done */

/* draw string at point, clipped, w/given color and alpha, and possible deltas:
   flags & 0x1: data contains x offsets, use instead of glyph x advance
   flags & 0x2: data contains y offsets, use instead of glyph y advance
   flags & 0x4: data contains a single x and y offset, which should be added to
                font's advancements for each glyph; results are undefined if
                this option is combined with either x or y offsets (0x1,0x2)
   flags & 0x8: data contains a single x and y offset, which should be added to
                font's advancement for glyph identified by 'wch'; if combined
                with 0x4 deltas contain exactly two offsets for x and y, the
                first for every character, the second for 'wch'; results are
                undefined if 0x8 is combined with 0x2 or 0x1
 */
-(void) drawString: (const char *)s
	at: (int)x : (int)y
	to: (int)x0 : (int)y0 : (int)x1 : (int)y1
	: (unsigned char *)buf : (int)bpl
	: (unsigned char *)abuf : (int)abpl
	color:(unsigned char)r : (unsigned char)g : (unsigned char)b : (unsigned char)alpha
	transform: (NSAffineTransform *)transform
	deltas: (const float *)delta_data : (int)delta_size : (int)delta_flags
        widthChar: (int) wch
	drawinfo: (draw_info_t *)di
{
#if 0
  NSLog(@"ignoring drawString");
#else
  const unsigned char *c;
  unsigned char ch;
  unsigned int uch;
  int d;

  FTC_CMapDescRec cmap;
  unsigned int glyph;

  int use_sbit;

  FTC_SBit sbit;
#ifdef FT212_STUFF
  FTC_ImageDesc cur;
#else
  FTC_ImageTypeRec cur;
#endif

  FT_Matrix ftmatrix;
  FT_Vector ftdelta;

  FT_Error error;


  if (!alpha)
    return;

  /* TODO: if we had guaranteed upper bounds on glyph image size we
     could do some basic clipping here */

  x1 -= x0;
  y1 -= y0;
  x -= x0;
  y -= y0;


/*	NSLog(@"[%@ draw using matrix: (%g %g %g %g %g %g)] transform=%@\n",
		self,
		matrix[0], matrix[1], matrix[2],
		matrix[3], matrix[4], matrix[5],
		transform
		);*/

  cur = imgd;
  {
    float xx, xy, yx, yy;

    xx = matrix[0] * transform->matrix.m11 + matrix[1] * transform->matrix.m21;
    yx = matrix[0] * transform->matrix.m12 + matrix[1] * transform->matrix.m22;
    xy = matrix[2] * transform->matrix.m11 + matrix[3] * transform->matrix.m21;
    yy = matrix[2] * transform->matrix.m12 + matrix[3] * transform->matrix.m22;

    /* If we're drawing 'normal' text (unscaled, unrotated, reasonable
       size), we can and should use the sbit cache for screen fonts. */
    if (screenFont &&
	fabs(xx - ((int)xx)) < 0.01 && fabs(yy - ((int)yy)) < 0.01 &&
	fabs(xy) < 0.01 && fabs(yx) < 0.01 &&
	xx < 72 && yy < 72 && xx > 0.5 && yy > 0.5)
      {
	use_sbit = 1;
	cur.font.pix_width = xx;
	cur.font.pix_height = yy;

	if (xx == yy && xx < 16 && xx >= 8)
	  {
	    int rh = face_info->render_hints_hack;
	    if (rh & 0x10000)
	      {
#ifdef FT212_STUFF
		cur.type = ftc_image_grays;
#else
		cur.flags = FT_LOAD_TARGET_NORMAL;
#endif
		rh = (rh >> 8) & 0xff;
	      }
	    else
	      {
#ifdef FT212_STUFF
		cur.type = ftc_image_mono;
#else
		cur.flags = FT_LOAD_TARGET_MONO;
#endif
		rh = rh & 0xff;
	      }
	    if (rh & 1)
#ifdef FT212_STUFF
	      cur.type |= ftc_image_flag_autohinted;
#else
	      cur.flags |= FT_LOAD_FORCE_AUTOHINT;
#endif
	    if (!(rh & 2))
#ifdef FT212_STUFF
	      cur.type |= ftc_image_flag_unhinted;
#else
	      cur.flags |= FT_LOAD_NO_HINTING;
#endif
	  }
	else if (xx < 8)
#ifdef FT212_STUFF
	  cur.type = ftc_image_grays | ftc_image_flag_unhinted;
#else
	  cur.flags = FT_LOAD_TARGET_NORMAL | FT_LOAD_NO_HINTING;
#endif
	else
#ifdef FT212_STUFF
	  cur.type = ftc_image_grays;
#else
	  cur.flags = FT_LOAD_TARGET_NORMAL;
#endif
      }
    else
      {
	float f;
	use_sbit = 0;

	f = fabs(xx * yy - xy * yx);
	if (f > 1)
	  f = sqrt(f);
	else
	  f = 1.0;

	f = (int)f;

	cur.font.pix_width = cur.font.pix_height = f;
	ftmatrix.xx = xx / f * 65536.0;
	ftmatrix.xy = xy / f * 65536.0;
	ftmatrix.yx = yx / f * 65536.0;
	ftmatrix.yy = yy / f * 65536.0;
	ftdelta.x = ftdelta.y = 0;
      }
  }


/*	NSLog(@"drawString: '%s' at: %i:%i  to: %i:%i:%i:%i:%p\n",
		s, x, y, x0, y0, x1, y1, buf);*/

  cmap.face_id = imgd.font.face_id;
  cmap.u.encoding = ft_encoding_unicode;
  cmap.type = FTC_CMAP_BY_ENCODING;
  d=0;

  for (c = s; *c; c++)
    {
/* TODO: do the same thing in outlineString:... */
      ch = *c;
      if (ch < 0x80)
	{
	  uch = ch;
	}
      else if (ch < 0xc0)
	{
	  uch = 0xfffd;
	}
      else if (ch < 0xe0)
	{
#define ADD_UTF_BYTE(shift, internal) \
  ch = *++c; \
  if (ch >= 0x80 && ch < 0xc0) \
    { \
      uch |= (ch & 0x3f) << shift; \
      internal \
    } \
  else \
    { \
      uch = 0xfffd; \
      c--; \
    }

	  uch = (ch & 0x1f) << 6;
	  ADD_UTF_BYTE(0,)
	}
      else if (ch < 0xf0)
	{
	  uch = (ch & 0x0f) << 12;
	  ADD_UTF_BYTE(6, ADD_UTF_BYTE(0,))
	}
      else if (ch < 0xf8)
	{
	  uch = (ch & 0x07) << 18;
	  ADD_UTF_BYTE(12, ADD_UTF_BYTE(6, ADD_UTF_BYTE(0,)))
	}
      else if (ch < 0xfc)
	{
	  uch = (ch & 0x03) << 24;
	  ADD_UTF_BYTE(18, ADD_UTF_BYTE(12, ADD_UTF_BYTE(6, ADD_UTF_BYTE(0,))))
	}
      else if (ch < 0xfe)
	{
	  uch = (ch & 0x01) << 30;
	  ADD_UTF_BYTE(24, ADD_UTF_BYTE(18, ADD_UTF_BYTE(12, ADD_UTF_BYTE(6, ADD_UTF_BYTE(0,)))))
	}
      else
	uch = 0xfffd;
#undef ADD_UTF_BYTE

      glyph = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, uch);
      cur.font.face_id = imgd.font.face_id;

      if (use_sbit)
	{
	  if ((error=FTC_SBitCache_Lookup(ftc_sbitcache, &cur, glyph, &sbit, NULL)))
	    {
	      NSLog(@"FTC_SBitCache_Lookup() failed with error %08x (%08x, %08x, %ix%i, %08x)\n",
		error, glyph, cur.font.face_id, cur.font.pix_width, cur.font.pix_height,
#ifdef FT212_STUFF
		cur.type
#else
		cur.flags
#endif
		);
	      continue;
	    }

	  if (!sbit->buffer)
	    {
              if (!delta_flags)
                {
                x += sbit->xadvance;
                }
              else
                {
                  if (delta_flags & 0x1)
                    x += delta_data[d++];
                  if (delta_flags & 0x2)
                    y += (transform->matrix.m22 < 0) ?
                        delta_data[d++] : -delta_data[d++];
                  if (delta_flags & 0x4)
                    {
                      x += sbit->xadvance + delta_data[0];
                      y += /*sbit->yadvance +*/ (transform->matrix.m22 < 0) ?
                          delta_data[1] : -delta_data[1];
                      if ((delta_flags & 0x8) && (uch == wch))
                        {
                          x += delta_data[2];
                          y += (transform->matrix.m22 < 0) ?
                              delta_data[3] : -delta_data[3];
                        }
                    }
                  else if (delta_flags & 0x8)
                    {
                      if (uch == wch)
                        {
                          x += sbit->xadvance + delta_data[0];
                          y += /*sbit->yadvance +*/ (transform->matrix.m22 < 0) ?
                            delta_data[1] : -delta_data[1];
                        }
                      else
                        {
                          x += sbit->xadvance;
                          /*y += sbit->yadvance;*/
                        }
                    }
                }
	      continue;
	    }

	  if (sbit->format == ft_pixel_mode_grays)
	    {
	      int gx = x + sbit->left, gy = y - sbit->top;
	      int sbpl = sbit->pitch;
	      int sx = sbit->width, sy = sbit->height;
	      const unsigned char *src = sbit->buffer;
	      unsigned char *dst = buf;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  if (alpha >= 255)
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA_OPAQUE(dst, src, r, g, b, sx);
		  else
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA(dst, src, r, g, b, alpha, sx);
		}
	    }
	  else if (sbit->format == ft_pixel_mode_mono)
	    {
	      int gx = x + sbit->left, gy = y - sbit->top;
	      int sbpl = sbit->pitch;
	      int sx = sbit->width, sy = sbit->height;
	      const unsigned char *src = sbit->buffer;
	      unsigned char *dst = buf;
	      int src_ofs = 0;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx / 8;
		  src_ofs = (-gx) & 7;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  if (alpha >= 255)
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_MONO_OPAQUE(dst, src, src_ofs, r, g, b, sx);
		  else
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_MONO(dst, src, src_ofs, r, g, b, alpha, sx);
		}
	    }
	  else
	    {
	      NSLog(@"unhandled font bitmap format %i", sbit->format);
	    }

          if (!delta_flags)
            {
              x += sbit->xadvance;
            }
          else
            {
              if (delta_flags & 0x1)
                  x += delta_data[d++];
              if (delta_flags & 0x2)
                  y += (transform->matrix.m22 < 0) ?
                      delta_data[d++] : -delta_data[d++];
              if (delta_flags & 0x4)
                {
                  x += sbit->xadvance + delta_data[0];
                  y += /*sbit->yadvance +*/ (transform->matrix.m22 < 0) ?
                      delta_data[1] : -delta_data[1];
                  if ((delta_flags & 0x8) && (uch == wch))
                    {
                      x += delta_data[2];
                      y += (transform->matrix.m22 < 0) ?
                          delta_data[3] : -delta_data[3];
                    }
                }
              else if (delta_flags & 0x8)
                {
                  if (uch == wch)
                    {
                      x += sbit->xadvance + delta_data[0];
                      y += /*sbit->yadvance +*/ (transform->matrix.m22 < 0) ?
                          delta_data[1] : -delta_data[1];
                    }
                  else
                    {
                      x += sbit->xadvance;
                      /*y += sbit->yadvance;*/
                    }
                }
            }
	}
      else
	{
	  FT_Face face;
	  FT_Glyph gl;
	  FT_BitmapGlyph gb;

	  if ((error=FTC_Manager_Lookup_Size(ftc_manager, &cur.font, &face, 0)))
	    {
	      NSLog(@"FTC_Manager_Lookup_Size() failed with error %08x\n",error);
	      continue;
	    }

	  /* TODO: for rotations of 90, 180, 270, and integer
	     scales hinting might still be a good idea. */
	  if ((error=FT_Load_Glyph(face, glyph, FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP)))
	    {
	      NSLog(@"FT_Load_Glyph() failed with error %08x\n",error);
	      continue;
	    }

	  if ((error=FT_Get_Glyph(face->glyph, &gl)))
	    {
	      NSLog(@"FT_Get_Glyph() failed with error %08x\n",error);
	      continue;
	    }

	  if ((error=FT_Glyph_Transform(gl, &ftmatrix, &ftdelta)))
	    {
	      NSLog(@"FT_Glyph_Transform() failed with error %08x\n",error);
	      continue;
	    }
	  if ((error=FT_Glyph_To_Bitmap(&gl, ft_render_mode_normal, 0, 1)))
	    {
	      NSLog(@"FT_Glyph_To_Bitmap() failed with error %08x\n",error);
	      FT_Done_Glyph(gl);
	      continue;
	    }
	  gb = (FT_BitmapGlyph)gl;


	  if (gb->bitmap.pixel_mode == ft_pixel_mode_grays)
	    {
	      int gx = x + gb->left, gy = y - gb->top;
	      int sbpl = gb->bitmap.pitch;
	      int sx = gb->bitmap.width, sy = gb->bitmap.rows;
	      const unsigned char *src = gb->bitmap.buffer;
	      unsigned char *dst = buf;
	      unsigned char *dsta = abuf;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		  if (dsta)
		    dsta += abpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		  if (dsta)
		    dsta += gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  if (dsta)
		    for (; gy < sy; gy++, src += sbpl, dst += bpl, dsta += abpl)
		      RENDER_BLIT_ALPHA_A(dst, dsta, src, r, g, b, alpha, sx);
		  else if (alpha >= 255)
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA_OPAQUE(dst, src, r, g, b, sx);
		  else
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA(dst, src, r, g, b, alpha, sx);
		}
	    }
/* TODO: will this case ever appear? */
/*			else if (gb->bitmap.pixel_mode==ft_pixel_mode_mono)*/
	  else
	    {
	      NSLog(@"unhandled font bitmap format %i", gb->bitmap.pixel_mode);
	    }

          if (!delta_flags)
            {
              ftdelta.x += gl->advance.x >> 10;
              ftdelta.y += gl->advance.y >> 10;
            }
          else
            {
              if (delta_flags & 0x1)
                ftdelta.x += delta_data[d++] * 64.0;
              if (delta_flags & 0x2)
                ftdelta.y += delta_data[d++] * 64.0;
              if (delta_flags & 0x4)
                {
                  ftdelta.x += (gl->advance.x >> 10) + delta_data[0] * 64.0;
                  ftdelta.y += (gl->advance.y >> 10) + delta_data[1] * 64.0;
                  if ((delta_flags & 0x8) && (uch == wch))
                    {
                      ftdelta.x += delta_data[2] * 64.0;
                      ftdelta.y += delta_data[3] * 64.0;
                    }
                }
              else if (delta_flags & 0x8)
                {
                  if (uch == wch)
                    {
                      ftdelta.x += (gl->advance.x>>10) + delta_data[0] * 64.0;
                      ftdelta.y += (gl->advance.y>>10) + delta_data[1] * 64.0;
                    }
                  else
                    {
                      ftdelta.x += gl->advance.x >> 10;
                      ftdelta.y += gl->advance.y >> 10;
                    }
                }
            }

	  FT_Done_Glyph(gl);
	}
    }

#endif
}


-(void) drawGlyphs: (const NSGlyph *)glyphs : (int)length
	at: (int)x : (int)y
	to: (int)x0 : (int)y0 : (int)x1 : (int)y1
	: (unsigned char *)buf : (int)bpl
	color: (unsigned char)r : (unsigned char)g : (unsigned char)b
	: (unsigned char)alpha
	transform: (NSAffineTransform *)transform
	drawinfo: (struct draw_info_s *)di
{
  unsigned int glyph;

  int use_sbit;

  FTC_SBit sbit;
#ifdef FT212_STUFF
  FTC_ImageDesc cur;
#else
  FTC_ImageTypeRec cur;
#endif

  FT_Matrix ftmatrix;
  FT_Vector ftdelta;

  FT_Error error;


  if (!alpha)
    return;

  /* TODO: if we had guaranteed upper bounds on glyph image size we
     could do some basic clipping here */

  x1 -= x0;
  y1 -= y0;
  x -= x0;
  y -= y0;


/*	NSLog(@"[%@ draw using matrix: (%g %g %g %g %g %g)] transform=%@\n",
		self,
		matrix[0], matrix[1], matrix[2],
		matrix[3], matrix[4], matrix[5],
		transform
		);*/

  cur = imgd;
  {
    float xx, xy, yx, yy;

    xx = matrix[0] * transform->matrix.m11 + matrix[1] * transform->matrix.m21;
    yx = matrix[0] * transform->matrix.m12 + matrix[1] * transform->matrix.m22;
    xy = matrix[2] * transform->matrix.m11 + matrix[3] * transform->matrix.m21;
    yy = matrix[2] * transform->matrix.m12 + matrix[3] * transform->matrix.m22;
 
    /* If we're drawing 'normal' text (unscaled, unrotated, reasonable
       size), we can and should use the sbit cache for screen fonts. */
    if (screenFont &&
	fabs(xx - ((int)xx)) < 0.01 && fabs(yy - ((int)yy)) < 0.01 &&
	fabs(xy) < 0.01 && fabs(yx) < 0.01 &&
	xx < 72 && yy < 72 && xx > 0.5 && yy > 0.5)
      {
	use_sbit = 1;
	cur.font.pix_width = xx;
	cur.font.pix_height = yy;

	if (xx == yy && xx < 16 && xx >= 8)
	  {
	    int rh = face_info->render_hints_hack;
	    if (rh & 0x10000)
	      {
#ifdef FT212_STUFF
		cur.type = ftc_image_grays;
#else
		cur.flags = FT_LOAD_TARGET_NORMAL;
#endif
		rh = (rh >> 8) & 0xff;
	      }
	    else
	      {
#ifdef FT212_STUFF
		cur.type = ftc_image_mono;
#else
		cur.flags = FT_LOAD_TARGET_MONO;
#endif
		rh = rh & 0xff;
	      }
	    if (rh & 1)
#ifdef FT212_STUFF
	      cur.type |= ftc_image_flag_autohinted;
#else
	      cur.flags |= FT_LOAD_FORCE_AUTOHINT;
#endif
	    if (!(rh & 2))
#ifdef FT212_STUFF
	      cur.type |= ftc_image_flag_unhinted;
#else
	      cur.flags |= FT_LOAD_NO_HINTING;
#endif
	  }
	else if (xx < 8)
#ifdef FT212_STUFF
	  cur.type = ftc_image_grays | ftc_image_flag_unhinted;
#else
	  cur.flags = FT_LOAD_TARGET_NORMAL | FT_LOAD_NO_HINTING;
#endif
	else
#ifdef FT212_STUFF
	  cur.type = ftc_image_grays;
#else
	  cur.flags = FT_LOAD_TARGET_NORMAL;
#endif
      }
    else
      {
	float f;
	use_sbit = 0;

	f = fabs(xx * yy - xy * yx);
	if (f > 1)
	  f = sqrt(f);
	else
	  f = 1.0;

	f = (int)f;

	cur.font.pix_width = cur.font.pix_height = f;
	ftmatrix.xx = xx / f * 65536.0;
	ftmatrix.xy = xy / f * 65536.0;
	ftmatrix.yx = yx / f * 65536.0;
	ftmatrix.yy = yy / f * 65536.0;
	ftdelta.x = ftdelta.y = 0;
      }
  }

/*	NSLog(@"drawString: '%s' at: %i:%i  to: %i:%i:%i:%i:%p\n",
		s, x, y, x0, y0, x1, y1, buf);*/

  for (; length; length--, glyphs++)
    {
      glyph = *glyphs - 1;

      if (use_sbit)
	{
	  if ((error = FTC_SBitCache_Lookup(ftc_sbitcache, &cur, glyph, &sbit, NULL)))
	    {
	      NSLog(@"FTC_SBitCache_Lookup() failed with error %08x (%08x, %08x, %ix%i, %08x)\n",
		error, glyph, cur.font.face_id, cur.font.pix_width, cur.font.pix_height,
#ifdef FT212_STUFF
		cur.type
#else
		cur.flags
#endif
		);
	      continue;
	    }

	  if (!sbit->buffer)
	    {
	      x += sbit->xadvance;
	      continue;
	    }

	  if (sbit->format == ft_pixel_mode_grays)
	    {
	      int gx = x + sbit->left, gy = y - sbit->top;
	      int sbpl = sbit->pitch;
	      int sx = sbit->width, sy = sbit->height;
	      const unsigned char *src = sbit->buffer;
	      unsigned char *dst = buf;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  if (alpha >= 255)
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA_OPAQUE(dst, src, r, g, b, sx);
		  else
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA(dst, src, r, g, b, alpha, sx);
		}
	    }
	  else if (sbit->format == ft_pixel_mode_mono)
	    {
	      int gx = x + sbit->left, gy = y - sbit->top;
	      int sbpl = sbit->pitch;
	      int sx = sbit->width, sy = sbit->height;
	      const unsigned char *src = sbit->buffer;
	      unsigned char *dst = buf;
	      int src_ofs = 0;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx / 8;
		  src_ofs = (-gx) & 7;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  if (alpha >= 255)
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_MONO_OPAQUE(dst, src, src_ofs, r, g, b, sx);
		  else
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_MONO(dst, src, src_ofs, r, g, b, alpha, sx);
		}
	    }
	  else
	    {
	      NSLog(@"unhandled font bitmap format %i", sbit->format);
	    }

	  x += sbit->xadvance;
	}
      else
	{
	  FT_Face face;
	  FT_Glyph gl;
	  FT_BitmapGlyph gb;

	  if ((error=FTC_Manager_Lookup_Size(ftc_manager, &cur.font, &face, 0)))
	    {
	      NSLog(@"FTC_Manager_Lookup_Size() failed with error %08x\n",error);
	      continue;
	    }

	  /* TODO: for rotations of 90, 180, 270, and integer
	     scales hinting might still be a good idea. */
	  if ((error=FT_Load_Glyph(face, glyph, FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP)))
	    {
	      NSLog(@"FT_Load_Glyph() failed with error %08x\n",error);
	      continue;
	    }

	  if ((error=FT_Get_Glyph(face->glyph, &gl)))
	    {
	      NSLog(@"FT_Get_Glyph() failed with error %08x\n",error);
	      continue;
	    }

	  if ((error=FT_Glyph_Transform(gl, &ftmatrix, &ftdelta)))
	    {
	      NSLog(@"FT_Glyph_Transform() failed with error %08x\n",error);
	      continue;
	    }
	  if ((error=FT_Glyph_To_Bitmap(&gl, ft_render_mode_normal, 0, 1)))
	    {
	      NSLog(@"FT_Glyph_To_Bitmap() failed with error %08x\n",error);
	      FT_Done_Glyph(gl);
	      continue;
	    }
	  gb = (FT_BitmapGlyph)gl;


	  if (gb->bitmap.pixel_mode == ft_pixel_mode_grays)
	    {
	      int gx = x + gb->left, gy = y - gb->top;
	      int sbpl = gb->bitmap.pitch;
	      int sx = gb->bitmap.width, sy = gb->bitmap.rows;
	      const unsigned char *src = gb->bitmap.buffer;
	      unsigned char *dst = buf;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  if (alpha >= 255)
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA_OPAQUE(dst, src, r, g, b, sx);
		  else
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA(dst, src, r, g, b, alpha, sx);
		}
	    }
/* TODO: will this case ever appear? */
/*			else if (gb->bitmap.pixel_mode==ft_pixel_mode_mono)*/
	  else
	    {
	      NSLog(@"unhandled font bitmap format %i", gb->bitmap.pixel_mode);
	    }

	  ftdelta.x += gl->advance.x >> 10;
	  ftdelta.y += gl->advance.y >> 10;

	  FT_Done_Glyph(gl);
	}
    }
}

-(void) drawGlyphs: (const NSGlyph *)glyphs : (int)length
	at: (int)x : (int)y
	to: (int)x0 : (int)y0 : (int)x1 : (int)y1
	: (unsigned char *)buf : (int)bpl
	alpha: (unsigned char *)abuf : (int)abpl
	color: (unsigned char)r : (unsigned char)g : (unsigned char)b
	: (unsigned char)alpha
	transform: (NSAffineTransform *)transform
	drawinfo: (struct draw_info_s *)di
{
  unsigned int glyph;

  int use_sbit;

  FTC_SBit sbit;
#ifdef FT212_STUFF
  FTC_ImageDesc cur;
#else
  FTC_ImageTypeRec cur;
#endif

  FT_Matrix ftmatrix;
  FT_Vector ftdelta;

  FT_Error error;


  if (!alpha)
    return;

  /* TODO: if we had guaranteed upper bounds on glyph image size we
     could do some basic clipping here */

  x1 -= x0;
  y1 -= y0;
  x -= x0;
  y -= y0;


/*	NSLog(@"[%@ draw using matrix: (%g %g %g %g %g %g)] transform=%@\n",
		self,
		matrix[0], matrix[1], matrix[2],
		matrix[3], matrix[4], matrix[5],
		transform
		);*/

  cur = imgd;
  {
    float xx, xy, yx, yy;

    xx = matrix[0] * transform->matrix.m11 + matrix[1] * transform->matrix.m21;
    yx = matrix[0] * transform->matrix.m12 + matrix[1] * transform->matrix.m22;
    xy = matrix[2] * transform->matrix.m11 + matrix[3] * transform->matrix.m21;
    yy = matrix[2] * transform->matrix.m12 + matrix[3] * transform->matrix.m22;
 
    /* If we're drawing 'normal' text (unscaled, unrotated, reasonable
       size), we can and should use the sbit cache for screen fonts. */
    if (screenFont &&
	fabs(xx - ((int)xx)) < 0.01 && fabs(yy - ((int)yy)) < 0.01 &&
	fabs(xy) < 0.01 && fabs(yx) < 0.01 &&
	xx < 72 && yy < 72 && xx > 0.5 && yy > 0.5)
      {
	use_sbit = 1;
	cur.font.pix_width = xx;
	cur.font.pix_height = yy;

	if (xx == yy && xx < 16 && xx >= 8)
	  {
	    int rh = face_info->render_hints_hack;
	    if (rh & 0x10000)
	      {
#ifdef FT212_STUFF
		cur.type = ftc_image_grays;
#else
		cur.flags = FT_LOAD_TARGET_NORMAL;
#endif
		rh = (rh >> 8) & 0xff;
	      }
	    else
	      {
#ifdef FT212_STUFF
		cur.type = ftc_image_mono;
#else
		cur.flags = FT_LOAD_TARGET_MONO;
#endif
		rh = rh & 0xff;
	      }
	    if (rh & 1)
#ifdef FT212_STUFF
	      cur.type |= ftc_image_flag_autohinted;
#else
	      cur.flags |= FT_LOAD_FORCE_AUTOHINT;
#endif
	    if (!(rh & 2))
#ifdef FT212_STUFF
	      cur.type |= ftc_image_flag_unhinted;
#else
	      cur.flags |= FT_LOAD_NO_HINTING;
#endif
	  }
	else if (xx < 8)
#ifdef FT212_STUFF
	  cur.type = ftc_image_grays | ftc_image_flag_unhinted;
#else
	  cur.flags = FT_LOAD_TARGET_NORMAL | FT_LOAD_NO_HINTING;
#endif
	else
#ifdef FT212_STUFF
	  cur.type = ftc_image_grays;
#else
	  cur.flags = FT_LOAD_TARGET_NORMAL;
#endif
      }
    else
      {
	float f;
	use_sbit = 0;

	f = fabs(xx * yy - xy * yx);
	if (f > 1)
	  f = sqrt(f);
	else
	  f = 1.0;

	f = (int)f;

	cur.font.pix_width = cur.font.pix_height = f;
	ftmatrix.xx = xx / f * 65536.0;
	ftmatrix.xy = xy / f * 65536.0;
	ftmatrix.yx = yx / f * 65536.0;
	ftmatrix.yy = yy / f * 65536.0;
	ftdelta.x = ftdelta.y = 0;
      }
  }

/*	NSLog(@"drawString: '%s' at: %i:%i  to: %i:%i:%i:%i:%p\n",
		s, x, y, x0, y0, x1, y1, buf);*/

  for (; length; length--, glyphs++)
    {
      glyph = *glyphs - 1;

      if (use_sbit)
	{
	  if ((error = FTC_SBitCache_Lookup(ftc_sbitcache, &cur, glyph, &sbit, NULL)))
	    {
	      if (glyph != 0xffffffff)
		NSLog(@"FTC_SBitCache_Lookup() failed with error %08x (%08x, %08x, %ix%i, %08x)\n",
		  error, glyph, cur.font.face_id, cur.font.pix_width, cur.font.pix_height,
#ifdef FT212_STUFF
		  cur.type
#else
		  cur.flags
#endif
		);
	      continue;
	    }

	  if (!sbit->buffer)
	    {
	      x += sbit->xadvance;
	      continue;
	    }

	  if (sbit->format == ft_pixel_mode_grays)
	    {
	      int gx = x + sbit->left, gy = y - sbit->top;
	      int sbpl = sbit->pitch;
	      int sx = sbit->width, sy = sbit->height;
	      const unsigned char *src = sbit->buffer;
	      unsigned char *dst = buf;
	      unsigned char *adst = abuf;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		  adst += abpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		  adst += gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  for (; gy < sy; gy++, src += sbpl, dst += bpl, adst += abpl)
		    RENDER_BLIT_ALPHA_A(dst, adst, src, r, g, b, alpha, sx);
		}
	    }
	  else if (sbit->format == ft_pixel_mode_mono)
	    {
	      int gx = x + sbit->left, gy = y - sbit->top;
	      int sbpl = sbit->pitch;
	      int sx = sbit->width, sy = sbit->height;
	      const unsigned char *src = sbit->buffer;
	      unsigned char *dst = buf;
	      unsigned char *adst = abuf;
	      int src_ofs = 0;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		  adst += abpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx / 8;
		  src_ofs = (-gx) & 7;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		  adst += gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  for (; gy < sy; gy++, src += sbpl, dst += bpl, adst += bpl)
		    RENDER_BLIT_MONO_A(dst, adst, src, src_ofs, r, g, b, alpha, sx);
		}
	    }
	  else
	    {
	      NSLog(@"unhandled font bitmap format %i", sbit->format);
	    }

	  x += sbit->xadvance;
	}
      else
	{
	  FT_Face face;
	  FT_Glyph gl;
	  FT_BitmapGlyph gb;

	  if ((error=FTC_Manager_Lookup_Size(ftc_manager, &cur.font, &face, 0)))
	    {
	      NSLog(@"FTC_Manager_Lookup_Size() failed with error %08x\n",error);
	      continue;
	    }

	  /* TODO: for rotations of 90, 180, 270, and integer
	     scales hinting might still be a good idea. */
	  if ((error=FT_Load_Glyph(face, glyph, FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP)))
	    {
	      NSLog(@"FT_Load_Glyph() failed with error %08x\n",error);
	      continue;
	    }

	  if ((error=FT_Get_Glyph(face->glyph, &gl)))
	    {
	      NSLog(@"FT_Get_Glyph() failed with error %08x\n",error);
	      continue;
	    }

	  if ((error=FT_Glyph_Transform(gl, &ftmatrix, &ftdelta)))
	    {
	      NSLog(@"FT_Glyph_Transform() failed with error %08x\n",error);
	      continue;
	    }
	  if ((error=FT_Glyph_To_Bitmap(&gl, ft_render_mode_normal, 0, 1)))
	    {
	      NSLog(@"FT_Glyph_To_Bitmap() failed with error %08x\n",error);
	      FT_Done_Glyph(gl);
	      continue;
	    }
	  gb = (FT_BitmapGlyph)gl;


	  if (gb->bitmap.pixel_mode == ft_pixel_mode_grays)
	    {
	      int gx = x + gb->left, gy = y - gb->top;
	      int sbpl = gb->bitmap.pitch;
	      int sx = gb->bitmap.width, sy = gb->bitmap.rows;
	      const unsigned char *src = gb->bitmap.buffer;
	      unsigned char *dst = buf;
	      unsigned char *adst = abuf;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		  adst += abpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		  adst += gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  for (; gy < sy; gy++, src += sbpl, dst += bpl, adst += bpl)
		    RENDER_BLIT_ALPHA_A(dst, adst, src, r, g, b, alpha, sx);
		}
	    }
/* TODO: will this case ever appear? */
/*			else if (gb->bitmap.pixel_mode==ft_pixel_mode_mono)*/
	  else
	    {
	      NSLog(@"unhandled font bitmap format %i", gb->bitmap.pixel_mode);
	    }

	  ftdelta.x += gl->advance.x >> 10;
	  ftdelta.y += gl->advance.y >> 10;

	  FT_Done_Glyph(gl);
	}
    }
}


-(BOOL) glyphIsEncoded: (NSGlyph)glyph
{
  FT_Face face;
  FT_Error error;

  glyph--;
  if ((error=FTC_Manager_Lookup_Size(ftc_manager, &imgd.font, &face, 0)))
    {
      NSLog(@"FTC_Manager_Lookup_Size() failed with error %08x",error);
      return NO;
    }

  if ((error=FT_Load_Glyph(face, glyph, 0)))
    {
      NSLog(@"FT_Load_Glyph() failed with error %08x",error);
      return NO;
    }

  return YES;
}


- (NSSize) advancementForGlyph: (NSGlyph)glyph
{
  FT_Error error;

  if (glyph == NSControlGlyph
   || glyph == GSAttachmentGlyph)
    return NSZeroSize;

  if (glyph != NSNullGlyph)
    glyph--;
  if (screenFont)
    {
      int entry = glyph % CACHE_SIZE;
      FTC_SBit sbit;

      if (cachedGlyph[entry] == glyph)
	return cachedSize[entry];

      if ((error=FTC_SBitCache_Lookup(ftc_sbitcache, &advancementImgd, glyph, &sbit, NULL)))
	{
	  NSLog(@"FTC_SBitCache_Lookup() failed with error %08x (%08x, %08x, %ix%i, %08x)\n",
	    error, glyph, advancementImgd.font.face_id,
	    advancementImgd.font.pix_width, advancementImgd.font.pix_height,
#ifdef FT212_STUFF
	    advancementImgd.type
#else
	    advancementImgd.flags
#endif
	);
	  return NSZeroSize;
	}

      cachedGlyph[entry] = glyph;
      cachedSize[entry] = NSMakeSize(sbit->xadvance, sbit->yadvance);
      return cachedSize[entry];
    }
  else
    {
      FT_Face face;
      FT_Glyph gl;
      FT_Matrix ftmatrix;
      FT_Vector ftdelta;
      float f;
      NSSize s;

      f = fabs(matrix[0] * matrix[3] - matrix[1] * matrix[2]);
      if (f > 1)
	f = sqrt(f);
      else
	f = 1.0;

      f = (int)f;

      ftmatrix.xx = matrix[0] / f * 65536.0;
      ftmatrix.xy = matrix[1] / f * 65536.0;
      ftmatrix.yx = matrix[2] / f * 65536.0;
      ftmatrix.yy = matrix[3] / f * 65536.0;
      ftdelta.x = ftdelta.y = 0;

      if (FTC_Manager_Lookup_Size(ftc_manager, &imgd.font, &face, 0))
	return NSZeroSize;

      if (FT_Load_Glyph(face, glyph, FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP))
	return NSZeroSize;

      if (FT_Get_Glyph(face->glyph, &gl))
	return NSZeroSize;

      if (FT_Glyph_Transform(gl, &ftmatrix, &ftdelta))
	return NSZeroSize;

      s = NSMakeSize(gl->advance.x / 65536.0, gl->advance.y / 65536.0);

      FT_Done_Glyph(gl);

      return s;
    }
}

- (NSRect) boundingRectForGlyph: (NSGlyph)glyph
{
#ifdef FT212_STUFF
  FTC_ImageDesc *cur;
#else
  FTC_ImageTypeRec *cur;
#endif
  FT_BBox bbox;
  FT_Glyph g;
  FT_Error error;

  glyph--;
/* TODO: this is ugly */
  cur = &imgd;
  if ((error=FTC_ImageCache_Lookup(ftc_imagecache, cur, glyph, &g, NULL)))
    {
      NSLog(@"FTC_ImageCache_Lookup() failed with error %08x",error);
//		NSLog(@"boundingRectForGlyph: %04x -> %i\n", aGlyph, glyph);
      return fontBBox;
    }

  FT_Glyph_Get_CBox(g, ft_glyph_bbox_gridfit, &bbox);

/*	printf("got cbox for %04x: %i, %i - %i, %i\n",
		aGlyph, bbox.xMin, bbox.yMin, bbox.xMax, bbox.yMax);*/

  return NSMakeRect(bbox.xMin / 64.0, bbox.yMin / 64.0,
		    (bbox.xMax - bbox.xMin) / 64.0, (bbox.yMax - bbox.yMin) / 64.0);
}

-(NSPoint) positionOfGlyph: (NSGlyph)g
	precededByGlyph: (NSGlyph)prev
	isNominal: (BOOL *)nominal
{
  NSPoint a;
  FT_Face face;
  FT_Vector vec;
  FT_GlyphSlot glyph;

  if (nominal)
    *nominal = YES;

  if (g == NSControlGlyph || prev == NSControlGlyph)
    return NSZeroPoint;

  g--;
  prev--;

  if (FTC_Manager_Lookup_Size(ftc_manager, &imgd.font, &face, 0))
    return NSZeroPoint;

  if (FT_Load_Glyph(face, prev, FT_LOAD_DEFAULT))
    return NSZeroPoint;

  glyph = face->glyph;
  a = NSMakePoint(glyph->advance.x / 64.0, glyph->advance.y / 64.0);

  if (FT_Get_Kerning(face, prev, g, ft_kerning_default, &vec))
    return a;

  if (vec.x == 0 && vec.y == 0)
    return a;

  if (nominal)
    *nominal = NO;

  a.x += vec.x / 64.0;
  a.y += vec.y / 64.0;
  return a;
}


- (float) widthOfString: (NSString*)string
{
  unichar ch;
  int i, c = [string length];
  int total;

  FTC_CMapDescRec cmap;
  unsigned int glyph;

  FTC_SBit sbit;

#ifdef FT212_STUFF
  FTC_ImageDesc *cur;
#else
  FTC_ImageTypeRec *cur;
#endif


  cmap.face_id = imgd.font.face_id;
  cmap.u.encoding = ft_encoding_unicode;
  cmap.type = FTC_CMAP_BY_ENCODING;

  total = 0;
  for (i = 0; i < c; i++)
    {
      ch = [string characterAtIndex: i];
      cur = &imgd;
      glyph = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, ch);

      /* TODO: shouldn't use sbit cache for this */
      if (1)
	{
	  if (FTC_SBitCache_Lookup(ftc_sbitcache, cur, glyph, &sbit, NULL))
	    continue;

	  total += sbit->xadvance;
	}
      else
	{
	  NSLog(@"non-sbit code not implemented");
	}
    }
  return total;
}


-(NSGlyph) glyphWithName: (NSString *)glyphName
{
  FT_Face face;
  NSGlyph g;

  if (FTC_Manager_Lookup_Size(ftc_manager, &imgd.font, &face, 0))
    return NSNullGlyph;

  g = FT_Get_Name_Index(face, (FT_String *)[glyphName lossyCString]);
  if (g)
    return g + 1;

  return NSNullGlyph;
}


/*

conic: (a,b,c)
p=(1-t)^2*a + 2*(1-t)*t*b + t^2*c

cubic: (a,b,c,d)
p=(1-t)^3*a + 3*(1-t)^2*t*b + 3*(1-t)*t^2*c + t^3*d



p(t)=(1-t)^3*a + 3*(1-t)^2*t*b + 3*(1-t)*t^2*c + t^3*d
t=m+ns=
n=l-m


q(s)=p(m+ns)=

(d-3c+3b-a)*n^3 * s^3 +
((3d-9c+9b-3a)*m+3c-6b+3a)*n^2 * s^2 +
((3d-9c+9b-3a)*m^2+(6c-12b+6a)*m+3b-3a)*n * s +
(d-3c+3b-a)*m^3+(3c-6b+3a)*m^2+(3b-3a)m+a


q(t)=(1-t)^3*aa + 3*(1-t)^2*t*bb + 3*(1-t)*t^2*cc + t^3*dd =

(dd-3cc+3bb-aa)*t^3 +
(3cc-6bb+3aa)*t^2 +
(3bb-3aa)*t +
aa


aa = (d-3*c+3*b-a)*m^3+(3*c-6*b+3*a)*m^2+(3*b-3*a)*m+a
3*bb-3*aa = ((3*d-9*c+9*b-3*a)*m^2+(6*c-12*b+6*a)*m+3*b-3*a)*n
3*cc-6*bb+3*aa = ((3*d-9*c+9*b-3*a)*m+3*c-6*b+3*a)*n^2
dd-3*cc+3*bb-aa = (d-3*c+3*b-a)*n^3


aa= (d - 3c + 3b - a) m^3  + (3c - 6b + 3a) m^2  + (3b - 3a) m + a

bb= ((d - 3c + 3b -  a) m^2  + (2c - 4b + 2a) m +  b -  a) n
  + aa

cc= ((d - 3c + 3b - a) m + c - 2b + a) n^2
 + 2*bb
 + aa

dd= (d - 3c + 3b - a) n^3
 + 3*cc
 + 3*bb
 + aa




p(t) = (1-t)^2*e + 2*(1-t)*t*f + t^2*g
 ~=
q(t) = (1-t)^3*a + 3*(1-t)^2*t*b + 3*(1-t)*t^2*c + t^3*d


p(0)=q(0) && p(1)=q(1) ->
a=e
d=g


p(0.5) = 1/8*(2a + 4f + 2d)
q(0.5) = 1/8*(a + 3*b + 3*c + d)

b+c=1/3*(a+4f+d)

p(1/4) = 1/64*
p(3/4) = 1/64*(4e+24f+36g)

q(1/4) = 1/64*
q(3/4) = 1/64*(a +  9b + 27c + 27d)

3b+c=1/3*(3a+8f+d)


3b+c=1/3*(3a+8f+d)
 b+c=1/3*(a+4f+d)

b=1/3*(e+2f)
c=1/3*(2f+g)


q(t) = (1-t)^3*e + (1-t)^2*t*(e+2f) + (1-t)*t^2*(2f+g) + t^3*g =
((1-t)^3+(1-t)^2*t)*e + (1-t)^2*t*2f + (1-t)*t^2*2f + (t^3+(1-t)*t^2)*g =

((1-t)^3+(1-t)^2*t)*e + 2f*(t*(1-t)*((1-t)+t)) + (t^3+(1-t)*t^2)*g =
((1-t)^3+(1-t)^2*t)*e + 2*(1-t)*t*f + (t^3+(1-t)*t^2)*g =
(1-t)^2*e + 2*(1-t)*t*f + t^2*g

p(t)=q(t)

*/

/* TODO: try to combine charpath and NSBezierPath handling? */

static int charpath_move_to(FT_Vector *to, void *user)
{
  GSGState *self = (GSGState *)user;
  NSPoint d;
  d.x = to->x / 65536.0;
  d.y = to->y / 65536.0;
  [self DPSclosepath]; /* TODO: this isn't completely correct */
  [self DPSmoveto: d.x:d.y];
  return 0;
}

static int charpath_line_to(FT_Vector *to, void *user)
{
  GSGState *self = (GSGState *)user;
  NSPoint d;
  d.x = to->x / 65536.0;
  d.y = to->y / 65536.0;
  [self DPSlineto: d.x:d.y];
  return 0;
}

static int charpath_conic_to(FT_Vector *c1, FT_Vector *to, void *user)
{
  GSGState *self = (GSGState *)user;
  NSPoint a, b, c, d;
  [self DPScurrentpoint: &a.x:&a.y];
  d.x = to->x / 65536.0;
  d.y = to->y / 65536.0;
  b.x = c1->x / 65536.0;
  b.y = c1->y / 65536.0;
  c.x = (b.x * 2 + d.x) / 3.0;
  c.y = (b.y * 2 + d.y) / 3.0;
  b.x = (b.x * 2 + a.x) / 3.0;
  b.y = (b.y * 2 + a.y) / 3.0;
  [self DPScurveto: b.x:b.y : c.x:c.y : d.x:d.y];
  return 0;
}

static int charpath_cubic_to(FT_Vector *c1, FT_Vector *c2, FT_Vector *to, void *user)
{
  GSGState *self = (GSGState *)user;
  NSPoint b, c, d;
  b.x = c1->x / 65536.0;
  b.y = c1->y / 65536.0;
  c.x = c2->x / 65536.0;
  c.y = c2->y / 65536.0;
  d.x = to->x / 65536.0;
  d.y = to->y / 65536.0;
  [self DPScurveto: b.x:b.y : c.x:c.y : d.x:d.y];
  return 0;
}

static FT_Outline_Funcs charpath_funcs = {
move_to:charpath_move_to,
line_to:charpath_line_to,
conic_to:charpath_conic_to,
cubic_to:charpath_cubic_to,
shift:10,
delta:0,
};


static int bezierpath_move_to(FT_Vector *to, void *user)
{
  NSBezierPath *path = (NSBezierPath *)user;
  NSPoint d;
  d.x = to->x / 65536.0;
  d.y = to->y / 65536.0;
  [path closePath]; /* TODO: this isn't completely correct */
  [path moveToPoint: d];
  return 0;
}

static int bezierpath_line_to(FT_Vector *to, void *user)
{
  NSBezierPath *path = (NSBezierPath *)user;
  NSPoint d;
  d.x = to->x / 65536.0;
  d.y = to->y / 65536.0;
  [path lineToPoint: d];
  return 0;
}

static int bezierpath_conic_to(FT_Vector *c1, FT_Vector *to, void *user)
{
  NSBezierPath *path = (NSBezierPath *)user;
  NSPoint a, b, c, d;
  a = [path currentPoint];
  d.x = to->x / 65536.0;
  d.y = to->y / 65536.0;
  b.x = c1->x / 65536.0;
  b.y = c1->y / 65536.0;
  c.x = (b.x * 2 + d.x) / 3.0;
  c.y = (b.y * 2 + d.y) / 3.0;
  b.x = (b.x * 2 + a.x) / 3.0;
  b.y = (b.y * 2 + a.y) / 3.0;
  [path curveToPoint: d controlPoint1: b controlPoint2: c];
  return 0;
}

static int bezierpath_cubic_to(FT_Vector *c1, FT_Vector *c2, FT_Vector *to, void *user)
{
  NSBezierPath *path = (NSBezierPath *)user;
  NSPoint b, c, d;
  b.x = c1->x / 65536.0;
  b.y = c1->y / 65536.0;
  c.x = c2->x / 65536.0;
  c.y = c2->y / 65536.0;
  d.x = to->x / 65536.0;
  d.y = to->y / 65536.0;
  [path curveToPoint: d controlPoint1: b controlPoint2: c];
  return 0;
}

static FT_Outline_Funcs bezierpath_funcs = {
move_to:bezierpath_move_to,
line_to:bezierpath_line_to,
conic_to:bezierpath_conic_to,
cubic_to:bezierpath_cubic_to,
shift:10,
delta:0,
};


/* TODO: sometimes gets 'glyph transformation failed', probably need to
add code to avoid loading bitmaps for glyphs */
-(void) outlineString: (const char *)s
		   at: (float)x : (float)y
	       gstate: (void *)func_param
{
  unichar *c;
  int i;
  FTC_CMapDescRec cmap;
  unsigned int glyph;

  unichar *uch;
  int ulen;

#ifdef FT212_STUFF
  FTC_ImageDesc cur;
#else
  FTC_ImageTypeRec cur;
#endif


  FT_Matrix ftmatrix;
  FT_Vector ftdelta;

  ftmatrix.xx = 65536;
  ftmatrix.xy = 0;
  ftmatrix.yx = 0;
  ftmatrix.yy = 65536;
  ftdelta.x = x * 64.0;
  ftdelta.y = y * 64.0;


  uch = NULL;
  ulen = 0;
  GSToUnicode(&uch, &ulen, s, strlen(s), NSUTF8StringEncoding, NSDefaultMallocZone(), 0);


  cur = imgd;

  cmap.face_id = imgd.font.face_id;
  cmap.u.encoding = ft_encoding_unicode;
  cmap.type = FTC_CMAP_BY_ENCODING;

  for (c = uch, i = 0; i < ulen; i++, c++)
    {
      FT_Face face;
      FT_Glyph gl;
      FT_OutlineGlyph og;

      glyph = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, *c);
      cur.font.face_id = imgd.font.face_id;

      if (FTC_Manager_Lookup_Size(ftc_manager, &cur.font, &face, 0))
	continue;
      if (FT_Load_Glyph(face, glyph, FT_LOAD_DEFAULT))
	continue;

      if (FT_Get_Glyph(face->glyph, &gl))
	continue;

      if (FT_Glyph_Transform(gl, &ftmatrix, &ftdelta))
	{
	  NSLog(@"glyph transformation failed!");
	  continue;
	}
      og = (FT_OutlineGlyph)gl;

      ftdelta.x += gl->advance.x >> 10;
      ftdelta.y += gl->advance.y >> 10;

      FT_Outline_Decompose(&og->outline, &charpath_funcs, func_param);

      FT_Done_Glyph(gl);

    }

  if (ulen)
    {
      [(GSGState *)func_param DPSmoveto: ftdelta.x / 64.0 : ftdelta.y / 64.0];
    }

  free(uch);
}


-(void) appendBezierPathWithGlyphs: (NSGlyph *)glyphs
			     count: (int)count
		      toBezierPath: (NSBezierPath *)path
{
  int i;
  NSGlyph glyph;

  FT_Matrix ftmatrix;
  FT_Vector ftdelta;

  NSPoint p = [path currentPoint];

  ftmatrix.xx = 65536;
  ftmatrix.xy = 0;
  ftmatrix.yx = 0;
  ftmatrix.yy = 65536;
  ftdelta.x = p.x * 64.0;
  ftdelta.y = p.y * 64.0;

  for (i = 0; i < count; i++, glyphs++)
    {
      FT_Face face;
      FT_Glyph gl;
      FT_OutlineGlyph og;

      glyph = *glyphs - 1;

      if (FTC_Manager_Lookup_Size(ftc_manager, &imgd.font, &face, 0))
	continue;
      if (FT_Load_Glyph(face, glyph, FT_LOAD_DEFAULT))
	continue;

      if (FT_Get_Glyph(face->glyph, &gl))
	continue;

      if (FT_Glyph_Transform(gl, &ftmatrix, &ftdelta))
	{
	  NSLog(@"glyph transformation failed!");
	  continue;
	}
      og = (FT_OutlineGlyph)gl;

      ftdelta.x += gl->advance.x >> 10;
      ftdelta.y += gl->advance.y >> 10;

      FT_Outline_Decompose(&og->outline, &bezierpath_funcs, path);

      FT_Done_Glyph(gl);
    }

  if (count)
    {
      [path moveToPoint: NSMakePoint(ftdelta.x / 64.0, ftdelta.y / 64.0)];
    }
}


static int filters[3][7]=
{
{ 0*65536/9, 1*65536/9, 2*65536/9, 3*65536/9, 2*65536/9, 1*65536/9, 0*65536/9},
{ 0*65536/9, 1*65536/9, 2*65536/9, 3*65536/9, 2*65536/9, 1*65536/9, 0*65536/9},
{ 0*65536/9, 1*65536/9, 2*65536/9, 3*65536/9, 2*65536/9, 1*65536/9, 0*65536/9}
};


+(void) initializeBackend
{
  [GSFontEnumerator setDefaultClass: [FTFontEnumerator class]];
  [GSFontInfo setDefaultClass: [FTFontInfo class]];

  if (FT_Init_FreeType(&ft_library))
    NSLog(@"FT_Init_FreeType failed");
  if (FTC_Manager_New(ft_library, 0, 0, 4096 * 24, ft_get_face, 0, &ftc_manager))
    NSLog(@"FTC_Manager_New failed");
  if (FTC_SBitCache_New(ftc_manager, &ftc_sbitcache))
    NSLog(@"FTC_SBitCache_New failed");
  if (FTC_ImageCache_New(ftc_manager, &ftc_imagecache))
    NSLog(@"FTC_ImageCache_New failed");
  if (FTC_CMapCache_New(ftc_manager, &ftc_cmapcache))
    NSLog(@"FTC_CMapCache_New failed");

  {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *s;
    NSArray *a;
    int i;

    subpixel_text = [ud integerForKey: @"back-art-subpixel-text"];

    if ([ud objectForKey: @"GSFontAntiAlias"])
      anti_alias_by_default = [ud boolForKey: @"GSFontAntiAlias"];
    else
      anti_alias_by_default = YES;

    /* To make it easier to find an optimal (or at least good) filter,
    the filters are configurable (for now). */
    for (i = 0; i < 3; i++)
      {
	s = [ud stringForKey:
	      [NSString stringWithFormat: @"back-art-subpixel-filter-%i",i]];
	if (s)
	  {
	    int j, c, sum, v;
	    a = [s componentsSeparatedByString: @" "];
	    c = [a count];
	    if (!c)
	      continue;
	    if (!(c & 1) || c > 7)
	      {
		NSLog(@"invalid number of components in filter (must be odd number, 1<=n<=7)");
		continue;
	      }
	    memset(filters[i], 0, sizeof(filters[0]));
	    sum = 0;
	    for (j = 0; j < c; j++)
	      {
		v = [[a objectAtIndex: j] intValue];
		sum += v;
		filters[i][j + (7 - c) / 2] = v * 65536;
	      }
	    if (sum)
	      {
		for (j = 0; j < 7; j++)
		  {
		    filters[i][j] /= sum;
		  }
	      }
	    NSLog(@"filter %i: %04x %04x %04x %04x %04x %04x %04x",
	          i,
		  filters[i][0],filters[i][1],filters[i][2],filters[i][3],
		  filters[i][4],filters[i][5],filters[i][6]);
	  }
      }
  }

  load_font_configuration();
}


@end


/* TODO: this whole thing needs cleaning up */
@implementation FTFontInfo_subpixel

-(void) drawGlyphs: (const NSGlyph *)glyphs : (int)length
	at: (int)x : (int)y
	to: (int)x0 : (int)y0 : (int)x1 : (int)y1
	: (unsigned char *)buf : (int)bpl
	color: (unsigned char)r : (unsigned char)g : (unsigned char)b
	: (unsigned char)alpha
	transform: (NSAffineTransform *)transform
	drawinfo: (struct draw_info_s *)di
{
  FTC_CMapDescRec cmap;
  unsigned int glyph;

  int use_sbit;

  FTC_SBit sbit;
#ifdef FT212_STUFF
  FTC_ImageDesc cur;
#else
  FTC_ImageTypeRec cur;
#endif

  FT_Matrix ftmatrix;
  FT_Vector ftdelta;

  BOOL subpixel = NO;

  if (!alpha)
    return;

  /* TODO: if we had guaranteed upper bounds on glyph image size we
     could do some basic clipping here */

  x1 -= x0;
  y1 -= y0;
  x -= x0;
  y -= y0;


/*	NSLog(@"[%@ draw using matrix: (%g %g %g %g %g %g)]\n",
		self,
		matrix[0], matrix[1], matrix[2],
		matrix[3], matrix[4], matrix[5]
		);*/

  cur = imgd;
  {
    float xx, xy, yx, yy;

    xx = matrix[0] * transform->matrix.m11 + matrix[1] * transform->matrix.m21;
    yx = matrix[0] * transform->matrix.m12 + matrix[1] * transform->matrix.m22;
    xy = matrix[2] * transform->matrix.m11 + matrix[3] * transform->matrix.m21;
    yy = matrix[2] * transform->matrix.m12 + matrix[3] * transform->matrix.m22;

    /* if we're drawing 'normal' text (unscaled, unrotated, reasonable
       size), we can and should use the sbit cache */
    if (fabs(xx - ((int)xx)) < 0.01 && fabs(yy - ((int)yy)) < 0.01 &&
	fabs(xy) < 0.01 && fabs(yx) < 0.01 &&
	xx < 72 && yy < 72 && xx > 0.5 && yy > 0.5)
      {
	use_sbit = 1;
	cur.font.pix_width = xx;
	cur.font.pix_height = yy;

/*	if (cur.font.pix_width < 16 && cur.font.pix_height < 16 &&
	    cur.font.pix_width > 6 && cur.font.pix_height > 6)
	  cur.type = ftc_image_mono;
	else*/
#ifdef FT212_STUFF
	  cur.type = ftc_image_grays, subpixel = YES, cur.font.pix_width *= 3, x *= 3;
#else
	  cur.flags = FT_LOAD_TARGET_LCD, subpixel = YES;
#endif
//			imgd.type|=|ftc_image_flag_unhinted; /* TODO? when? */
      }
    else
      {
	float f;
	use_sbit = 0;

	f = fabs(xx * yy - xy * yx);
	if (f > 1)
	  f = sqrt(f);
	else
	  f = 1.0;

	f = (int)f;

	cur.font.pix_width = cur.font.pix_height = f;
	ftmatrix.xx = xx / f * 65536.0;
	ftmatrix.xy = xy / f * 65536.0;
	ftmatrix.yx = yx / f * 65536.0;
	ftmatrix.yy = yy / f * 65536.0;
	ftdelta.x = ftdelta.y = 0;
      }
  }


/*	NSLog(@"drawString: '%s' at: %i:%i  to: %i:%i:%i:%i:%p\n",
		s, x, y, x0, y0, x1, y1, buf);*/

  cmap.face_id = imgd.font.face_id;
  cmap.u.encoding = ft_encoding_unicode;
  cmap.type = FTC_CMAP_BY_ENCODING;

  for (; length; length--, glyphs++)
    {
      glyph = *glyphs - 1;

      if (use_sbit)
	{
	  if (FTC_SBitCache_Lookup(ftc_sbitcache, &cur, glyph, &sbit, NULL))
	    continue;

	  if (!sbit->buffer)
	    {
	      x += sbit->xadvance;
	      continue;
	    }

#ifdef FT212_STUFF
	  if (sbit->format == ft_pixel_mode_grays)
#else
	  if (sbit->format == FT_PIXEL_MODE_LCD)
#endif
	    {
#ifdef FT212_STUFF
	      int gx = x + sbit->left, gy = y - sbit->top;
#else
	      int gx = 3 * x + sbit->left, gy = y - sbit->top;
#endif
	      int px0 = (gx - 2 < 0? gx - 4 : gx - 2) / 3;
	      int px1 = (gx + sbit->width + 2 < 0? gx + sbit->width + 2: gx + sbit->width + 4) / 3;
	      int llip = gx - px0 * 3;
	      int sbpl = sbit->pitch;
	      int sx = sbit->width, sy = sbit->height;
	      int psx = px1 - px0;
	      const unsigned char *src = sbit->buffer;
	      unsigned char *dst = buf;
	      unsigned char scratch[psx * 3];
	      int mode = subpixel_text == 2? 2 : 0;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (px1 > x1)
	        px1 = x1;
	      if (px0 < 0)
		{
		  px0 = -px0;
		}
	      else
		{
		  px1 -= px0;
		  dst += px0 * DI.bytes_per_pixel;
		  px0 = 0;
		}

	      if (px1 <= 0)
		{
		  x += sbit->xadvance;
		  continue;
		}

	      for (; gy < sy; gy++, src += sbpl, dst += bpl)
		{
		  int i, j;
		  int v0, v1, v2;
		  for (i = 0, j = -llip; i < psx * 3; i+=3)
		    {
		      v0 = (0 +
		       + (j >  2 && j<sx + 3? src[j - 3] * filters[0][0] : 0)
		       + (j >  1 && j<sx + 2? src[j - 2] * filters[0][1] : 0)
		       + (j >  0 && j<sx + 1? src[j - 1] * filters[0][2] : 0)
		       + (j > -1 && j<sx    ? src[j    ] * filters[0][3] : 0)
		       + (j > -2 && j<sx - 1? src[j + 1] * filters[0][4] : 0)
		       + (j > -3 && j<sx - 2? src[j + 2] * filters[0][5] : 0)
		       + (j > -4 && j<sx - 3? src[j + 3] * filters[0][6] : 0)
		) / 65536;
		      j++;
		      v1 = (0 +
		       + (j >  2 && j<sx + 3? src[j - 3] * filters[1][0] : 0)
		       + (j >  1 && j<sx + 2? src[j - 2] * filters[1][1] : 0)
		       + (j >  0 && j<sx + 1? src[j - 1] * filters[1][2] : 0)
		       + (j > -1 && j<sx    ? src[j    ] * filters[1][3] : 0)
		       + (j > -2 && j<sx - 1? src[j + 1] * filters[1][4] : 0)
		       + (j > -3 && j<sx - 2? src[j + 2] * filters[1][5] : 0)
		       + (j > -4 && j<sx - 3? src[j + 3] * filters[1][6] : 0)
		) / 65536;
		      j++;
		      v2 = (0 +
		       + (j >  2 && j<sx + 3? src[j - 3] * filters[2][0] : 0)
		       + (j >  1 && j<sx + 2? src[j - 2] * filters[2][1] : 0)
		       + (j >  0 && j<sx + 1? src[j - 1] * filters[2][2] : 0)
		       + (j > -1 && j<sx    ? src[j    ] * filters[2][3] : 0)
		       + (j > -2 && j<sx - 1? src[j + 1] * filters[2][4] : 0)
		       + (j > -3 && j<sx - 2? src[j + 2] * filters[2][5] : 0)
		       + (j > -4 && j<sx - 3? src[j + 3] * filters[2][6] : 0)
		) / 65536;
		      j++;

		      scratch[i + mode] = v0>0?v0:0;
		      scratch[i + 1] = v1>0?v1:0;
		      scratch[i + (mode ^ 2)] = v2>0?v2:0;
		    }
		  DI.render_blit_subpixel(dst,
					  scratch + px0 * 3, r, g, b, alpha,
					  px1);
		}
	    }
	  else if (sbit->format == ft_pixel_mode_mono)
	    {
	      int gx = x + sbit->left, gy = y - sbit->top;
	      int sbpl = sbit->pitch;
	      int sx = sbit->width, sy = sbit->height;
	      const unsigned char *src = sbit->buffer;
	      unsigned char *dst = buf;
	      int src_ofs = 0;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx / 8;
		  src_ofs = (-gx) & 7;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  if (alpha >= 255)
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_MONO_OPAQUE(dst, src, src_ofs, r, g, b, sx);
		  else
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_MONO(dst, src, src_ofs, r, g, b, alpha, sx);
		}
	    }
	  else
	    {
	      NSLog(@"unhandled font bitmap format %i", sbit->format);
	    }

	  x += sbit->xadvance;
	}
      else
	{
	  FT_Face face;
	  FT_Glyph gl;
	  FT_BitmapGlyph gb;

	  if (FTC_Manager_Lookup_Size(ftc_manager, &cur.font, &face, 0))
	    continue;

	  /* TODO: for rotations of 90, 180, 270, and integer
	     scales hinting might still be a good idea. */
	  if (FT_Load_Glyph(face, glyph, FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP))
	    continue;

	  if (FT_Get_Glyph(face->glyph, &gl))
	    continue;

	  if (FT_Glyph_Transform(gl, &ftmatrix, &ftdelta))
	    {
	      NSLog(@"glyph transformation failed!");
	      continue;
	    }
	  if (FT_Glyph_To_Bitmap(&gl, ft_render_mode_normal, 0, 1))
	    {
	      FT_Done_Glyph(gl);
	      continue;
	    }
	  gb = (FT_BitmapGlyph)gl;


	  if (gb->bitmap.pixel_mode == ft_pixel_mode_grays)
	    {
	      int gx = x + gb->left, gy = y - gb->top;
	      int sbpl = gb->bitmap.pitch;
	      int sx = gb->bitmap.width, sy = gb->bitmap.rows;
	      const unsigned char *src = gb->bitmap.buffer;
	      unsigned char *dst = buf;

	      if (gy < 0)
		{
		  sy += gy;
		  src -= sbpl * gy;
		  gy = 0;
		}
	      else if (gy > 0)
		{
		  dst += bpl * gy;
		}

	      sy += gy;
	      if (sy > y1)
		sy = y1;

	      if (gx < 0)
		{
		  sx += gx;
		  src -= gx;
		  gx = 0;
		}
	      else if (gx > 0)
		{
		  dst += DI.bytes_per_pixel * gx;
		}

	      sx += gx;
	      if (sx > x1)
		sx = x1;
	      sx -= gx;

	      if (sx > 0)
		{
		  if (alpha >= 255)
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA_OPAQUE(dst, src, r, g, b, sx);
		  else
		    for (; gy < sy; gy++, src += sbpl, dst += bpl)
		      RENDER_BLIT_ALPHA(dst, src, r, g, b, alpha, sx);
		}
	    }
/* TODO: will this case ever appear? */
/*			else if (gb->bitmap.pixel_mode==ft_pixel_mode_mono)*/
	  else
	    {
	      NSLog(@"unhandled font bitmap format %i", gb->bitmap.pixel_mode);
	    }

	  ftdelta.x += gl->advance.x >> 10;
	  ftdelta.y += gl->advance.y >> 10;

	  FT_Done_Glyph(gl);
	}
    }
}

@end


@interface NSFont (backend)
-(NSGlyph) glyphForCharacter: (unichar)ch;
-(NSString *) nameOfGlyph: (NSGlyph)glyph;
@end

@implementation NSFont (backend)
-(NSGlyph) glyphForCharacter: (unichar)ch
{
  FTFontInfo *fi=fontInfo;
  NSGlyph g;

  FTC_CMapDescRec cmap;

  cmap.face_id = fi->imgd.font.face_id;
  cmap.u.encoding = ft_encoding_unicode;
  cmap.type = FTC_CMAP_BY_ENCODING;

  g = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, ch);
  if (g)
    return g + 1;
  else
    return NSNullGlyph;
}

-(NSString *) nameOfGlyph: (NSGlyph)glyph
{
  FTFontInfo *fi=fontInfo;
  FT_Face face;

  char buf[256];

  glyph--;

  if (FTC_Manager_Lookup_Size(ftc_manager, &fi->imgd.font, &face, 0))
    return nil;

  if (FT_Get_Glyph_Name(face,glyph,buf,sizeof(buf)))
    return nil;

  return [NSString stringWithCString: buf]; /* TODO: really cstring? */
}
@end


/*
GSLayoutManager glyph generation code.

TODO: clean this up
*/
#include <Foundation/NSCharacterSet.h>
#include <GNUstepGUI/GSLayoutManager_internal.h>
#include <AppKit/NSTextStorage.h>
#include <AppKit/NSTextAttachment.h>

@implementation GSLayoutManager (backend)

/*
This is a fairly simple implementation. It will use "ff", "fl", "fi",
"ffl", and "ffi" ligatures if available. If a glyph for a character isn't
available, it will try to decompose it before giving up.

TODO: how should words like "pfffffffffff" be handled?

0066 'f'
0069 'i'
006c 'l'
fb00 'ff'
fb01 'fi'
fb02 'fl'
fb03 'ffi'
fb04 'ffl'
*/

-(unsigned int) _findSafeBreakMovingBackwardFrom: (unsigned int)ch
{
	NSString *str=[_textStorage string];
	while (ch>0 && [str characterAtIndex: ch-1]=='f')
		ch--;
	return ch;
}

-(unsigned int) _findSafeBreakMovingForwardFrom: (unsigned int)ch
{
	unsigned int l=[_textStorage length];
	NSString *str=[_textStorage string];
	while (ch<l && [str characterAtIndex: ch]=='f')
		ch++;
	if (ch<l && ch>0 && [str characterAtIndex: ch-1]=='f')
		ch++;
	return ch;
}

-(void) _generateGlyphsForRun: (glyph_run_t *)run  at: (unsigned int)pos
{
	glyph_t *g;
	unsigned int glyph_size;
	unsigned int i,j;
	unsigned int ch,ch2,ch3;

	FTFontInfo *fi=[run->font fontInfo];
	FTC_CMapDescRec cmap;

	NSCharacterSet *cs=[NSCharacterSet controlCharacterSet];
	IMP characterIsMember=[cs methodForSelector: @selector(characterIsMember:)];

	unsigned int c=run->head.char_length;
	unichar buf[c];


	[[_textStorage string] getCharacters: buf
		range: NSMakeRange(pos,c)];

	cmap.face_id = fi->imgd.font.face_id;
	cmap.u.encoding = ft_encoding_unicode;
	cmap.type = FTC_CMAP_BY_ENCODING;

	/* first guess */
	glyph_size=c;
	g=run->glyphs=malloc(sizeof(glyph_t)*glyph_size);
	memset(g,0,sizeof(glyph_t)*glyph_size);

	for (i=j=0;i<c;i++,g++,j++)
	{
		ch=buf[i];
		ch2=ch3=0;
		if (i+1<c)
		{
			ch2=buf[i+1];
			if (i+2<c)
				ch3=buf[i+2];
		}

		g->char_offset=i;
		if (characterIsMember(cs,@selector(characterIsMember:),ch))
		{
			g->g=NSControlGlyph;
			continue;
		}

		if (ch == NSAttachmentCharacter)
		{
			g->g=GSAttachmentGlyph;
			continue;
		}

		if (run->ligature>=1)
		{
			if (ch=='f' && ch2=='f' && ch3=='l' && fi->ligature_ffl)
			{
				g->g=fi->ligature_ffl + 1;
				i+=2;
				continue;
			}
			if (ch=='f' && ch2=='f' && ch3=='i' && fi->ligature_ffi)
			{
				g->g=fi->ligature_ffi + 1;
				i+=2;
				continue;
			}
			if (ch=='f' && ch2=='f' && fi->ligature_ff)
			{
				g->g=fi->ligature_ff + 1;
				i++;
				continue;
			}
			if (ch=='f' && ch2=='i' && fi->ligature_fi)
			{
				g->g=fi->ligature_fi + 1;
				i++;
				continue;
			}
			if (ch=='f' && ch2=='l' && fi->ligature_fl)
			{
				g->g=fi->ligature_fl + 1;
				i++;
				continue;
			}
		}

		if (ch>=0xd800 && ch<=0xdfff)
		{
			if (ch >= 0xd800 && ch < 0xdc00 && ch2 >= 0xdc00 && ch2 <= 0xdfff)
			{
				ch = ((ch & 0x3ff) << 10) + (ch2 & 0x3ff) + 0x10000;
				i++;
			}
			else
				ch = 0xfffd;
		}

		g->g=FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, ch) + 1;

		if (g->g == 1 && ch<0x10000)
		{
			unichar *decomp;
			decomp=uni_is_decomp(ch);
			if (decomp)
			{
				int c=0;
				for (;*decomp;decomp++)
				{
					glyph_size++;
					run->glyphs=realloc(run->glyphs,sizeof(glyph_t)*glyph_size);
					g=run->glyphs+j;
					memset(&run->glyphs[glyph_size-1],0,sizeof(glyph_t));

					g->g=FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, *decomp) + 1;
					if (g->g == 1)
						break;
					c++;
					g++;
					j++;
					g->char_offset=i;
				}
				if (*decomp)
				{
					g-=c;
					j-=c;
					g->g=0;
				}
				else
				{
					g--;
					j--;
				}
			}
		}
	}

	/* TODO: shrink allocated array if possible */
	run->head.glyph_length=j;
}
@end


@interface FTFontInfo (experimental_glyph_printing_extension)
-(const char *) nameOfGlyph: (NSGlyph)g;
@end

@implementation FTFontInfo (experimental_glyph_printing_extension)
-(const char *) nameOfGlyph: (NSGlyph)g
{
static char buf[1024]; /* !!TODO!! */
  FT_Face face;

  g--;
  if (FTC_Manager_Lookup_Size(ftc_manager, &imgd.font, &face, 0))
    return ".notdef";

  if (FT_Get_Glyph_Name(face, g, buf, sizeof(buf)))
    return ".notdef";

  return buf;
}
@end


