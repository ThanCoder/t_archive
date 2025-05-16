// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';
import 'dart:typed_data';

class TArchiveResponseFile {
  String name;
  int size;
  int offset;
  String path;
  TArchiveResponseFile({
    required this.path,
    required this.name,
    required this.size,
    required this.offset,
  });

  static Future<Uint8List> readFileAtOffset(
    RandomAccessFile raf,
    int offset,
    int size,
  ) async {
    final data = Uint8List(size);
    await raf.setPosition(offset);

    int total = 0;
    while (total < size) {
      final read = await raf.readInto(data, total, size);
      if (read == 0) break;
      total += read;
    }

    return data;
  }

  Future<void> writeFile(
    String outPath, {
    void Function(double progress)? onProgress,
  }) async {
    const chunkSize = 1024 * 1024; // 1MB per chunk
    final outFile = await File(outPath).openWrite();
    final raf = await File(path).open();

    await raf.setPosition(offset);

    final buffer = Uint8List(chunkSize);
    int remaining = size;
    int written = 0;

    while (remaining > 0) {
      final toRead = remaining > chunkSize ? chunkSize : remaining;
      final read = await raf.readInto(buffer, 0, toRead);
      if (read == 0) break;
      outFile.add(buffer.sublist(0, read));
      remaining -= read;
      written += read;

      //progress
      if (onProgress != null) {
        onProgress(written / size);
      }
    }

    await outFile.close();
    await raf.close();
  }

  @override
  String toString() {
    return name;
  }
}
