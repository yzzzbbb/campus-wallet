import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 金额显示组件：分 -> ¥1,234.56（契约：禁止改公开接口）
class AmountText extends StatelessWidget {
  final int cents;
  final TextStyle? style;
  final bool signed; // true 且 cents>0 时显示负号（用于支出）

  const AmountText({super.key, required this.cents, this.style, this.signed = false});

  static String formatCents(int cents) {
    final nf = NumberFormat('#,##0');
    final whole = cents ~/ 100;
    final frac = (cents % 100).abs().toString().padLeft(2, '0');
    return '¥${nf.format(whole)}.$frac';
  }

  @override
  Widget build(BuildContext context) {
    final sign = signed && cents > 0 ? '-' : '';
    return Text('$sign${formatCents(cents)}', style: style);
  }
}