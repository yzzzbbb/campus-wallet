import 'package:flutter/foundation.dart' hide Category;

import '../core/data/dao.dart';
import '../core/models/category.dart';

/// 分类状态（契约：禁止改公开方法签名）
class CategoryProvider extends ChangeNotifier {
  List<Category>? _all;

  Future<List<Category>> categories() async {
    if (_all != null) return _all!;
    _all = await Dao.instance.categories();
    return _all!;
  }

  Future<List<Category>> categoriesOf(String type) async =>
      (await categories()).where((c) => c.type == type).toList();

  Future<void> addCategory(Category c) async {
    await Dao.instance.insertCategory(c);
    _all = null;
    notifyListeners();
  }

  Future<void> updateCategory(Category c) async {
    await Dao.instance.updateCategory(c);
    _all = null;
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    await Dao.instance.deleteCategory(id);
    _all = null;
    notifyListeners();
  }
}