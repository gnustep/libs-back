/*
   win32pbs.m

   GNUstep pasteboard server - Win32 extension

   Copyright (C) 2003 Free Software Foundation, Inc.

   Author: Fred Kiefer <fredkiefer@gmx.de>
   Date: December 2003

   This file is part of the GNUstep Project

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 3
   of the License, or (at your option) any later version.
    
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public  
   License along with this library; see the file COPYING.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

/* Access Windows 2000 (and later) API.  Required for HWND_MESSAGE.  */
#define WINVER 0x500

#include <Foundation/Foundation.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSBitmapImageRep.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSGraphics.h>

#include <windows.h>

#ifdef __CYGWIN__
#include <sys/file.h>
#endif

// The Windows SDK declares BOOL as an int.  Objective C defines BOOl as a char.
// Those two types clash.  MinGW's implementation of the Windows SDK uses the WINBOOL
// type to avoid this clash.  When compiling natively on Windows, we need to manually
// define WINBOOL.
// MinGW will define _DEF_WINBOOL_ if it has defined WINBOOL so we can use the same trick
// here.
// See https://github.com/mingw-w64/mingw-w64/blob/master/mingw-w64-headers/include/ntdef.h#L355
#ifndef _DEF_WINBOOL_
#define _DEF_WINBOOL_
typedef int WINBOOL;
#endif

@interface Win32PbOwner : NSObject
{
  NSPasteboard	*_pb;
  HINSTANCE _hinstance;
  HWND _hwnd;
  BOOL _ignore;
}

- (id) initWithOSPb: (NSPasteboard*) ospb;
- (void) clipboardHasData;
- (void) setClipboardData: (UINT)format;
- (void) grapClipboard;
- (void) setupRunLoopInputSourcesForMode: (NSString*)mode;

@end

static Win32PbOwner *wpb = nil;
static HWND hwndNextViewer = NULL;
/* The format browsers and other programs use for PNG images. */
static UINT pngFormat = 0;
/* The largest image converted, in pixels (1GB at 32 bits a pixel).  */
#define MAX_PIXELS 0x10000000
LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg,
                             WPARAM wParam, LPARAM lParam);

/* Return a copy of the data for FORMAT on the open Windows clipboard.  */
static NSData *
clipboardDataForFormat(UINT format)
{
  HGLOBAL hglb;
  NSData *data = nil;
  void *p;

  hglb = GetClipboardData(format);
  if (hglb != NULL && (p = GlobalLock(hglb)) != NULL)
    {
      data = [NSData dataWithBytes: p length: GlobalSize(hglb)];
      GlobalUnlock(hglb);
    }
  return data;
}

/* Scale the field selected by MASK in PIXEL to 0-255.  */
static unsigned char
maskedComponent(DWORD pixel, DWORD mask)
{
  DWORD max;
  int shift = 0;

  if (mask == 0)
    {
      return 0;
    }
  while ((mask & ((DWORD)1 << shift)) == 0)
    {
      shift++;
    }
  max = mask >> shift;
  return (unsigned char)((((pixel & mask) >> shift) * 255) / max);
}

/* Convert a packed DIB (the contents of a CF_DIB block) to an
   8 bit RGB(A) bitmap.  32 bit DIBs are read directly; GDI converts any
   other depth or compression.  The fourth byte of a 32 bit pixel is only
   taken as alpha when the header gives an alpha mask, and some pixel is
   not transparent: programs often leave it zero, and the DIB Windows makes
   from a bitmap can hold stray values there.  Images with alpha usually
   come with a PNG as well, which is preferred.  */
