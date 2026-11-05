import 'package:campus_wallet/core/logic/alert_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('levelForUsage 三档边界', () {
    expect(AlertLogic.levelForUsage(0.79), 'none');
    expect(AlertLogic.levelForUsage(0.8), 'warn');
    expect(AlertLogic.levelForUsage(0.99), 'warn');
    expect(AlertLogic.levelForUsage(1.0), 'over');
    expect(AlertLogic.levelForUsage(1.5), 'over');
  });

  test('shouldAlert：同一天不重复提醒', () {
    expect(
      AlertLogic.shouldAlert(
        lastAlertDate: '2026-11-05',
        lastLevel: 'warn',
        today: '2026-11-05',
        newLevel: 'over',
      ),
      isFalse,
    );
  });

  test('shouldAlert：级别不高于上次则不提醒', () {
    expect(
      AlertLogic.shouldAlert(
        lastAlertDate: '2026-11-04',
        lastLevel: 'over',
        today: '2026-11-05',
        newLevel: 'warn',
      ),
      isFalse,
    );
  });

  test('shouldAlert：首次 warn 提醒', () {
    expect(
      AlertLogic.shouldAlert(
        lastAlertDate: '',
        lastLevel: '',
        today: '2026-11-05',
        newLevel: 'warn',
      ),
      isTrue,
    );
  });

  test('shouldAlert：新一天升级为 over 提醒', () {
    expect(
      AlertLogic.shouldAlert(
        lastAlertDate: '2026-11-04',
        lastLevel: 'warn',
        today: '2026-11-05',
        newLevel: 'over',
      ),
      isTrue,
    );
  });

  test('shouldAlert：none 级别永不提醒', () {
    expect(
      AlertLogic.shouldAlert(
        lastAlertDate: '',
        lastLevel: '',
        today: '2026-11-05',
        newLevel: 'none',
      ),
      isFalse,
    );
  });
}