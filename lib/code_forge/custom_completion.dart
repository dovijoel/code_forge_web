/// Custom completion provider API for code_forge_web.
/// 
/// This API is designed to mirror LSP (Language Server Protocol) types,
/// making it easy to migrate to a WebSocket-based LSP backend later.
/// 
/// Example usage:
/// ```dart
/// controller.registerCompletionProvider(
///   id: 'sql',
///   triggerCharacters: [' ', '.', ',', '('],
///   provider: (params) async {
///     // Use params.textBeforeCursor, params.position, etc.
///     return [
///       CompletionItem(
///         label: 'SELECT',
///         kind: CompletionItemKind.keyword,
///         detail: 'SQL keyword',
///       ),
///     ];
///   },
/// );
/// ```

/// Callback signature for custom completion providers.
/// 
/// The provider receives [CompletionParams] containing context about
/// the cursor position and surrounding text, and returns a list of
/// [CompletionItem]s to display in the suggestion popup.
typedef CompletionProvider = Future<List<CompletionItem>> Function(
  CompletionParams params,
);

/// Parameters passed to a completion provider when completions are requested.
/// 
/// This structure mirrors LSP's `CompletionParams` for future compatibility,
/// with additional convenience fields for text context.
class CompletionParams {
  /// Identifies the document (editor instance).
  final TextDocumentIdentifier textDocument;
  
  /// The cursor position where completion was requested.
  /// Uses 0-based line and character indices (LSP standard).
  final CompletionPosition position;
  
  /// Context about how completion was triggered.
  final CompletionContext? context;
  
  /// The text before the cursor on the current line.
  /// Convenience field for quick prefix matching.
  final String textBeforeCursor;
  
  /// The full text of the current line.
  final String currentLineText;
  
  /// The full text of the document.
  final String fullText;

  const CompletionParams({
    required this.textDocument,
    required this.position,
    this.context,
    required this.textBeforeCursor,
    required this.currentLineText,
    required this.fullText,
  });
}

/// Identifies a text document.
/// Mirrors LSP's TextDocumentIdentifier.
class TextDocumentIdentifier {
  /// The URI of the document (e.g., 'editor://1' or 'file:///path/to/file.sql').
  final String uri;

  const TextDocumentIdentifier({required this.uri});
}

/// A position in a text document.
/// Mirrors LSP's Position using 0-based indices.
class CompletionPosition {
  /// Line number (0-based).
  final int line;
  
  /// Character offset within the line (0-based).
  final int character;

  const CompletionPosition({
    required this.line,
    required this.character,
  });
  
  @override
  String toString() => 'Position(line: $line, character: $character)';
}

/// Context about how completion was triggered.
/// Mirrors LSP's CompletionContext.
class CompletionContext {
  /// How the completion was triggered.
  final CompletionTriggerKind triggerKind;
  
  /// The character that triggered completion (if [triggerKind] is [CompletionTriggerKind.triggerCharacter]).
  final String? triggerCharacter;

  const CompletionContext({
    required this.triggerKind,
    this.triggerCharacter,
  });
}

/// How completion was triggered.
/// Mirrors LSP's CompletionTriggerKind.
enum CompletionTriggerKind {
  /// Completion was manually invoked (e.g., Ctrl+Space).
  invoked,
  
  /// Completion was triggered by a trigger character.
  triggerCharacter,
  
  /// Completion was re-triggered for incomplete completion results.
  triggerForIncompleteCompletions,
}

/// A completion item to be displayed in the suggestion popup.
/// Mirrors LSP's CompletionItem structure.
class CompletionItem {
  /// The label to display in the suggestion list.
  final String label;
  
  /// The kind of completion (keyword, function, variable, etc.).
  final CompletionItemKind? kind;
  
  /// A short description shown next to the label.
  final String? detail;
  
  /// Documentation for the item (shown in expanded view).
  final String? documentation;
  
  /// The text to insert. If not provided, [label] is used.
  final String? insertText;
  
  /// The format of [insertText].
  final InsertTextFormat? insertTextFormat;
  
  /// Sort priority for custom ordering (lower = higher priority).
  /// This is an extension to LSP for custom provider control.
  final int? sortPriority;

  const CompletionItem({
    required this.label,
    this.kind,
    this.detail,
    this.documentation,
    this.insertText,
    this.insertTextFormat,
    this.sortPriority,
  });
  
  /// Gets the text that should be inserted when this item is selected.
  String get textToInsert => insertText ?? label;
}

/// The kind of a completion item.
/// Mirrors LSP's CompletionItemKind.
enum CompletionItemKind {
  text,
  method,
  function,
  constructor,
  field,
  variable,
  classKind,
  interface,
  module,
  property,
  unit,
  value,
  enumKind,
  keyword,
  snippet,
  color,
  file,
  reference,
  folder,
  enumMember,
  constant,
  struct,
  event,
  operator,
  typeParameter,
}

/// The format of insert text.
/// Mirrors LSP's InsertTextFormat.
enum InsertTextFormat {
  /// Plain text, inserted as-is.
  plainText,
  
  /// Snippet with placeholders (e.g., '${1:tableName}').
  snippet,
}

/// Registered completion provider with its configuration.
class RegisteredCompletionProvider {
  /// Unique identifier for this provider.
  final String id;
  
  /// Characters that trigger completion for this provider.
  final List<String> triggerCharacters;
  
  /// The completion provider callback.
  final CompletionProvider provider;

  const RegisteredCompletionProvider({
    required this.id,
    required this.triggerCharacters,
    required this.provider,
  });
}
