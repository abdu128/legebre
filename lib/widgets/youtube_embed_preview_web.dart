import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class YouTubeEmbedPreview extends StatefulWidget {
  const YouTubeEmbedPreview({super.key, required this.videoId});

  final String videoId;

  @override
  State<YouTubeEmbedPreview> createState() => _YouTubeEmbedPreviewState();
}

class _YouTubeEmbedPreviewState extends State<YouTubeEmbedPreview> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'youtube-embed-${widget.videoId}-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src =
            'https://www.youtube.com/embed/${widget.videoId}?autoplay=1&rel=0&modestbranding=1&playsinline=1'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..allowFullscreen = true;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
