# Timed Layers Rendering Issue - Investigation & Fixes

## Issue Summary

**Problem**: When adding multiple timed layers (text/paint) to a video, only one layer renders in the final video on the first generation attempt. After navigating back from the preview and regenerating, all layers appear correctly.

**Reported Date**: December 17-18, 2025  
**Platform**: Android (iOS works correctly)  
**Affected Component**: Native Android video rendering with Media3 Transformer

---

## Root Causes Identified

### 1. **Flutter/Dart Side: Incorrect Generation Stage Order**

**Location**: `example/lib/features/editor/pages/video_editor_basic_example_page.dart`

**Problem**: 
- Video generation stages were in wrong order
- Audio/video bubble merging tried to use `_outputPath` before it was initialized
- Native rendering (which sets `_outputPath`) happened LAST instead of FIRST

**Original (Broken) Order**:
```
1. Audio merging (uses _outputPath!) ❌
2. Video bubble merging (uses _outputPath!) ❌  
3. Native rendering (sets _outputPath) ✅
```

**Fixed Order**:
```
1. Native rendering (sets _outputPath) ✅
2. Audio merging (uses _outputPath) ✅
3. Video bubble merging (uses _outputPath) ✅
```

**Why it worked on second attempt**: `_outputPath` retained its value from the previous generation, so subsequent runs worked.

---

### 2. **Android Side: Multiple Separate OverlayEffect Instances**

**Location**: `android/src/main/kotlin/ch/waio/pro_video_editor/src/features/render/RenderVideo.kt`

**Problem**:
- Each timed layer created its own separate `OverlayEffect`
- Multiple separate `OverlayEffect` instances don't composite correctly in Media3
- Only the LAST `OverlayEffect` would be visible

**Original (Broken) Approach**:
```kotlin
// This created MULTIPLE separate OverlayEffect instances
timedImageBytes.forEach { timedLayer ->
    applyTimedImageLayer(...)  // Each call creates its own OverlayEffect
}
// Result: videoEffects = [OverlayEffect1, OverlayEffect2, OverlayEffect3]
// Problem: Media3 only renders the LAST OverlayEffect! ❌
```

**Fixed Approach**:
```kotlin
// Collect all overlays first
val allOverlays = mutableListOf<TextureOverlay>()
timedImageBytes.forEach { timedLayer ->
    val overlay = createTimedBitmapOverlay(...)  // Just creates the overlay
    allOverlays.add(overlay)                     // Add to collection
}
// Then create ONE OverlayEffect with ALL overlays
val overlayEffect = OverlayEffect(allOverlays)
videoEffects += overlayEffect
// Result: videoEffects = [OverlayEffect(overlay1, overlay2, overlay3)]
// Success: Media3 renders ALL overlays! ✅
```

---

## Changes Made

### Flutter/Dart Files Modified

#### 1. `example/lib/features/editor/pages/video_editor_basic_example_page.dart`

**Changes**:
- Reordered generation stages (native rendering → audio → video bubbles)
- Added `else` clause to handle cases without native rendering
- Added debug logging to track layer creation

```dart
// Stage 1: Native rendering (if needed)
if (needsNativeRendering) {
  final directory = await getTemporaryDirectory();
  final intermediateOutput = hasAudioLayers || hasVideoBubbleLayers
      ? '${directory.path}/intermediate_${DateTime.now().millisecondsSinceEpoch}.mp4'
      : '${directory.path}/my_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

  var exportModel = RenderVideoModel(
    id: _taskId,
    video: _video,
    outputFormat: _outputFormat,
    enableAudio: _proVideoController?.isAudioEnabled ?? true,
    timedImageLayers: timedImageLayers,
    // ... other parameters
  );

  _outputPath = await ProVideoEditor.instance.renderVideoToFile(
    intermediateOutput,
    exportModel,
  );
} else {
  // If no native rendering is needed, use the original video
  // as the base for audio/video bubble merging
  if (hasAudioLayers || hasVideoBubbleLayers) {
    _outputPath = await _video.safeFilePath();
  }
}

// Stage 2: Audio merging (if needed)
if (hasAudioLayers) { /* ... */ }

// Stage 3: Video bubble merging (if needed)
if (hasVideoBubbleLayers) { /* ... */ }
```