static NSBitmapImageRep *
bitmapFromDIB(NSData *dib)
{
  const BITMAPINFOHEADER *bih = [dib bytes];
  SIZE_T size = [dib length];
  DWORD masks[4] = {0x00FF0000, 0x0000FF00, 0x000000FF, 0};
  NSMutableData *converted = nil;
  NSBitmapImageRep *rep;
  const unsigned char *bits;
  unsigned char *dst;
  SIZE_T offset;
  int width, height, x, y, dstRow;
  BOOL topDown, hasAlpha = NO;

  if (size < sizeof(BITMAPINFOHEADER)
      || bih->biSize < sizeof(BITMAPINFOHEADER) || bih->biSize > size)
    {
      return nil;
    }
  width = bih->biWidth;
  height = bih->biHeight;
  topDown = (height < 0);
  if (topDown)
    {
      height = -height;
    }
  if (width <= 0 || height <= 0 || (SIZE_T)width * height > MAX_PIXELS)
    {
      return nil;
    }

  /* The pixels follow the header, any colour masks and the colour table. */
  offset = bih->biSize;
  if (bih->biCompression == BI_BITFIELDS
      && bih->biSize == sizeof(BITMAPINFOHEADER))
    {
      offset += 3 * sizeof(DWORD);
    }
  if (bih->biClrUsed != 0)
    {
      offset += bih->biClrUsed * sizeof(RGBQUAD);
    }
  else if (bih->biBitCount >= 1 && bih->biBitCount <= 8)
    {
      offset += (1 << bih->biBitCount) * sizeof(RGBQUAD);
    }
  if (offset > size)
    {
      return nil;
    }
  bits = (const unsigned char*)bih + offset;

  if (bih->biBitCount == 32
      && (bih->biCompression == BI_RGB || bih->biCompression == BI_BITFIELDS))
    {
      if (offset + (SIZE_T)width * 4 * height > size)
        {
          return nil;
        }
      if (bih->biCompression == BI_BITFIELDS)
        {
          /* The masks follow a BITMAPINFOHEADER, or are the first fields
             a larger header adds; only those carry an alpha mask.  */
          const DWORD *m = (const DWORD*)((const char*)bih
                                          + sizeof(BITMAPINFOHEADER));

          masks[0] = m[0];
          masks[1] = m[1];
          masks[2] = m[2];
          if (bih->biSize >= sizeof(BITMAPINFOHEADER) + 4 * sizeof(DWORD))
            {
              masks[3] = m[3];
            }
        }
    }
  else
    {
      BITMAPINFO bmi;
      HDC hdc;
      HBITMAP hbm;
      void *pixels = NULL;
      int lines = 0;

      if (bih->biCompression == BI_RGB || bih->biCompression == BI_BITFIELDS)
        {
          SIZE_T rowBytes = (((SIZE_T)width * bih->biBitCount + 31) / 32) * 4;

          if (offset + rowBytes * height > size)
            {
              return nil;
            }
        }
      else if (bih->biSizeImage == 0 || bih->biSizeImage > size - offset)
        {
          return nil;
        }

      memset(&bmi, 0, sizeof(bmi));
      bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
      bmi.bmiHeader.biWidth = width;
      bmi.bmiHeader.biHeight = -height;
      bmi.bmiHeader.biPlanes = 1;
      bmi.bmiHeader.biBitCount = 32;
      bmi.bmiHeader.biCompression = BI_RGB;
      hdc = CreateCompatibleDC(NULL);
      hbm = CreateDIBSection(hdc, &bmi, DIB_RGB_COLORS, &pixels, NULL, 0);
      if (hbm != NULL)
        {
          HGDIOBJ old = SelectObject(hdc, hbm);

          lines = SetDIBitsToDevice(hdc, 0, 0, width, height, 0, 0, 0, height,
                                    bits, (const BITMAPINFO*)bih,
                                    DIB_RGB_COLORS);
          GdiFlush();
          if (lines > 0)
            {
              converted = [NSMutableData
                            dataWithBytes: pixels
                                   length: (SIZE_T)width * 4 * height];
            }
          SelectObject(hdc, old);
          DeleteObject(hbm);
        }
      DeleteDC(hdc);
      if (converted == nil)
        {
          return nil;
        }
      bits = [converted bytes];
      topDown = YES;
    }

  if (masks[3] != 0)
    {
      const DWORD *p = (const DWORD*)bits;
      SIZE_T i, count = (SIZE_T)width * height;

      for (i = 0; i < count && !hasAlpha; i++)
        {
          hasAlpha = ((p[i] & masks[3]) != 0);
        }
    }

  rep = [[NSBitmapImageRep alloc]
          initWithBitmapDataPlanes: NULL
                        pixelsWide: width
                        pixelsHigh: height
                     bitsPerSample: 8
                   samplesPerPixel: (hasAlpha ? 4 : 3)
                          hasAlpha: hasAlpha
                          isPlanar: NO
                    colorSpaceName: NSDeviceRGBColorSpace
                      bitmapFormat: (hasAlpha
                                     ? NSAlphaNonpremultipliedBitmapFormat : 0)
                       bytesPerRow: 0
                      bitsPerPixel: 0];
  dst = [rep bitmapData];
  dstRow = [rep bytesPerRow];
  for (y = 0; y < height; y++)
    {
      const DWORD *src = (const DWORD*)bits
        + (SIZE_T)width * (topDown ? y : height - 1 - y);
      unsigned char *d = dst + (SIZE_T)dstRow * y;

      for (x = 0; x < width; x++)
        {
          *d++ = maskedComponent(src[x], masks[0]);
          *d++ = maskedComponent(src[x], masks[1]);
          *d++ = maskedComponent(src[x], masks[2]);
          if (hasAlpha)
            {
              *d++ = maskedComponent(src[x], masks[3]);
            }
        }
    }
  return AUTORELEASE(rep);
}

