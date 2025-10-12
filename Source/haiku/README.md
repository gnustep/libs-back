# GNUstep Haiku Backend

This is the beginning of a Haiku backend for GNUstep's graphics backend library (libs-back).

## Status

This is a very early implementation that provides:

- Basic backend structure and class hierarchy
- Haiku server initialization framework  
- Font enumeration stub (uses hardcoded common fonts for now)
- Graphics context and state management stubs
- Window management stubs

## TODO

The following major components need to be implemented:

### Core Haiku Integration

- [ ] BApplication initialization and event loop integration
- [ ] BWindow creation and management
- [ ] BView integration for drawing contexts
- [ ] Event handling (mouse, keyboard, window events)
- [ ] Screen and display configuration queries

### Drawing Implementation  

- [ ] Implement all drawing operations in HaikuContext using Haiku's BView drawing API
- [ ] Path construction and rendering
- [ ] Color management and conversion
- [ ] Clipping and transformations
- [ ] Image/bitmap rendering

### Font System

- [ ] Complete font enumeration using Haiku's font APIs (count_font_families, get_font_family, etc.)
- [ ] Font metrics calculation using BFont
- [ ] Text rendering and measurement
- [ ] Font caching and management

### Window System

- [ ] Window creation, resizing, and destruction
- [ ] Window decorations and title bar management
- [ ] Window positioning and stacking
- [ ] Full-screen support
- [ ] Multi-monitor support

### Advanced Features

- [ ] Drag and drop integration with Haiku's system
- [ ] Clipboard integration
- [ ] System integration (beep, cursors, etc.)
- [ ] OpenGL context support (if needed)

## Building

To configure and build with the Haiku backend:

```bash
./configure --enable-server=haiku --enable-graphics=cairo
make
make install
```

## Requirements

- Haiku R1 or later
- GNUstep base and gui libraries built for Haiku
- Cairo graphics library (for the graphics backend)

## Architecture

The Haiku backend follows the same pattern as other GNUstep backends:

- `HaikuServer`: Main display server class, manages screens and windows
- `HaikuContext`: Graphics context for drawing operations  
- `HaikuGState`: Graphics state management
- `HaikuFontInfo`: Font information and metrics
- `HaikuFontEnumerator`: System font discovery
- `HaikuFaceInfo`: Detailed font face information

Each class inherits from the corresponding GSC (GNUstep Core) base class and provides Haiku-specific implementations.

## Contributing

This backend is in very early development. Contributors familiar with both GNUstep architecture and Haiku's API are welcome to help implement the missing functionality.

Key areas where help is needed:

- Haiku API expertise for proper system integration
- Event handling and window management
- Font system implementation  
- Drawing operations using Haiku's graphics APIs
