import 'package:flutter_test/flutter_test.dart';
import 'package:code_forge_web/code_forge.dart';
import 'package:code_forge_web/code_forge/custom_completion.dart';

void main() {
  group('Custom Completion API', () {
    group('CompletionItem', () {
      test('can be created with minimal parameters', () {
        final item = CompletionItem(label: 'SELECT');
        expect(item.label, 'SELECT');
        expect(item.kind, isNull);
        expect(item.detail, isNull);
      });

      test('can be created with all parameters', () {
        final item = CompletionItem(
          label: 'SELECT',
          kind: CompletionItemKind.keyword,
          detail: 'SQL keyword',
          documentation: 'Retrieves data from a table',
          insertText: 'SELECT ',
          insertTextFormat: InsertTextFormat.plainText,
          sortPriority: 1,
        );
        expect(item.label, 'SELECT');
        expect(item.kind, CompletionItemKind.keyword);
        expect(item.detail, 'SQL keyword');
        expect(item.documentation, 'Retrieves data from a table');
        expect(item.insertText, 'SELECT ');
        expect(item.insertTextFormat, InsertTextFormat.plainText);
        expect(item.sortPriority, 1);
      });
    });

    group('CompletionPosition', () {
      test('uses 0-based line and character (LSP standard)', () {
        final pos = CompletionPosition(line: 0, character: 5);
        expect(pos.line, 0);
        expect(pos.character, 5);
      });
    });

    group('CompletionContext', () {
      test('can represent manual invocation', () {
        final context = CompletionContext(
          triggerKind: CompletionTriggerKind.invoked,
        );
        expect(context.triggerKind, CompletionTriggerKind.invoked);
        expect(context.triggerCharacter, isNull);
      });

      test('can represent trigger character invocation', () {
        final context = CompletionContext(
          triggerKind: CompletionTriggerKind.triggerCharacter,
          triggerCharacter: '.',
        );
        expect(context.triggerKind, CompletionTriggerKind.triggerCharacter);
        expect(context.triggerCharacter, '.');
      });
    });

    group('CompletionParams', () {
      test('contains all necessary info for completion', () {
        final params = CompletionParams(
          textDocument: TextDocumentIdentifier(uri: 'editor://1'),
          position: CompletionPosition(line: 5, character: 10),
          context: CompletionContext(
            triggerKind: CompletionTriggerKind.triggerCharacter,
            triggerCharacter: ' ',
          ),
          textBeforeCursor: 'SELECT ',
          currentLineText: 'SELECT FROM',
          fullText: 'SELECT FROM users',
        );
        
        expect(params.textDocument.uri, 'editor://1');
        expect(params.position.line, 5);
        expect(params.position.character, 10);
        expect(params.context?.triggerCharacter, ' ');
        expect(params.textBeforeCursor, 'SELECT ');
        expect(params.currentLineText, 'SELECT FROM');
        expect(params.fullText, 'SELECT FROM users');
      });
    });

    group('CodeForgeController completion registration', () {
      late CodeForgeController controller;

      setUp(() {
        controller = CodeForgeController();
      });

      tearDown(() {
        controller.dispose();
      });

      test('can register a completion provider', () {
        bool providerCalled = false;
        
        controller.registerCompletionProvider(
          id: 'sql',
          triggerCharacters: [' ', '.', ',', '('],
          provider: (params) async {
            providerCalled = true;
            return [
              CompletionItem(label: 'SELECT', kind: CompletionItemKind.keyword),
            ];
          },
        );
        
        expect(controller.hasCompletionProvider('sql'), isTrue);
        expect(providerCalled, isFalse); // Not called until triggered
      });

      test('can unregister a completion provider', () {
        controller.registerCompletionProvider(
          id: 'sql',
          triggerCharacters: [' '],
          provider: (params) async => [],
        );
        
        expect(controller.hasCompletionProvider('sql'), isTrue);
        
        controller.unregisterCompletionProvider('sql');
        
        expect(controller.hasCompletionProvider('sql'), isFalse);
      });

      test('can check trigger characters', () {
        controller.registerCompletionProvider(
          id: 'sql',
          triggerCharacters: [' ', '.', ',', '('],
          provider: (params) async => [],
        );
        
        expect(controller.isTriggerCharacter(' '), isTrue);
        expect(controller.isTriggerCharacter('.'), isTrue);
        expect(controller.isTriggerCharacter('x'), isFalse);
      });

      test('can get completions from provider', () async {
        controller.registerCompletionProvider(
          id: 'sql',
          triggerCharacters: [' '],
          provider: (params) async {
            return [
              CompletionItem(label: 'SELECT', kind: CompletionItemKind.keyword, sortPriority: 1),
              CompletionItem(label: 'FROM', kind: CompletionItemKind.keyword, sortPriority: 2),
            ];
          },
        );
        
        final params = CompletionParams(
          textDocument: TextDocumentIdentifier(uri: 'editor://test'),
          position: CompletionPosition(line: 0, character: 7),
          context: CompletionContext(
            triggerKind: CompletionTriggerKind.triggerCharacter,
            triggerCharacter: ' ',
          ),
          textBeforeCursor: 'SELECT ',
          currentLineText: 'SELECT ',
          fullText: 'SELECT ',
        );
        
        final completions = await controller.getCompletions(params);
        
        expect(completions, hasLength(2));
        expect(completions[0].label, 'SELECT'); // Priority 1 comes first
        expect(completions[1].label, 'FROM');   // Priority 2 comes second
      });

      test('sorts completions alphabetically when same priority', () async {
        controller.registerCompletionProvider(
          id: 'sql',
          triggerCharacters: [' '],
          provider: (params) async {
            return [
              CompletionItem(label: 'SELECT', kind: CompletionItemKind.keyword),
              CompletionItem(label: 'FROM', kind: CompletionItemKind.keyword),
              CompletionItem(label: 'WHERE', kind: CompletionItemKind.keyword),
            ];
          },
        );
        
        final params = CompletionParams(
          textDocument: TextDocumentIdentifier(uri: 'editor://test'),
          position: CompletionPosition(line: 0, character: 0),
          context: CompletionContext(
            triggerKind: CompletionTriggerKind.invoked,
          ),
          textBeforeCursor: '',
          currentLineText: '',
          fullText: '',
        );
        
        final completions = await controller.getCompletions(params);
        
        expect(completions, hasLength(3));
        // Without explicit priority, items sort alphabetically
        expect(completions[0].label, 'FROM');
        expect(completions[1].label, 'SELECT');
        expect(completions[2].label, 'WHERE');
      });
    });
  });
}