/* Convert image data GNUstep can read (TIFF, PNG ...) to a packed 32 bit
   DIB in global memory, with unpremultiplied alpha in the fourth byte.  */
static HGLOBAL
dibFromImageData(NSData *data)
{
  NSBitmapImageRep *rep;
  NSString *space;
  BITMAPINFOHEADER *bih;
  unsigned char *d;
  HGLOBAL hglb;
  NSInteger width, height, x, y, colors;
  NSUInteger max;
  BOOL alpha, alphaFirst, premultiplied, integer, rgb, white;

  rep = [NSBitmapImageRep imageRepWithData: data];
  if (rep == nil)
    {
      return NULL;
    }
  width = [rep pixelsWide];
  height = [rep pixelsHigh];
  if (width <= 0 || height <= 0 || (SIZE_T)width * height > MAX_PIXELS)
    {
      return NULL;
    }
  hglb = GlobalAlloc(GMEM_MOVEABLE,
                     sizeof(BITMAPINFOHEADER) + width * 4 * height);
  if (hglb == NULL)
    {
      return NULL;
    }

  space = [rep colorSpaceName];
  alpha = [rep hasAlpha];
  alphaFirst = ([rep bitmapFormat] & NSAlphaFirstBitmapFormat) != 0;
  premultiplied = alpha
    && ([rep bitmapFormat] & NSAlphaNonpremultipliedBitmapFormat) == 0;
  colors = [rep samplesPerPixel] - (alpha ? 1 : 0);
  /* Read integer RGB and grey samples directly, anything else as colours. */
  integer = ([rep bitsPerSample] <= 16
             && !([rep bitmapFormat] & NSFloatingPointSamplesBitmapFormat));
  max = integer ? (1 << [rep bitsPerSample]) - 1 : 1;
  rgb = (integer && colors == 3
         && ([space isEqualToString: NSDeviceRGBColorSpace]
             || [space isEqualToString: NSCalibratedRGBColorSpace]));
  white = (integer && colors == 1
           && ([space isEqualToString: NSDeviceWhiteColorSpace]
               || [space isEqualToString: NSCalibratedWhiteColorSpace]));

  bih = GlobalLock(hglb);
  memset(bih, 0, sizeof(BITMAPINFOHEADER));
  bih->biSize = sizeof(BITMAPINFOHEADER);
  bih->biWidth = width;
  bih->biHeight = height;
  bih->biPlanes = 1;
  bih->biBitCount = 32;
  bih->biCompression = BI_RGB;
  bih->biSizeImage = width * 4 * height;

  /* DIB rows run from the bottom of the image up.  */
  d = (unsigned char*)(bih + 1);
  for (y = height - 1; y >= 0; y--)
    {
      CREATE_AUTORELEASE_POOL(pool);

      for (x = 0; x < width; x++)
        {
          NSUInteger p[5];
          NSUInteger r, g, b, a;

          if (rgb || white)
            {
              NSUInteger *c;

              [rep getPixel: p atX: x y: y];
              c = (alpha && alphaFirst) ? p + 1 : p;
              a = alpha ? (alphaFirst ? p[0] : p[colors]) : max;
              r = c[0];
              g = rgb ? c[1] : c[0];
              b = rgb ? c[2] : c[0];
              if (premultiplied && a != 0 && a != max)
                {
                  r = MIN(r * max / a, max);
                  g = MIN(g * max / a, max);
                  b = MIN(b * max / a, max);
                }
              r = r * 255 / max;
              g = g * 255 / max;
              b = b * 255 / max;
              a = a * 255 / max;
            }
          else
            {
              NSColor *c;
              CGFloat fr = 0, fg = 0, fb = 0, fa = 1;

              c = [[rep colorAtX: x y: y]
                    colorUsingColorSpaceName: NSDeviceRGBColorSpace];
              [c getRed: &fr green: &fg blue: &fb alpha: &fa];
              r = (NSUInteger)(fr * 255 + 0.5);
              g = (NSUInteger)(fg * 255 + 0.5);
              b = (NSUInteger)(fb * 255 + 0.5);
              a = (NSUInteger)(fa * 255 + 0.5);
            }
          *d++ = b;
          *d++ = g;
          *d++ = r;
          *d++ = a;
        }
      [pool drain];
    }
  GlobalUnlock(hglb);
  return hglb;
}


