import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/core/models/timed_layers/timed_paint_layer.dart';
import 'package:pro_image_editor/core/models/timed_layers/timed_text_layer.dart';
import 'package:pro_image_editor/features/main_editor/services/ffmpeg_export_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/core/platform/io/io_helper.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import '/features/editor/widgets/video_initializing_widget.dart';
import '../widgets/preview_video.dart';
import '../widgets/video_progress_alert.dart';

/// A sample page demonstrating how to use the video-editor.
class VideoEditorBasicExamplePage extends StatefulWidget {
  /// Creates a [VideoEditorBasicExamplePage] widget.
  const VideoEditorBasicExamplePage({super.key});

  @override
  State<VideoEditorBasicExamplePage> createState() =>
      _VideoEditorBasicExamplePageState();
}

class _VideoEditorBasicExamplePageState
    extends State<VideoEditorBasicExamplePage> {
  /// The target format for the exported video.
  final _outputFormat = VideoOutputFormat.mp4;

  /// Video editor configuration settings.
  late final VideoEditorConfigs _videoConfigs = const VideoEditorConfigs(
    initialMuted: false,
    initialPlay: false,
    isAudioSupported: true,
    minTrimDuration: Duration(seconds: 7),
  );

  /// Indicates whether a seek operation is in progress.
  bool _isSeeking = false;

  /// Stores the currently selected trim duration span.
  TrimDurationSpan? _durationSpan;

  /// Temporarily stores a pending trim duration span.
  TrimDurationSpan? _tempDurationSpan;

  /// Controls video playback and trimming functionalities.
  ProVideoController? _proVideoController;

  /// Stores generated thumbnails for the trimmer bar and filter background.
  List<ImageProvider>? _thumbnails;

  /// Holds information about the selected video.
  ///
  /// This will be populated via [_setMetadata].
  late VideoMetadata _videoMetadata;

  /// Number of thumbnails to generate across the video timeline.
  final int _thumbnailCount = 7;

  /// The video currently loaded in the editor.
  final _video = EditorVideo.network(
      'https://firebasestorage.googleapis.com/v0/b/athlepad-development/o/videos%2F3iog22PGQthr19jS4cptBT0NUcW2%2FChGEzLco9nqS0EUF7LRN.mp4?alt=media&token=e2bb0abb-f48f-46a6-b4c8-345719b95791');

  String? _outputPath;

  /// The duration it took to generate the exported video.
  Duration _videoGenerationTime = Duration.zero;
  late VideoPlayerController _videoController;

  final _taskId = DateTime.now().microsecondsSinceEpoch.toString();

  /// Stream controllers for FFmpeg progress tracking
  StreamController<double>? _audioProgressController;
  StreamController<double>? _videoBubbleProgressController;

  @override
  void initState() {
    super.initState();
    // Initialize stream controllers early so they're available when dialog is shown
    _audioProgressController = StreamController<double>.broadcast();
    _videoBubbleProgressController = StreamController<double>.broadcast();
    _audioProgressController?.add(-1);
    _videoBubbleProgressController?.add(-1);
    if (kDebugMode) {
      print('Stream controllers initialized in initState');
      print('Audio controller: $_audioProgressController');
      print('Video bubble controller: $_videoBubbleProgressController');
    }
    _initializePlayer();
  }

  @override
  void dispose() {
    _videoController.dispose();
    _audioProgressController?.close();
    _videoBubbleProgressController?.close();
    super.dispose();
  }

  /// Loads and sets [_videoMetadata] for the given [_video].
  Future<void> _setMetadata() async {
    _videoMetadata = await ProVideoEditor.instance.getMetadata(_video);
  }

  /// Generates thumbnails for the given [_video].
  void _generateThumbnails() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      var imageWidth = MediaQuery.sizeOf(context).width /
          _thumbnailCount *
          MediaQuery.devicePixelRatioOf(context);

      List<Uint8List> thumbnailList = [];

      /// On android `getKeyFrames` is a way faster than `getThumbnails` but
      /// the timestamps are more "random". If you want the best results i
      /// recommend you to use only `getThumbnails`.
      if (!kIsWeb && Platform.isAndroid) {
        thumbnailList = await ProVideoEditor.instance.getKeyFrames(
          KeyFramesConfigs(
            video: _video,
            outputSize: Size.square(imageWidth),
            boxFit: ThumbnailBoxFit.cover,
            maxOutputFrames: _thumbnailCount,
            outputFormat: ThumbnailFormat.jpeg,
          ),
        );
      } else {
        final duration = _videoMetadata.duration;
        final segmentDuration = duration.inMilliseconds / _thumbnailCount;

        thumbnailList = await ProVideoEditor.instance.getThumbnails(
          ThumbnailConfigs(
            video: _video,
            outputSize: Size.square(imageWidth),
            boxFit: ThumbnailBoxFit.cover,
            timestamps: List.generate(_thumbnailCount, (i) {
              final midpointMs = (i + 0.5) * segmentDuration;
              return Duration(milliseconds: midpointMs.round());
            }),
            outputFormat: ThumbnailFormat.jpeg,
          ),
        );
      }

      List<ImageProvider> temporaryThumbnails =
          thumbnailList.map(MemoryImage.new).toList();

      /// Optional precache every thumbnail
      var cacheList =
          temporaryThumbnails.map((item) => precacheImage(item, context));
      await Future.wait(cacheList);
      _thumbnails = temporaryThumbnails;

      if (_proVideoController != null) {
        _proVideoController!.thumbnails = _thumbnails;
      }
    });
  }

  void _initializePlayer() async {
    await _setMetadata();
    _generateThumbnails();

    _videoController = VideoPlayerController.networkUrl(Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/athlepad-development/o/videos%2F3iog22PGQthr19jS4cptBT0NUcW2%2FChGEzLco9nqS0EUF7LRN.mp4?alt=media&token=e2bb0abb-f48f-46a6-b4c8-345719b95791'));

    await Future.wait([
      _videoController.initialize(),
      _videoController.setLooping(false),
      _videoController.setVolume(_videoConfigs.initialMuted ? 0 : 100),
      _videoConfigs.initialPlay
          ? _videoController.play()
          : _videoController.pause(),
    ]);
    if (!mounted) return;

    _proVideoController = ProVideoController(
      videoPlayer: _buildVideoPlayer(),
      initialResolution: _videoMetadata.resolution,
      videoDuration: _videoMetadata.duration,
      fileSize: _videoMetadata.fileSize,
      thumbnails: _thumbnails,
    );

    _videoController.addListener(_onDurationChange);

    setState(() {});
  }

  void _onDurationChange() {
    var totalVideoDuration = _videoMetadata.duration;
    var duration = _videoController.value.position;
    _proVideoController!.setPlayTime(duration);

    if (_durationSpan != null && duration >= _durationSpan!.end) {
      _seekToPosition(_durationSpan!);
    } else if (duration >= totalVideoDuration) {
      _seekToPosition(
        TrimDurationSpan(start: Duration.zero, end: totalVideoDuration),
      );
    }
  }

  Future<void> _seekToPosition(TrimDurationSpan span) async {
    _durationSpan = span;

    if (_isSeeking) {
      _tempDurationSpan = span; // Store the latest seek request
      return;
    }
    _isSeeking = true;

    _proVideoController!.pause();
    _proVideoController!.setPlayTime(_durationSpan!.start);

    await _videoController.pause();
    await _videoController.seekTo(span.start);

    _isSeeking = false;

    // Check if there's a pending seek request
    if (_tempDurationSpan != null) {
      TrimDurationSpan nextSeek = _tempDurationSpan!;
      _tempDurationSpan = null; // Clear the pending seek
      await _seekToPosition(nextSeek); // Process the latest request
    }
  }

  /// Generates the final video based on the given [parameters].
  ///
  /// Applies blur, color filters, cropping, rotation, flipping, and trimming
  /// before exporting using FFmpeg. Measures and stores the generation time.
 Future<void> generateVideo(
    CompleteParameters parameters,
  ) async {
    // Extract audio and video bubble layers first to determine what controllers we need
    final audioLayers = parameters.layers.whereType<AudioLayer>().toList();
    final hasAudioLayers = audioLayers.isNotEmpty;

    final videoBubbleLayers =
        parameters.layers.whereType<VideoBubbleLayer>().toList();
    final hasVideoBubbleLayers = videoBubbleLayers.isNotEmpty;

    // Reset stream controllers with initial 0 progress
    // Controllers are already initialized in initState
    if (hasAudioLayers) {
      _audioProgressController?.add(0.0);
    }
    if (hasVideoBubbleLayers) {
      _videoBubbleProgressController?.add(0.0);
    }

    final stopwatch = Stopwatch()..start();

    unawaited(_videoController.pause());

    // Extract timed image layers (from text and paint layers)
    final timedImageLayers = timedImageLayersMapper(parameters);
    final hasTimedImageLayers = timedImageLayers.isNotEmpty;

    // Check if native rendering is needed
    final needsNativeRendering = hasTimedImageLayers ||
        parameters.isTransformed ||
        parameters.blur > 0 ||
        parameters.colorFilters.isNotEmpty ||
        parameters.startTime != null ||
        parameters.endTime != null;

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
        blur: parameters.blur,
        colorMatrixList: parameters.colorFilters,
        startTime: parameters.startTime,
        endTime: parameters.endTime,
        transform: parameters.isTransformed
            ? ExportTransform(
                width: parameters.cropWidth,
                height: parameters.cropHeight,
                rotateTurns: parameters.rotateTurns,
                x: parameters.cropX,
                y: parameters.cropY,
                flipX: parameters.flipX,
                flipY: parameters.flipY,
              )
            : null,
        // bitrate: _videoMetadata.bitrate,
      );

      _outputPath = await ProVideoEditor.instance.renderVideoToFile(
        intermediateOutput,
        exportModel,
      );
    } else {
      // If no native rendering is needed, we still need to use the original video
      // as the base for audio/video bubble merging
      if (hasAudioLayers || hasVideoBubbleLayers) {
        _outputPath = await _video.safeFilePath();
      }
    }

    final ffmpegService = FfmpegExportService();
    final videoDurationMs = _videoMetadata.duration.inMilliseconds;

    // Stage 2: Audio merging (if needed)
    if (hasAudioLayers) {
      final directory = await getTemporaryDirectory();
      final audioOutput =
          '${directory.path}/audio_merged_${DateTime.now().millisecondsSinceEpoch}.mp4';

      _outputPath = await ffmpegService.mergeAudioIntoVideo(
        inputVideoPath: _outputPath!,
        audioLayers: audioLayers,
        outputPath: audioOutput,
        videoDurationMs: videoDurationMs,
        keepOriginalAudio: parameters.keepOriginalAudio,
        onProgress: (progress) {
          _audioProgressController?.add(progress);
          if (kDebugMode) {
            print(
                'FFmpeg audio progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );
    }

    // Stage 3: Video bubble merging (if needed)
    if (hasVideoBubbleLayers) {
      final directory = await getTemporaryDirectory();
      final finalOutput =
          '${directory.path}/video_bubbles_${DateTime.now().millisecondsSinceEpoch}.mp4';

      _outputPath = await ffmpegService.mergeVideoBubblesIntoVideo(
        inputVideoPath: _outputPath!,
        videoBubbleLayers: videoBubbleLayers,
        outputPath: finalOutput,
        videoDurationMs: videoDurationMs,
        onProgress: (progress) {
          _videoBubbleProgressController?.add(progress);
          if (kDebugMode) {
            print(
                'FFmpeg video bubble progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );
    }

    _videoGenerationTime = stopwatch.elapsed;
  }

  List<TimedImageLayer> timedImageLayersMapper(CompleteParameters parameter) {
    if (parameter.layerCaptures == null ||
        parameter.layerCaptures?.isEmpty == true) {
      if (kDebugMode) print('🔴 No layer captures found');
      return [];
    }

    if (kDebugMode) {
      print('========================================');
      print('📦 Processing ${parameter.layerCaptures!.length} layer captures');
    }

    List<TimedImageLayer> timedImageLayers = [];
    for (final layerCapture in parameter.layerCaptures!) {
      final layer = layerCapture.layer;
      if (layer is TimedTextLayer) {
        final timedLayer = TimedImageLayer(
          imageBytes: layerCapture.imageBytes,
          startTime: Duration(milliseconds: layer.startTime),
          endTime: Duration(milliseconds: layer.endTime),
        );
        timedImageLayers.add(timedLayer);
        if (kDebugMode) {
          print('✅ Text Layer ${timedImageLayers.length}: ${layer.startTime / 1000}s-${layer.endTime / 1000}s, bytes: ${layerCapture.imageBytes.length}');
        }
      } else if (layer is TimedPaintLayer) {
        final timedLayer = TimedImageLayer(
          imageBytes: layerCapture.imageBytes,
          startTime: Duration(milliseconds: layer.startTime),
          endTime: Duration(milliseconds: layer.endTime),
        );
        timedImageLayers.add(timedLayer);
        if (kDebugMode) {
          print('✅ Paint Layer ${timedImageLayers.length}: ${layer.startTime / 1000}s-${layer.endTime / 1000}s, bytes: ${layerCapture.imageBytes.length}');
        }
      }
    }
    
    if (kDebugMode) {
      print('📊 Total timed layers created: ${timedImageLayers.length}');
      print('========================================');
    }
    
    return timedImageLayers;
  }


  /// Closes the video editor and opens a preview screen if a video was
  /// exported.
  ///
  /// If [_outputPath] is available, it navigates to [PreviewVideo].
  /// Afterwards, it pops the current editor page.
  void onCloseEditor(EditorMode editorMode) async {
    if (editorMode != EditorMode.main) return Navigator.pop(context);
    if (_outputPath != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewVideo(
            filePath: _outputPath!,
            generationTime: _videoGenerationTime,
          ),
        ),
      );
      _outputPath = null;
    } else {
      return Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _proVideoController == null
          ? const VideoInitializingWidget()
          : _buildEditor(),
    );
  }

  final _editor = GlobalKey<ProImageEditorState>();

  Widget _buildEditor() {
    return ProImageEditor.video(
      _proVideoController!,
      key: _editor,
      callbacks: ProImageEditorCallbacks(
        onCompleteWithParameters: generateVideo,
        onCloseEditor: onCloseEditor,
        videoEditorCallbacks: VideoEditorCallbacks(
          onPause: _videoController.pause,
          onPlay: _videoController.play,
          onMuteToggle: (isMuted) {
            _videoController.setVolume(isMuted ? 0 : 100);
          },
          onTrimSpanUpdate: (durationSpan) {
            if (_videoController.value.isPlaying) {
              _proVideoController!.pause();
            }
          },
          onTrimSpanEnd: _seekToPosition,
          onSeek: (position) async {
            // Pause first
            await _videoController.pause();
            // Seek the actual video player
            await _videoController.seekTo(position);
            // Update ProVideoController's play time
            _proVideoController!.setPlayTime(position);
          },
        ),
      ),
      configs: ProImageEditorConfigs(
        dialogConfigs: DialogConfigs(
          widgets: DialogWidgets(
            loadingDialog: (message, configs) => VideoProgressAlert(
              taskId: _taskId,
            ),
          ),
        ),
        mainEditor: MainEditorConfigs(
          widgets: MainEditorWidgets(
            removeLayerArea: (
              removeAreaKey,
              editor,
              rebuildStream,
              isLayerBeingTransformed,
            ) =>
                VideoEditorRemoveArea(
              removeAreaKey: removeAreaKey,
              editor: editor,
              rebuildStream: rebuildStream,
              isLayerBeingTransformed: isLayerBeingTransformed,
            ),
          ),
        ),
        paintEditor: const PaintEditorConfigs(
          /// Blur and pixelate are not supported.
          enableModePixelate: false,
          enableModeBlur: false,
        ),
        videoEditor: _videoConfigs.copyWith(
          playTimeSmoothingDuration: const Duration(milliseconds: 600),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Center(
      child: AspectRatio(
        aspectRatio: _videoController.value.size.aspectRatio,
        child: VideoPlayer(
          _videoController,
        ),
      ),
    );
  }
}
