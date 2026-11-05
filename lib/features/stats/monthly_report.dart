import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/amount_text.dart';
import 'stats_data.dart';

/// 月报摘要（纯数据组装，可测）
class MonthlyReportData {
  final String monthTitle; // 'YYYY年M月'
  final int totalExpenseCents;
  final int totalIncomeCents;
  final int budgetCents;
  final List<PieEntry> topCategories; // 最多 5 个，按金额降序
  final List<OverrunEntry> overruns;

  const MonthlyReportData({
    required this.monthTitle,
    required this.totalExpenseCents,
    required this.totalIncomeCents,
    required this.budgetCents,
    required this.topCategories,
    required this.overruns,
  });
}

/// 组装月报数据：标题、汇总、Top5 分类、超支列表
MonthlyReportData buildMonthlyReportData({
  required DateTime month,
  required int totalExpenseCents,
  required int totalIncomeCents,
  required int budgetCents,
  required List<PieEntry> pieEntries,
  required List<OverrunEntry> overruns,
}) {
  final top = [...pieEntries]..sort((a, b) => b.cents.compareTo(a.cents));
  return MonthlyReportData(
    monthTitle: '${month.year}年${month.month}月',
    totalExpenseCents: totalExpenseCents,
    totalIncomeCents: totalIncomeCents,
    budgetCents: budgetCents,
    topCategories: top.take(5).toList(),
    overruns: overruns,
  );
}

/// 预算完成率文案（纯函数）：'xx.x%' 或 '未设置预算'
String budgetCompletionText(int expenseCents, int budgetCents) {
  if (budgetCents <= 0) return '未设置预算';
  final tenths = (expenseCents * 1000 + budgetCents ~/ 2) ~/ budgetCents;
  return '${tenths ~/ 10}.${tenths % 10}%';
}

/// 用 Canvas 直绘月报图片，返回 PNG 字节（无需挂载 widget 树）
Future<Uint8List> renderReportPng(
  MonthlyReportData data, {
  int width = 420,
  int height = 560,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();

  // 背景
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );

  // 顶部品牌横幅
  final headerRect = Rect.fromLTWH(0, 0, width.toDouble(), 130);
  paint.shader = const LinearGradient(
    colors: [Color(0xFF16BD8C), Color(0xFF0B9E73)],
  ).createShader(headerRect);
  canvas.drawRect(headerRect, paint);
  paint.shader = null;
  _text(
    canvas,
    '生活费账本 · 月报',
    const Offset(24, 34),
    const TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
  );
  _text(
    canvas,
    data.monthTitle,
    const Offset(24, 72),
    const TextStyle(color: Colors.white70, fontSize: 15),
  );

  // 总支出 / 总收入
  _text(
    canvas,
    '总支出',
    const Offset(24, 158),
    const TextStyle(fontSize: 13, color: Colors.grey),
  );
  _text(
    canvas,
    AmountText.formatCents(data.totalExpenseCents),
    const Offset(24, 180),
    const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
  );
  _text(
    canvas,
    '总收入 ${AmountText.formatCents(data.totalIncomeCents)}',
    const Offset(210, 192),
    const TextStyle(fontSize: 15, color: AppColors.income),
  );

  // 预算完成率
  final budgetText =
      '预算完成率 ${budgetCompletionText(data.totalExpenseCents, data.budgetCents)}';
  _text(canvas, budgetText, const Offset(24, 232),
      const TextStyle(fontSize: 14, color: Colors.black87));
  final p = data.budgetCents <= 0
      ? 0.0
      : (data.totalExpenseCents / data.budgetCents).clamp(0.0, 1.0);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(24, 256, width - 48.0, 10),
      const Radius.circular(5),
    ),
    Paint()..color = const Color(0xFFEEEEEE),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(24, 256, (width - 48) * p, 10),
      const Radius.circular(5),
    ),
    Paint()..color = p >= 1.0 ? AppColors.over : AppColors.primary,
  );

  // 支出排行 Top5
  var y = 296.0;
  _text(
    canvas,
    '支出排行',
    Offset(24, y),
    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
  );
  y += 32;
  final maxCents =
      data.topCategories.isEmpty ? 1 : data.topCategories.first.cents;
  for (final c in data.topCategories) {
    _text(canvas, c.name, Offset(24, y), const TextStyle(fontSize: 13));
    _text(
      canvas,
      AmountText.formatCents(c.cents),
      Offset(width - 128, y),
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
    final barWidth = (width - 48 - 104) * (c.cents / maxCents);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(128, y + 4, barWidth, 8),
        const Radius.circular(4),
      ),
      Paint()..color = Color(c.color),
    );
    y += 30;
  }

  // 超支提醒
  if (data.overruns.isNotEmpty) {
    y += 8;
    _text(
      canvas,
      '超支提醒：${data.overruns.map((o) => o.name).join('、')}',
      Offset(24, y),
      const TextStyle(fontSize: 12, color: AppColors.over),
    );
  }

  // 页脚
  _text(
    canvas,
    'campus-wallet · 数据仅存本机',
    Offset(24, height - 28.0),
    const TextStyle(fontSize: 11, color: Colors.grey),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void _text(Canvas canvas, String s, Offset offset, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, offset);
}