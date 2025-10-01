/// Pre-defined video quality presets for common export scenarios.
///
/// Each preset defines standard resolution and bitrate combinations optimized
/// for different use cases, from high-quality 4K exports to web-optimized
/// low-quality videos.
enum VideoQualityPreset {
  /// Ultra High Definition (3840x2160)
  ///
  /// Best for: Professional content, theatrical displays
  /// - Resolution: 3840x2160
  /// - Bitrate: 45 Mbps
  ultra4K,

  /// 4K resolution (3840x2160)
  ///
  /// Best for: High-quality content, large screens
  /// - Resolution: 3840x2160
  /// - Bitrate: 35 Mbps
  k4,

  /// Full HD High Quality (1920x1080)
  ///
  /// Best for: High-quality social media, YouTube
  /// - Resolution: 1920x1080
  /// - Bitrate: 16 Mbps
  p1080High,

  /// Full HD Standard Quality (1920x1080)
  ///
  /// Best for: Standard social media, streaming
  /// - Resolution: 1920x1080
  /// - Bitrate: 8 Mbps
  p1080,

  /// HD High Quality (1280x720)
  ///
  /// Best for: Social media stories, streaming
  /// - Resolution: 1280x720
  /// - Bitrate: 5 Mbps
  p720High,

  /// HD Standard Quality (1280x720)
  ///
  /// Best for: Mobile viewing, web uploads
  /// - Resolution: 1280x720
  /// - Bitrate: 3 Mbps
  p720,

  /// Standard Definition (854x480)
  ///
  /// Best for: Fast uploads, limited bandwidth
  /// - Resolution: 854x480
  /// - Bitrate: 2.5 Mbps
  p480,

  /// Low Quality (640x360)
  ///
  /// Best for: Preview videos, very limited bandwidth
  /// - Resolution: 640x360
  /// - Bitrate: 1 Mbps
  low,

  /// Custom quality (user-defined settings)
  ///
  /// Use this when you want to specify your own bitrate and resolution
  custom,
}
