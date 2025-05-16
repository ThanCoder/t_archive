# t_archive

```Dart
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
```
