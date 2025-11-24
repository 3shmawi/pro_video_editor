import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/managers/timed_layer_manager.dart';
import '../../../core/models/timed_layer_model.dart';

/// Widget providing controls to add timed overlays at current playback position
class LayerControlsWidget extends StatelessWidget {
  final TimedLayerManager layerManager;
  final VideoPlayerController videoController;

  const LayerControlsWidget({
    super.key,
    required this.layerManager,
    required this.videoController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Timed Overlay',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Current time: ${_formatDuration(videoController.value.position)}',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLayerButton(
                context,
                icon: Icons.arrow_forward,
                label: 'Arrow',
                color: Colors.red,
                onPressed: () => _addArrow(context),
              ),
              _buildLayerButton(
                context,
                icon: Icons.text_fields,
                label: 'Text',
                color: Colors.yellow,
                onPressed: () => _addText(context),
              ),
              _buildLayerButton(
                context,
                icon: Icons.emoji_emotions,
                label: 'Emoji',
                color: Colors.orange,
                onPressed: () => _addEmoji(context),
              ),
              _buildLayerButton(
                context,
                icon: Icons.star,
                label: 'Shape',
                color: Colors.blue,
                onPressed: () => _addShape(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLayerList(),
        ],
      ),
    );
  }

  Widget _buildLayerButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildLayerList() {
    return ListenableBuilder(
      listenable: layerManager,
      builder: (context, child) {
        final layers = layerManager.layers;
        
        if (layers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'No layers added yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Layers (${layers.length}):',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...layers.map((layer) => _buildLayerItem(context, layer)),
          ],
        );
      },
    );
  }

  Widget _buildLayerItem(BuildContext context, TimedLayer layer) {
    final startTime = Duration(milliseconds: layer.startMs);
    final endTime = Duration(milliseconds: layer.endMs);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            _getIconForLayerType(layer.type),
            size: 16,
            color: layer.color ?? Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getLayerTitle(layer),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_formatDuration(startTime)} - ${_formatDuration(endTime)}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            color: Colors.blue,
            onPressed: () => _editLayer(context, layer),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete, size: 16),
            color: Colors.red,
            onPressed: () => layerManager.removeLayer(layer.id),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _getLayerTitle(TimedLayer layer) {
    switch (layer.type) {
      case TimedLayerType.text:
        return 'Text: ${layer.content}';
      case TimedLayerType.arrow:
        return 'Arrow';
      case TimedLayerType.emoji:
        return 'Emoji: ${layer.content}';
      case TimedLayerType.shape:
        return 'Shape';
      default:
        return layer.type.toString();
    }
  }

  IconData _getIconForLayerType(TimedLayerType type) {
    switch (type) {
      case TimedLayerType.text:
        return Icons.text_fields;
      case TimedLayerType.arrow:
        return Icons.arrow_forward;
      case TimedLayerType.emoji:
        return Icons.emoji_emotions;
      case TimedLayerType.sticker:
        return Icons.image;
      case TimedLayerType.drawing:
        return Icons.brush;
      case TimedLayerType.shape:
        return Icons.star;
    }
  }

  void _addArrow(BuildContext context) {
    final currentMs = videoController.value.position.inMilliseconds;
    
    layerManager.addLayer(
      TimedLayer(
        id: 'arrow_${DateTime.now().microsecondsSinceEpoch}',
        type: TimedLayerType.arrow,
        startMs: currentMs,
        endMs: currentMs + 1000, // 1 second duration
        content: 'arrow',
        position: const Offset(0.3, -0.2),
        color: Colors.red,
        scale: 1.5,
      ),
    );

    _showSnackbar(context, 'Arrow added at ${_formatDuration(videoController.value.position)}');
  }

  void _addText(BuildContext context) {
    final currentMs = videoController.value.position.inMilliseconds;
    
    // Show dialog to input text
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
                layerManager.addLayer(
                  TimedLayer(
                    id: 'text_${DateTime.now().microsecondsSinceEpoch}',
                    type: TimedLayerType.text,
                    startMs: currentMs,
                    endMs: currentMs + 2000, // 2 seconds duration
                    content: text,
                    position: const Offset(0, 0.3),
                    color: Colors.yellow,
                    scale: 1.2,
                  ),
                );
                Navigator.pop(context);
                _showSnackbar(context, 'Text added');
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addEmoji(BuildContext context) {
    final currentMs = videoController.value.position.inMilliseconds;
    
    // Show emoji picker
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Emoji'),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ['😀', '🎉', '❤️', '⭐', '🔥', '👍', '✨', '🎵']
                .map((emoji) => GestureDetector(
                      onTap: () {
                        layerManager.addLayer(
                          TimedLayer(
                            id: 'emoji_${DateTime.now().microsecondsSinceEpoch}',
                            type: TimedLayerType.emoji,
                            startMs: currentMs,
                            endMs: currentMs + 1500, // 1.5 seconds duration
                            content: emoji,
                            position: const Offset(-0.4, -0.3),
                            scale: 2.0,
                          ),
                        );
                        Navigator.pop(context);
                        _showSnackbar(context, 'Emoji added');
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

  void _addShape(BuildContext context) {
    final currentMs = videoController.value.position.inMilliseconds;
    
    layerManager.addLayer(
      TimedLayer(
        id: 'shape_${DateTime.now().microsecondsSinceEpoch}',
        type: TimedLayerType.shape,
        startMs: currentMs,
        endMs: currentMs + 2000, // 2 seconds duration
        content: 'rectangle',
        position: const Offset(0.4, 0.2),
        color: Colors.blue,
        scale: 1.0,
      ),
    );

    _showSnackbar(context, 'Shape added');
  }

  void _editLayer(BuildContext context, TimedLayer layer) {
    showDialog(
      context: context,
      builder: (context) {
        int startMs = layer.startMs;
        int endMs = layer.endMs;

        return AlertDialog(
          title: const Text('Edit Layer Timing'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Start Time (seconds)'),
                    subtitle: Slider(
                      value: startMs / 1000,
                      min: 0,
                      max: videoController.value.duration.inMilliseconds / 1000,
                      divisions: 100,
                      label: '${(startMs / 1000).toStringAsFixed(1)}s',
                      onChanged: (value) {
                        setState(() => startMs = (value * 1000).round());
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('End Time (seconds)'),
                    subtitle: Slider(
                      value: endMs / 1000,
                      min: startMs / 1000,
                      max: videoController.value.duration.inMilliseconds / 1000,
                      divisions: 100,
                      label: '${(endMs / 1000).toStringAsFixed(1)}s',
                      onChanged: (value) {
                        setState(() => endMs = (value * 1000).round());
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                layerManager.updateLayer(
                  layer.id,
                  layer.copyWith(startMs: startMs, endMs: endMs),
                );
                Navigator.pop(context);
                _showSnackbar(context, 'Layer timing updated');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final milliseconds = duration.inMilliseconds % 1000;
    return '${seconds}s ${(milliseconds / 100).round()}';
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

