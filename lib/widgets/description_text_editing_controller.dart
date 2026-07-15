import 'package:flutter/material.dart';

class DescriptionTextEditingController extends TextEditingController {
  DescriptionTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final textVal = text;

    if (textVal.isEmpty) {
      return TextSpan(text: textVal, style: baseStyle);
    }

    final lines = textVal.split('\n');
    if (lines.isNotEmpty) {
      final firstLine = lines[0];
      // If the first line is uppercase and looks like a promo/CRM tag
      final isCrmTag = firstLine.trim().isNotEmpty &&
          firstLine == firstLine.toUpperCase() &&
          firstLine.length < 80 &&
          (firstLine.contains(RegExp(r'\d')) || 
           firstLine.contains('TL') || 
           firstLine.contains('SEPETTE') || 
           firstLine.contains('İNDİRİM') ||
           firstLine.contains('HEMEN') ||
           firstLine.contains('%'));

      if (isCrmTag) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final crmStyle = baseStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          color: isDark ? Colors.amber[300] : const Color(0xFFFF7F00),
        );

        final List<InlineSpan> children = [];
        children.add(TextSpan(text: firstLine, style: crmStyle));
        
        if (lines.length > 1) {
          final restText = '\n' + lines.sublist(1).join('\n');
          children.add(TextSpan(text: restText, style: baseStyle));
        }
        return TextSpan(children: children, style: baseStyle);
      }
    }

    return TextSpan(text: textVal, style: baseStyle);
  }
}
