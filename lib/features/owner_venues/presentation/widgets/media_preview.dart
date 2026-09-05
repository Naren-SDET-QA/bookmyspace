import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../venues/domain/media_item.dart';

Future<void> showMediaPreview(BuildContext context, MediaItem item) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(child: _MediaPreviewPage(item: item)),
  );
}

class _MediaPreviewPage extends StatelessWidget {
  const _MediaPreviewPage({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(item.kind == MediaKind.video ? 'Video' : '3D model'),
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
    body: item.kind == MediaKind.video
        ? _VideoPreview(url: item.url)
        : _ModelPreview(url: item.url),
  );
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.url});
  final String url;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _controller.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      _error = Object();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _RetryPreview(
        message: 'Video could not be loaded. Try again.',
        onRetry: () async {
          await _controller.dispose();
          setState(() => _error = null);
          await _load();
        },
      );
    }
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          VideoProgressIndicator(_controller, allowScrubbing: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () => setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                }),
              ),
              IconButton(
                icon: Icon(
                  _controller.value.volume == 0
                      ? Icons.volume_off
                      : Icons.volume_up,
                ),
                onPressed: () => _controller.setVolume(
                  _controller.value.volume == 0 ? 1 : 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelPreview extends StatelessWidget {
  const _ModelPreview({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => ModelViewer(
    src: url,
    alt: '3D venue model',
    autoRotate: true,
    cameraControls: true,
    disableZoom: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
  );
}

class _RetryPreview extends StatelessWidget {
  const _RetryPreview({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}
