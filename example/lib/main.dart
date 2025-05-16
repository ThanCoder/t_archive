import 'dart:io';

import 'package:flutter/material.dart';
import 'package:t_archive/t_archive.dart';
import 'package:t_archive/t_archive_file.dart';

void main() async {
  final tArchive = TArchive.createFiles(
    [TArchiveFile.fromFile('')],
    config: {},
    mime: 'custom mime type',
  );
  // TArchive.createFiles([TArchiveFile('name', Uint8List(0))], config: {});

  //save
  tArchive.writeToFile(
    'savepath.bin',
    coverImage: File('cover.png').readAsBytesSync(),
    onProgress: (name, progress) {},
  );

  //read
  final archive = await TArchive.readArchive(
    'savepath.bin',
    mime: 'check custom mime',
  );
  print(archive.config);
  print(archive.fileMetaList);
  print(archive.fileList);
  if (archive.coverImage != null) {
    //you can save
    File('out-cover.png').writeAsBytesSync(archive.coverImage!);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: Placeholder()));
  }
}
