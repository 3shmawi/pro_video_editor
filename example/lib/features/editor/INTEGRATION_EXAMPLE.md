# Integration Example: Adding Timed Overlays to Your Existing Video Editor

This guide shows you how to add timed overlay support to the existing video editor in this project.

## Before Integration

Your current video editor (`video_editor_grounded_example_page.dart`):

```dart
class _VideoEditorGroundedExamplePageState extends State<...> {
  ProVideoController? _proVideoController;
  late VideoPlayerController _videoController;
  
  void _onDurationChange() {
    var duration = _videoController.value.position;
    _proVideoController!.setPlayTime(duration);
    // ... trim logic
  }
  
  @override
  Widget build(BuildContext context) {
    return ProImageEditor.video(_proVideoController!, ...);
  }
}
```

## After Integration

Your enhanced video editor with timed overlays:

```dart
import '/core/managers/timed_layer_manager.dart';
import '/core/models/timed_layer_model.dart';
import '/features/editor/widgets/timed_overlay_widget.dart';

class _VideoEditorGroundedExamplePageState extends State<...> {
  ProVideoController? _proVideoController;
  late VideoPlayerController _videoController;
  
  // ✅ ADD: Layer manager
  final _layerManager = TimedLayerManager();
  final _overlayKey = GlobalKey();
  
  @override
  void dispose() {
    _layerManager.dispose();  // ✅ ADD: Dispose manager
    _videoController.dispose();
    super.dispose();
  }
  
  void _onDurationChange() {
    var duration = _videoController.value.position;
    _proVideoController!.setPlayTime(duration);
    
    // ✅ ADD: Update layer manager
    _layerManager.setCurrentTime(duration);
    
    // ... trim logic
  }
  
  // ✅ ADD: Method to add overlays
  void _addOverlayAtCurrentTime() {
    final currentMs = _videoController.value.position.inMilliseconds;
    
    _layerManager.addLayer(
      TimedLayer(
        id: 'overlay_${DateTime.now().microsecondsSinceEpoch}',
        type: TimedLayerType.arrow,
        startMs: currentMs,
        endMs: currentMs + 1000,
        content: 'arrow',
        position: const Offset(0, 0),
        color: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // ✅ MODIFY: Wrap editor in Stack
    return Stack(
      children: [
        // Original editor
        ProImageEditor.video(_proVideoController!, ...),
        
        // ✅ ADD: Overlay widget
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
        
        // ✅ ADD: Control button (optional)
        Positioned(
          top: 100,
          right: 20,
          child: FloatingActionButton(
            mini: true,
            onPressed: _addOverlayAtCurrentTime,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
```

## Step-by-Step Changes

### Step 1: Import Required Files

Add these imports at the top of your file:

```dart
import '/core/managers/timed_layer_manager.dart';
import '/core/models/timed_layer_model.dart';
import '/features/editor/widgets/timed_overlay_widget.dart';
```

### Step 2: Add Layer Manager Field

In your state class:

```dart
class _VideoEditorGroundedExamplePageState extends State<...> {
  // Add these lines
  final _layerManager = TimedLayerManager();
  final _overlayKey = GlobalKey();
  
  // ... rest of your fields
}
```

### Step 3: Dispose Layer Manager

In your dispose method:

```dart
@override
void dispose() {
  _layerManager.dispose();  // ← Add this line
  _videoController.dispose();
  super.dispose();
}
```

### Step 4: Update Position Tracking

In your `_onDurationChange` method:

```dart
void _onDurationChange() {
  var duration = _videoController.value.position;
  _proVideoController!.setPlayTime(duration);
  
  // Add this line
  _layerManager.setCurrentTime(duration);
  
  // ... rest of your logic
}
```

### Step 5: Add Overlay Widget to Build

Change your build method to wrap everything in a Stack:

**Before:**
```dart
@override
Widget build(BuildContext context) {
  return LayoutBuilder(builder: (context, constraints) {
    return ProImageEditor.video(_proVideoController!, ...);
  });
}
```

**After:**
```dart
@override
Widget build(BuildContext context) {
  return LayoutBuilder(builder: (context, constraints) {
    return Stack(
      children: [
        // Your existing ProImageEditor.video
        ProImageEditor.video(_proVideoController!, ...),
        
        // Add the overlay widget
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
  });
}
```

### Step 6: Add Method to Create Overlays