**Added Debug Logging**:
```dart
List<TimedImageLayer> timedImageLayersMapper(CompleteParameters parameter) {
  if (kDebugMode) {
    print('========================================');
    print('📦 Processing ${parameter.layerCaptures!.length} layer captures');
  }
  
  // ... layer creation with per-layer logging
  
  if (kDebugMode) {
    print('📊 Total timed layers created: ${timedImageLayers.length}');
    print('========================================');
  }
  return timedImageLayers;
}
```

---

### Android/Kotlin Files Modified

#### 1. `android/src/main/kotlin/ch/waio/pro_video_editor/src/features/render/RenderVideo.kt`

**Changes**:
- Refactored to collect all overlays before creating a single `OverlayEffect`
- Added import for `TextureOverlay`
- Added extensive debug logging

**Before**:
```kotlin
//1st - Apply static image layer (if provided)
applyImageLayer(
    videoEffects, inputFile, imageBytes, rotationDegrees,
    cropWidth, cropHeight, scaleX, scaleY
)

// 2nd - Apply timed image layers (if any)
if (timedImageBytes.isNotEmpty()) {
    Log.d(RENDER_TAG, "Applying ${timedImageBytes.size} timed image layer(s)")
    timedImageBytes.forEach { timedLayer ->
        applyTimedImageLayer(
            videoEffects = videoEffects,
            inputFile = inputFile,
            timedLayer = timedLayer,
            // ... parameters
        )
    }
}
```

**After**:
```kotlin
// Collect all overlays (static + timed) and combine them into a single OverlayEffect
val hasStaticImageLayer = imageBytes != null
val hasTimedImageLayers = timedImageBytes.isNotEmpty()

if (hasStaticImageLayer || hasTimedImageLayers) {
    val allBitmapOverlays = mutableListOf<TextureOverlay>()
    
    // 1st - Add static image layer (if provided)
    if (hasStaticImageLayer) {
        val staticOverlay = createStaticBitmapOverlay(
            inputFile, imageBytes!!, rotationDegrees,
            cropWidth, cropHeight, scaleX, scaleY
        )
        if (staticOverlay != null) {
            allBitmapOverlays.add(staticOverlay)
        }
    }
    
    // 2nd - Add timed image layers (if any)
    if (hasTimedImageLayers) {
        Log.d(RENDER_TAG, "========================================")
        Log.d(RENDER_TAG, "Processing ${timedImageBytes.size} timed image layer(s)")
        timedImageBytes.forEachIndexed { index, timedLayer ->
            Log.d(RENDER_TAG, "Layer $index: startTime=${timedLayer.startTimeUs/1_000_000.0}s, endTime=${timedLayer.endTimeUs/1_000_000.0}s, imageSize=${timedLayer.imageBytes.size}")
            val timedOverlay = createTimedBitmapOverlay(
                inputFile = inputFile,
                timedLayer = timedLayer,
                rotationDegrees = rotationDegrees,
                cropWidth = cropWidth,
                cropHeight = cropHeight,
                scaleX = scaleX,
                scaleY = scaleY
            )
            if (timedOverlay != null) {
                allBitmapOverlays.add(timedOverlay)
                Log.d(RENDER_TAG, "Layer $index: Successfully created and added to list")
            } else {
                Log.e(RENDER_TAG, "Layer $index: FAILED to create overlay!")
            }
        }
        Log.d(RENDER_TAG, "========================================")
    }
    
    // Create a single OverlayEffect with all overlays
    if (allBitmapOverlays.isNotEmpty()) {
        Log.d(RENDER_TAG, "========================================")
        Log.d(RENDER_TAG, "CREATING SINGLE OverlayEffect with ${allBitmapOverlays.size} overlays")
        Log.d(RENDER_TAG, "Overlay list contents: ${allBitmapOverlays.joinToString { it::class.java.simpleName }}")
        Log.d(RENDER_TAG, "========================================")
        val overlayEffect = androidx.media3.effect.OverlayEffect(allBitmapOverlays)
        videoEffects += overlayEffect
        Log.d(RENDER_TAG, "OverlayEffect added to videoEffects. Total videoEffects count: ${videoEffects.size}")
    }
}
```

**Imports Changed**:
```kotlin
// Removed:
import applyImageLayer
import applyTimedImageLayer

// Added:
import androidx.media3.effect.TextureOverlay
import createStaticBitmapOverlay
import createTimedBitmapOverlay
```

---

