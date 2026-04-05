/// Manages the reliability score using a weighted moving average
/// over the last [maxHistory] entries.
class ReliabilityManager {
  final int maxHistory;
  final List<double> _scoreHistory = [];

  ReliabilityManager({
    this.maxHistory = 10,
  }); // Reduced from 20 for faster response

  /// Adds a new score (0.0 ~ 100.0) to history and returns the weighted average.
  double addAndCalculate(double newScore) {
    // 1. Add to history
    if (_scoreHistory.length >= maxHistory) {
      _scoreHistory.removeAt(0); // Remove oldest
    }
    _scoreHistory.add(newScore);

    // 2. Calculate Weighted Average
    return _calculateWeightedAverage();
  }

  double _calculateWeightedAverage() {
    if (_scoreHistory.isEmpty) return 0.0;

    double weightedSum = 0.0;
    double weightTotal = 0.0;
    int n = _scoreHistory.length;

    for (int i = 0; i < n; i++) {
      // Weight increases linearly: 1, 2, 3 ... n
      // Most recent item gets weight 'n'
      double weight = (i + 1).toDouble();

      weightedSum += _scoreHistory[i] * weight;
      weightTotal += weight;
    }

    if (weightTotal == 0) return 0.0;
    return weightedSum / weightTotal;
  }

  void clear() {
    _scoreHistory.clear();
  }
}
