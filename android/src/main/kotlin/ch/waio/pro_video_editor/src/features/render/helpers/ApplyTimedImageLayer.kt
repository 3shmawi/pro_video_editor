import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import androidx.media3.common.Effect
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import ch.waio.pro_video_editor.src.features.render.models.TimedImageLayer
import ch.waio.pro_video_editor.src.features.render.utils.getRotatedVideoDimensions
import java.io.File


/**
 * Applies a timed image layer to a video at a specific time range
 *
 * @param videoEffects The list of video effects to add the overlay to
 * @param inputFile The input video file
 * @param timedLayer The timed image layer model containing image data and timing info
 * @param rotationDegrees The rotation degrees of the video
 * @param cropWidth The crop width (if any)
 * @param cropHeight The crop height (if any)
 * @param scaleX The horizontal scale factor (if any)
 * @param scaleY The vertical scale factor (if any)
 */
@UnstableApi
fun applyTimedImageLayer(
    videoEffects: MutableList<Effect>,
    inputFile: File,
    timedLayer: TimedImageLayer,
    rotationDegrees: Float,
    cropWidth: Int?,
    cropHeight: Int?,
    scaleX: Float?,
    scaleY: Float?,
) {
    val imageBytes = timedLayer.imageBytes
    // Hardcoded for testing: 4 seconds to 7 seconds
    val startTimeUs =   timedLayer.startTimeUs
    val endTimeUs =   timedLayer.endTimeUs
    
    Log.d(RENDER_TAG, "=== Starting applyTimedImageLayer ===")
    Log.d(RENDER_TAG, "Image bytes size: ${imageBytes.size}")
    Log.d(RENDER_TAG, "Time range: ${startTimeUs / 1_000_000.0}s to ${endTimeUs / 1_000_000.0}s")

    var (videoWidth, videoHeight, videoRotation) = getRotatedVideoDimensions(
        inputFile,
        rotationDegrees
    )

    val isRotated90Deg = videoRotation == 90 || videoRotation == 270
    if (cropWidth != null) {
        if (isRotated90Deg) {
            videoHeight = cropWidth
        } else {
            videoWidth = cropWidth
        }
    }
    if (cropHeight != null) {
        if (isRotated90Deg) {
            videoWidth = cropHeight
        } else {
            videoHeight = cropHeight
        }
    }

    if (scaleX != null) videoWidth = (videoWidth * scaleX).toInt()
    if (scaleY != null) videoHeight = (videoHeight * scaleY).toInt()

    Log.d(
        RENDER_TAG,
        "Applying Timed Image-Layer: Size ${videoWidth}x${videoHeight}, " +
                "Time Range: ${startTimeUs / 1_000_000.0}s - ${endTimeUs / 1_000_000.0}s"
    )

    val overlayBitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
    
    if (overlayBitmap == null) {
        Log.e(
            RENDER_TAG,
            "Failed to decode timed image layer bitmap. Image bytes size: ${imageBytes.size}. " +
                    "The image data may be corrupted or in an unsupported format."
        )
        return
    }
    
    val scaledOverlay =
        Bitmap.createScaledBitmap(overlayBitmap, videoWidth, videoHeight, true)
    
    Log.d(RENDER_TAG, "Timed overlay bitmap created: ${scaledOverlay.width}x${scaledOverlay.height}")

    // Create a transparent bitmap to use when outside the time range
    val transparentBitmap = Bitmap.createBitmap(videoWidth, videoHeight, Bitmap.Config.ARGB_8888)

    // Create a timed bitmap overlay that only appears between startTimeUs and endTimeUs
    val bitmapOverlay = object : BitmapOverlay() {
        override fun getBitmap(presentationTimeUs: Long): Bitmap {
            val isInRange = presentationTimeUs in startTimeUs..endTimeUs
            Log.d(RENDER_TAG, "getBitmap called: presentationTimeUs=${presentationTimeUs / 1_000_000.0}s, inRange=$isInRange")
            
            // Only return the actual bitmap if we're within the specified time range
            return if (isInRange) {
                scaledOverlay
            } else {
                transparentBitmap
            }
        }
    }

    val overlayEffect = OverlayEffect(listOf(bitmapOverlay))

    videoEffects += overlayEffect
    
    Log.d(RENDER_TAG, "Timed overlay effect added successfully. Total effects: ${videoEffects.size}")
    Log.d(RENDER_TAG, "=== Finished applyTimedImageLayer ===")
}