@implementation Win32PbOwner

+ (BOOL) initializePasteboard
{
  if (self == [Win32PbOwner class])
    {
      wpb = [[Win32PbOwner alloc] initWithOSPb: 
                                    [NSPasteboard generalPasteboard]];
      [wpb clipboardHasData];
    }
  return YES;
}

+ (id) ownerByOsPb: (NSString*)p
{
  if ([p isEqual: [[NSPasteboard generalPasteboard] name]])
    {
      return wpb;
    }
  else
    {
      return nil;
    }
}

- (id) initWithOSPb: (NSPasteboard*) ospb
{
  WNDCLASSEX wc; 

  _ignore = NO;  
  _hinstance = (HINSTANCE)GetModuleHandle(NULL);
  pngFormat = RegisterClipboardFormat("PNG");

  // Register the main window class. 
  wc.cbSize = sizeof(wc);          
  //wc.style = CS_OWNDC;
  wc.style = CS_HREDRAW | CS_VREDRAW; 
  wc.lpfnWndProc = (WNDPROC) MainWndProc; 
  wc.cbClsExtra = 0; 
  wc.cbWndExtra = 0; 
  wc.hInstance = _hinstance; 
  wc.hIcon = NULL;
  wc.hCursor = NULL;
  wc.hbrBackground = NULL; 
  wc.lpszMenuName =  NULL; 
  wc.lpszClassName = "GNUstepClipboardClass"; 
  wc.hIconSm = NULL;

  if (RegisterClassEx(&wc)) 
    {
      _hwnd = CreateWindowEx(0, "GNUstepClipboardClass", "GNUstepClipboard", 
                             0, 0, 0, 10, 10, 
                             HWND_MESSAGE, (HMENU)NULL, _hinstance, NULL); 
    }

  ASSIGN(_pb, ospb);
  [self setupRunLoopInputSourcesForMode: NSDefaultRunLoopMode]; 

  return self;  
}

- (void) dealloc
{
  RELEASE(_pb);
  DestroyWindow(_hwnd);
  UnregisterClass("GNUstepClipboardClass", _hinstance);
  [super dealloc];
}