Add this helper method to your state class:

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
      position: const Offset(0.3, -0.2),
      color: Colors.red,
      scale: 1.5,
    ),
  );
  
  setState(() {});  // Refresh UI
}
```

### Step 7: Add UI Control (Optional)

Add a button to trigger overlay creation. You can add this in your custom toolbar or as a floating button:

```dart
// In your build method's Stack children:
Positioned(
  top: 100,
  right: 20,
  child: Column(
    children: [
      FloatingActionButton(
        mini: true,
        heroTag: 'add_arrow',
        onPressed: _addArrowAtCurrentTime,
        child: const Icon(Icons.arrow_forward),
        tooltip: 'Add Arrow',
      ),
      const SizedBox(height: 8),
      FloatingActionButton(
        mini: true,
        heroTag: 'add_text',
        onPressed: _addTextAtCurrentTime,
        child: const Icon(Icons.text_fields),
        tooltip: 'Add Text',
      ),
    ],
  ),
)
```

## Complete Minimal Example

Here's a minimal diff showing exactly what changes:

```diff
+ import '/core/managers/timed_layer_manager.dart';
+ import '/core/models/timed_layer_model.dart';
+ import '/features/editor/widgets/timed_overlay_widget.dart';

class _VideoEditorGroundedExamplePageState extends State<...> {
+ final _layerManager = TimedLayerManager();
+ final _overlayKey = GlobalKey();
  
  ProVideoController? _proVideoController;
  late VideoPlayerController _videoController;
  
  @override
  void dispose() {
+   _layerManager.dispose();
    _videoController.dispose();
    super.dispose();
  }
  
  void _onDurationChange() {
    var duration = _videoController.value.position;
    _proVideoController!.setPlayTime(duration);
+   _layerManager.setCurrentTime(duration);
    
    if (_durationSpan != null && duration >= _durationSpan!.end) {
      _seekToPosition(_durationSpan!);
    }
  }
  
+ void _addArrowAtCurrentTime() {
+   final currentMs = _videoController.value.position.inMilliseconds;
+   _layerManager.addLayer(
+     TimedLayer(
+       id: 'arrow_${DateTime.now().microsecondsSinceEpoch}',
+       type: TimedLayerType.arrow,
+       startMs: currentMs,
+       endMs: currentMs + 1000,
+       content: 'arrow',
+       position: const Offset(0.3, -0.2),
+       color: Colors.red,
+     ),
+   );
+ }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
+     return Stack(
+       children: [
          ProImageEditor.video(_proVideoController!, ...),
+         Positioned.fill(
+           child: IgnorePointer(
+             child: RepaintBoundary(
+               key: _overlayKey,
+               child: TimedOverlayWidget(
+                 layerManager: _layerManager,
+                 videoSize: _videoController.value.size,
+               ),
+             ),
+           ),
+         ),
+       ],
+     );
    });
  }
}
```

## Testing Your Integration

### 1. Basic Test

```dart
// In initState, add a test layer
@override
void initState() {
  super.initState();
  _initializePlayer();
  
  // Add test layer at 2 seconds
  _layerManager.addLayer(
    TimedLayer(
      id: 'test_arrow',
      type: TimedLayerType.arrow,
      startMs: 2000,
      endMs: 3000,
      content: 'arrow',
      position: const Offset(0, 0),
      color: Colors.red,
    ),
  );
}
```

Run the app and:
- ✅ Play video to 2 seconds - arrow should appear
- ✅ Continue to 3 seconds - arrow should disappear
- ✅ Scrub timeline back to 2s - arrow should reappear

### 2. Interactive Test

Add a button and click it while video is paused:
- ✅ Pause at 5 seconds
- ✅ Click "Add Arrow"
- ✅ Scrub to 5s - arrow should appear
- ✅ Scrub to 6s - arrow should disappear

### 3. Export Test

Export the video with overlays:
- ✅ Add overlays at different timestamps
- ✅ Export video
- ✅ Play exported video
- ✅ Verify overlays appear at correct times

## Advanced Integration: Interactive Layer Controls

For a full UI to manage layers, integrate the `LayerControlsWidget`:

```dart
import '/features/editor/widgets/layer_controls_widget.dart';

