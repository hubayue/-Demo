export function starParts(level) {
  if (level <= 5) return { t2: 0, hi: 0, lo: level };
  if (level <= 10) return { t2: 0, hi: level - 5, lo: 10 - level };
  return { t2: level - 10, hi: 15 - level, lo: 0 };
}

export function starDamageMultiplier(level, hasPhoenixFeather) {
  const ascended = hasPhoenixFeather ? 1.5 : 1.4;
  const ascended2 = hasPhoenixFeather ? 1.4 : 1.3;
  return Math.pow(1.9, Math.min(level, 5) - 1)
    * Math.pow(ascended, Math.max(0, Math.min(level, 10) - 5))
    * Math.pow(ascended2, Math.max(0, level - 10));
}