- (void) clipboardHasTypes
{
  NSMutableArray *types;
  BOOL png;

  if (_hwnd == GetClipboardOwner())
    {
      return;
    }

  types = [NSMutableArray arrayWithCapacity: 3];
  if (IsClipboardFormatAvailable(CF_UNICODETEXT))
    {
      [types addObject: NSStringPboardType];
    }
  png = (pngFormat != 0 && IsClipboardFormatAvailable(pngFormat));
  if (png || IsClipboardFormatAvailable(CF_DIBV5)
      || IsClipboardFormatAvailable(CF_DIB)
      || IsClipboardFormatAvailable(CF_BITMAP))
    {
      [types addObject: NSTIFFPboardType];
    }
  if (png)
    {
      [types addObject: NSPasteboardTypePNG];
    }
  if ([types count] > 0)
    {
      [_pb declareTypes: types owner: self];
    }
}

/* 
   The owner of the Windows clipboard did change. Check if this 
   results in some action for us.
 */
- (void) clipboardHasData
{
  if (!_ignore)
    {
      _ignore = YES;
      [self clipboardHasTypes];
      _ignore = NO;
    }
}

- (void) setClipboardString
{
  HGLOBAL hglb; 
  LPWSTR lpwstr; 
  NSString *s;
  unsigned int len;

  s = [_pb stringForType: NSStringPboardType];
  if (s == nil)
    {
      return;
    }

  len = [s length];
  hglb = GlobalAlloc(GMEM_MOVEABLE, (len + 1) * sizeof(WCHAR)); 
  if (hglb == NULL) 
    { 
      return; 
    } 
  
  // Lock the handle and copy the text to the buffer. 
  lpwstr = GlobalLock(hglb); 
  [s getCharacters: lpwstr];
  lpwstr[len] = (WCHAR)0;
  GlobalUnlock(hglb); 
  SetClipboardData(CF_UNICODETEXT, hglb);
}

/* Render the pasteboard's image as FORMAT, which is CF_DIB or PNG.  */
- (void) setClipboardImage: (UINT)format
{
  NSArray *types = [_pb types];
  NSData *data = nil;
  HGLOBAL hglb = NULL;

  if (format == pngFormat && [types containsObject: NSPasteboardTypePNG])
    {
      data = [_pb dataForType: NSPasteboardTypePNG];
    }
  if (data == nil && [types containsObject: NSTIFFPboardType])
    {
      data = [_pb dataForType: NSTIFFPboardType];
    }
  if (data == nil && [types containsObject: NSPasteboardTypePNG])
    {
      data = [_pb dataForType: NSPasteboardTypePNG];
    }
  if (data == nil)
    {
      return;
    }

  if (format == CF_DIB)
    {
      hglb = dibFromImageData(data);
    }
  else
    {
      if ([data length] < 4 || memcmp([data bytes], "\x89PNG", 4) != 0)
        {
          data = [[NSBitmapImageRep imageRepWithData: data]
                   representationUsingType: NSPNGFileType
                                properties: nil];
        }
      if ([data length] > 0
          && (hglb = GlobalAlloc(GMEM_MOVEABLE, [data length])) != NULL)
        {
          memcpy(GlobalLock(hglb), [data bytes], [data length]);
          GlobalUnlock(hglb);
        }
    }
  if (hglb != NULL)
    {
      SetClipboardData(format, hglb);
    }
}

/* 
   Data is requested from the Windows clipboard. We are already the 
   owner of the clipboard.
 */
- (void) setClipboardData: (UINT)format
{
  if (!_ignore)
    {
      _ignore = YES;  
      if (format == CF_UNICODETEXT)
        {
          [self setClipboardString];
        }
      else if (format == CF_DIB || (format == pngFormat && pngFormat != 0))
        {
          [self setClipboardImage: format];
        }
      _ignore = NO;;  
    }
}

/* 
   Take over the ownership of the Windows clipboard, but don't provide data 
 */
