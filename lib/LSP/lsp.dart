import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

part 'lsp_socket.dart';
part 'lsp_stdio.dart';

sealed class LspConfig {
  /// The file path of the document to be processed by the LSP.
  final String filePath;

  /// The language ID of the language.
  ///
  /// languageId depends on the server you are using.
  /// For example, for rust-analyzer give "rust", for pyright-langserver, it is 'python' and so on.
  final String languageId;

  /// The workspace path of the document to be processed by the LSP.
  ///
  /// The workspacePath is the root directory of the project or workspace.
  /// If you are using a single file, you can set it to the parent directory of the file.
  final String workspacePath;

  /// Whether to disable warnings from the LSP server.
  final bool disableWarning;

  /// Whether to disable errors from the LSP server.
  final bool disableError;

  final StreamController<Map<String, dynamic>> _responseController =
      StreamController.broadcast();
  int _nextId = 1;
  final _openDocuments = <String, int>{};

  LspConfig({
    required this.filePath,
    required this.workspacePath,
    required this.languageId,
    this.disableWarning = false,
    this.disableError = false,
  });

  void dispose();

  Future<Map<String, dynamic>> _sendRequest({
    required String method,
    required Map<String, dynamic> params,
  });

  Future<void> _sendNotification({
    required String method,
    required Map<String, dynamic> params,
  });

  /// This method is used to initialize the LSP server.
  ///
  /// This method is used internally by the [CodeForge] widget and calling it directly is not recommended.
  /// It may crash the LSP server if called multiple times.
  Future<void> initialize() async {
    final workspaceUri = Uri.directory(workspacePath).toString();
    final response = await _sendRequest(
      method: 'initialize',
      params: {
        'processId': pid,
        'rootUri': workspaceUri,
        'workspaceFolders': [
          {'uri': workspaceUri, 'name': 'workspace'},
        ],
        'capabilities': {
          'textDocument': {
            'completion': {
              'completionItem': {'snippetSupport': false},
            },
          },
          'hover': {
            'contentFormat': ['markdown'],
          },
        },
      },
    );

    if (response['error'] != null) {
      throw Exception('Initialization failed: ${response['error']}');
    }

    await _sendNotification(method: 'initialized', params: {});
  }

  Map<String, dynamic> _commonParams(int line, int character) {
    return {
      'textDocument': {'uri': Uri.file(filePath).toString()},
      'position': {'line': line, 'character': character},
    };
  }

  /// Opens the document in the LSP server.
  ///
  /// This method is used internally by the [CodeForge] widget and calling it directly is not recommended.
  Future<void> openDocument() async {
    final version = (_openDocuments[filePath] ?? 0) + 1;
    _openDocuments[filePath] = version;
    final String text = await File(filePath).readAsString();
    await _sendNotification(
      method: 'textDocument/didOpen',
      params: {
        'textDocument': {
          'uri': Uri.file(filePath).toString(),
          'languageId': languageId,
          'version': version,
          'text': text,
        },
      },
    );
    await Future.delayed(Duration(milliseconds: 300));
  }

  Future<void> updateDocument(String content) async {
    if (!_openDocuments.containsKey(filePath)) {
      return;
    }

    final version = _openDocuments[filePath]! + 1;
    _openDocuments[filePath] = version;

    await _sendNotification(
      method: 'textDocument/didChange',
      params: {
        'textDocument': {
          'uri': Uri.file(filePath).toString(),
          'version': version,
        },
        'contentChanges': [
          {'text': content},
        ],
      },
    );
  }

  /// Updates the document in the LSP server if there is any change.
  /// ///
  /// This method is used internally by the [CodeForge] widget and calling it directly is not recommended.
  Future<void> closeDocument() async {
    if (!_openDocuments.containsKey(filePath)) return;

    await _sendNotification(
      method: 'textDocument/didClose',
      params: {
        'textDocument': {'uri': Uri.file(filePath).toString()},
      },
    );
    _openDocuments.remove(filePath);
  }