// In your build method:
Positioned(
  left: 20,
  bottom: 100,
  child: LayerControlsWidget(
    layerManager: _layerManager,
    videoController: _videoController,
  ),
)
```

This provides:
- Buttons to add different layer types
- List of all layers with timing
- Edit/delete functionality
- Time sliders for adjusting timing

## Export Integration

To capture overlays during export:

```dart
Future<void> generateVideo(CompleteParameters parameters) async {
  final startMs = parameters.startTime?.inMilliseconds ?? 0;
  final endMs = parameters.endTime?.inMilliseconds ?? 
      _videoMetadata.duration.inMilliseconds;

  // Get layers in export range
  final layersInRange = _layerManager.getLayersInRange(startMs, endMs);

  Uint8List? overlayImage;
  if (layersInRange.isNotEmpty) {
    // Capture overlay at first layer timestamp
    final captureTime = layersInRange.first.startMs;
    overlayImage = await _captureOverlayAtTime(captureTime);
  }

  var exportModel = RenderVideoModel(
    video: _video,
    imageBytes: overlayImage ?? 
        (parameters.layers.isNotEmpty ? parameters.image : null),
    // ... other parameters
  );

  await ProVideoEditor.instance.renderVideoToFile(outputPath, exportModel);
}

Future<Uint8List?> _captureOverlayAtTime(int timeMs) async {
  _layerManager.setCurrentTime(Duration(milliseconds: timeMs));
  await Future.delayed(const Duration(milliseconds: 50));
  
  final boundary = _overlayKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  
  if (boundary == null) return null;
  
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  
  return byteData?.buffer.asUint8List();
}
```

## Common Patterns

### Pattern 1: Add Layer on Tap

```dart
GestureDetector(
  onTapUp: (details) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final size = renderBox.size;
    
    // Convert to normalized coordinates
    final x = (localPosition.dx / size.width) * 2 - 1;
    final y = (localPosition.dy / size.height) * 2 - 1;
    
    _addLayerAt(Offset(x, y));
  },
  child: YourVideoWidget(),
)
```

### Pattern 2: Sync with Trim Range

```dart
void _onTrimSpanEnd(TrimDurationSpan span) {
  // Adjust all layers to trim range
  final trimStartMs = span.start.inMilliseconds;
  final trimEndMs = span.end.inMilliseconds;
  
  for (final layer in _layerManager.layers) {
    final adjusted = _layerManager.adjustLayerForTrim(
      layer,
      trimStartMs,
      trimEndMs,
    );
    _layerManager.updateLayer(layer.id, adjusted);
  }
}
```

### Pattern 3: Layer Presets

```dart
void _addPreset(String presetName) {
  final currentMs = _videoController.value.position.inMilliseconds;
  
  switch (presetName) {
    case 'attention':
      _layerManager.addLayer(TimedLayer(
        id: 'arrow_${DateTime.now().microsecondsSinceEpoch}',
        type: TimedLayerType.arrow,
        startMs: currentMs,
        endMs: currentMs + 1500,
        content: 'arrow',
        position: const Offset(0, -0.3),
        color: Colors.red,
        scale: 2.0,
      ));
      break;
      
    case 'celebration':
      _layerManager.addLayer(TimedLayer(
        id: 'emoji_${DateTime.now().microsecondsSinceEpoch}',
        type: TimedLayerType.emoji,
        startMs: currentMs,
        endMs: currentMs + 2000,
        content: '🎉',
        position: const Offset(0, 0),
        scale: 2.5,
      ));
      break;
  }
}
```

## Troubleshooting Integration

### Issue: Overlays not showing

**Solution:** Check Stack order
```dart
Stack(
  children: [
    ProImageEditor.video(...),  // ← First (bottom)
    TimedOverlayWidget(...),    // ← Second (top) ✅
  ],
)
```

### Issue: Overlays block touches

**Solution:** Wrap in `IgnorePointer`
```dart
Positioned.fill(
  child: IgnorePointer(  // ← Important!
    child: TimedOverlayWidget(...),
  ),
)
```

### Issue: Timing is off by a few milliseconds

**Solution:** Ensure consistent time updates
```dart
_videoController.addListener(() {
  _layerManager.setCurrentTime(_videoController.value.position);
});
```

## Next Steps

1. ✅ **Basic Integration** - You've completed this!
2. 📝 **Add UI Controls** - Use `LayerControlsWidget`
3. 🎨 **Customize Layers** - Modify `TimedOverlayWidget`
4. 💾 **Persistence** - Save layers to JSON
5. 📤 **Advanced Export** - Multi-frame rendering

See the complete example at `video_editor_with_timed_overlays_page.dart` for reference!

