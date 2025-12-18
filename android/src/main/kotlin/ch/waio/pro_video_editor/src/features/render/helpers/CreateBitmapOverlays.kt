import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import ch.waio.pro_video_editor.src.features.render.models.TimedImageLayer
import ch.waio.pro_video_editor.src.features.render.utils.getRotatedVideoDimensions
import java.io.File

/**
 * Creates a static bitmap overlay that appears for the entire duration of the video.
 *
 * @param inputFile The input video file
 * @param imageBytes The image data as a byte array
 * @param rotationDegrees The rotation degrees of the video
 * @param cropWidth The crop width (if any)
 * @param cropHeight The crop height (if any)
 * @param scaleX The horizontal scale factor (if any)
 * @param scaleY The vertical scale factor (if any)
 * @return A BitmapOverlay or null if the bitmap cannot be decoded
 */
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

    Log.d(RENDER_TAG, "Creating static Image-Layer: Size $videoWidth x $videoHeight")

    val overlayBitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

    if (overlayBitmap == null) {
        Log.e(
            RENDER_TAG,
            "Failed to decode image layer bitmap. Image bytes size: ${imageBytes.size}. " +
                    "The image data may be corrupted or in an unsupported format."
        )
        return null
    }

    val scaledOverlay = Bitmap.createScaledBitmap(overlayBitmap, videoWidth, videoHeight, true)

    return BitmapOverlay.createStaticBitmapOverlay(scaledOverlay)
}

/**
 * Creates a timed bitmap overlay that appears only during a specific time range.
 *
 * @param inputFile The input video file
 * @param timedLayer The timed image layer model containing image data and timing info
 * @param rotationDegrees The rotation degrees of the video
 * @param cropWidth The crop width (if any)
 * @param cropHeight The crop height (if any)
 * @param scaleX The horizontal scale factor (if any)
 * @param scaleY The vertical scale factor (if any)
 * @return A BitmapOverlay or null if the bitmap cannot be decoded
 */
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

    Log.d(RENDER_TAG, "=== Creating timed bitmap overlay ===")
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
        "Creating Timed Image-Layer: Size ${videoWidth}x${videoHeight}, " +
                "Time Range: ${startTimeUs / 1_000_000.0}s - ${endTimeUs / 1_000_000.0}s"
    )

    val overlayBitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

    if (overlayBitmap == null) {
        Log.e(
            RENDER_TAG,
            "Failed to decode timed image layer bitmap. Image bytes size: ${imageBytes.size}. " +
                    "The image data may be corrupted or in an unsupported format."
        )
        return null
    }

    val scaledOverlay = Bitmap.createScaledBitmap(overlayBitmap, videoWidth, videoHeight, true)

    Log.d(RENDER_TAG, "Timed overlay bitmap created: ${scaledOverlay.width}x${scaledOverlay.height}")

    // Create a transparent bitmap to use when outside the time range
    val transparentBitmap = Bitmap.createBitmap(videoWidth, videoHeight, Bitmap.Config.ARGB_8888)

    // Create a timed bitmap overlay that only appears between startTimeUs and endTimeUs
    val bitmapOverlay = object : BitmapOverlay() {
        override fun getBitmap(presentationTimeUs: Long): Bitmap {
            val isInRange = presentationTimeUs in startTimeUs..endTimeUs
            
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

