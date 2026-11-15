/* Tests for the Windows clipboard bridge in gpbs (Tools/win32pbs.m).
 *
 * Text and images must pass both ways between the Windows clipboard and the
 * GNUstep general pasteboard:
 *  - a DIB on the Windows clipboard is offered as NSTIFFPboardType, keeps
 *    its size, orientation and colours;
 *  - a "PNG" on the Windows clipboard is offered as NSPasteboardTypePNG
 *    (passed through unchanged) and as NSTIFFPboardType;
 *  - a TIFF on the general pasteboard is published as CF_DIB (a 32 bit
 *    bottom-up DIB carrying alpha) and as "PNG";
 *  - CF_UNICODETEXT and NSStringPboardType still pass both ways.
 * These guard against images being dropped, flipped, shifted or losing
 * their alpha, and against the image formats disturbing text.
 *
 * The test talks to whichever gpbs serves the general pasteboard (it is
 * started on demand, so normally the installed one), and it replaces the
 * contents of the Windows clipboard.  It guards on the win32 display server
 * being built and skips cleanly otherwise.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_win32) \
  && BUILD_SERVER == SERVER_win32

#import <AppKit/AppKit.h>
#include <windows.h>
#include <stdlib.h>

/* Other programs (gpbs among them) hold the clipboard open briefly, so
   retry for a while rather than fail on the first refusal.  */
static BOOL
openClipboard(HWND window)
{
  int i;

  for (i = 0; i < 20; i++)
    {
      if (OpenClipboard(window))
	{
	  return YES;
	}
      Sleep(50);
    }
  return NO;
}

/* Replace the Windows clipboard with LEN bytes of FORMAT.  The clipboard
   owner is a window destroyed straight after, as this thread does not
   answer the messages Windows sends the owner when gpbs takes over.  */
static BOOL
putOnClipboard(UINT format, const void *bytes, size_t len)
{
  HGLOBAL hglb = GlobalAlloc(GMEM_MOVEABLE, len);
  HWND window;
  BOOL ok = NO;

  if (hglb == NULL)
    {
      return NO;
    }
  memcpy(GlobalLock(hglb), bytes, len);
  GlobalUnlock(hglb);
  window = CreateWindowEx(0, "STATIC", "pasteboard test", 0, 0, 0, 0, 0,
			  HWND_MESSAGE, NULL, GetModuleHandle(NULL), NULL);
  if (window != NULL && openClipboard(window))
    {
      if (EmptyClipboard() && SetClipboardData(format, hglb) != NULL)
	{
	  ok = YES;
	}
      CloseClipboard();
    }
  if (window != NULL)
    {
      DestroyWindow(window);
    }
  if (!ok)
    {
      GlobalFree(hglb);
    }
  return ok;
}

/* Copy the data for FORMAT from the Windows clipboard.  */
static NSData *
getFromClipboard(UINT format)
{
  NSData *data = nil;

  if (openClipboard(NULL))
    {
      HGLOBAL hglb = GetClipboardData(format);
      void *p;

      if (hglb != NULL && (p = GlobalLock(hglb)) != NULL)
	{
	  data = [NSData dataWithBytes: p length: GlobalSize(hglb)];
	  GlobalUnlock(hglb);
	}
      CloseClipboard();
    }
  return data;
}

/* gpbs follows the Windows clipboard asynchronously; give it a moment.  */
static BOOL
waitForType(NSPasteboard *pb, NSString *type)
{
  int i;

  for (i = 0; i < 50; i++)
    {
      if ([[pb types] containsObject: type])
	{
	  return YES;
	}
      [NSThread sleepForTimeInterval: 0.1];
    }
  return NO;
}

static BOOL
waitForFormat(UINT format)
{
  int i;

  for (i = 0; i < 50; i++)
    {
      if (IsClipboardFormatAvailable(format))
	{
	  return YES;
	}
      [NSThread sleepForTimeInterval: 0.1];
    }
  return NO;
}

