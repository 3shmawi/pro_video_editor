# Time-Based Overlay Synchronization for Video Editor

This implementation provides a complete solution for syncing visual overlays (text, arrows, graphics) with a video timeline, ensuring overlays appear only at the correct timestamps during both preview and export.

## Overview

The system consists of four main components:

1. **TimedLayer Model** - Stores overlay data with timing information
2. **TimedLayerManager** - Manages layers and tracks playback position
3. **TimedOverlayWidget** - Renders visible overlays on top of video
4. **VideoEditorWithTimedOverlaysPage** - Integrates everything into the editor

## How It Works

### 1. Layer Timing Model (`timed_layer_model.dart`)

Each overlay is represented by a `TimedLayer` object:

```dart
TimedLayer(
  id: 'arrow_1',
  type: TimedLayerType.arrow,
  startMs: 2000,  // Appears at 2 seconds
  endMs: 3000,    // Disappears at 3 seconds
  content: 'arrow',
  position: Offset(0.3, -0.2),  // Position on screen (-1.0 to 1.0)
  color: Colors.red,
  scale: 1.5,
  rotation: 0.0,
  opacity: 1.0,
)
```

**Properties:**
- `id`: Unique identifier
- `type`: `text`, `arrow`, `sticker`, `emoji`, `drawing`, or `shape`
- `startMs`: Start time in milliseconds
- `endMs`: End time in milliseconds
- `content`: Layer-specific data (text string, image path, etc.)
- `position`: Offset from center (x: -1.0 to 1.0, y: -1.0 to 1.0)
- `scale`: Size multiplier
- `rotation`: Rotation in radians
- `color`: Color for text/drawings
- `opacity`: Transparency (0.0 to 1.0)

### 2. Layer Manager (`timed_layer_manager.dart`)

The `TimedLayerManager` handles layer lifecycle and visibility:

```dart
final layerManager = TimedLayerManager();

// Add a layer
layerManager.addLayer(layer);

// Update current video position (called on every frame)
layerManager.setCurrentTime(Duration(milliseconds: 2500));

// Get visible layers at current time
final visible = layerManager.visibleLayers;

// Remove a layer
layerManager.removeLayer('arrow_1');
```

**Key Methods:**
- `addLayer(TimedLayer)` - Add a new overlay
- `removeLayer(String id)` - Remove overlay by ID
- `updateLayer(String id, TimedLayer)` - Modify existing layer
- `setCurrentTime(Duration)` - Update playback position
- `visibleLayers` - Get layers visible at current time
- `getLayersInRange(startMs, endMs)` - Get layers for export

### 3. Overlay Widget (`timed_overlay_widget.dart`)

Renders visible overlays on top of the video player:

```dart
TimedOverlayWidget(
  layerManager: layerManager,
  videoSize: videoController.value.size,
)
```

The widget automatically updates when:
- Playback position changes
- Layers are added/removed/modified
- Layer timing causes visibility changes

### 4. Integration Example

See `video_editor_with_timed_overlays_page.dart` for full implementation:

```dart
class _VideoEditorWithTimedOverlaysPageState extends State<...> {
  final _layerManager = TimedLayerManager();
  final _overlayKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
    
    // Add demo layers
    _layerManager.addLayer(
      TimedLayer(
        id: 'arrow_1',
        type: TimedLayerType.arrow,
        startMs: 2000,  // Show at 2 seconds
        endMs: 3000,    // Hide at 3 seconds
        content: 'arrow',
        position: Offset(0.3, -0.2),
        color: Colors.red,
      ),
    );
  }
  
  void _onDurationChange() {
    // Update layer manager with current position
    _layerManager.setCurrentTime(_videoController.value.position);
    
    // ... other playback logic
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ProImageEditor.video(...),  // Main editor
        
        // Overlay timed layers
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              key: _overlayKey,
              child: TimedOverlayWidget(
                layerManager: _layerManager,
                videoSize: _videoController.value.size,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

## Usage Examples

### Adding Text at Specific Time

```dart
layerManager.addLayer(
  TimedLayer(
    id: 'text_${DateTime.now().millisecondsSinceEpoch}',
    type: TimedLayerType.text,
    startMs: 1000,  // 1 second
    endMs: 4000,    // 4 seconds
    content: 'Hello World!',
    position: Offset(0, 0.3),  // Bottom center
    color: Colors.yellow,
    scale: 1.2,
  ),
);
```

### Adding Arrow at Current Playback Position

```dart
final currentMs = _videoController.value.position.inMilliseconds;

