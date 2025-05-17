import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:t_archive/constants.dart';

import 't_archive_file.dart';
import 't_archive_header.dart';
import 't_file_entry_info.dart';

class TArchive {
  final Map<String, dynamic> config;
  final List<TArchiveFile> files;
  Uint8List? coverImage;
  int version;
  String mime;
  TArchive({
    required this.config,
    this.mime = tArchiveMime,
    this.version = tArchiveVersion,
    required this.files,
  });

  factory TArchive.createFiles(
    List<TArchiveFile> files, {
    String mime = tArchiveMime,
    Map<String, dynamic> config = const {'creator': 'thanCoder'},
  }) {
    return TArchive(config: config, files: files, mime: mime);
  }

  factory TArchive.createDirectory(
    String path, {
    Map<String, dynamic> config = const {'creator': 'thanCoder'},
    String mime = tArchiveMime,
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
    final file = File(path);
    final sink = file.openWrite();

    // --- MAGIC + VERSION + FLAGS ---
    sink.add(utf8.encode(mime)); // magic
    sink.add([version]);

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

    // --- File Index Section (names, offsets, lengths) ---
    // final indexStart = await file.length(); // save index start position
    // final fileCount = files.length;

    // placeholder for file index
    final fileIndex = BytesBuilder();
    int currentOffset = 0;

    for (final f in files) {
      final nameBytes = utf8.encode(f.name);
      final nameLen = ByteData(2)..setUint16(0, nameBytes.length);
      final offsetBytes = ByteData(8)..setInt64(0, currentOffset);
      final lengthBytes = ByteData(8)..setInt64(0, f.data.length);

      fileIndex.add(nameLen.buffer.asUint8List());
      fileIndex.add(nameBytes);
      fileIndex.add(offsetBytes.buffer.asUint8List());
      fileIndex.add(lengthBytes.buffer.asUint8List());

      currentOffset += f.data.length;
    }

    final indexBytes = fileIndex.toBytes();
    final indexSize = ByteData(4)..setUint32(0, indexBytes.length);
    sink.add(indexSize.buffer.asUint8List());
    sink.add(indexBytes);

    // --- Write Actual File Data ---
    int writtenSize = 0;
    final totalSize = files.fold<int>(0, (sum, f) => sum + f.data.length);

    for (final f in files) {
      final data = f.data;
      const chunkSize = 1024 * 1024;
      int offset = 0;

      while (offset < data.length) {
        final end = (offset + chunkSize).clamp(0, data.length);
        sink.add(data.sublist(offset, end));
        writtenSize += (end - offset);
        offset = end;

        if (onProgress != null) {
          onProgress(f.name, writtenSize / totalSize);
        }
      }
    }

    await sink.flush();
    await sink.close();
  }

  static Future<TArchiveHeader> readHeader(
    String path, {
    String mime = tArchiveMime,
  }) async {
    final raf = File(path).openSync();

    int pos = 0;

    // --- MAGIC ---
    final magicBytes = raf.readSync(4); // adjust if your `mime` is longer
    final magic = utf8.decode(magicBytes);
    if (magic != mime) throw Exception('invalid MIME type');
    pos += magicBytes.length;

    // --- VERSION ---
    final version = raf.readByteSync();
    pos++;

    // --- FLAGS ---
    final flags = raf.readByteSync();
    pos++;

    // --- Optional Cover ---
    Uint8List? coverImage;
    if ((flags & (1 << 0)) != 0) {
      final coverSizeBytes = raf.readSync(4);
      final coverSize = ByteData.sublistView(coverSizeBytes).getUint32(0);
      coverImage = raf.readSync(coverSize);
      pos += 4 + coverSize;
    }

    // --- Config JSON ---
    final configSizeBytes = raf.readSync(4);
    final configSize = ByteData.sublistView(configSizeBytes).getUint32(0);
    final configBytes = raf.readSync(configSize);
    final config = jsonDecode(utf8.decode(configBytes));
    pos += 4 + configSize;

    // --- Index Section ---
    final indexSizeBytes = raf.readSync(4);
    final indexSize = ByteData.sublistView(indexSizeBytes).getUint32(0);
    final indexBytes = raf.readSync(indexSize);
    pos += 4 + indexSize;

    final files = <TFileEntryInfo>[];

    int offset = 0;
    int currentFileDataStart = pos; // total so far = where file data starts

    while (offset < indexBytes.length) {
      final nameLen = ByteData.sublistView(
        indexBytes,
        offset,
        offset + 2,
      ).getUint16(0);
      offset += 2;

      final name = utf8.decode(indexBytes.sublist(offset, offset + nameLen));
      offset += nameLen;

      final fileOffset = ByteData.sublistView(
        indexBytes,
        offset,
        offset + 8,
      ).getInt64(0);
      offset += 8;

      final fileLength = ByteData.sublistView(
        indexBytes,
        offset,
        offset + 8,
      ).getInt64(0);
      offset += 8;

      files.add(
        TFileEntryInfo(
          path: path,
          name: name,
          length: fileLength,
          offset: currentFileDataStart + fileOffset,
        ),
      );
    }

    raf.closeSync();

    return TArchiveHeader(
      mime: magic,
      version: version,
      flags: flags,
      coverImage: coverImage,
      config: config,
      files: files,
    );
  }

  static Future<void> deleteFile(
    String archivePath, {
    required String filename,
  }) async {
    final header = await readHeader(archivePath);
    final oldFile = File(archivePath);
    final tempFile = File('.$archivePath.tmp');
    final sink = tempFile.openWrite();

    // --- Write Header ---
    sink.add(utf8.encode(header.mime));
    sink.add([header.version]);
    sink.add([header.flags]);

    if (header.coverImage != null) {
      final coverSize = ByteData(4)..setUint32(0, header.coverImage!.length);
      sink.add(coverSize.buffer.asUint8List());
      sink.add(header.coverImage!);
    }

    final configBytes = utf8.encode(jsonEncode(header.config));
    final configSize = ByteData(4)..setUint32(0, configBytes.length);
    sink.add(configSize.buffer.asUint8List());
    sink.add(configBytes);

    // --- Prepare Index + Data ---
    final indexBuilder = BytesBuilder();
    int currentOffset = 0;

    final updatedFiles = <TFileEntryInfo>[];

    for (final entry in header.files) {
      if (entry.name == filename) {
        continue; // skip this one = delete
      }

      final data = await entry.readFileData();

      // Build index
      final nameBytes = utf8.encode(entry.name);
      final nameLen = ByteData(2)..setUint16(0, nameBytes.length);
      final offsetBytes = ByteData(8)..setInt64(0, currentOffset);
      final lengthBytes = ByteData(8)..setInt64(0, data.length);

      indexBuilder.add(nameLen.buffer.asUint8List());
      indexBuilder.add(nameBytes);
      indexBuilder.add(offsetBytes.buffer.asUint8List());
      indexBuilder.add(lengthBytes.buffer.asUint8List());

      // updatedFiles.add(FileEntryInfo(entry.name, currentOffset, data.length));
      updatedFiles.add(
        TFileEntryInfo(
          path: entry.path,
          name: entry.name,
          length: entry.length,
          offset: entry.offset,
        ),
      );
      currentOffset += data.length;
    }

    // Write index section
    final indexBytes = indexBuilder.toBytes();
    final indexSize = ByteData(4)..setUint32(0, indexBytes.length);
    sink.add(indexSize.buffer.asUint8List());
    sink.add(indexBytes);

    // Write file data
    for (final file in updatedFiles) {
      // final data = await readFileData(archivePath, file.offset, file.length);
      final data = await file.readFileData();
      sink.add(data);
    }

    await sink.flush();
    await sink.close();

    await oldFile.delete();
    await tempFile.rename(archivePath);
  }
}