  /// This method is used to get completions at a specific position in the document.
  ///
  /// This method is used internally by the [CodeForge], calling this with appropriate parameters will returns a [List] of [LspCompletion].
  Future<List<LspCompletion>> getCompletions(int line, int character) async {
    List<LspCompletion> completion = [];
    final response = await _sendRequest(
      method: 'textDocument/completion',
      params: _commonParams(line, character),
    );
    for (var item in response['result']['items']) {
      completion.add(
        LspCompletion(
          label: item['label'],
          itemType: CompletionItemType.values.firstWhere(
            (type) => type.value == item['kind'],
            orElse: () => CompletionItemType.text,
          ),
        ),
      );
    }
    return completion;
  }

  /// This method is used to get details at a specific position in the document.
  ///
  /// This method is used internally by the [CodeForge], calling this with appropriate parameters will returns a [String].
  /// If the LSP server does not support hover or the location provided is invalid, it will return an empty string.
  Future<String> getHover(int line, int character) async {
    final response = await _sendRequest(
      method: 'textDocument/hover',
      params: _commonParams(line, character),
    );
    final contents = response['result']?['contents'];
    if (contents == null || contents.isEmpty) return '';
    if (contents is String) return contents;
    if (contents is Map && contents.containsKey('value')) {
      return contents['value'] ?? '';
    }
    if (contents is List && contents.isNotEmpty) {
      return contents
          .map((item) {
            if (item is String) return item;
            if (item is Map && item.containsKey('value')) return item['value'];
            return '';
          })
          .join('\n');
    }
    return '';
  }

  Future<String> getDefinition(int line, int character) async {
    final response = await _sendRequest(
      method: 'textDocument/definition',
      params: _commonParams(line, character),
    );
    if (response['result'] == null || response['result'].isEmpty) return '';
    return response['result'][1]['uri'] ?? '';
  }

  Future<List<dynamic>> getReferences(int line, int character) async {
    final params = _commonParams(line, character);
    params['context'] = {'includeDeclaration': true};
    final response = await _sendRequest(
      method: 'textDocument/references',
      params: params,
    );
    if (response['result'] == null || response['result'].isEmpty) return [];
    return response['result'];
  }

  Stream<Map<String, dynamic>> get responses => _responseController.stream;
}

/// Represents a completion item in the LSP (Language Server Protocol).
/// This class is used internally by the [CodeForge] widget to display completion suggestions.
class LspCompletion {
  /// The label of the completion item, which is displayed in the completion suggestions.
  final String label;

  /// The type of the completion item, which determines the icon and color used to represent it.
  /// The icon is determined by the [completionItemIcons] map.
  final CompletionItemType itemType;

  /// The icon associated with the completion item, determined by its type.
  final Icon icon;

  LspCompletion({required this.label, required this.itemType})
    : icon = Icon(
        completionItemIcons[itemType]!.icon,
        color: completionItemIcons[itemType]!.color,
        size: 18,
      );
}

/// Represents an error in the LSP (Language Server Protocol).
/// This class is used internally by the [CodeForge] widget to display errors in the editor.
class LspErrors {
  /// The severity of the error, which can be one of the following:
  /// - 1: Error
  /// - 2: Warning
  /// - 3: Information
  /// - 4: Hint
  final int severity;

  /// The range of the error in the document, represented as a map with keys 'start' and 'end'.
  /// The 'start' and 'end' keys are maps with 'line' and 'character' keys.
  final Map<String, dynamic> range;

  /// The message describing the error.
  String message;

  LspErrors({
    required this.severity,
    required this.range,
    required this.message,
  });
}

enum CompletionItemType {
  text(1),
  method(2),
  function(3),
  constructor(4),
  field(5),
  variable(6),
  class_(7),
  interface(8),
  module(9),
  property(10),
  unit(11),
  value_(12),
  enum_(13),
  keyword(14),
  snippet(15),
  color(16),
  file(17),
  reference(18),
  folder(19),
  enumMember(20),
  constant(21),
  struct(22),
  event(23),
  operator(24),
  typeParameter(25);

