import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_colors.dart';

class FormattedAiMarkdown extends StatelessWidget {
  final String data;
  final bool isUser;
  final double fontSize;

  const FormattedAiMarkdown({
    super.key,
    required this.data,
    this.isUser = false,
    this.fontSize = 13.5,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isUser ? Colors.white : AppColors.textPrimary;
    final highlightColor = isUser ? Colors.white : const Color(0xFF34D399); // Verde esmeralda para montos y negritas

    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: baseColor,
          fontSize: fontSize,
          height: 1.45,
        ),
        strong: TextStyle(
          color: highlightColor,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
        em: TextStyle(
          color: isUser ? Colors.white70 : AppColors.textSecondary,
          fontStyle: FontStyle.italic,
          fontSize: fontSize,
        ),
        h1: TextStyle(
          color: baseColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize + 4,
          height: 1.4,
        ),
        h2: TextStyle(
          color: baseColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize + 2.5,
          height: 1.35,
        ),
        h3: TextStyle(
          color: isUser ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: fontSize + 1,
          height: 1.3,
        ),
        listBullet: TextStyle(
          color: isUser ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
        listIndent: 20.0,

        tableBorder: TableBorder.all(
          color: AppColors.border,
          width: 1,
          borderRadius: BorderRadius.circular(8),
        ),
        tableHead: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        tableBody: TextStyle(
          color: baseColor,
          fontSize: fontSize - 1,
        ),
        tablePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        code: TextStyle(
          color: AppColors.accent,
          backgroundColor: isUser ? Colors.black26 : AppColors.surfaceLight,
          fontSize: fontSize - 1,
          fontFamily: 'monospace',
        ),
        codeblockPadding: const EdgeInsets.all(8),
        codeblockDecoration: BoxDecoration(
          color: AppColors.surfaceLight.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        blockquote: TextStyle(
          color: isUser ? Colors.white70 : AppColors.textSecondary,
          fontSize: fontSize,
        ),
        blockquoteDecoration: BoxDecoration(
          color: isUser ? Colors.white10 : AppColors.surfaceLight.withAlpha(40),
          borderRadius: BorderRadius.circular(6),
          border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
        ),
      ),
    );
  }
}
