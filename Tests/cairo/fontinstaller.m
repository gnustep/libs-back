/* Coverage for the font asset installer's validation and directory lookup
 * (Source/fontconfig/FCFontAssetInstaller.m).
 *
 * -validateFontPath:error: rejects a nil path, a missing file, a file under 12
 * bytes and a file whose first bytes are not a known font signature, each with
 * its own error code, and accepts a file that starts with a TrueType or
 * OpenType signature.  The checks drive it with small synthetic files, since it
 * only reads the length and the first four bytes.  -userFontsDirectory and
 * -systemFontsDirectory return an absolute path.
 *
 * The class is private to the backend, so it is reached through NSClassFromString
 * once the backend is loaded; the test opens the window server named by the
 * environment and skips when there is none, and guards on the cairo graphics
 * backend being the one built.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>

@interface NSObject (FCFontAssetInstaller)
- (BOOL) validateFontPath: (NSString *)fontPath error: (NSError **)error;
- (NSString *) userFontsDirectory;
- (NSString *) systemFontsDirectory;
@end

static NSString *
writeTemp(NSString *name, const unsigned char *bytes, unsigned len)
{
  NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent: name];

  [[NSData dataWithBytes: bytes length: len] writeToFile: path atomically: YES];
  return path;
}

int
main(void)
{
  START_SET("fontconfig font asset installer")
  ENTER_POOL

  Class installerClass = Nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      installerClass = NSClassFromString(@"FCFontAssetInstaller");
    }
  NS_HANDLER
    {
      installerClass = Nil;
    }
  NS_ENDHANDLER

  if (installerClass == Nil)
    {
      SKIP("no fontconfig backend available")
    }
  else
    {
      id installer = [[[installerClass alloc] init] autorelease];
      NSFileManager *fm = [NSFileManager defaultManager];
      NSError *err;
      const unsigned char otf[12] = {'O','T','T','O',0,0,0,0,0,0,0,0};
      const unsigned char ttf[12] = {0x00,0x01,0x00,0x00,0,0,0,0,0,0,0,0};
      const unsigned char bad[12] = {'N','O','P','E',0,0,0,0,0,0,0,0};
      const unsigned char tiny[3] = {'a','b','c'};
      NSString *otfPath, *ttfPath, *badPath, *tinyPath, *missing;

      /* A nil path is rejected with the nil-path error. */
      err = nil;
      PASS([installer validateFontPath: nil error: &err] == NO
	&& err != nil && [err code] == -3001,
	"a nil font path is rejected")

      /* A path with no file is rejected with the missing-file error. */
      missing = [NSTemporaryDirectory()
		  stringByAppendingPathComponent: @"gs-no-such-font.ttf"];
      [fm removeItemAtPath: missing error: NULL];
      err = nil;
      PASS([installer validateFontPath: missing error: &err] == NO
	&& err != nil && [err code] == -3002,
	"a missing font file is rejected")

      /* A file under 12 bytes is rejected with the too-small error. */
      tinyPath = writeTemp(@"gs-tiny-font.ttf", tiny, 3);
      err = nil;
      PASS([installer validateFontPath: tinyPath error: &err] == NO
	&& err != nil && [err code] == -3003,
	"a font file under 12 bytes is rejected")

      /* A file with an unknown signature is rejected with the signature
       * error, and the error uses the installer's domain. */
      badPath = writeTemp(@"gs-bad-font.bin", bad, 12);
      err = nil;
      PASS([installer validateFontPath: badPath error: &err] == NO
	&& err != nil && [err code] == -3004,
	"a file with an unknown signature is rejected")
      PASS([[err domain] isEqualToString: @"FCFontAssetInstallerErrorDomain"],
	"the error uses the installer error domain")

      /* Files that start with an OpenType or TrueType signature are accepted. */
      otfPath = writeTemp(@"gs-valid.otf", otf, 12);
      PASS([installer validateFontPath: otfPath error: NULL] == YES,
	"a file with an OpenType signature is accepted")
      ttfPath = writeTemp(@"gs-valid.ttf", ttf, 12);
      PASS([installer validateFontPath: ttfPath error: NULL] == YES,
	"a file with a TrueType signature is accepted")

      /* The install directories resolve to absolute paths. */
      PASS([[installer userFontsDirectory] isAbsolutePath],
	"userFontsDirectory returns an absolute path")
      PASS([[installer systemFontsDirectory] isAbsolutePath],
	"systemFontsDirectory returns an absolute path")

      [fm removeItemAtPath: tinyPath error: NULL];
      [fm removeItemAtPath: badPath error: NULL];
      [fm removeItemAtPath: otfPath error: NULL];
      [fm removeItemAtPath: ttfPath error: NULL];
    }

  LEAVE_POOL
  END_SET("fontconfig font asset installer")
  return 0;
}

#else

int
main(void)
{
  START_SET("fontconfig font asset installer")
    SKIP("back is not built with the cairo graphics backend")
  END_SET("fontconfig font asset installer")
  return 0;
}

#endif
