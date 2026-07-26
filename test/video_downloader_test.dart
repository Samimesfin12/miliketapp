import 'package:esl_learning_flutter/backend/services/video_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds fallback Google Drive download URLs for a file id', () {
    final urls = VideoDownloader.driveCandidateUrls('abc123');

    expect(urls.first, 'https://drive.google.com/uc?export=download&id=abc123');
    expect(
      urls,
      contains(
        'https://drive.google.com/uc?export=download&id=abc123&confirm=t',
      ),
    );
    expect(
      urls,
      contains('https://docs.google.com/uc?export=download&id=abc123'),
    );
  });
}