layerManager.addLayer(
  TimedLayer(
    id: 'arrow_${DateTime.now().millisecondsSinceEpoch}',
    type: TimedLayerType.arrow,
    startMs: currentMs,
    endMs: currentMs + 1000,  // Show for 1 second
    content: 'arrow',
    position: Offset(0.3, -0.2),
    color: Colors.red,
    scale: 1.5,
  ),
);
```

### Adding Emoji

```dart
layerManager.addLayer(
  TimedLayer(
    id: 'emoji_1',
    type: TimedLayerType.emoji,
    startMs: 5000,
    endMs: 7000,
    content: '🎉',
    position: Offset(-0.4, -0.3),
    scale: 2.0,
  ),
);
```

## Export with Timed Overlays

The export process captures overlays at the correct timestamps:

```dart
Future<void> generateVideo(CompleteParameters parameters) async {
  final startMs = parameters.startTime?.inMilliseconds ?? 0;
  final endMs = parameters.endTime?.inMilliseconds ?? 
      _videoMetadata.duration.inMilliseconds;

  // Get layers that appear in the export range
  final layersInRange = _layerManager.getLayersInRange(startMs, endMs);

  // Capture overlay image at specific timestamp
  if (layersInRange.isNotEmpty) {
    final captureTime = layersInRange.first.startMs;
    final overlayImage = await _captureOverlayAtTime(captureTime);
    
    // Include in export
    exportModel = RenderVideoModel(
      imageBytes: overlayImage,
      // ... other parameters
    );
  }
}
```

**Note:** The current implementation captures a single frame. For production use with multiple timed overlays, you would need to:

1. Generate multiple overlay frames at different timestamps
2. Use FFmpeg filter_complex with timing parameters
3. Or extend the native rendering pipeline to support frame-by-frame overlay composition

## Position Coordinate System

Positions use a normalized coordinate system:

```
(-1.0, -1.0)  ←→  (1.0, -1.0)   Top
      ↑              ↑
      |    (0, 0)    |          Center
      |      •       |
      ↓              ↓
(-1.0, 1.0)   ←→  (1.0, 1.0)    Bottom
   Left                Right
```

Examples:
- `Offset(0, 0)` - Center of screen
- `Offset(0, -0.5)` - Top center
- `Offset(0, 0.5)` - Bottom center
- `Offset(-0.5, 0)` - Left center
- `Offset(0.5, 0)` - Right center

## Customizing Layer Appearance

### Custom Layer Types

Add new layer types by:

1. Extending `TimedLayerType` enum
2. Adding render logic in `_buildLayerContent()` in `timed_overlay_widget.dart`

Example:

```dart
enum TimedLayerType {
  // ... existing types
  customShape,
}

Widget _buildLayerContent(TimedLayer layer) {
  switch (layer.type) {
    // ... existing cases
    case TimedLayerType.customShape:
      return _buildCustomShape(layer);
  }
}

Widget _buildCustomShape(TimedLayer layer) {
  return CustomPaint(
    size: Size(100, 100),
    painter: YourCustomPainter(
      color: layer.color ?? Colors.blue,
    ),
  );
}
```

### Animations

Add animations by interpolating layer properties based on time:

```dart
Widget _buildLayerWidget(TimedLayer layer) {
  final progress = calculateProgress(layer);  // 0.0 to 1.0
  
  return Transform.scale(
    scale: layer.scale * (0.5 + 0.5 * progress),  // Fade in scale
    child: Opacity(
      opacity: layer.opacity * progress,  // Fade in opacity
      child: _buildLayerContent(layer),
    ),
  );
}
```

## Interactive Layer Editing

To allow users to place layers at current playback position:

```dart
void _addLayerAtCurrentTime(LayerType type, dynamic content) {
  final currentMs = _videoController.value.position.inMilliseconds;
  
  layerManager.addLayer(
    TimedLayer(
      id: '${type}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      startMs: currentMs,
      endMs: currentMs + 2000,  // Default 2 second duration
      content: content,
      position: Offset.zero,
      scale: 1.0,
    ),
  );
}

// Usage
ElevatedButton(
  onPressed: () => _addLayerAtCurrentTime(
    TimedLayerType.arrow,
    'arrow',
  ),
  child: Text('Add Arrow Here'),
)
```

## Best Practices

1. **Unique IDs**: Always use unique IDs for layers (timestamp-based recommended)
2. **Time Units**: Use milliseconds consistently throughout
3. **Position Range**: Keep positions within -1.0 to 1.0 for visibility
4. **Memory Management**: Remove layers when not needed
5. **Performance**: Limit simultaneous visible layers (< 10 recommended)
6. **Export Testing**: Test with short clips first to verify timing

## Troubleshooting

**Overlays not appearing:**
- Check `startMs` and `endMs` are within video duration
- Verify `_onDurationChange()` calls `layerManager.setCurrentTime()`
- Ensure `TimedOverlayWidget` is in the widget tree

**Timing is off:**
- Use same time base (milliseconds) everywhere
- Check video controller position updates correctly
- Verify seek operations update layer manager

**Export missing overlays:**
- Confirm layers are in the export time range
- Check `_captureOverlayAtTime()` is called correctly
- Verify RepaintBoundary has a valid context

## Future Enhancements

Potential improvements:

1. **Frame-accurate rendering**: Generate overlay frames for each video frame
2. **FFmpeg integration**: Use filter_complex for native timed overlays
3. **Layer transitions**: Fade in/out, slide animations
4. **Interactive timeline**: Visual timeline editor for layer timing
5. **Layer grouping**: Manage related layers together
6. **Undo/redo**: Track layer changes for editing
7. **Persistence**: Save/load layer configurations

## Demo

The example includes demo layers that automatically appear:
- Arrow at 2-3 seconds
- Text from 1-4 seconds
- Emoji at 5-7 seconds

Run the app and scrub the timeline to see overlays appear/disappear at their designated timestamps!

