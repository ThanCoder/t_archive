// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';
import 'dart:typed_data';

class TFileEntryInfo {
  String name;
  int length;
  int offset;
  String path;
  TFileEntryInfo({
    required this.path,
    required this.name,
    required this.length,
    required this.offset,
  });

  Future<Uint8List> readFileData() async {
    final raf = File(path).openSync();
    raf.setPositionSync(offset);
    final bytes = raf.readSync(length);
    raf.closeSync();
    return bytes;
  }

  Future<void> writeFile(
    String outPath, {
    void Function(double progress)? onProgress,
  }) async {
    const chunkSize = 1024 * 1024; // 1MB per chunk
    final outFile = File(outPath).openWrite();
    final raf = await File(path).open();

    await raf.setPosition(offset);

    final buffer = Uint8List(chunkSize);
    int remaining = length;
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
        onProgress(written / length);
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
