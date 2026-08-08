/// Normalisation for Japanese licence plates (ナンバープレート).
///
/// Plates are typed by hand and pasted from OCR, so the same plate arrives in
/// several shapes: full-width digits from a Japanese IME (１２－３４), an ideographic
/// space between the 地名 and the 分類番号, a full-width hyphen, stray spacing.
///
/// Without normalisation these are distinct strings, so the duplicate check in
/// `isLicensePlateExists` compares raw text and lets the *same* car be
/// registered twice — once as "品川 300 あ 12-34" and again as
/// "品川　３００　あ　１２－３４". For fleet management that means one vehicle
/// counted twice.
library;

/// Full-width ASCII (Ａ-Ｚ ａ-ｚ ０-９ and punctuation) sits at U+FF01–U+FF5E,
/// exactly 0xFEE0 above its half-width counterpart.
const int _fullWidthOffset = 0xFEE0;

/// Hyphen-like characters that appear in hand-typed plates, mapped to '-'.
const Set<String> _hyphenVariants = {
  '‐', // hyphen
  '‑', // non-breaking hyphen
  '‒', // figure dash
  '–', // en dash
  '—', // em dash
  '―', // horizontal bar (often produced by Japanese IMEs)
  '−', // minus sign
  '－', // full-width hyphen-minus
  'ｰ', // half-width katakana prolonged sound mark
  'ー', // katakana-hiragana prolonged sound mark（ー）
};

/// Returns [input] with full-width characters folded to half-width, hyphen
/// variants unified to '-', and whitespace collapsed to single spaces.
///
/// Kana and kanji are left as they are — the 地名 (品川) and the ひらがな
/// classifier (あ) are meaningful and must not be transformed.
String normalizeLicensePlate(String input) {
  final buffer = StringBuffer();

  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);

    if (_hyphenVariants.contains(ch)) {
      buffer.write('-');
      continue;
    }

    // Ideographic space → normal space.
    if (rune == 0x3000) {
      buffer.write(' ');
      continue;
    }

    // Full-width ASCII → half-width.
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      buffer.write(String.fromCharCode(rune - _fullWidthOffset));
      continue;
    }

    buffer.write(ch);
  }

  // Collapse runs of whitespace and trim the ends.
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Key used to decide whether two plates are the same vehicle.
///
/// Spacing is not part of a plate's identity — "品川300あ12-34" and
/// "品川 300 あ 12-34" are the same car — so all whitespace is removed here.
/// Use this for comparison only; show [normalizeLicensePlate] to the user.
String licensePlateKey(String input) =>
    normalizeLicensePlate(input).replaceAll(' ', '');
