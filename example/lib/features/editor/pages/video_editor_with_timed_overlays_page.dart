import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/designs/grounded/grounded_design.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/core/platform/io/io_helper.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import '/core/constants/example_constants.dart';
import '/core/managers/timed_layer_manager.dart';
import '/core/models/timed_layer_model.dart';
import '/features/editor/widgets/video_initializing_widget.dart';
import '/features/editor/widgets/timed_overlay_widget.dart';
import '../widgets/demo_build_stickers.dart';
import '../widgets/preview_video.dart';
import '../widgets/video_progress_alert.dart';

/// Video editor with time-based overlay synchronization
class VideoEditorWithTimedOverlaysPage extends StatefulWidget {
  const VideoEditorWithTimedOverlaysPage({super.key});

  @override
  State<VideoEditorWithTimedOverlaysPage> createState() =>
      _VideoEditorWithTimedOverlaysPageState();
}

class _VideoEditorWithTimedOverlaysPageState
    extends State<VideoEditorWithTimedOverlaysPage> {
  final _mainEditorBarKey = GlobalKey<GroundedMainBarState>();
  final bool _useMaterialDesign =
      platformDesignMode == ImageEditorDesignMode.material;
  final _overlayKey = GlobalKey();

  /// Manages timed layers
  final _layerManager = TimedLayerManager();

  final _outputFormat = VideoOutputFormat.mp4;
  final VideoEditorConfigs _videoConfigs = const VideoEditorConfigs(
    initialMuted: true,
    initialPlay: false,
    isAudioSupported: true,
    minTrimDuration: Duration(seconds: 7),
    enablePlayButton: true,
  );

  bool _isSeeking = false;
  TrimDurationSpan? _durationSpan;
  TrimDurationSpan? _tempDurationSpan;
  ProVideoController? _proVideoController;
  List<ImageProvider>? _thumbnails;
  late VideoMetadata _videoMetadata;
  final int _thumbnailCount = 7;
  final _video = EditorVideo.asset(kVideoEditorExampleAssetPath);
  String? _outputPath;
  Duration _videoGenerationTime = Duration.zero;
  late VideoPlayerController _videoController;
  final _taskId = DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _addDemoLayers(); // Add some demo layers
  }

  @override
  void dispose() {
    _videoController.dispose();
    _layerManager.dispose();
    super.dispose();
  }

  /// Add demo layers for testing
  void _addDemoLayers() {
    // Add an arrow at second 2
    _layerManager.addLayer(
      TimedLayer(
        id: 'arrow_1',
        type: TimedLayerType.arrow,
        startMs: 2000, // Appears at 2 seconds
        endMs: 3000, // Disappears at 3 seconds
        content: 'arrow',
        position: const Offset(0.3, -0.2),
        color: Colors.red,
        scale: 1.5,
      ),
    );

    // Add text at second 1 to 4
    _layerManager.addLayer(
      TimedLayer(
        id: 'text_1',
        type: TimedLayerType.text,
        startMs: 1000,
        endMs: 4000,
        content: 'Sample Text',
        position: const Offset(0, 0.3),
        color: Colors.yellow,
        scale: 1.2,
      ),
    );

    // Add emoji at second 5
    _layerManager.addLayer(
      TimedLayer(
        id: 'emoji_1',
        type: TimedLayerType.emoji,
        startMs: 5000,
        endMs: 7000,
        content: '🎉',
        position: const Offset(-0.4, -0.3),
        scale: 2.0,
      ),
    );
  }

  Future<void> _setMetadata() async {
    _videoMetadata = await ProVideoEditor.instance.getMetadata(_video);
  }

  void _generateThumbnails() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      var imageWidth = MediaQuery.sizeOf(context).width /
          _thumbnailCount *
          MediaQuery.devicePixelRatioOf(context);

      List<Uint8List> thumbnailList = [];

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

    _videoController =
        VideoPlayerController.asset(kVideoEditorExampleAssetPath);

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

    // Update layer manager with current position
    _layerManager.setCurrentTime(duration);

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
      _tempDurationSpan = span;
      return;
    }
    _isSeeking = true;

    _proVideoController!.pause();
    _proVideoController!.setPlayTime(_durationSpan!.start);

    await _videoController.pause();
    await _videoController.seekTo(span.start);

    _isSeeking = false;

    if (_tempDurationSpan != null) {
      TrimDurationSpan nextSeek = _tempDurationSpan!;
      _tempDurationSpan = null;
      await _seekToPosition(nextSeek);
    }
  }

  /// Captures the overlay widget as an image for a specific timestamp
  Future<Uint8List?> _captureOverlayAtTime(int timeMs) async {
    // Update layer manager to show overlays for this specific time
    _layerManager.setCurrentTime(Duration(milliseconds: timeMs));

    // Wait for the frame to render
    await Future.delayed(const Duration(milliseconds: 50));

    // Capture the overlay widget
    final boundary = _overlayKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;

    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  /// Generate video with time-based overlays
  Future<void> generateVideo(CompleteParameters parameters) async {
    final stopwatch = Stopwatch()..start();

    unawaited(_videoController.pause());

    // Get the video duration range for export
    final startMs = parameters.startTime?.inMilliseconds ?? 0;
    final endMs = parameters.endTime?.inMilliseconds ??
        _videoMetadata.duration.inMilliseconds;

    // Get all layers that should appear in the exported range
    final layersInRange = _layerManager.getLayersInRange(startMs, endMs);

    debugPrint(
        '📹 Exporting video with ${layersInRange.length} overlay layers');

    // Capture overlay image with ALL layers visible at their respective times
    Uint8List? overlayImage;

    if (layersInRange.isNotEmpty) {
      // For simplicity, capture all overlays at once (they'll all be visible)
      // This creates a composite image with all overlays
      // Alternative: capture at the timestamp with most overlays visible

      // Find the timestamp with the most overlays visible
      final allTimestamps = layersInRange
          .expand((layer) =>
              [layer.startMs, (layer.startMs + layer.endMs) ~/ 2, layer.endMs])
          .toSet()
          .toList()
        ..sort();

      int maxOverlays = 0;
      int bestTimestamp = layersInRange.first.startMs;

      for (final timestamp in allTimestamps) {
        final count = layersInRange
            .where((l) => timestamp >= l.startMs && timestamp < l.endMs)
            .length;
        if (count > maxOverlays) {
          maxOverlays = count;
          bestTimestamp = timestamp;
        }
      }

      debugPrint(
          '📸 Capturing overlays at ${bestTimestamp}ms (${maxOverlays} visible)');
      overlayImage = await _captureOverlayAtTime(bestTimestamp);
    }

    // Combine the captured timed overlays with editor layers (if any)
    Uint8List? finalImageBytes;
    if (overlayImage != null && parameters.layers.isNotEmpty) {
      // Merge both overlay images (timed + editor layers)
      // For now, prioritize timed overlays
      finalImageBytes = overlayImage;
      debugPrint(
          '⚠️  Note: Both timed overlays and editor layers present. Using timed overlays.');
    } else {
      finalImageBytes = overlayImage ??
          (parameters.layers.isNotEmpty ? parameters.image : null);
    }

    var exportModel = RenderVideoModel(
      id: _taskId,
      video: _video,
      outputFormat: _outputFormat,
      enableAudio: _proVideoController?.isAudioEnabled ?? true,
      imageBytes: finalImageBytes,
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
    );

    final directory = await getTemporaryDirectory();
    final now = DateTime.now().millisecondsSinceEpoch;
    _outputPath = await ProVideoEditor.instance.renderVideoToFile(
      '${directory.path}/my_video_$now.mp4',
      exportModel,
    );
    _videoGenerationTime = stopwatch.elapsed;

    // Show info about exported layers
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Video exported with ${layersInRange.length} overlay(s)\n'
            'Duration: ${_videoGenerationTime.inSeconds}s',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green.shade700,
        ),
      );

      debugPrint(
          '✅ Export complete: ${layersInRange.length} overlays included');
    }
  }

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

  int _calculateEmojiColumns(BoxConstraints constraints) =>
      max(1, (_useMaterialDesign ? 6 : 10) / 400 * constraints.maxWidth - 1)
          .floor();

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _proVideoController == null
          ? const VideoInitializingWidget()
          : _buildEditor(),
    );
  }

  Widget _buildEditor() {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          ProImageEditor.video(
            _proVideoController!,
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
              ),
              mainEditorCallbacks: MainEditorCallbacks(
                onStartCloseSubEditor: (value) {
                  _mainEditorBarKey.currentState?.setState(() {});
                },
              ),
              stickerEditorCallbacks: StickerEditorCallbacks(
                onSearchChanged: (value) {
                  debugPrint(value);
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
              videoEditor: _videoConfigs.copyWith(
                playTimeSmoothingDuration: const Duration(milliseconds: 600),
              ),
              designMode: platformDesignMode,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue.shade800,
                  brightness: Brightness.dark,
                ),
              ),
              layerInteraction: const LayerInteractionConfigs(
                hideToolbarOnInteraction: false,
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
                  appBar: (editor, rebuildStream) => null,
                  bottomBar: (editor, rebuildStream, key) => ReactiveWidget(
                    key: key,
                    builder: (context) {
                      return GroundedMainBar(
                        key: _mainEditorBarKey,
                        editor: editor,
                        configs: editor.configs,
                        callbacks: editor.callbacks,
                      );
                    },
                    stream: rebuildStream,
                  ),
                ),
                style: const MainEditorStyle(
                  background: Color(0xFF000000),
                  bottomBarBackground: Color(0xFF161616),
                ),
              ),
              paintEditor: PaintEditorConfigs(
                enableModePixelate: false,
                enableModeBlur: false,
                style: const PaintEditorStyle(
                  background: Color(0xFF000000),
                  bottomBarBackground: Color(0xFF161616),
                  initialStrokeWidth: 5,
                ),
                widgets: PaintEditorWidgets(
                  appBar: (paintEditor, rebuildStream) => null,
                  colorPicker:
                      (paintEditor, rebuildStream, currentColor, setColor) =>
                          null,
                  bottomBar: (editorState, rebuildStream) {
                    return ReactiveWidget(
                      builder: (context) {
                        return GroundedPaintBar(
                            configs: editorState.configs,
                            callbacks: editorState.callbacks,
                            editor: editorState,
                            i18nColor: 'Color',
                            showColorPicker: (currentColor) {
                              Color? newColor;
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: currentColor,
                                      onColorChanged: (color) {
                                        newColor = color;
                                      },
                                    ),
                                  ),
                                  actions: <Widget>[
                                    ElevatedButton(
                                      child: const Text('Got it'),
                                      onPressed: () {
                                        if (newColor != null) {
                                          setState(() =>
                                              editorState.setColor(newColor!));
                                        }
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            });
                      },
                      stream: rebuildStream,
                    );
                  },
                ),
              ),
              textEditor: TextEditorConfigs(
                customTextStyles: [
                  GoogleFonts.roboto(),
                  GoogleFonts.averiaLibre(),
                  GoogleFonts.lato(),
                  GoogleFonts.comicNeue(),
                  GoogleFonts.actor(),
                  GoogleFonts.odorMeanChey(),
                  GoogleFonts.nabla(),
                ],
                style: TextEditorStyle(
                  textFieldMargin: const EdgeInsets.only(top: kToolbarHeight),
                  bottomBarBackground: const Color(0xFF161616),
                  bottomBarMainAxisAlignment: !_useMaterialDesign
                      ? MainAxisAlignment.spaceEvenly
                      : MainAxisAlignment.start,
                ),
                widgets: TextEditorWidgets(
                  appBar: (textEditor, rebuildStream) => null,
                  colorPicker:
                      (textEditor, rebuildStream, currentColor, setColor) =>
                          null,
                  bottomBar: (editorState, rebuildStream) {
                    return ReactiveWidget(
                      builder: (context) {
                        return GroundedTextBar(
                            configs: editorState.configs,
                            callbacks: editorState.callbacks,
                            editor: editorState,
                            i18nColor: 'Color',
                            showColorPicker: (currentColor) {
                              Color? newColor;
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: currentColor,
                                      onColorChanged: (color) {
                                        newColor = color;
                                      },
                                    ),
                                  ),
                                  actions: <Widget>[
                                    ElevatedButton(
                                      child: const Text('Got it'),
                                      onPressed: () {
                                        if (newColor != null) {
                                          setState(() => editorState
                                              .primaryColor = newColor!);
                                        }
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            });
                      },
                      stream: rebuildStream,
                    );
                  },
                  bodyItems: (editorState, rebuildStream) => [
                    ReactiveWidget(
                      stream: rebuildStream,
                      builder: (_) => Padding(
                        padding: const EdgeInsets.only(top: kToolbarHeight),
                        child: GroundedTextSizeSlider(textEditor: editorState),
                      ),
                    ),
                  ],
                ),
              ),
              cropRotateEditor: CropRotateEditorConfigs(
                style: const CropRotateEditorStyle(
                  cropCornerColor: Color(0xFFFFFFFF),
                  cropCornerLength: 36,
                  cropCornerThickness: 4,
                  background: Color(0xFF000000),
                  bottomBarBackground: Color(0xFF161616),
                  helperLineColor: Color(0x25FFFFFF),
                ),
                widgets: CropRotateEditorWidgets(
                  appBar: (cropRotateEditor, rebuildStream) => null,
                  bottomBar: (cropRotateEditor, rebuildStream) =>
                      ReactiveWidget(
                    stream: rebuildStream,
                    builder: (_) => GroundedCropRotateBar(
                      configs: cropRotateEditor.configs,
                      callbacks: cropRotateEditor.callbacks,
                      editor: cropRotateEditor,
                      selectedRatioColor: kImageEditorPrimaryColor,
                    ),
                  ),
                ),
              ),
              filterEditor: FilterEditorConfigs(
                fadeInUpDuration: kGroundedFadeInDuration,
                fadeInUpStaggerDelayDuration: kGroundedFadeInStaggerDelay,
                style: const FilterEditorStyle(
                  filterListSpacing: 7,
                  filterListMargin: EdgeInsets.fromLTRB(8, 0, 8, 8),
                  background: Color(0xFF000000),
                ),
                widgets: FilterEditorWidgets(
                  slider: (editorState, rebuildStream, value, onChanged,
                          onChangeEnd) =>
                      ReactiveWidget(
                    stream: rebuildStream,
                    builder: (_) => Slider(
                      onChanged: onChanged,
                      onChangeEnd: onChangeEnd,
                      value: value,
                      activeColor: Colors.blue.shade200,
                    ),
                  ),
                  appBar: (editorState, rebuildStream) => null,
                  bottomBar: (editorState, rebuildStream) {
                    return ReactiveWidget(
                      builder: (context) {
                        return GroundedFilterBar(
                          configs: editorState.configs,
                          callbacks: editorState.callbacks,
                          editor: editorState,
                          image: _buildVideoPlayer(),
                        );
                      },
                      stream: rebuildStream,
                    );
                  },
                ),
              ),
              tuneEditor: TuneEditorConfigs(
                style: const TuneEditorStyle(
                  background: Color(0xFF000000),
                  bottomBarBackground: Color(0xFF161616),
                ),
                widgets: TuneEditorWidgets(
                  appBar: (editor, rebuildStream) => null,
                  bottomBar: (editorState, rebuildStream) {
                    return ReactiveWidget(
                      builder: (context) {
                        return GroundedTuneBar(
                          configs: editorState.configs,
                          callbacks: editorState.callbacks,
                          editor: editorState,
                        );
                      },
                      stream: rebuildStream,
                    );
                  },
                ),
              ),
              blurEditor: BlurEditorConfigs(
                style: const BlurEditorStyle(
                  background: Color(0xFF000000),
                ),
                widgets: BlurEditorWidgets(
                  appBar: (blurEditor, rebuildStream) => null,
                  bottomBar: (editorState, rebuildStream) {
                    return ReactiveWidget(
                      builder: (context) {
                        return GroundedBlurBar(
                          configs: editorState.configs,
                          callbacks: editorState.callbacks,
                          editor: editorState,
                        );
                      },
                      stream: rebuildStream,
                    );
                  },
                ),
              ),
              emojiEditor: EmojiEditorConfigs(
                checkPlatformCompatibility: !kIsWeb,
                style: EmojiEditorStyle(
                  backgroundColor: Colors.transparent,
                  textStyle: DefaultEmojiTextStyle.copyWith(
                    fontFamily: !kIsWeb
                        ? null
                        : GoogleFonts.notoColorEmoji().fontFamily,
                    fontSize: _useMaterialDesign ? 48 : 30,
                  ),
                  emojiViewConfig: EmojiViewConfig(
                    gridPadding: EdgeInsets.zero,
                    horizontalSpacing: 0,
                    verticalSpacing: 0,
                    recentsLimit: 40,
                    backgroundColor: Colors.transparent,
                    buttonMode: !_useMaterialDesign
                        ? ButtonMode.CUPERTINO
                        : ButtonMode.MATERIAL,
                    loadingIndicator:
                        const Center(child: CircularProgressIndicator()),
                    columns: _calculateEmojiColumns(constraints),
                    emojiSizeMax: !_useMaterialDesign ? 32 : 64,
                    replaceEmojiOnLimitExceed: false,
                  ),
                  bottomActionBarConfig:
                      const BottomActionBarConfig(enabled: false),
                ),
              ),
              i18n: const I18n(
                paintEditor: I18nPaintEditor(
                  changeOpacity: 'Opacity',
                  lineWidth: 'Thickness',
                ),
                textEditor: I18nTextEditor(
                  backgroundMode: 'Mode',
                  textAlign: 'Align',
                ),
              ),
              stickerEditor: StickerEditorConfigs(
                enabled: true,
                builder: (setLayer, scrollController) => DemoBuildStickers(
                    categoryColor: const Color(0xFF161616),
                    setLayer: setLayer,
                    scrollController: scrollController),
              ),
            ),
          ),
          // Overlay the timed layers on top of the video
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
          // Add interactive controls for adding overlays
          Positioned(
            top: 80,
            right: 16,
            child: _buildOverlayControls(),
          ),
        ],
      );
    });
  }

  /// Build interactive controls for adding overlays
  Widget _buildOverlayControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(
            icon: Icons.arrow_forward,
            label: 'Arrow',
            color: Colors.red,
            onTap: _addArrowAtCurrentTime,
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            icon: Icons.text_fields,
            label: 'Text',
            color: Colors.yellow,
            onTap: _addTextAtCurrentTime,
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            icon: Icons.emoji_emotions,
            label: 'Emoji',
            color: Colors.orange,
            onTap: _addEmojiAtCurrentTime,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addArrowAtCurrentTime() {
    final currentMs = _videoController.value.position.inMilliseconds;

    _layerManager.addLayer(
      TimedLayer(
        id: 'arrow_${DateTime.now().microsecondsSinceEpoch}',
        type: TimedLayerType.arrow,
        startMs: currentMs,
        endMs: currentMs + 1000, // Show for 1 second
        content: 'arrow',
        position: const Offset(0.3, -0.2),
        color: Colors.red,
        scale: 1.5,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Arrow added at ${(currentMs / 1000).toStringAsFixed(1)}s',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _addTextAtCurrentTime() {
    final currentMs = _videoController.value.position.inMilliseconds;

    showDialog(
      context: context,
      builder: (context) {
        String text = 'Sample Text';
        return AlertDialog(
          title: const Text('Add Text Overlay'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Text',
              hintText: 'Enter text to display',
            ),
            onChanged: (value) => text = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _layerManager.addLayer(
                  TimedLayer(
                    id: 'text_${DateTime.now().microsecondsSinceEpoch}',
                    type: TimedLayerType.text,
                    startMs: currentMs,
                    endMs: currentMs + 2000, // Show for 2 seconds
                    content: text,
                    position: const Offset(0, 0.3),
                    color: Colors.yellow,
                    scale: 1.2,
                  ),
                );
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Text added at ${(currentMs / 1000).toStringAsFixed(1)}s',
                    ),
                    duration: const Duration(seconds: 1),
                    backgroundColor: Colors.yellow.shade700,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addEmojiAtCurrentTime() {
    final currentMs = _videoController.value.position.inMilliseconds;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Emoji'),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ['😀', '🎉', '❤️', '⭐', '🔥', '👍', '✨', '🎵', '🎬', '📱']
                .map((emoji) => GestureDetector(
                      onTap: () {
                        _layerManager.addLayer(
                          TimedLayer(
                            id: 'emoji_${DateTime.now().microsecondsSinceEpoch}',
                            type: TimedLayerType.emoji,
                            startMs: currentMs,
                            endMs: currentMs + 1500, // Show for 1.5 seconds
                            content: emoji,
                            position: const Offset(-0.4, -0.3),
                            scale: 2.0,
                          ),
                        );
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Emoji added at ${(currentMs / 1000).toStringAsFixed(1)}s',
                            ),
                            duration: const Duration(seconds: 1),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ))
                .toList(),
          ),
        );
      },
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
