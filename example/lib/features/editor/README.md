# Video Editor with Time-Based Overlay Synchronization

## 🎯 What This Does

Allows you to add visual overlays (text, arrows, graphics, emojis) to videos at specific timestamps. **If you add an arrow at 2 seconds, it will only appear at 2 seconds - not at 3 seconds.**

## 📁 Files Overview

### Core Components

| File | Purpose |
|------|---------|
| `timed_layer_model.dart` | Data model for timed overlays |
| `timed_layer_manager.dart` | Manages overlay lifecycle and visibility |
| `timed_overlay_widget.dart` | Renders overlays on top of video |
| `layer_controls_widget.dart` | UI controls for adding/editing overlays |

### Examples

| File | Purpose |
|------|---------|
| `video_editor_with_timed_overlays_page.dart` | Complete working example |
| `video_editor_grounded_example_page.dart` | Original editor (no overlays) |
| `video_editor_basic_example_page.dart` | Basic editor (no overlays) |

### Documentation

| File | Purpose |
|------|---------|
| `README.md` | This file - Quick overview |
| `QUICK_START.md` | 5-minute integration guide |
| `TIMED_OVERLAYS_README.md` | Complete documentation |
| `INTEGRATION_EXAMPLE.md` | Step-by-step integration |

## 🚀 Quick Start (3 Steps)

### 1. Add Layer Manager

```dart
final _layerManager = TimedLayerManager();
```

### 2. Update Position

```dart
_videoController.addListener(() {
  _layerManager.setCurrentTime(_videoController.value.position);
});
```

### 3. Add Overlay Widget

```dart
Stack(
  children: [
    ProImageEditor.video(...),  // Your editor
    TimedOverlayWidget(layerManager: _layerManager, ...),  // Overlays
  ],
)
```

**Done!** See `QUICK_START.md` for details.

## 💡 Usage Example

```dart
// Add arrow at current timestamp (shows for 1 second)
final currentMs = _videoController.value.position.inMilliseconds;

_layerManager.addLayer(
  TimedLayer(
    id: 'arrow_1',
    type: TimedLayerType.arrow,
    startMs: currentMs,     // Appears at current time
    endMs: currentMs + 1000, // Disappears 1 second later
    content: 'arrow',
    position: Offset(0.3, -0.2),
    color: Colors.red,
  ),
);
```

## 🎬 Demo

The complete example (`video_editor_with_timed_overlays_page.dart`) includes:

- **Arrow** - appears at 2-3 seconds
- **Text** - appears from 1-4 seconds  
- **Emoji** - appears at 5-7 seconds

Run the example and scrub the timeline to see overlays appear/disappear precisely!

## 📖 Learn More

- **New to this?** → Start with `QUICK_START.md`
- **Integrating to existing editor?** → Read `INTEGRATION_EXAMPLE.md`
- **Need full details?** → Check `TIMED_OVERLAYS_README.md`
- **Want complete example?** → Open `video_editor_with_timed_overlays_page.dart`

## 🎨 Layer Types Supported

| Type | Description | Example Use |
|------|-------------|-------------|
| `text` | Custom text overlays | Captions, labels, titles |
| `arrow` | Directional pointers | Point to objects, indicate direction |
| `emoji` | Large emoji reactions | Celebrations, reactions |
| `sticker` | Image overlays | Logos, icons, graphics |
| `drawing` | Custom paths | Circles, underlines, highlights |
| `shape` | Geometric shapes | Boxes, borders, frames |

## ⚡ Key Features

✅ **Millisecond-accurate timing** - Precise control over when overlays appear  
✅ **Real-time preview** - See overlays while editing  
✅ **Export integration** - Overlays included in final video  
✅ **Interactive editing** - Add/edit/delete overlays easily  
✅ **Multiple layer types** - Text, arrows, emojis, and more  
✅ **Flexible positioning** - Place overlays anywhere on screen  
✅ **Full customization** - Colors, sizes, rotations, opacity  

## 🔧 Advanced Features

### Interactive Controls

Use `LayerControlsWidget` for a complete UI:

```dart
LayerControlsWidget(
  layerManager: _layerManager,
  videoController: _videoController,
)
```

Provides:
- One-click buttons to add layers
- List of all layers with timing info
- Edit/delete functionality
- Visual time sliders

### Custom Layer Types

Extend `TimedLayerType` and add rendering logic:

```dart
enum TimedLayerType {
  text, arrow, emoji, sticker, drawing, shape,
  myCustomType,  // Your custom type
}

// Add rendering in TimedOverlayWidget
Widget _buildLayerContent(TimedLayer layer) {
  switch (layer.type) {
    case TimedLayerType.myCustomType:
      return MyCustomWidget(layer);
    // ...
  }
}
```

### Animation Support

Add transitions by interpolating properties:

```dart
final progress = (currentMs - layer.startMs) / 
                 (layer.endMs - layer.startMs);

return Opacity(
  opacity: progress,  // Fade in
  child: Transform.scale(
    scale: 0.5 + (0.5 * progress),  // Scale up
    child: layerWidget,
  ),
);
```

## 🎯 Position System

Positions use normalized coordinates (-1.0 to 1.0):

```
Top Left (-1,-1)     Center (0,0)      Top Right (1,-1)
        ↓                 ↓                    ↓
        
        
        
Bottom Left (-1,1)   Bottom (0,1)      Bottom Right (1,1)
```

**Examples:**
- `Offset(0, 0)` → Center
- `Offset(0, -0.5)` → Top center
- `Offset(0.5, 0.5)` → Bottom right quadrant

## 🐛 Troubleshooting

