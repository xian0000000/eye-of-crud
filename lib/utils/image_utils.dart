import 'dart:convert';
import 'dart:typed_data';

/// Photos are stored inline as base64 in the board item's own RTDB node
/// (no Cloud Storage, to stay on the free Spark plan) — base64 inflates
/// size by ~33%, so keep the raw image small to limit database
/// size/bandwidth usage.
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
