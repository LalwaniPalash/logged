import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/muscle_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled GLB contains every renderer entity in the taxonomy', () async {
    final data = await rootBundle.load(muscleModelAssetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    expect(ascii.decode(bytes.sublist(0, 4)), 'glTF');
    expect(ByteData.sublistView(bytes).getUint32(4, Endian.little), 2);
    expect(bytes.lengthInBytes, lessThan(25 * 1024 * 1024));

    final jsonLength = ByteData.sublistView(bytes).getUint32(12, Endian.little);
    final jsonStart = 20;
    final document =
        jsonDecode(
              utf8.decode(bytes.sublist(jsonStart, jsonStart + jsonLength)),
            )
            as Map<String, dynamic>;
    final names = (document['nodes'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((node) => node.containsKey('mesh'))
        .map((node) => node['name'] as String)
        .toSet();

    expect(names, muscleModelEntityNames);
    expect(names, hasLength(47));
  });
}