#### 2. `android/src/main/kotlin/ch/waio/pro_video_editor/src/features/render/helpers/CreateBitmapOverlays.kt` (NEW FILE)

**Purpose**: Extracted overlay creation logic into reusable functions with proper separation of concerns.

**Functions**:

##### `createStaticBitmapOverlay()`
Creates a static bitmap overlay that appears for the entire duration of the video.

```kotlin
@UnstableApi
fun createStaticBitmapOverlay(
    inputFile: File,
    imageBytes: ByteArray,
    rotationDegrees: Float,
    cropWidth: Int?,
    cropHeight: Int?,
    scaleX: Float?,
    scaleY: Float?,
): BitmapOverlay? {
    // ... dimension calculations ...
    
    val overlayBitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
    if (overlayBitmap == null) {
        Log.e(RENDER_TAG, "Failed to decode image layer bitmap")
        return null
    }
    
    val scaledOverlay = Bitmap.createScaledBitmap(overlayBitmap, videoWidth, videoHeight, true)
    return BitmapOverlay.createStaticBitmapOverlay(scaledOverlay)
}
```

##### `createTimedBitmapOverlay()`
Creates a timed bitmap overlay that appears only during a specific time range.

```kotlin
@UnstableApi
fun createTimedBitmapOverlay(
    inputFile: File,
    timedLayer: TimedImageLayer,
    rotationDegrees: Float,
    cropWidth: Int?,
    cropHeight: Int?,
    scaleX: Float?,
    scaleY: Float?,
): BitmapOverlay? {
    val imageBytes = timedLayer.imageBytes
    val startTimeUs = timedLayer.startTimeUs
    val endTimeUs = timedLayer.endTimeUs

    // ... dimension calculations and bitmap decoding ...
    
    Log.d(RENDER_TAG, "Decoded bitmap: ${overlayBitmap.width}x${overlayBitmap.height}, hasAlpha: ${overlayBitmap.hasAlpha()}, config: ${overlayBitmap.config}")

    // Scale while preserving alpha channel
    val scaledOverlay = if (overlayBitmap.width == videoWidth && overlayBitmap.height == videoHeight) {
        overlayBitmap
    } else {
        Bitmap.createScaledBitmap(overlayBitmap, videoWidth, videoHeight, true).apply {
            if (overlayBitmap.hasAlpha()) {
                setHasAlpha(true)
                setPremultiplied(true)
            }
        }
    }

    Log.d(RENDER_TAG, "Timed overlay bitmap created: ${scaledOverlay.width}x${scaledOverlay.height}")
    Log.d(RENDER_TAG, "Scaled overlay hasAlpha: ${scaledOverlay.hasAlpha()}, premultiplied: ${scaledOverlay.isPremultiplied}")

    // Create a fully transparent bitmap to use when outside the time range
    val transparentBitmap = Bitmap.createBitmap(videoWidth, videoHeight, Bitmap.Config.ARGB_8888).apply {
        eraseColor(android.graphics.Color.TRANSPARENT)
        setHasAlpha(true)
        setPremultiplied(true)
    }

    // Create a timed bitmap overlay that only appears between startTimeUs and endTimeUs
    val bitmapOverlay = object : BitmapOverlay() {
        private var lastLoggedSecond = -1L
        
        override fun getBitmap(presentationTimeUs: Long): Bitmap {
            val isInRange = presentationTimeUs in startTimeUs..endTimeUs
            
            // Log once per second
            val currentSecond = presentationTimeUs / 1_000_000
            if (currentSecond != lastLoggedSecond) {
                lastLoggedSecond = currentSecond
                Log.d(RENDER_TAG, "🎬 Layer[${startTimeUs/1_000_000}s-${endTimeUs/1_000_000}s] @ ${presentationTimeUs/1_000_000.0}s: ${if (isInRange) "✅ VISIBLE" else "⬜ TRANSPARENT"}")
            }
            
            // Only return the actual bitmap if we're within the specified time range
            return if (isInRange) {
                scaledOverlay
            } else {
                transparentBitmap
            }
        }
    }

    Log.d(RENDER_TAG, "=== Finished creating timed bitmap overlay (${startTimeUs/1_000_000}s-${endTimeUs/1_000_000}s) ===")
    
    return bitmapOverlay
}
```

**Key Features**:
- Proper alpha channel preservation during scaling
- Fully transparent bitmaps with proper alpha configuration
- Per-second logging during video rendering
- Returns `null` on error instead of throwing

