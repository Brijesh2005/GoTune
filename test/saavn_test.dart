import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/services/saavn_api_service.dart';
import 'package:gotune/utils/html_unescape.dart';

void main() {
  group('SaavnApiService & Model Tests', () {
    final saavnService = SaavnApiService();

    test('decrypts Saavn encrypted media URL into 320kbps URL', () {
      const encrypted =
          'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDytWwlsHMWu0of8ELnm9OVKLu8Z4B2mFqeHsaz5HjTmZASlvgUQz71cBw7tS9a8Gtq';
      final decrypted320 = saavnService.decryptMediaUrl(encrypted, quality: '320');
      final decrypted160 = saavnService.decryptMediaUrl(encrypted, quality: '160');

      expect(decrypted320, isNotNull);
      expect(decrypted320!.endsWith('_320.mp4'), isTrue);
      expect(decrypted320.startsWith('https://aac.saavncdn.com/'), isTrue);

      expect(decrypted160, isNotNull);
      expect(decrypted160!.endsWith('_160.mp4'), isTrue);
    });

    test('HtmlUnescape cleans HTML entities properly', () {
      expect(HtmlUnescape.unescape('Gehra Hua (From &quot;Dhurandhar&quot;)'),
          'Gehra Hua (From "Dhurandhar")');
      expect(HtmlUnescape.unescape('Rock &amp; Roll'), 'Rock & Roll');
      expect(HtmlUnescape.unescape('It&#039;s My Life'), "It's My Life");
    });

    test('parses JioSaavn song JSON into Track model', () {
      final sampleJson = {
        'id': 'test_song_40QbaX8a',
        'title': 'Hangover (From &quot;Kick&quot;)',
        'subtitle': 'Meet Bros Anjjan, Salman Khan, Shreya Ghoshal - Kick',
        'image': 'https://c.saavncdn.com/801/Kick-Hindi-2014-150x150.jpg',
        'language': 'hindi',
        'year': '2014',
        'play_count': '30000000',
        'more_info': {
          'duration': '377',
          'album': 'Kick',
          'artistMap': {
            'primary_artists': [
              {'name': 'Meet Bros Anjjan'},
              {'name': 'Salman Khan'},
              {'name': 'Shreya Ghoshal'},
            ],
          },
        },
      };

      const streamUrl = 'https://aac.saavncdn.com/801/test_320.mp4';
      final track = Track.fromSaavnJson(sampleJson, decryptedStreamUrl: streamUrl);

      expect(track.id, 'test_song_40QbaX8a');
      expect(track.title, 'Hangover (From "Kick")');
      expect(track.artist, 'Meet Bros Anjjan, Salman Khan, Shreya Ghoshal');
      expect(track.provider, 'saavn');
      expect(track.durationSeconds, 377);
      expect(track.genre, 'Hindi');
      expect(track.streamInfo.directStreamUrl, streamUrl);
      expect(track.bestArtworkUrl, 'https://c.saavncdn.com/801/Kick-Hindi-2014-500x500.jpg');

      final mediaItem = track.toMediaItem();
      expect(mediaItem.extras?['provider'], 'saavn');
      expect(mediaItem.extras?['streamUrl'], streamUrl);
    });
  });
}
