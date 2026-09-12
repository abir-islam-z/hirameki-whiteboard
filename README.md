# Hirameki Whiteboard

A standalone, local, multi-page vector whiteboard with native PDF annotation for macOS.

## Features
- **tldraw-Style Multi-Page System**: Infinite vector canvas with page switcher dropdown, page reordering, duplication, and renaming.
- **Native Selectable PDF Support**: Embed multipage PDF documents with Apple `PDFKit`, copyable text selection (`⌘C`), and pagination controls (`‹`, `›`).
- **Vector Annotations & Tools**: Pen, Highlighter, Laser Pointer, Object Eraser, Text Boxes, Sticky Notes, and geometric vector shapes (Rectangles, Circles, Arrows, Lines, Diamonds, Stars).
- **High-Quality PDF Export**: Vector-quality export combining background embedded PDFs with overlay annotations and drawings.
- **Native macOS Experience**: Keyboard shortcuts, spacebar panning, smooth trackpad gestures, and transparent floating controls.

## Building & Running
```bash
# Debug build
swift build

# Release app bundle
./scripts/build_app.sh
```

## License
MIT
