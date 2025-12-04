import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';

/// Cached highlighting result for a single line
class HighlightedLine {
  final String text;
  final TextSpan? span;
  final int version;
  
  HighlightedLine(this.text, this.span, this.version);
}

/// Serializable span data for isolate communication
class _SpanData {
  final String text;
  final String? scope;
  final List<_SpanData> children;
  
  _SpanData(this.text, this.scope, [this.children = const []]);
}

/// Efficient syntax highlighter with caching and optional isolate support
class SyntaxHighlighter {
  final Mode language;
  final Map<String, TextStyle> editorTheme;
  final TextStyle? baseTextStyle;
  late final String _langId;
  late final Highlight _highlight;
  final Map<int, HighlightedLine> _cache = {};
  final Set<int> _dirtyLines = {};
  int _version = 0;
  static const int isolateThreshold = 500;
  VoidCallback? onHighlightComplete;
  
  SyntaxHighlighter({
    required this.language,
    required this.editorTheme,
    this.baseTextStyle,
    this.onHighlightComplete,
  }) {
    _langId = language.hashCode.toString();
    _highlight = Highlight();
    _highlight.registerLanguage(_langId, language);
  }
  
  /// Mark all lines as dirty (full rehighlight needed)
  void invalidateAll() {
    _cache.clear();
    _version++;
  }
  
  /// Mark specific lines as dirty
  void invalidateLines(Set<int> lines) {
    for (final line in lines) {
      _cache.remove(line);
      _dirtyLines.add(line);
    }
    _version++;
  }
  
  /// Mark a range of lines as dirty (for insertions/deletions)
  void invalidateRange(int startLine, int endLine) {
    for (int i = startLine; i <= endLine; i++) {
      _cache.remove(i);
      _dirtyLines.add(i);
    }
    final keysToRemove = _cache.keys.where((k) => k > endLine).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    _version++;
  }
  
  /// Get highlighted TextSpan for a line, using cache if available
  TextSpan? getLineSpan(int lineIndex, String lineText) {
    final cached = _cache[lineIndex];
    if (cached != null && cached.text == lineText && cached.version == _version) {
      return cached.span;
    }
    
    final span = _highlightLine(lineText);
    _cache[lineIndex] = HighlightedLine(lineText, span, _version);
    _dirtyLines.remove(lineIndex);
    return span;
  }
  
  /// Highlight a single line synchronously
  TextSpan? _highlightLine(String lineText) {
    if (lineText.isEmpty) return null;
    
    try {
      final result = _highlight.highlight(code: lineText, language: _langId);
      final renderer = TextSpanRenderer(baseTextStyle, editorTheme);
      result.render(renderer);
      return renderer.span;
    } catch (e) {
      return TextSpan(text: lineText, style: baseTextStyle);
    }
  }
  
  /// Build a ui.Paragraph for a line with syntax highlighting
  ui.Paragraph buildHighlightedParagraph(
    int lineIndex,
    String lineText,
    ui.ParagraphStyle paragraphStyle,
    double fontSize,
    String? fontFamily,
  ) {
    final span = getLineSpan(lineIndex, lineText);
    final builder = ui.ParagraphBuilder(paragraphStyle);
    
    if (span == null || lineText.isEmpty) {
      final style = _getUiTextStyle(null, fontSize, fontFamily);
      builder.pushStyle(style);
      builder.addText(lineText.isEmpty ? ' ' : lineText);
      final p = builder.build();
      p.layout(const ui.ParagraphConstraints(width: double.infinity));
      return p;
    }
    
    _addTextSpanToBuilder(builder, span, fontSize, fontFamily);
    
    final p = builder.build();
    p.layout(const ui.ParagraphConstraints(width: double.infinity));
    return p;
  }
  
  /// Recursively add TextSpan children to paragraph builder
  void _addTextSpanToBuilder(
    ui.ParagraphBuilder builder,
    TextSpan span,
    double fontSize,
    String? fontFamily,
  ) {
    final style = _textStyleToUiStyle(span.style, fontSize, fontFamily);
    builder.pushStyle(style);
    
    if (span.text != null) {
      builder.addText(span.text!);
    }
    
    if (span.children != null) {
      for (final child in span.children!) {
        if (child is TextSpan) {
          _addTextSpanToBuilder(builder, child, fontSize, fontFamily);
        }
      }
    }
    
    builder.pop();
  }
  