**Overlays not showing?**
- ✅ Check `_layerManager.setCurrentTime()` is called in video listener
- ✅ Verify timing: `startMs` < `currentMs` < `endMs`
- ✅ Ensure `TimedOverlayWidget` is in Stack after editor

**Timing seems off?**
- ✅ Use milliseconds consistently everywhere
- ✅ Check video controller position updates correctly
- ✅ Verify seek operations update layer manager

**Performance issues?**
- ✅ Limit simultaneous visible layers (< 10)
- ✅ Use `RepaintBoundary` around overlay widget
- ✅ Remove layers after they're no longer needed

## 📊 Architecture

```
┌─────────────────────────────────────┐
│     Video Editor Page               │
│  ┌──────────────────────────────┐   │
│  │  ProImageEditor (Video)      │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │  TimedOverlayWidget          │   │
│  │   ├─ TimedLayerManager       │   │
│  │   └─ Visible Layers          │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
           ↓
    Position Updates
           ↓
  Layer Visibility Sync
           ↓
    Auto Show/Hide
```

## 🔄 Workflow

1. **User adds overlay** → `layerManager.addLayer()`
2. **Video plays** → Position updates → `layerManager.setCurrentTime()`
3. **Manager filters** → Returns only visible layers
4. **Widget rebuilds** → Shows/hides overlays automatically
5. **User exports** → Overlays captured at correct timestamps

## 🎓 Examples

### Example 1: Arrow Pointer

```dart
// Point to something at 2 seconds
_layerManager.addLayer(
  TimedLayer(
    id: 'arrow_1',
    type: TimedLayerType.arrow,
    startMs: 2000,
    endMs: 3000,
    content: 'arrow',
    position: Offset(0.4, -0.3),  // Top right
    color: Colors.red,
    scale: 1.5,
    rotation: 0.785,  // 45 degrees
  ),
);
```

### Example 2: Text Caption

```dart
// Show text from 5-10 seconds
_layerManager.addLayer(
  TimedLayer(
    id: 'caption_1',
    type: TimedLayerType.text,
    startMs: 5000,
    endMs: 10000,
    content: 'Look at this!',
    position: Offset(0, 0.4),  // Bottom center
    color: Colors.yellow,
    scale: 1.2,
  ),
);
```

### Example 3: Celebration Emoji

```dart
// Emoji at 15 seconds
_layerManager.addLayer(
  TimedLayer(
    id: 'emoji_1',
    type: TimedLayerType.emoji,
    startMs: 15000,
    endMs: 16500,
    content: '🎉',
    position: Offset(0, 0),  // Center
    scale: 2.5,
  ),
);
```

## 🛠️ API Reference

### TimedLayer

```dart
TimedLayer(
  id: String,              // Unique identifier
  type: TimedLayerType,    // Layer type
  startMs: int,            // Start time (milliseconds)
  endMs: int,              // End time (milliseconds)
  content: dynamic,        // Layer content
  position: Offset,        // Position (-1.0 to 1.0)
  scale: double,           // Size multiplier
  rotation: double,        // Rotation (radians)
  color: Color?,           // Color
  opacity: double,         // Opacity (0.0 to 1.0)
)
```

### TimedLayerManager

```dart
// Add layer
layerManager.addLayer(TimedLayer(...))

// Remove layer
layerManager.removeLayer(String id)

// Update layer
layerManager.updateLayer(String id, TimedLayer updated)

// Set current time
layerManager.setCurrentTime(Duration position)

// Get visible layers
final visible = layerManager.visibleLayers

// Get layers in range (for export)
final layers = layerManager.getLayersInRange(startMs, endMs)
```

## 📦 What You Get

### Models
- ✅ `TimedLayer` - Complete layer data model
- ✅ `TimedLayerType` - Enum for layer types

### Managers
- ✅ `TimedLayerManager` - Full layer lifecycle management

### Widgets
- ✅ `TimedOverlayWidget` - Automatic rendering
- ✅ `LayerControlsWidget` - Interactive UI

### Examples
- ✅ Complete working video editor
- ✅ Demo with pre-configured layers
- ✅ Interactive controls demonstration

### Documentation
- ✅ Quick start guide (5 minutes)
- ✅ Complete documentation (40+ sections)
- ✅ Integration guide (step-by-step)
- ✅ Code examples and patterns

## 🚧 Current Limitations

1. **Single Frame Export**: Captures one frame per layer
   - Works well for static overlays
   - Future: Multi-frame rendering

2. **No Native FFmpeg**: Uses bitmap overlay
   - Future: FFmpeg filter integration

3. **Instant Transitions**: No fade in/out
   - Future: Animation support

See `TIMED_OVERLAYS_IMPLEMENTATION.md` for planned enhancements.

## 🎉 Success Criteria

After integration, you should be able to:

✅ Add overlays at any timestamp  
✅ See overlays appear/disappear during playback  
✅ Scrub timeline with accurate overlay timing  
✅ Edit overlay timing visually  
✅ Export video with overlays at correct times  
✅ Support multiple overlays simultaneously  

## 📝 License

Part of the pro_video_editor example project.

## 🤝 Contributing

This implementation is production-ready but can be extended:

1. **Add more layer types** - Extend `TimedLayerType`
2. **Add animations** - Implement transitions
3. **Improve export** - Multi-frame rendering
4. **Add templates** - Pre-configured layer sets
5. **Persistence** - Save/load layer configs

## 📞 Support

- 📖 Full docs: `TIMED_OVERLAYS_README.md`
- 🚀 Quick start: `QUICK_START.md`
- 🔧 Integration: `INTEGRATION_EXAMPLE.md`
- 💻 Example: `video_editor_with_timed_overlays_page.dart`

---

**Ready to get started?** Open `QUICK_START.md` for a 5-minute integration guide! 🚀

