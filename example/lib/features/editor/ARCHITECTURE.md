# Time-Based Overlay Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       Video Editor Page                          │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  ProImageEditor                          │    │
│  │              (Main Video Editor)                         │    │
│  │  ┌──────────────────────────────────────────────────┐   │    │
│  │  │          Video Player Widget                      │   │    │
│  │  │  ┌────────────────────────────────────────────┐  │   │    │
│  │  │  │   VideoPlayerController                    │  │   │    │
│  │  │  │   - Controls playback                      │  │   │    │
│  │  │  │   - Tracks position                        │  │   │    │
│  │  │  └────────────────────────────────────────────┘  │   │    │
│  │  └──────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │            TimedOverlayWidget (Transparent)              │    │
│  │  ┌──────────────────────────────────────────────────┐   │    │
│  │  │         TimedLayerManager                         │   │    │
│  │  │  ┌────────────────────────────────────────────┐  │   │    │
│  │  │  │  Layer 1: Arrow (2s-3s)    [VISIBLE]      │  │   │    │
│  │  │  │  Layer 2: Text (1s-4s)     [VISIBLE]      │  │   │    │
│  │  │  │  Layer 3: Emoji (5s-7s)    [HIDDEN]       │  │   │    │
│  │  │  └────────────────────────────────────────────┘  │   │    │
│  │  │                                                   │   │    │
│  │  │  Current Time: 2.5 seconds                       │   │    │
│  │  │  Visible Layers: [Arrow, Text]                   │   │    │
│  │  └──────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Component Hierarchy

```
VideoEditorPage
    ├── Stack
    │   ├── ProImageEditor
    │   │   ├── VideoPlayer
    │   │   ├── Editing Tools
    │   │   └── Timeline
    │   │
    │   └── TimedOverlayWidget (overlay on top)
    │       ├── ListenableBuilder (listens to manager)
    │       └── For each visible layer:
    │           ├── Positioned
    │           ├── Transform (rotation, scale)
    │           └── LayerContent (arrow, text, etc.)
    │
    └── LayerControlsWidget (optional UI)
        ├── Add buttons
        ├── Layer list
        └── Edit controls
```

## Data Flow

### 1. Video Playback Position Update

```
VideoPlayerController
    ↓ (position changes)
addListener callback
    ↓
_onDurationChange()
    ↓
layerManager.setCurrentTime(position)
    ↓
LayerManager filters layers by time
    ↓
notifyListeners()
    ↓
TimedOverlayWidget rebuilds
    ↓
Only visible layers rendered
```

### 2. Adding a New Layer

```
User clicks "Add Arrow"
    ↓
_addArrowAtCurrentTime()
    ↓
Get current position: videoController.value.position
    ↓
Create TimedLayer(
    startMs: currentMs,
    endMs: currentMs + 1000
)
    ↓
layerManager.addLayer(layer)
    ↓
Manager adds to internal list
    ↓
notifyListeners()
    ↓
UI rebuilds with new layer
```

### 3. Layer Visibility Determination

```
layerManager.visibleLayers
    ↓
For each layer in _layers:
    ↓
    Check: currentMs >= layer.startMs 
           AND currentMs < layer.endMs
    ↓
    If TRUE: Include in visible list
    If FALSE: Skip
    ↓
Return filtered list
```

## State Management

```
┌─────────────────────────────────────────────┐
│        TimedLayerManager                     │
│         (ChangeNotifier)                     │
│                                              │
│  State:                                      │
│  - _layers: List<TimedLayer>                │
│  - _currentTimeMs: int                      │
│                                              │
│  Getters:                                    │
│  - visibleLayers (computed)                 │
│  - currentTimeMs                            │
│                                              │
│  Methods:                                    │
│  - addLayer()        → notifyListeners()    │
│  - removeLayer()     → notifyListeners()    │
│  - updateLayer()     → notifyListeners()    │
│  - setCurrentTime()  → notifyListeners()    │
│                                              │
│  Listeners:                                  │
│  - TimedOverlayWidget (rebuilds on change)  │
│  - LayerControlsWidget (shows layer list)   │
└─────────────────────────────────────────────┘
```

## Timing Logic

### Layer Visibility Calculation

```dart
bool isVisibleAt(int currentMs) {
  return currentMs >= startMs && currentMs < endMs;
}
```

### Example Timeline

