import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A simple page to preview images from TimedImageLayer.imageBytes for debugging
class ImagePreviewPage extends StatefulWidget {
  final List<Uint8List> imageBytes;

  /// Creates a [ImagePreviewPage] widget.
  const ImagePreviewPage({
    super.key,
    required this.imageBytes,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  int? _selectedBytesIndex;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    // Load first image if available
    if (widget.imageBytes.isNotEmpty) {
      _loadImageBytes(0);
    }
  }

  void _loadImageBytes(int index) {
    if (index >= 0 && index < widget.imageBytes.length) {
      setState(() {
        _selectedBytesIndex = index;
        _imageBytes = widget.imageBytes[index];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Preview (Debug)'),
      ),
      body: Column(
        children: [
          // Uint8List image bytes list selector
          if (widget.imageBytes.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.imageBytes.length,
                itemBuilder: (context, index) {
                  final bytes = widget.imageBytes[index];
                  final isSelected = _selectedBytesIndex == index;
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ChoiceChip(
                      label: Text(
                        'Image ${index + 1}\n${(bytes.length / 1024).toStringAsFixed(1)} KB',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _loadImageBytes(index);
                        }
                      },
                    ),
                  );
                },
              ),
            ),

          // Image preview
          Expanded(
            child: Center(
              child: _imageBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.imageBytes.isEmpty
                              ? 'No images configured.'
                              : 'Select an image from the list above',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    )
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to display image',
                                style: TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ),

          // Image info
          if (_imageBytes != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedBytesIndex != null) ...[
                      Text(
                        'Source: Uint8List (Direct)',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Index: $_selectedBytesIndex',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                    ]
                  ]),
            ),
        ],
      ),
    );
  }
}
