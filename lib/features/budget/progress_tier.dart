/// 配额进度档位（UI 规则）：<80% 正常，80%~100% 提醒，>=100% 超支
enum ProgressTier { normal, warn, over }

ProgressTier progressTierFor(double p) {
  if (p >= 1.0) return ProgressTier.over;
  if (p >= 0.8) return ProgressTier.warn;
  return ProgressTier.normal;
}