  final int value;
  const CompletionItemType(this.value);
}

Map<CompletionItemType, Icon> completionItemIcons = {
  CompletionItemType.text: Icon(Icons.text_snippet_rounded, color: Colors.grey),
  CompletionItemType.method: Icon(
    CustomIcons.method,
    color: const Color(0xff9e74c0),
  ),
  CompletionItemType.function: Icon(
    CustomIcons.method,
    color: const Color(0xff9e74c0),
  ),
  CompletionItemType.constructor: Icon(
    CustomIcons.method,
    color: const Color(0xff9e74c0),
  ),
  CompletionItemType.field: Icon(
    CustomIcons.field,
    color: const Color(0xff75beff),
  ),
  CompletionItemType.variable: Icon(
    CustomIcons.variable,
    color: const Color(0xff75beff),
  ),
  CompletionItemType.class_: Icon(
    CustomIcons.class_,
    color: const Color(0xffee9d28),
  ),
  CompletionItemType.interface: Icon(CustomIcons.interface, color: Colors.grey),
  CompletionItemType.module: Icon(Icons.folder_special, color: Colors.grey),
  CompletionItemType.property: Icon(Icons.build, color: Colors.grey),
  CompletionItemType.unit: Icon(Icons.view_module, color: Colors.grey),
  CompletionItemType.value_: Icon(Icons.numbers, color: Colors.grey),
  CompletionItemType.enum_: Icon(
    CustomIcons.enum_,
    color: const Color(0xffee9d28),
  ),
  CompletionItemType.keyword: Icon(CustomIcons.keyword, color: Colors.grey),
  CompletionItemType.snippet: Icon(CustomIcons.snippet, color: Colors.grey),
  CompletionItemType.color: Icon(Icons.color_lens, color: Colors.grey),
  CompletionItemType.file: Icon(Icons.insert_drive_file, color: Colors.grey),
  CompletionItemType.reference: Icon(CustomIcons.reference, color: Colors.grey),
  CompletionItemType.folder: Icon(Icons.folder, color: Colors.grey),
  CompletionItemType.enumMember: Icon(
    CustomIcons.enum_,
    color: const Color(0xff75beff),
  ),
  CompletionItemType.constant: Icon(
    CustomIcons.constant,
    color: const Color(0xff75beff),
  ),
  CompletionItemType.struct: Icon(
    CustomIcons.struct,
    color: const Color(0xff75beff),
  ),
  CompletionItemType.event: Icon(
    CustomIcons.event,
    color: const Color(0xffee9d28),
  ),
  CompletionItemType.operator: Icon(CustomIcons.operator, color: Colors.grey),
  CompletionItemType.typeParameter: Icon(
    CustomIcons.parameter,
    color: const Color(0xffee9d28),
  ),
};

class CustomIcons {
  static const IconData method = IconData(0xe900, fontFamily: 'Method');
  static const IconData variable = IconData(0xe900, fontFamily: 'Variable');
  static const IconData class_ = IconData(0xe900, fontFamily: 'Class');
  static const IconData enum_ = IconData(0x900, fontFamily: 'Enum');
  static const IconData keyword = IconData(0x900, fontFamily: 'KeyWord');
  static const IconData reference = IconData(0x900, fontFamily: 'Reference');
  static const IconData constant = IconData(0x900, fontFamily: 'Constant');
  static const IconData struct = IconData(0x900, fontFamily: 'Struct');
  static const IconData event = IconData(0x900, fontFamily: 'Event');
  static const IconData operator = IconData(0x900, fontFamily: 'Operator');
  static const IconData parameter = IconData(0x900, fontFamily: 'Parameter');
  static const IconData snippet = IconData(0x900, fontFamily: 'Snippet');
  static const IconData interface = IconData(0x900, fontFamily: 'Interface');
  static const IconData field = IconData(0x900, fontFamily: 'Field');
}
