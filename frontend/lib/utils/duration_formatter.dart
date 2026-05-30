String formatSeconds(double seconds) {
  final total = seconds.round().clamp(0, double.maxFinite.toInt());
  if (total < 60) return '${total}s';
  final m = total ~/ 60;
  final s = total % 60;
  return '${m}m ${s}s';
}
