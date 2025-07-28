import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class StreamingNotAvailableException implements Exception {
  final String message;
  StreamingNotAvailableException(this.message);

  @override
  String toString() => 'StreamingNotAvailableException: $message';
}

class StreamingService {
  static final _logger = Logger();

  static int _parseResolution(String? res) {
    if (res == null) return 0;
    final match = RegExp(r'(\d+)p').firstMatch(res);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  static Future<Map<String, String>> getStreamingLink({
    required String tmdbId,
    required String title,
    required int releaseYear,
    required String resolution,
    required bool enableSubtitles,
    int? season,
    int? episode,
    String? seasonTmdbId,
    String? episodeTmdbId,
    bool forDownload = false,
  }) async {
    _logger.i('Calling backend for streaming link: $tmdbId');

    final url = Uri.parse('https://moviflxpro.onrender.com/media-links');
    final isShow = season != null && episode != null;

    final body = <String, dynamic>{
      'type': isShow ? 'show' : 'movie',
      'tmdbId': tmdbId,
      'title': title,
      'releaseYear': releaseYear.toString(),
      'resolution': resolution,
      'subtitleLanguage': 'en',
      if (isShow) ...{
        'seasonNumber': season,
        'seasonTmdbId': seasonTmdbId ?? tmdbId,
        'episodeNumber': episode,
        'episodeTmdbId': episodeTmdbId ?? tmdbId,
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        _logger.e('Backend error: ${response.statusCode} ${response.body}');
        throw StreamingNotAvailableException(
          'Failed to get streaming link: ${response.statusCode}',
        );
      }

      final decodedRaw = jsonDecode(response.body);
      if (decodedRaw is! Map<String, dynamic>) {
        _logger.e('Invalid response format: $decodedRaw');
        throw StreamingNotAvailableException('Invalid response format.');
      }

      final decoded = Map<String, dynamic>.from(decodedRaw);
      dynamic raw = decoded['streams'] ?? (decoded.containsKey('stream') ? [decoded['stream']] : null);
      if (raw == null) {
        _logger.e('No streams found: $decoded');
        throw StreamingNotAvailableException('No streaming links available.');
      }

      final streams = List<Map<String, dynamic>>.from(raw);
      if (streams.isEmpty) throw StreamingNotAvailableException('No streams available.');

      Map<String, dynamic> selectedStream;

      if (resolution == "auto") {
        List<Map<String, dynamic>> hls = streams.where((s) {
          final type = s['type'] as String?;
          final url = s['url'] as String?;
          return type == 'm3u8' || (url != null && url.endsWith('.m3u8'));
        }).toList();
        selectedStream = hls.isNotEmpty ? hls.first : streams.first;
      } else {
        selectedStream = streams.first;
      }

      String? playlist;
      String streamType = 'm3u8';
      String streamUrl = '';
      String subtitleUrl = '';

      final playlistEncoded = selectedStream['playlist'] as String?;
      if (playlistEncoded != null && playlistEncoded.startsWith('data:application/vnd.apple.mpegurl;base64,')) {
        final base64Part = playlistEncoded.split(',')[1];
        playlist = utf8.decode(base64Decode(base64Part));

        if (kIsWeb) {
          final bytes = base64Decode(base64Part);
          final blob = html.Blob([bytes], 'application/vnd.apple.mpegurl');
          streamUrl = html.Url.createObjectUrlFromBlob(blob);
        } else {
          final file = File('${(await getTemporaryDirectory()).path}/$tmdbId-playlist.m3u8');
          await file.writeAsString(playlist);
          streamUrl = file.path;
        }
      } else {
        final urlValue = selectedStream['url']?.toString();
        if (urlValue == null || urlValue.isEmpty) {
          throw StreamingNotAvailableException('No stream URL available.');
        }
        streamUrl = urlValue;

        if (streamUrl.endsWith('.m3u8') && forDownload && !kIsWeb) {
          final playlistResponse = await http.get(Uri.parse(streamUrl));
          if (playlistResponse.statusCode == 200) {
            final file = File('${(await getTemporaryDirectory()).path}/$tmdbId-playlist.m3u8');
            await file.writeAsString(playlistResponse.body);
            streamUrl = file.path;
          }
        }
        streamType = streamUrl.endsWith('.mp4') ? 'mp4' : 'm3u8';
      }

      final captionsList = selectedStream['captions'] as List<dynamic>?;
      if (enableSubtitles && captionsList != null && captionsList.isNotEmpty) {
        final selectedCap = captionsList.firstWhere(
          (c) => c['language'] == 'en',
          orElse: () => captionsList.first,
        );

        final srtUrl = selectedCap['url']?.toString() ?? '';
        if (srtUrl.isNotEmpty && !kIsWeb) {
          try {
            final subtitleResponse = await http.get(Uri.parse(srtUrl));
            if (subtitleResponse.statusCode == 200) {
              final srtContent = utf8.decode(subtitleResponse.bodyBytes);
              final vttContent = _convertSrtToVtt(srtContent);

              final vttFile = File('${(await getTemporaryDirectory()).path}/$tmdbId-subtitles.vtt');
              await vttFile.writeAsString(vttContent);

              subtitleUrl = vttFile.path;
            }
          } catch (e) {
            _logger.w('Failed to convert/download subtitles: $e');
          }
        }
      }

      final result = <String, String>{
        'url': streamUrl,
        'type': streamType,
        'title': title,
      };
      if (playlist != null) result['playlist'] = playlist;
      if (subtitleUrl.isNotEmpty) result['subtitleUrl'] = subtitleUrl;

      return result;
    } catch (e, st) {
      _logger.e('Error fetching stream: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Converts SRT subtitles to VTT format.
  static String _convertSrtToVtt(String srtContent) {
    final lines = srtContent.split('\n');
    final buffer = StringBuffer()..writeln('WEBVTT\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (RegExp(r'^\d+$').hasMatch(line)) {
        // Skip subtitle index line
        continue;
      } else if (line.contains('-->')) {
        buffer.writeln(
          line.replaceAll(',', '.'), // Convert SRT time format to VTT
        );
      } else {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trim();
  }
} 


