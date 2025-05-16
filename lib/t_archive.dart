import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 't_archive_file.dart';
import 't_archive_response.dart';
import 't_archive_response_file.dart';

class TArchive {
  final Map<String, dynamic> config;
  final List<TArchiveFile> files;
  Uint8List? coverImage;
  int version;
  String mime;
  TArchive({
    required this.config,
    this.mime = 'TZip',
    this.version = 1,
    required this.files,
  });

  factory TArchive.createFiles(
    List<TArchiveFile> files, {
    String mime = 'TZip',
    required Map<String, dynamic> config,
  }) {
    return TArchive(config: config, files: files, mime: mime);
  }

  factory TArchive.createDirectory(
    String path, {
    required Map<String, dynamic> config,
    String mime = 'TZip',
  }) {
    final dir = Directory(path);
    if (!dir.existsSync()) throw Exception('dir not exists!');
    List<TArchiveFile> files = [];

    for (var file in dir.listSync()) {
      if (file.statSync().type != FileSystemEntityType.file) continue;
      files.add(TArchiveFile.fromFile(file.path));
    }
    return TArchive(config: config, files: files, mime: mime);
  }

  Future<void> writeToFile(
    String path, {
    Uint8List? coverImage,
    void Function(String name, double progress)? onProgress,
  }) async {
    final sink = File(path).openWrite();

    // --- MAGIC + VERSION + FLAGS ---
    sink.add(utf8.encode(mime)); // magic
    sink.add([version]); // version

    int flags = 0;
    if (coverImage != null) flags |= 1 << 0;
    sink.add([flags]);

    // --- Optional PNG Cover ---
    if (coverImage != null) {
      final coverSize = ByteData(4)..setUint32(0, coverImage.length);
      sink.add(coverSize.buffer.asUint8List());
      sink.add(coverImage);
    }

    // --- Config JSON ---
    final configJson = utf8.encode(jsonEncode(config));
    final configSize = ByteData(4)..setUint32(0, configJson.length);
    sink.add(configSize.buffer.asUint8List());
    sink.add(configJson);

    // --- File Meta JSON List ---
    final jsonData = files.map((f) => f.toMap()).toList();
    final fileListJson = utf8.encode(jsonEncode(jsonData));
    final fileListSize = ByteData(4)..setUint32(0, fileListJson.length);
    sink.add(fileListSize.buffer.asUint8List());
    sink.add(fileListJson);

    // --- Total file data size for progress tracking ---
    final totalSize = files.fold<int>(0, (sum, f) => sum + f.data.length);
    int writtenSize = 0;

    // --- Write each file ---
    const chunkSize = 1024 * 1024; // 1MB

    for (final f in files) {
      final nameBytes = utf8.encode(f.name);
      final nameLength = ByteData(2)..setUint16(0, nameBytes.length);

      sink.add(nameLength.buffer.asUint8List());
      sink.add(nameBytes);

      // --- Write file content in chunks ---
      final data = f.data;
      int offset = 0;

      while (offset < data.length) {
        final end = (offset + chunkSize).clamp(0, data.length);
        sink.add(data.sublist(offset, end));
        writtenSize += (end - offset);
        offset = end;

        if (onProgress != null) {
          onProgress(f.name, writtenSize / totalSize);
        }

        // await Future.delayed(Duration.zero); // Let UI update
      }
    }

    await sink.flush();
    await sink.close();
  }

  static Future<TArchiveResponse> readArchive(
    String path, {
    String mime = 'TZip',
  }) async {
    final file = File(path);
    final raf = await file.open();
    final reader = ByteData(8);
    int offset = 0;

    // --- MAGIC (4 bytes), VERSION (1), FLAGS (1) ---
    await raf.readInto(reader.buffer.asUint8List(0, 6));
    final magic = utf8.decode(reader.buffer.asUint8List(0, 4));
    if (magic != mime) throw Exception('Invalid format');
    final version = reader.getUint8(4);
    final flags = reader.getUint8(5);
    offset += 6;

    // --- Optional Cover Image ---
    Uint8List? cover;
    if ((flags & 0x01) != 0) {
      await raf.setPosition(offset);
      await raf.readInto(reader.buffer.asUint8List(0, 4));
      final coverSize = reader.getUint32(0);
      offset += 4;

      cover = Uint8List(coverSize);
      await raf.setPosition(offset);
      await raf.readInto(cover);
      offset += coverSize;
    }

    // --- Config JSON ---
    await raf.setPosition(offset);
    await raf.readInto(reader.buffer.asUint8List(0, 4));
    final configSize = reader.getUint32(0);
    offset += 4;

    final configBytes = Uint8List(configSize);
    await raf.setPosition(offset);
    await raf.readInto(configBytes);
    final config = jsonDecode(utf8.decode(configBytes)) as Map<String, dynamic>;
    offset += configSize;

    // --- File List JSON ---
    await raf.setPosition(offset);
    await raf.readInto(reader.buffer.asUint8List(0, 4));
    final fileListSize = reader.getUint32(0);
    offset += 4;

    final fileListJsonBytes = Uint8List(fileListSize);
    await raf.setPosition(offset);
    await raf.readInto(fileListJsonBytes);
    List<dynamic> fileMetaList = jsonDecode(utf8.decode(fileListJsonBytes));
    offset += fileListSize;

    // --- Read Each File Entry ---
    List<TArchiveResponseFile> fileList = [];

    for (final meta in fileMetaList) {
      // Read name length
      await raf.setPosition(offset);
      await raf.readInto(reader.buffer.asUint8List(0, 2));
      final nameLen = reader.getUint16(0);
      offset += 2;

      // Read name bytes
      final nameBytes = Uint8List(nameLen);
      await raf.setPosition(offset);
      await raf.readInto(nameBytes);
      final name = utf8.decode(nameBytes);
      offset += nameLen;

      // Get data size from meta
      final dataSize = meta['size'] as int;
      // final data = Uint8List(dataSize);
      await raf.setPosition(offset);
      // await raf.readInto(data);

      fileList.add(
        TArchiveResponseFile(
          path: path,
          name: name,
          size: dataSize,
          offset: offset,
        ),
      );

      offset += dataSize;
    }

    await raf.close();

    return TArchiveResponse(
      config: config,
      mime: magic,
      version: version,
      coverImage: cover,
      fileMetaList: fileMetaList,
      fileList: fileList,
    );
  }
}
