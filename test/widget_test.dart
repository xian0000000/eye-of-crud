import 'dart:typed_data';

import 'package:eye_of_crud/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodeImageBytes flags oversized images', () {
    final small = encodeImageBytes(Uint8List(10));
    expect(small.tooLarge, isFalse);

    final big = encodeImageBytes(Uint8List(maxImageDocBytes + 1));
    expect(big.tooLarge, isTrue);
  });
}