static BOOL
pixelIs(NSBitmapImageRep *rep, int x, int y, int r, int g, int b, int a)
{
  NSUInteger px[5] = {0, 0, 0, 255, 0};

  [rep getPixel: px atX: x y: y];
  if (![rep hasAlpha])
    {
      px[3] = 255;
    }
  return abs((int)px[0] - r) <= 2 && abs((int)px[1] - g) <= 2
    && abs((int)px[2] - b) <= 2 && abs((int)px[3] - a) <= 2;
}

/* A 4x4 RGBA image: the top half red, the bottom-left quarter green and
   the bottom-right quarter blue at half alpha.  */
static NSBitmapImageRep *
testImage(void)
{
  NSBitmapImageRep *rep;
  unsigned char *d;
  int x, y;

  rep = [[NSBitmapImageRep alloc]
	  initWithBitmapDataPlanes: NULL pixelsWide: 4 pixelsHigh: 4
		     bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES
			  isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace
		      bitmapFormat: NSAlphaNonpremultipliedBitmapFormat
		       bytesPerRow: 16 bitsPerPixel: 32];
  d = [rep bitmapData];
  for (y = 0; y < 4; y++)
    {
      for (x = 0; x < 4; x++, d += 4)
	{
	  d[0] = (y < 2) ? 255 : 0;
	  d[1] = (y >= 2 && x < 2) ? 255 : 0;
	  d[2] = (y >= 2 && x >= 2) ? 255 : 0;
	  d[3] = (y >= 2 && x >= 2) ? 128 : 255;
	}
    }
  return [rep autorelease];
}