  /// Convert Flutter TextStyle to ui.TextStyle
  ui.TextStyle _textStyleToUiStyle(TextStyle? style, double fontSize, String? fontFamily) {
    final baseStyle = style ?? baseTextStyle ?? editorTheme['root'];
    
    return ui.TextStyle(
      color: baseStyle?.color ?? editorTheme['root']?.color ?? Colors.black,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: baseStyle?.fontWeight,
      fontStyle: baseStyle?.fontStyle,
    );
  }
  
  /// Get ui.TextStyle for a className (kept for compatibility)
  ui.TextStyle _getUiTextStyle(String? className, double fontSize, String? fontFamily) {
    final themeStyle = className != null ? editorTheme[className] : null;
    final baseStyle = themeStyle ?? baseTextStyle ?? editorTheme['root'];
    
    return ui.TextStyle(
      color: baseStyle?.color ?? editorTheme['root']?.color ?? Colors.black,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: baseStyle?.fontWeight,
      fontStyle: baseStyle?.fontStyle,
    );
  }
  
  /// Pre-highlight visible lines asynchronously (for smoother scrolling)
  Future<void> preHighlightLines(
    int startLine,
    int endLine,
    String Function(int) getLineText,
  ) async {
    final linesToProcess = <int, String>{};
    
    for (int i = startLine; i <= endLine; i++) {
      final lineText = getLineText(i);
      final cached = _cache[i];
      if (cached == null || cached.text != lineText || cached.version != _version) {
        linesToProcess[i] = lineText;
      }
    }
    
    if (linesToProcess.isEmpty) return;
    
    if (linesToProcess.length < 50) {
      for (final entry in linesToProcess.entries) {
        final span = _highlightLine(entry.value);
        _cache[entry.key] = HighlightedLine(entry.value, span, _version);
      }
      onHighlightComplete?.call();
      return;
    }
    
    final results = await compute(_highlightLinesInBackground, _BackgroundHighlightData(
      langId: _langId,
      lines: linesToProcess,
      languageMode: language,
      theme: editorTheme,
      baseStyle: baseTextStyle,
    ));
    
    for (final entry in results.entries) {
      final spanData = entry.value;
      final textSpan = spanData != null ? _spanDataToTextSpan(spanData) : null;
      _cache[entry.key] = HighlightedLine(linesToProcess[entry.key]!, textSpan, _version);
    }
    
    onHighlightComplete?.call();
  }
  
  /// Convert serializable span data back to TextSpan
  TextSpan? _spanDataToTextSpan(_SpanData? data) {
    if (data == null) return null;
    
    final style = data.scope != null ? editorTheme[data.scope] : baseTextStyle;
    
    if (data.children.isEmpty) {
      return TextSpan(text: data.text, style: style);
    }
    
    return TextSpan(
      text: data.text.isEmpty ? null : data.text,
      style: style,
      children: data.children.map((c) => _spanDataToTextSpan(c)!).toList(),
    );
  }
  
  /// Dispose resources
  void dispose() {
    _cache.clear();
  }
}

/// Data class for background highlighting
class _BackgroundHighlightData {
  final String langId;
  final Map<int, String> lines;
  final Mode languageMode;
  final Map<String, TextStyle> theme;
  final TextStyle? baseStyle;
  
  _BackgroundHighlightData({
    required this.langId,
    required this.lines,
    required this.languageMode,
    required this.theme,
    this.baseStyle,
  });
}

/// Background highlighting function (runs in isolate via compute)
/// Returns serializable span data since TextSpan can't cross isolate boundaries
Map<int, _SpanData?> _highlightLinesInBackground(_BackgroundHighlightData data) {
  final highlight = Highlight();
  highlight.registerLanguage(data.langId, data.languageMode);
  
  final results = <int, _SpanData?>{};
  
  for (final entry in data.lines.entries) {
    final lineIndex = entry.key;
    final lineText = entry.value;
    
    if (lineText.isEmpty) {
      results[lineIndex] = null;
      continue;
    }
    
    try {
      final result = highlight.highlight(code: lineText, language: data.langId);
      final renderer = TextSpanRenderer(data.baseStyle, data.theme);
      result.render(renderer);
      final span = renderer.span;
      results[lineIndex] = span != null ? _textSpanToSpanData(span) : null;
    } catch (e) {
      results[lineIndex] = _SpanData(lineText, null);
    }
  }
  
  return results;
}

/// Convert TextSpan to serializable span data
_SpanData _textSpanToSpanData(TextSpan span) {
  final children = <_SpanData>[];
  
  if (span.children != null) {
    for (final child in span.children!) {
      if (child is TextSpan) {
        children.add(_textSpanToSpanData(child));
      }
    }
  }
  
  String? scope;
  
  return _SpanData(span.text ?? '', scope, children);
}