```
Video Timeline: 0s ────────────────────────────────────────> 10s

Layer 1 (Arrow):   
    startMs: 2000
    endMs: 3000
    Timeline:      [2s========3s]

Layer 2 (Text):
    startMs: 1000
    endMs: 4000
    Timeline:   [1s=================4s]

Layer 3 (Emoji):
    startMs: 5000
    endMs: 7000
    Timeline:                     [5s=========7s]


Playback Position: 2.5s
    ↓
Visible Layers:
    ✓ Layer 1 (Arrow)  - 2.5s is between 2s and 3s
    ✓ Layer 2 (Text)   - 2.5s is between 1s and 4s
    ✗ Layer 3 (Emoji)  - 2.5s is NOT between 5s and 7s
```

## Rendering Pipeline

```
Frame Render Cycle
    ↓
1. VideoPlayer renders video frame
    ↓
2. ProImageEditor renders editor UI
    ↓
3. TimedOverlayWidget builds
    ↓
4. Get visibleLayers from manager
    ↓
5. For each visible layer:
    ↓
    a. Calculate position (normalized to actual)
    ↓
    b. Apply transforms (scale, rotation)
    ↓
    c. Apply opacity
    ↓
    d. Render layer content (arrow, text, etc.)
    ↓
6. Composite all layers
    ↓
7. Display final frame
```

## Position Coordinate System

```
Screen Space (pixels):              Normalized Space (-1.0 to 1.0):

(0,0) ────────────── (W,0)          (-1,-1) ────────── (1,-1)
  │                     │               │                  │
  │    Video Player     │               │   Center (0,0)   │
  │                     │               │        ●         │
  │                     │               │                  │
(0,H) ────────────── (W,H)          (-1,1) ─────────── (1,1)

W = video width                     Normalized coordinates:
H = video height                    - Independent of screen size
                                    - Easy positioning
                                    - (-1,-1) = top-left
                                    - (1,1) = bottom-right
                                    - (0,0) = center
```

### Position Conversion

```dart
// Normalized to Screen
final screenX = (normalizedX + 1.0) / 2.0 * screenWidth;
final screenY = (normalizedY + 1.0) / 2.0 * screenHeight;

// Screen to Normalized
final normalizedX = (screenX / screenWidth) * 2.0 - 1.0;
final normalizedY = (screenY / screenHeight) * 2.0 - 1.0;
```

## Layer Lifecycle

```
┌──────────────────────────────────────────────────────┐
│              Layer Lifecycle                          │
└──────────────────────────────────────────────────────┘

1. CREATED
    ↓
    User action or programmatic creation
    ↓
    TimedLayer object instantiated
    ↓

2. ADDED
    ↓
    layerManager.addLayer(layer)
    ↓
    Added to _layers list
    ↓
    notifyListeners() called
    ↓

3. HIDDEN (before startMs)
    ↓
    currentMs < startMs
    ↓
    Not in visibleLayers list
    ↓
    Not rendered
    ↓

4. VISIBLE (startMs ≤ currentMs < endMs)
    ↓
    currentMs >= startMs AND currentMs < endMs
    ↓
    Included in visibleLayers list
    ↓
    Rendered on screen
    ↓

5. HIDDEN (after endMs)
    ↓
    currentMs >= endMs
    ↓
    Not in visibleLayers list
    ↓
    Not rendered
    ↓

6. REMOVED (optional)
    ↓
    layerManager.removeLayer(id)
    ↓
    Removed from _layers list
    ↓
    notifyListeners() called
    ↓

7. DISPOSED
    ↓
    layerManager.dispose()
    ↓
    All resources cleaned up
```

## Export Architecture

```
┌────────────────────────────────────────────────────┐
│                Export Pipeline                      │
└────────────────────────────────────────────────────┘

1. User initiates export
    ↓
2. Get export time range (startMs, endMs)
    ↓
3. Get layers in range:
    layerManager.getLayersInRange(startMs, endMs)
    ↓
4. For each layer timestamp:
    ↓
    a. Set current time to layer.startMs
    ↓
    b. Capture overlay widget as image:
        RepaintBoundary → RenderObject → Image → Bytes
    ↓
    c. Store image with timestamp
    ↓
5. Create RenderVideoModel:
    ↓
    RenderVideoModel(
        video: originalVideo,
        imageBytes: overlayImage,  ← Captured overlay
        startTime: exportStartTime,
        endTime: exportEndTime,
        transform: cropRotateData,
    )
    ↓
6. Render video:
    ProVideoEditor.instance.renderVideoToFile()
    ↓
    Native platform composites:
    - Video frames
    - Overlay image (at correct time)
    - Transforms (crop, rotate, etc.)
    ↓
7. Output final video file
```

## Performance Optimizations