int
main(void)
{
  START_SET("win32 clipboard bridge")

  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  UINT pngFormat = RegisterClipboardFormat("PNG");

  /* Windows to GNUstep: a 4x4 24 bit bottom-up DIB, top half red and
     bottom half green.  */
  {
    unsigned char dib[sizeof(BITMAPINFOHEADER) + 4 * 12];
    BITMAPINFOHEADER *bih = (BITMAPINFOHEADER*)dib;
    unsigned char *p = dib + sizeof(BITMAPINFOHEADER);
    NSBitmapImageRep *rep;
    int i;

    memset(dib, 0, sizeof(dib));
    bih->biSize = sizeof(BITMAPINFOHEADER);
    bih->biWidth = 4;
    bih->biHeight = 4;
    bih->biPlanes = 1;
    bih->biBitCount = 24;
    bih->biCompression = BI_RGB;
    for (i = 0; i < 16; i++, p += 3)
      {
	/* The first two rows in memory are the bottom of the image.  */
	p[1] = (i < 8) ? 255 : 0;
	p[2] = (i < 8) ? 0 : 255;
      }
    PASS(putOnClipboard(CF_DIB, dib, sizeof(dib)),
	 "a DIB can be put on the Windows clipboard")
    PASS(waitForType(pb, NSTIFFPboardType),
	 "a DIB on the Windows clipboard is offered as TIFF")
    rep = [NSBitmapImageRep imageRepWithData:
			      [pb dataForType: NSTIFFPboardType]];
    PASS(rep != nil && [rep pixelsWide] == 4 && [rep pixelsHigh] == 4,
	 "the TIFF made from a DIB has the DIB's size")
    PASS(pixelIs(rep, 0, 0, 255, 0, 0, 255)
	 && pixelIs(rep, 3, 1, 255, 0, 0, 255)
	 && pixelIs(rep, 0, 2, 0, 255, 0, 255)
	 && pixelIs(rep, 3, 3, 0, 255, 0, 255),
	 "the TIFF made from a DIB keeps its orientation and colours")
  }

  /* Windows to GNUstep: a PNG passes through and converts to TIFF.  */
  {
    NSData *png = [testImage() representationUsingType: NSPNGFileType
					     properties: nil];
    NSBitmapImageRep *rep;

    PASS(png != nil && putOnClipboard(pngFormat, [png bytes], [png length]),
	 "a PNG can be put on the Windows clipboard")
    PASS(waitForType(pb, NSPasteboardTypePNG)
	 && [[pb types] containsObject: NSTIFFPboardType],
	 "a PNG on the Windows clipboard is offered as PNG and TIFF")
    PASS_EQUAL([pb dataForType: NSPasteboardTypePNG], png,
	       "the PNG is passed on unchanged")
    rep = [NSBitmapImageRep imageRepWithData:
			      [pb dataForType: NSTIFFPboardType]];
    PASS(rep != nil && pixelIs(rep, 0, 0, 255, 0, 0, 255)
	 && pixelIs(rep, 3, 3, 0, 0, 255, 128),
	 "the TIFF made from a PNG keeps its colours and alpha")
  }

  /* GNUstep to Windows: a TIFF is published as CF_DIB and PNG.  */
  {
    NSData *dib;
    NSBitmapImageRep *rep;
    const BITMAPINFOHEADER *bih;
    const unsigned char *bits;

    [pb declareTypes: [NSArray arrayWithObject: NSTIFFPboardType] owner: nil];
    [pb setData: [testImage() TIFFRepresentation] forType: NSTIFFPboardType];
    PASS(waitForFormat(CF_DIB) && IsClipboardFormatAvailable(pngFormat)
	 && !IsClipboardFormatAvailable(CF_UNICODETEXT),
	 "a TIFF on the pasteboard is published as CF_DIB and PNG only")
    dib = getFromClipboard(CF_DIB);
    bih = [dib bytes];
    PASS([dib length] >= sizeof(BITMAPINFOHEADER) + 64
	 && bih->biWidth == 4 && bih->biHeight == 4
	 && bih->biBitCount == 32 && bih->biCompression == BI_RGB,
	 "the CF_DIB is a 4x4 32 bit bottom-up DIB")
    /* Pixels are BGRA; the first row in memory is the bottom one.  */
    bits = (const unsigned char*)(bih + 1);
    PASS([dib length] >= sizeof(BITMAPINFOHEADER) + 64
	 && bits[0] == 0 && bits[1] == 255 && bits[2] == 0 && bits[3] == 255
	 && bits[12] == 255 && bits[13] == 0 && bits[14] == 0
	 && bits[15] == 128
	 && bits[48] == 0 && bits[49] == 0 && bits[50] == 255
	 && bits[51] == 255,
	 "the CF_DIB keeps the orientation, colours and alpha")
    rep = [NSBitmapImageRep imageRepWithData: getFromClipboard(pngFormat)];
    PASS(rep != nil && [rep pixelsWide] == 4
	 && pixelIs(rep, 3, 3, 0, 0, 255, 128),
	 "the PNG published for a TIFF holds the image")
  }

  /* Text still passes both ways.  */
  {
    const WCHAR text[] = {'W', 'i', 'n', ' ', 0xE9, 0x2713, 0};
    const WCHAR back[] = {'G', 'N', 'U', 's', 't', 'e', 'p', ' ', 0xFC, 0};
    NSString *expected = [NSString stringWithCharacters: text length: 6];
    NSData *data;

    PASS(putOnClipboard(CF_UNICODETEXT, text, sizeof(text))
	 && waitForType(pb, NSStringPboardType)
	 && ![[pb types] containsObject: NSTIFFPboardType],
	 "text on the Windows clipboard is offered as a string only")
    PASS_EQUAL([pb stringForType: NSStringPboardType], expected,
	       "the string matches the Windows text")

    [pb declareTypes: [NSArray arrayWithObject: NSStringPboardType]
	       owner: nil];
    [pb setString: [NSString stringWithCharacters: back length: 9]
	   forType: NSStringPboardType];
    PASS(waitForFormat(CF_UNICODETEXT) && !IsClipboardFormatAvailable(CF_DIB),
	 "a string on the pasteboard is published as text only")
    data = getFromClipboard(CF_UNICODETEXT);
    PASS(data != nil && [data length] >= sizeof(back)
	 && memcmp([data bytes], back, sizeof(back)) == 0,
	 "the Windows text matches the string")
  }

  END_SET("win32 clipboard bridge")
  return 0;
}

#else

int
main(void)
{
  START_SET("win32 clipboard bridge")
    SKIP("back is not built with the win32 display server")
  END_SET("win32 clipboard bridge")
  return 0;
}

#endif
