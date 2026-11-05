# campus-wallet 架构文档 v0.1

> 本文档是给开发（主代理 + Claude Code 委派）看的**契约**。
> 业务规则见 PRD.md 第 3 节决策表；此处定义代码结构与模块边界。

## 1. 目录结构（lib/）

```
lib/
  main.dart                      # 入口：ProviderScope + MaterialApp + 主题
  core/
    models/
      category.dart              # Category 模型（含 toMap/fromMap）
      transaction.dart           # Transaction 模型
      budget_setting.dart        # 生活费/预算设置读写封装
      category_budget.dart       # 分类配额模型
    data/
      app_database.dart          # sqflite 单例：建表、开库、内置分类种子
      dao.dart                   # 各表 CRUD + 汇总查询
    logic/
      finance_math.dart          # 决策表 R1~R10 的纯函数（无 UI、无 DB 依赖）
    theme/
      app_theme.dart             # 主题色、深色模式、分类默认色板
  state/
    transaction_provider.dart    # 流水列表 + 增删改，暴露 ChangeNotifier
    budget_provider.dart         # 预算总额/生活费设置/分类配额 + 衍生计算
    settings_provider.dart       # 深色模式等 UI 设置
  features/
    home/                        # 首页（倒计时卡片、本月概览、今日流水）
    transaction/                 # 记账页 + 流水列表页
    budget/                      # 预算规划页
    stats/                       # 统计页
    settings/                    # 设置页
  widgets/
    category_icon.dart           # 分类图标组件（按 icon 字段映射）
    amount_text.dart             # 分 -> "¥12.34" 显示组件
```

## 2. 模块边界（委派硬约束）

| 模块 | 可改目录 | 禁止改 |
|---|---|---|
| home | `lib/features/home/**` | `lib/core/**`、`lib/state/**`、其他 `lib/features/*` |
| transaction | `lib/features/transaction/**` | 同上 |
| budget | `lib/features/budget/**` | 同上 |
| stats | `lib/features/stats/**` | 同上 |
| settings | `lib/features/settings/**` | 同上 |

- 核心层（core/、state/、widgets/）由主代理先写好，作为**契约**固定下来。
- 功能模块只能**消费**契约的公开 API，不得修改契约文件；发现契约不足 → 停下报告，不得自行扩展契约。
- 禁止引入新依赖（pubspec.yaml 只读）。

## 3. 核心契约（先由主代理实现，模块开发前必须就绪）

### 3.1 模型
- `Category { int? id; String name; String type; String icon; int color; int sort; bool builtin; }`
- `Transaction { int? id; String type; int amountCents; int categoryId; String note; DateTime occurredAt; DateTime createdAt; }`
- `BudgetSetting`：从 settings 表读写（键见 PRD 4 节）
- `CategoryBudget { int? id; int categoryId; String month; int limitCents; }`

### 3.2 finance_math.dart 纯函数（决策表 R1~R10）
- `DateTime nextPayDate({required String periodType, int? payDay, DateTime? lastPayDate, required int everyNDays, required DateTime today})`
- `int remainingCents({required int monthlyBudgetCents, required int monthExpenseCents})`
- `double dailyAvailable({required int remainingCents, required int daysToNextPay})`
- `double categoryProgress({required int spentCents, required int limitCents})`
- `String monthKey(DateTime d)` → `'YYYY-MM'`

### 3.3 State Providers（ChangeNotifier，注册于 ProviderScope）
- `TransactionProvider`：
  - `Future<List<Transaction>> transactionsOfMonth(String monthKey)`
  - `Future<void> add(Transaction t)` / `update(Transaction t)` / `delete(int id)`
  - `Future<int> monthExpenseCents(String monthKey)` / `Future<int> monthIncomeCents(String monthKey)`
  - `Future<Map<int,int>> expenseByCategory(String monthKey)`
- `CategoryProvider`：
  - `Future<List<Category>> categories()` / `Future<List<Category>> categoriesOf(String type)`
  - `Future<void> addCategory / updateCategory / deleteCategory`
- `BudgetProvider`：
  - `BudgetSetting get setting`、`bool get loaded`、`Future<void> load()`
  - `Future<void> saveSetting(BudgetSetting)`
  - `int get daysToNextPay`（内部调 finance_math R1/R2）
  - `int get effectiveMonthlyBudgetCents`（R7）
  - `Future<List<CategoryBudget>> budgetsOfMonth(String month)`
  - `Future<void> setCategoryBudget({required int categoryId, required String month, required int limitCents})`
- `SettingsProvider`：`ThemeMode get themeMode` / `Future<void> setThemeMode(ThemeMode)` / `Future<void> load()`

> 派生数值（剩余可用 / 日均可用 / 分类进度）由页面用 `TransactionProvider` + `BudgetProvider` 数据 + `FinanceMath` 纯函数自行计算（R3/R4/R6）。

### 3.4 共享组件
- `CategoryIcon(icon, color, size)`：按 icon 名映射内置 Material 图标集
- `AmountText(cents, {style})`：分 → `¥1,234.56`（intl 格式化）

## 4. 构建环境（中国网络）

- `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`
- `PUB_HOSTED_URL=https://pub.flutter-io.cn`
- Gradle 仓库已配置阿里云镜像（见 android/ 构建脚本，由主代理处理）
- 全部验证命令：`flutter analyze`（0 错误）+ `flutter test`

## 5. 验收流程

1. 模块自测：`flutter analyze` + `flutter test`（若有该模块测试）
2. 主代理在 main 分支合并后跑整体 `flutter build apk --debug`
3. 产品负责人 YZB 安装 APK 真机验收，反馈进下一轮迭代