### 1. Efficient Rebuilds

```
┌──────────────────────────────────────────────────┐
│         ListenableBuilder                         │
│  (only rebuilds when manager changes)             │
│                                                    │
│  Instead of:                                      │
│    setState(() { ... })  ← Rebuilds entire widget│
│                                                    │
│  Use:                                             │
│    ListenableBuilder(                             │
│      listenable: layerManager,                    │
│      builder: (context, child) {                  │
│        return buildOverlays();  ← Only this part │
│      }                                            │
│    )                                              │
└──────────────────────────────────────────────────┘
```

### 2. Lazy Filtering

```dart
// Computed getter - only calculates when accessed
List<TimedLayer> get visibleLayers {
  return _layers.where((layer) => 
    layer.isVisibleAt(_currentTimeMs)
  ).toList();
}

// Not stored - calculated on demand
// No memory overhead for visibility state
```

### 3. RepaintBoundary

```
┌──────────────────────────────────────────────────┐
│           Widget Tree                             │
│                                                    │
│  Stack                                            │
│    ├── ProImageEditor  ← RepaintBoundary         │
│    │   (isolates video rendering)                │
│    │                                              │
│    └── RepaintBoundary  ← RepaintBoundary        │
│        └── TimedOverlayWidget                    │
│            (isolates overlay rendering)          │
│                                                    │
│  Benefits:                                        │
│  - Video and overlays repaint independently      │
│  - Reduces unnecessary redraws                   │
│  - Better performance                            │
└──────────────────────────────────────────────────┘
```

## Memory Management

```
┌────────────────────────────────────────────────────┐
│            Memory Usage                             │
└────────────────────────────────────────────────────┘

Per Layer (~1KB):
  - id: String (16 bytes)
  - type: enum (4 bytes)
  - startMs: int (8 bytes)
  - endMs: int (8 bytes)
  - content: dynamic (~100 bytes)
  - position: Offset (16 bytes)
  - scale: double (8 bytes)
  - rotation: double (8 bytes)
  - color: Color (8 bytes)
  - opacity: double (8 bytes)

10 layers ≈ 10KB
100 layers ≈ 100KB

Negligible for modern devices!
```

## Threading Model

```
┌────────────────────────────────────────────────────┐
│              Thread Architecture                    │
└────────────────────────────────────────────────────┘

UI Thread (Main Isolate):
  ├── Video playback updates
  ├── Layer manager updates
  ├── Widget rebuilds
  └── User interactions

Platform Thread:
  ├── Video decoding
  └── Native rendering

Export Thread:
  ├── Video encoding
  ├── Frame composition
  └── File I/O

Benefits:
  - Non-blocking UI
  - Smooth 60 FPS
  - Responsive controls
```

## Error Handling

```
┌────────────────────────────────────────────────────┐
│            Error Prevention                         │
└────────────────────────────────────────────────────┘

1. Timing Validation:
    assert(startMs < endMs)
    ↓
    Prevents invalid time ranges

2. Null Safety:
    TimedLayer? getLayer(String id)
    ↓
    Returns null if not found

3. Bounds Checking:
    position.clamp(-1.0, 1.0)
    ↓
    Keeps overlays on screen

4. Disposal Safety:
    @override
    void dispose() {
      layerManager.dispose();
      super.dispose();
    }
    ↓
    Prevents memory leaks
```

## Testing Strategy

```
┌────────────────────────────────────────────────────┐
│              Test Pyramid                           │
└────────────────────────────────────────────────────┘

Manual Tests (UI):
  ├── Add layer at timestamp
  ├── Verify visibility during playback
  ├── Scrub timeline
  ├── Edit layer timing
  └── Export and verify

Integration Tests:
  ├── Layer manager lifecycle
  ├── Visibility filtering
  ├── Position calculations
  └── Widget rebuilds

Unit Tests:
  ├── TimedLayer.isVisibleAt()
  ├── Position normalization
  ├── Time range calculations
  └── JSON serialization
```

## Summary

This architecture provides:

✅ **Separation of Concerns**
- Data (TimedLayer)
- Logic (TimedLayerManager)
- UI (TimedOverlayWidget)

✅ **Efficient Updates**
- Minimal rebuilds
- Lazy calculations
- Repaint boundaries

✅ **Type Safety**
- Null-safe Dart
- Enum-based types
- Compile-time checks

✅ **Scalability**
- Supports many layers
- Minimal memory
- 60 FPS performance

✅ **Maintainability**
- Clean architecture
- Well-documented
- Easy to extend

For implementation details, see the source code files!

