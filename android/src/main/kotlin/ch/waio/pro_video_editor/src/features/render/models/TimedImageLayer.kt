package ch.waio.pro_video_editor.src.features.render.models

/**
 * Represents an image layer that should appear at a specific time range in a video.
 *
 * @property imageBytes The image data as a byte array (PNG, JPG, etc.)
 * @property startTimeUs The start time in microseconds when the overlay should appear
 * @property endTimeUs The end time in microseconds when the overlay should disappear
 */
data class TimedImageLayer(
    val imageBytes: ByteArray,
    val startTimeUs: Long,
    val endTimeUs: Long
) {
    /**
     * Checks if this layer should be visible at the given time.
     *
     * @param currentTimeUs The current playback time in microseconds
     * @return true if the layer should be visible, false otherwise
     */
    fun isVisibleAt(currentTimeUs: Long): Boolean {
        return currentTimeUs in startTimeUs..endTimeUs
    }

    /**
     * Custom equals implementation that properly compares byte arrays.
     * Auto-generated equals() doesn't handle ByteArray correctly.
     */
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as TimedImageLayer

        if (!imageBytes.contentEquals(other.imageBytes)) return false
        if (startTimeUs != other.startTimeUs) return false
        if (endTimeUs != other.endTimeUs) return false

        return true
    }

    /**
     * Custom hashCode implementation for ByteArray.
     */
    override fun hashCode(): Int {
        var result = imageBytes.contentHashCode()
        result = 31 * result + startTimeUs.hashCode()
        result = 31 * result + endTimeUs.hashCode()
        return result
    }

    companion object {
        /**
         * Creates a TimedImageLayer from a map of parameters (typically from Flutter).
         *
         * @param map A map containing 'imageBytes', 'startTimeUs', and 'endTimeUs'
         * @return A TimedImageLayer instance or null if required fields are missing
         */
        fun fromMap(map: Map<String, Any?>): TimedImageLayer? {
            val imageBytes = map["imageBytes"] as? ByteArray ?: return null
            val startTimeUs = (map["startTimeUs"] as? Number)?.toLong() ?: return null
            val endTimeUs = (map["endTimeUs"] as? Number)?.toLong() ?: return null

            return TimedImageLayer(
                imageBytes = imageBytes,
                startTimeUs = startTimeUs,
                endTimeUs = endTimeUs
            )
        }

        /**
         * Creates a list of TimedImageLayer from a list of maps.
         *
         * @param list A list of maps, each containing timed image layer data
         * @return A list of TimedImageLayer instances (skips invalid entries)
         */
        fun fromMapList(list: List<Map<String, Any?>>): List<TimedImageLayer> {
            return list.mapNotNull { fromMap(it) }
        }
    }
}

