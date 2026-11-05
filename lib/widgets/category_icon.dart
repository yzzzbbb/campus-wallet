import 'package:flutter/material.dart';

/// 分类图标组件：按分类 icon 字段映射内置图标（契约：禁止改公开接口）
class CategoryIcon extends StatelessWidget {
  final String icon;
  final int color;
  final double size;

  const CategoryIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24,
  });

  static const Map<String, IconData> _icons = {
    'restaurant': Icons.restaurant,
    'shopping_basket': Icons.shopping_basket,
    'school': Icons.school,
    'directions_bus': Icons.directions_bus,
    'movie': Icons.movie,
    'checkroom': Icons.checkroom,
    'local_hospital': Icons.local_hospital,
    'favorite': Icons.favorite,
    'more_horiz': Icons.more_horiz,
    'payments': Icons.payments,
    'work': Icons.work,
    'redeem': Icons.redeem,
  };

  static List<String> get iconNames => _icons.keys.toList();

  static IconData iconDataOf(String name) => _icons[name] ?? Icons.category;

  @override
  Widget build(BuildContext context) =>
      Icon(_icons[icon] ?? Icons.category, color: Color(color), size: size);
}