- (void) grapClipboard
{
  NSArray *types = [_pb types];

  if (!OpenClipboard(_hwnd)) 
     {
       NSLog(@"Failed to get the Win32 clipboard. %d", GetLastError());
       return; 
     }
  if (!EmptyClipboard())
    {
      NSLog(@"Failed to get the Win32 clipboard. %d", GetLastError());
      CloseClipboard();
      return;
    }
  if ([types containsObject: NSStringPboardType])
    {
      SetClipboardData(CF_UNICODETEXT, NULL);
    }
  if ([types containsObject: NSTIFFPboardType]
      || [types containsObject: NSPasteboardTypePNG])
    {
      SetClipboardData(CF_DIB, NULL);
      if (pngFormat != 0)
        {
          SetClipboardData(pngFormat, NULL);
        }
    }

  CloseClipboard();
}

/*
 * If this gets called, a GNUstep object has grabbed the pasteboard
 * or has changed the types of data available from the pasteboard
 * so we must tell the Windows system, that we have the current selection.
 */
- (void) pasteboardChangedOwner: (NSPasteboard*)sender
{
  if (!_ignore)
    {
      _ignore = YES;  
      [self grapClipboard];
      _ignore = NO;;  
    }
}

- (void) provideStringTo: (NSPasteboard*)pb
{
  HGLOBAL hglb; 
 
  if (!IsClipboardFormatAvailable(CF_UNICODETEXT) || 
      !OpenClipboard(_hwnd)) 
    {
      return; 
    }
  
  hglb = GetClipboardData(CF_UNICODETEXT); 
  if (hglb != NULL) 
    { 
      LPWSTR lpwstr; 
      
      lpwstr = GlobalLock(hglb); 
      if (lpwstr != NULL) 
        {
          unsigned int len;
          NSString *s;
          
          len = lstrlenW(lpwstr);
          s = [NSString stringWithCharacters: lpwstr 
                        length: len]; 
          [pb setString: s forType: NSStringPboardType];
          GlobalUnlock(hglb); 
        } 
    } 
  CloseClipboard(); 
}

/* Provide the clipboard's image as TYPE, which is TIFF or PNG.  A PNG on
   the clipboard is passed on as is, or converted to TIFF; otherwise
   the DIB (which Windows makes from a bitmap if need be) is converted.  */
- (void) provideImageTo: (NSPasteboard*)pb type: (NSString*)type
{
  NSData *png = nil;
  NSData *dib = nil;
  NSData *data = nil;

  if (!OpenClipboard(_hwnd))
    {
      return;
    }
  if (pngFormat != 0 && IsClipboardFormatAvailable(pngFormat))
    {
      png = clipboardDataForFormat(pngFormat);
    }
  /* CF_DIB rather than CF_DIBV5: the CF_DIBV5 Windows synthesizes can
     carry colour masks after its header, so where its pixels start
     is ambiguous.  A 32 bit CF_DIB still holds any alpha.  */
  if (png == nil && [type isEqual: NSTIFFPboardType]
      && IsClipboardFormatAvailable(CF_DIB))
    {
      dib = clipboardDataForFormat(CF_DIB);
    }
  CloseClipboard();

  if ([type isEqual: NSPasteboardTypePNG])
    {
      data = png;
    }
  else if (png != nil)
    {
      data = [[NSBitmapImageRep imageRepWithData: png] TIFFRepresentation];
    }
  else if (dib != nil)
    {
      data = [bitmapFromDIB(dib) TIFFRepresentation];
    }
  if (data != nil)
    {
      [pb setData: data forType: type];
    }
}

- (void) pasteboard: (NSPasteboard*)pb provideDataForType: (NSString*)type
{
  if (!_ignore)
    {
      if ([type isEqual: NSStringPboardType])
        {
          _ignore = YES;  
          [self provideStringTo: pb];
          _ignore = NO;;  
        }
      else if ([type isEqual: NSTIFFPboardType]
               || [type isEqual: NSPasteboardTypePNG])
        {
          _ignore = YES;
          [self provideImageTo: pb type: type];
          _ignore = NO;
        }
    }
}

