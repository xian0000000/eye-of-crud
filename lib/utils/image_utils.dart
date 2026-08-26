import 'dart:convert';
import 'dart:typed_data';

/// Firestore documents cap out at ~1MiB; base64 inflates size by ~33%,
/// so keep the raw image comfortably under that after encoding.
const int maxImageDocBytes = 900 * 1024;

class EncodedImage {
  final String base64;
  final bool tooLarge;
  EncodedImage({required this.base64, required this.tooLarge});
}

EncodedImage encodeImageBytes(Uint8List bytes) {
  final b64 = base64Encode(bytes);
  return EncodedImage(base64: b64, tooLarge: b64.length > maxImageDocBytes);
}
