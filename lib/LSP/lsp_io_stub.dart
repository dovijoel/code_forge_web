// Web platform stub - dart:io is not available on web
// This file is imported when dart.library.io is NOT available

import 'dart:async';

/// Returns -1 on web since process ID is not available
int getPlatformPid() => -1;

/// Indicates whether stdio-based LSP is supported on this platform
bool get isStdioLspSupported => false;

/// Stub Process class for web - throws UnsupportedError on any operation
/// This allows the code to compile but fail at runtime if someone tries to use LspStdioConfig on web
class ProcessStub {
  ProcessStub._();
  
  int get pid => throw UnsupportedError('Process is not supported on web');
  Future<int> get exitCode => throw UnsupportedError('Process is not supported on web');
  Stream<List<int>> get stdout => throw UnsupportedError('Process is not supported on web');
  Stream<List<int>> get stderr => throw UnsupportedError('Process is not supported on web');
  IOSink get stdin => throw UnsupportedError('Process is not supported on web');
  bool kill([dynamic signal]) => throw UnsupportedError('Process is not supported on web');
  
  static Future<ProcessStub> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    dynamic mode,
  }) async {
    throw UnsupportedError(
      'Process.start is not supported on web. '
      'LspStdioConfig cannot be used in web environments. '
      'Use LspSocketConfig with a WebSocket-based LSP server proxy instead.',
    );
  }
}

/// Stub IOSink for web
abstract class IOSink implements StreamSink<List<int>> {
  void write(Object? object);
  void writeln([Object? object = '']);
  void writeAll(Iterable objects, [String separator = '']);
  void writeCharCode(int charCode);
  @override
  void add(List<int> data);
  @override
  void addError(Object error, [StackTrace? stackTrace]);
  @override
  Future addStream(Stream<List<int>> stream);
  Future flush();
  @override
  Future close();
  @override
  Future get done;
}

/// Stub File class for web - throws UnsupportedError on any operation
class FileStub {
  final String path;
  FileStub(this.path);
  
  Future<String> readAsString() async {
    throw UnsupportedError(
      'File operations are not supported on web. '
      'File path: $path',
    );
  }
  
  String readAsStringSync() {
    throw UnsupportedError(
      'File operations are not supported on web. '
      'File path: $path',
    );
  }
  
  void writeAsStringSync(String contents) {
    throw UnsupportedError(
      'File operations are not supported on web. '
      'File path: $path',
    );
  }
  
  Future<FileStub> writeAsString(String contents) async {
    throw UnsupportedError(
      'File operations are not supported on web. '
      'File path: $path',
    );
  }
}

/// Stub Platform class for web
class PlatformStub {
  PlatformStub._();
  
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;
}

// Export stubs with original names for compatibility
typedef Process = ProcessStub;
typedef File = FileStub;
typedef Platform = PlatformStub;
