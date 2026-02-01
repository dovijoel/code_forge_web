// Native platform implementation - dart:io is available
// This file is imported when dart.library.io IS available

import 'dart:io';

// Re-export dart:io types for use by the library
export 'dart:io' show Process, IOSink, File, Platform;

/// Returns the current process ID on native platforms
int getPlatformPid() => pid;

/// Indicates whether stdio-based LSP is supported on this platform
bool get isStdioLspSupported => true;
