# Quick Start Guide: Time-Based Overlays

This guide shows you how to quickly add time-based overlay support to your video editor.

## 5-Minute Integration

### Step 1: Add the Layer Manager

In your video editor state class:

```dart
class _YourVideoEditorState extends State<YourVideoEditor> {
  // Add this line
  final _layerManager = TimedLayerManager();
  
  // Your existing fields
  late VideoPlayerController _videoController;
  ProVideoController? _proVideoController;
  
  @override
  void dispose() {
    _layerManager.dispose();  // Don't forget to dispose!
    _videoController.dispose();
    super.dispose();
  }
}
```

### Step 2: Update Playback Position

In your video listener callback:

```dart
void _onVideoPositionChange() {
  var position = _videoController.value.position;
  
  // Add this line to sync layer visibility
  _layerManager.setCurrentTime(position);
  
  // Your existing logic
  _proVideoController?.setPlayTime(position);
}
```

### Step 3: Add Overlay Widget

In your build method, wrap your editor with a Stack:

```dart
@override
Widget build(BuildContext context) {
  return Stack(
    children: [
      // Your existing editor
      ProImageEditor.video(_proVideoController!, ...),
      
      // Add the overlay widget
      Positioned.fill(
        child: IgnorePointer(
          child: TimedOverlayWidget(
            layerManager: _layerManager,
            videoSize: _videoController.value.size,
          ),
        ),
      ),
    ],
  );
}
```

### Step 4: Add Layers Programmatically

Add a button or gesture to create layers:

```dart
void _addArrowAtCurrentTime() {
  final currentMs = _videoController.value.position.inMilliseconds;
  
  _layerManager.addLayer(
    TimedLayer(
      id: 'arrow_${DateTime.now().microsecondsSinceEpoch}',
      type: TimedLayerType.arrow,
      startMs: currentMs,
      endMs: currentMs + 1000,  // Show for 1 second
      content: 'arrow',
      position: const Offset(0, 0),  // Center
      color: Colors.red,
    ),
  );
}
```

## Complete Example

Here's a minimal working example:

```dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '/core/managers/timed_layer_manager.dart';
import '/core/models/timed_layer_model.dart';
import '/features/editor/widgets/timed_overlay_widget.dart';

class SimpleTimedVideoEditor extends StatefulWidget {
  const SimpleTimedVideoEditor({super.key});

  @override
  State<SimpleTimedVideoEditor> createState() => _SimpleTimedVideoEditorState();
}

class _SimpleTimedVideoEditorState extends State<SimpleTimedVideoEditor> {
  // Layer manager for timed overlays
  final _layerManager = TimedLayerManager();
  
  late VideoPlayerController _videoController;
  ProVideoController? _proVideoController;
  final _video = EditorVideo.asset('assets/sample.mp4');

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _layerManager.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.asset('assets/sample.mp4');
    await _videoController.initialize();
    
    final metadata = await ProVideoEditor.instance.getMetadata(_video);
    
    _proVideoController = ProVideoController(
      videoPlayer: VideoPlayer(_videoController),
      initialResolution: metadata.resolution,
      videoDuration: metadata.duration,
      fileSize: metadata.fileSize,
    );

    _videoController.addListener(_onPositionChange);
    setState(() {});
  }

  void _onPositionChange() {
    // Update layer manager with current position
    _layerManager.setCurrentTime(_videoController.value.position);
    _proVideoController?.setPlayTime(_videoController.value.position);
  }

  void _addArrowAtCurrentTime() {
    final currentMs = _videoController.value.position.inMilliseconds;
    
    _layerManager.addLayer(
      TimedLayer(
        id: 'arrow_${DateTime.now().microsecondsSinceEpoch}',
        type: TimedLayerType.arrow,
        startMs: currentMs,
        endMs: currentMs + 1000,
        content: 'arrow',
        position: const Offset(0.3, -0.2),
        color: Colors.red,
        scale: 1.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_proVideoController == null) {
      return const CircularProgressIndicator();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Main video editor
          ProImageEditor.video(
            _proVideoController!,
            callbacks: ProImageEditorCallbacks(
              videoEditorCallbacks: VideoEditorCallbacks(
                onPause: _videoController.pause,
                onPlay: _videoController.play,
              ),
            ),
          ),
          
          // Timed overlays
          Positioned.fill(
            child: IgnorePointer(
              child: TimedOverlayWidget(
                layerManager: _layerManager,
                videoSize: _videoController.value.size,
              ),
            ),
          ),
          
          // Add arrow button
          Positioned(
            top: 100,
            right: 20,
            child: FloatingActionButton(
              onPressed: _addArrowAtCurrentTime,
              child: const Icon(Icons.arrow_forward),
            ),
          ),
        ],
      ),
    );
  }
}
```

