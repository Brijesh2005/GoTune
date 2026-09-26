/// Helper to unescape common HTML entities in music track titles and descriptions.
class HtmlUnescape {
  static final Map<String, String> _entities = {
    '&quot;': '"',
    '&amp;': '&',
    '&#039;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
    '&#x2F;': '/',
    '&#47;': '/',
    '&#x27;': "'",
  };

  static String unescape(String? text) {
    if (text == null || text.isEmpty) return '';
    var result = text;
    _entities.forEach((entity, replacement) {
      result = result.replaceAll(entity, replacement);
    });
    // Replace any remaining numeric character entities if any (e.g. &#123;)
    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null) {
        return String.fromCharCode(code);
      }
      return match.group(0)!;
    });
    return result.trim();
  }
}
