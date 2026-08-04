class File {
  final String path;
  File(this.path);
  bool existsSync() => false;
}