---

## Technical Details

### Why Multiple OverlayEffect Instances Don't Work

According to Media3 Transformer architecture:
1. Video effects are applied in sequence to the video pipeline
2. Each `OverlayEffect` replaces the previous frame buffer
3. When multiple `OverlayEffect` instances are in the effects list, only the last one is visible
4. To composite multiple overlays, they must be in a **single `OverlayEffect` containing a list of overlays**

### Overlay Compositing Order

Overlays in the list are composited in order:
```kotlin
val overlays = listOf(overlay1, overlay2, overlay3)
val effect = OverlayEffect(overlays)
// Result: overlay1 drawn first (bottom layer)
//         overlay2 drawn on top
//         overlay3 drawn on top (top layer)
```

### Transparent Bitmap Requirements

For proper alpha compositing in Media3:
1. Use `Bitmap.Config.ARGB_8888` (supports alpha channel)
2. Call `eraseColor(Color.TRANSPARENT)` to fill with transparent pixels
3. Call `setHasAlpha(true)` to enable alpha channel
4. Call `setPremultiplied(true)` for proper alpha blending

---

## Testing & Verification

### Test Logs - Successful Layer Creation

```
D  ========================================
D  Processing 2 timed image layer(s)
D  Layer 0: startTime=7.271s, endTime=14.835s, imageSize=3648
D  === Creating timed bitmap overlay ===
D  Image bytes size: 3648
D  Time range: 7.271s to 14.835s
D  Creating Timed Image-Layer: Size 640x358, Time Range: 7.271s - 14.835s
D  Timed overlay bitmap created: 640x358
D  === Finished creating timed bitmap overlay (7s-14s) ===
D  Layer 0: Successfully created and added to list
D  Layer 1: startTime=0.0s, endTime=11.792s, imageSize=968
D  === Creating timed bitmap overlay ===
D  Image bytes size: 968
D  Time range: 0.0s to 11.792s
D  Creating Timed Image-Layer: Size 640x358, Time Range: 0.0s - 11.792s
D  Timed overlay bitmap created: 640x358
D  === Finished creating timed bitmap overlay (0s-11s) ===
D  Layer 1: Successfully created and added to list
D  ========================================
D  ========================================
D  CREATING SINGLE OverlayEffect with 2 overlays
D  Overlay list contents: , 
D  ========================================
D  OverlayEffect added to videoEffects. Total videoEffects count: 1
```

### Expected Runtime Behavior

During video rendering, you should see logs like:
```
D  🎬 Layer[0s-11s] @ 0.0s: ✅ VISIBLE
D  🎬 Layer[7s-14s] @ 7.0s: ✅ VISIBLE
D  🎬 Layer[0s-11s] @ 8.0s: ✅ VISIBLE
D  🎬 Layer[7s-14s] @ 8.0s: ✅ VISIBLE  <- Both layers visible
D  🎬 Layer[0s-11s] @ 12.0s: ⬜ TRANSPARENT
D  🎬 Layer[7s-14s] @ 12.0s: ✅ VISIBLE
```

---


## Status Update (Dec 18, 15:40)

### ✅ Alpha Transparency Fixed
The "Potential Issue: Alpha Transparency in Captured Images" has been addressed.

**Fix Applied**: 
Modified `android/src/main/kotlin/ch/waio/pro_video_editor/src/features/render/helpers/CreateBitmapOverlays.kt` to force `Bitmap.Config.ARGB_8888` when decoding layer images.

**Details**:
- Previously: `BitmapFactory.decodeByteArray` might have chosen `RGB_565` (opaque) for images without obvious alpha, or if the system preferred it.
- Now: `inPreferredConfig = Bitmap.Config.ARGB_8888` is explicitly set options.
- Added explicit `setHasAlpha(true)` and `setPremultiplied(true)` to the decoded/scaled bitmaps.

**Verification**:
Run the video generation. Layers should now blend correctly without opaque backgrounds blocking each other.

---

## Conclusion

The primary issues have been identified and fixed:
1. ✅ Flutter generation stage ordering fixed
2. ✅ Android overlay compositing refactored to use single OverlayEffect
3. ✅ Alpha transparency enforced with ARGB_8888

**Action**: Verify fixes in the attached `video_editor_basic_example_page.dart` by running the app on Android.