## Testing Your Integration

1. **Run the app** and open your video editor
2. **Play the video** for a few seconds
3. **Pause at 2 seconds** and click "Add Arrow"
4. **Scrub the timeline** - the arrow should appear at 2s and disappear at 3s
5. **Export the video** - the arrow should be in the final output

## Common Use Cases

### Add Text at Specific Time

```dart
_layerManager.addLayer(
  TimedLayer(
    id: 'text_1',
    type: TimedLayerType.text,
    startMs: 2000,  // At 2 seconds
    endMs: 5000,    // Until 5 seconds
    content: 'Important Note!',
    position: const Offset(0, 0.4),  // Near bottom
    color: Colors.yellow,
    scale: 1.2,
  ),
);
```

### Add Emoji Reaction

```dart
_layerManager.addLayer(
  TimedLayer(
    id: 'emoji_1',
    type: TimedLayerType.emoji,
    startMs: 3500,
    endMs: 4500,  // Show for 1 second
    content: '🎉',
    position: const Offset(0, 0),  // Center
    scale: 2.0,
  ),
);
```

### Add Pointing Arrow

```dart
_layerManager.addLayer(
  TimedLayer(
    id: 'arrow_1',
    type: TimedLayerType.arrow,
    startMs: 1000,
    endMs: 2000,
    content: 'arrow',
    position: const Offset(-0.3, -0.4),  // Top left area
    color: Colors.red,
    scale: 1.5,
    rotation: 0.785,  // 45 degrees in radians
  ),
);
```

## Troubleshooting

### Overlays not showing?

**Check 1:** Verify layer manager is being updated
```dart
void _onPositionChange() {
  print('Position: ${_videoController.value.position}');
  _layerManager.setCurrentTime(_videoController.value.position);  // ← Must call this!
}
```

**Check 2:** Confirm timing is correct
```dart
final currentMs = _videoController.value.position.inMilliseconds;
print('Adding layer at: $currentMs ms');
```

**Check 3:** Ensure overlay widget is visible
```dart
// Should be AFTER ProImageEditor in the Stack
Positioned.fill(
  child: IgnorePointer(  // ← Important! Don't block touches
    child: TimedOverlayWidget(...),
  ),
)
```

### Timing seems off?

- Make sure you're using milliseconds everywhere
- Verify `_videoController.value.position` is updating
- Check that video controller listener is properly added

### Performance issues?

- Limit number of simultaneous visible layers (< 10)
- Use `RepaintBoundary` around overlay widget
- Consider removing old layers that won't be visible again

## Next Steps

1. ✅ **Basic Integration** (You're here!)
2. 📝 **Add Interactive Controls** - Let users add/edit layers via UI
3. 🎨 **Custom Layer Types** - Create your own overlay designs
4. 💾 **Save/Load** - Persist layer configurations
5. 📤 **Advanced Export** - Multi-frame overlay rendering

See the full `TIMED_OVERLAYS_README.md` for advanced features and customization options.

## Need Help?

- Check the complete example in `video_editor_with_timed_overlays_page.dart`
- Review the `TIMED_OVERLAYS_README.md` for detailed documentation
- Look at `layer_controls_widget.dart` for UI examples

Happy editing! 🎬✨

