#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

int main (int argc, const char * argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Create a small pattern image and make a pattern color (non-RGB)
    NSImage *pat = [[NSImage alloc] initWithSize:NSMakeSize(4,4)];
    [pat lockFocus];
    [[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0] setFill];
    NSRectFill(NSMakeRect(0,0,4,4));
    [pat unlockFocus];

    NSColor *pattern = [NSColor colorWithPatternImage:pat];

    NSGradient *g = [[NSGradient alloc] initWithStartingColor:pattern endingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];

    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(100,100)];
    @try {
        [img lockFocus];
        [g drawInRect:NSMakeRect(0,0,100,100) angle:90.0];
        [img unlockFocus];
        NSLog(@"OK: gradient drawn without exception");
    } @catch (NSException *ex) {
        NSLog(@"FAIL: exception: %@", ex);
        return 1;
    }

    [pool drain];
    return 0;
}