- (void) callback: (id) sender
{
  MSG msg;
  WINBOOL bRet; 

  while ((bRet = PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) != 0)
    { 

      if (msg.message == WM_QUIT)
        {
          // Exit the program
          return;
        }
      if (bRet == -1)
        {
          // handle the error and possibly exit
        }
      else
        {
          // Don't translate messages, as this would give extra character messages.
          DispatchMessage(&msg); 
        } 
    } 
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
#ifdef    __CYGWIN__
  if (type == ET_RDESC)
#else 
  if (type == ET_WINMSG)
#endif
    {
      MSG *m = (MSG*)extra;

      if (m->message == WM_QUIT)
        {
          //[NSApp terminate: nil];
          // Exit the program
          return;
        }
      else
        {
          DispatchMessage(m); 
        } 
    } 
  if (mode != nil)
    [self callback: mode];
}

- (void) setupRunLoopInputSourcesForMode: (NSString*)mode
{
  NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];

#ifdef    __CYGWIN__
  int fdMessageQueue;
#define WIN_MSG_QUEUE_FNAME    "/dev/windows"

  // Open a file descriptor for the windows message queue
  fdMessageQueue = open (WIN_MSG_QUEUE_FNAME, O_RDONLY);
  if (fdMessageQueue == -1)
    {
      NSLog(@"Failed opening %s\n", WIN_MSG_QUEUE_FNAME);
      exit(1);
    }
  [currentRunLoop addEvent: (void*)fdMessageQueue
                  type: ET_RDESC
                  watcher: (id<RunLoopEvents>)self
                  forMode: mode];
#else 
  [currentRunLoop addEvent: (void*)0
                  type: ET_WINMSG
                  watcher: (id<RunLoopEvents>)self
                  forMode: mode];
#endif
}

@end

LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg, 
                             WPARAM wParam, LPARAM lParam) 
{ 
  switch (uMsg) 
    { 
    case WM_CREATE: 
      // Add the window to the clipboard viewer chain. 
      hwndNextViewer = SetClipboardViewer(hwnd); 
      break;
      
    case WM_CHANGECBCHAIN: 
      // If the next window is closing, repair the chain. 
      if ((HWND) wParam == hwndNextViewer) 
        hwndNextViewer = (HWND) lParam; 
      // Otherwise, pass the message to the next link. 
      else if (hwndNextViewer != NULL) 
        SendMessage(hwndNextViewer, uMsg, wParam, lParam); 
      break;

    case WM_DESTROY: 
      ChangeClipboardChain(hwnd, hwndNextViewer); 
      PostQuitMessage(0); 
      break;

    case WM_DRAWCLIPBOARD:
      // clipboard contents changed. 
      if (wpb != nil)
        [wpb clipboardHasData];

      // Pass the message to the next window in clipboard 
      // viewer chain. 
      if (hwndNextViewer != NULL) 
        SendMessage(hwndNextViewer, uMsg, wParam, lParam); 
      break; 

    case WM_RENDERFORMAT: 
      [wpb setClipboardData: (UINT)wParam];
      break; 
 
    case WM_RENDERALLFORMATS:
      if (!OpenClipboard(hwnd))
	{
	  NSWarnMLog(@"Failed to get the Win32 clipboard. %d", GetLastError());
	}
      else if (GetClipboardOwner() == hwnd)
	{
	  if (!EmptyClipboard())
	    {
	      NSWarnMLog(@"Failed to get the Win32 clipboard. %d", GetLastError());
	    }
	  else
	    {
	      SendMessage(hwnd, WM_RENDERFORMAT, CF_UNICODETEXT, 0);
	      SendMessage(hwnd, WM_RENDERFORMAT, CF_DIB, 0);
	      if (pngFormat != 0)
		{
		  SendMessage(hwnd, WM_RENDERFORMAT, pngFormat, 0);
		}
	      CloseClipboard();
	    }
	}
      break;
      
    default:
      return DefWindowProc(hwnd, uMsg, wParam, lParam);
    } 

  return (LRESULT) NULL; 
}

