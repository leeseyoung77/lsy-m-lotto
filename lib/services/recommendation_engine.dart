import 'dart:math';
import '../models/lotto_draw.dart';

class RecommendationEngine {
  final Random _random = Random();

  // 최근 분석 구간 (약 6개월 = 26주)
  static const _recentCount = 26;

  // 소수 목록 (1~45 범위)
  static const _primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43};

  /// 추천 번호 생성
  List<Recommendation> generate({
    required int gameCount,
    List<LottoDraw> recentDraws = const [],
    Set<int> excludeNumbers = const {},
    String method = '통계 기반 추천',
  }) {
    final recommendations = <Recommendation>[];
    final analysis = _fullAnalysis(recentDraws);
    final skewInfo = _detectSkew(recentDraws);

    String? alertMsg;
    if (skewInfo != null && skewInfo['message'] != null) {
      alertMsg = skewInfo['message'] as String;
    }

    for (int i = 0; i < gameCount; i++) {
      List<int> numbers;
      if (method == '완전 랜덤') {
        numbers = _generateRandom(excludeNumbers);
      } else {
        numbers = _generateSmart(
          analysis: analysis,
          excludeNumbers: excludeNumbers,
          method: method,
          skewInfo: skewInfo,
          recentDraws: recentDraws,
        );
      }
      recommendations.add(Recommendation(
        numbers: numbers,
        alertMessage: i == 0 ? alertMsg : null,
      ));
    }

    return recommendations;
  }

  // ============================================================
  //  종합 분석
  // ============================================================

  Map<String, dynamic> _fullAnalysis(List<LottoDraw> draws) {
    final recent = draws.take(_recentCount).toList();

    return {
      'totalFreq': _analyzeFrequency(draws),
      'recentFreq': _analyzeFrequency(recent),
      'gap': _analyzeGap(draws),
      'pairs': _analyzePairs(draws),
      'recentPairs': _analyzePairs(recent),
      'cycle': _analyzeCycle(draws),         // [신규] 번호 사이클
      'carryOver': _analyzeCarryOver(draws), // [신규] 이월번호 통계
      'totalCount': draws.length,
      'recentCount': recent.length,
    };
  }

  /// 출현 빈도 분석
  Map<int, int> _analyzeFrequency(List<LottoDraw> draws) {
    final freq = <int, int>{};
    for (int i = 1; i <= 45; i++) {
      freq[i] = 0;
    }
    for (final draw in draws) {
      for (final n in draw.numbers) {
        freq[n] = (freq[n] ?? 0) + 1;
      }
    }
    return freq;
  }

  /// 미출현 간격 (각 번호가 마지막으로 나온 후 몇 회차 경과)
  Map<int, int> _analyzeGap(List<LottoDraw> draws) {
    final gap = <int, int>{};
    for (int i = 1; i <= 45; i++) {
      gap[i] = draws.length;
    }
    for (int d = 0; d < draws.length; d++) {
      for (final n in draws[d].numbers) {
        if (gap[n] == draws.length) {
          gap[n] = d;
        }
      }
    }
    return gap;
  }

  /// 동반 출현 쌍 분석
  Map<String, int> _analyzePairs(List<LottoDraw> draws) {
    final pairs = <String, int>{};
    for (final draw in draws) {
      final nums = draw.numbers;
      for (int i = 0; i < nums.length; i++) {
        for (int j = i + 1; j < nums.length; j++) {
          final key = '${nums[i]}-${nums[j]}';
          pairs[key] = (pairs[key] ?? 0) + 1;
        }
      }
    }
    return pairs;
  }

  // ============================================================
  //  [신규1] 이월번호 분석
  //  - 직전 당첨번호 중 다음 회차에 다시 나오는 비율 분석
  //  - 역대 약 70%의 회차에서 1~2개 이월
  // ============================================================

  Map<String, dynamic> _analyzeCarryOver(List<LottoDraw> draws) {
    if (draws.length < 2) return {'rate': 0.0, 'avgCount': 0.0};

    int totalCarry = 0;
    int matchedRounds = 0;

    for (int i = 0; i < draws.length - 1; i++) {
      final current = draws[i].numbers.toSet();
      final prev = draws[i + 1].numbers.toSet();
      final overlap = current.intersection(prev).length;
      totalCarry += overlap;
      if (overlap > 0) matchedRounds++;
    }

    final total = draws.length - 1;
    return {
      'rate': total > 0 ? matchedRounds / total : 0.0,
      'avgCount': total > 0 ? totalCarry / total : 0.0,
    };
  }

  // ============================================================
  //  [신규2] 번호 사이클 감지
  //  - 최근 10회차에서의 출현 추이로 상승기/하강기 판단
  // ============================================================

  Map<int, double> _analyzeCycle(List<LottoDraw> draws) {
    final cycle = <int, double>{};
    if (draws.length < 10) {
      for (int i = 1; i <= 45; i++) {
        cycle[i] = 0.0;
      }
      return cycle;
    }

    // 최근 10회를 전반 5회 / 후반 5회로 나눠 비교
    final recentHalf = draws.take(5).toList();  // 가장 최근 5회
    final olderHalf = draws.skip(5).take(5).toList();  // 그 전 5회

    final recentFreq = _analyzeFrequency(recentHalf);
    final olderFreq = _analyzeFrequency(olderHalf);

    for (int i = 1; i <= 45; i++) {
      final r = recentFreq[i] ?? 0;
      final o = olderFreq[i] ?? 0;
      // 양수 = 상승기 (최근에 더 많이 출현), 음수 = 하강기
      cycle[i] = (r - o).toDouble();
    }

    return cycle;
  }

  // ============================================================
  //  분포 패턴 분석 + 쏠림 감지
  // ============================================================

  Map<String, dynamic>? _detectSkew(List<LottoDraw> draws) {
    if (draws.isEmpty) return null;
    final latest = draws.first;

    final dist = _getDistribution(latest.numbers);
    final low = dist['low']!;
    final midLow = dist['midLow']!;
    final mid = dist['mid']!;
    final midHigh = dist['midHigh']!;
    final high = dist['high']!;

    String pattern;
    String message;
    final front = low + midLow;
    final back = midHigh + high;
    final center = mid;

    if (front >= 4) {
      pattern = 'front_heavy';
      message = '직전 패턴: 앞쪽 집중(1~19) ${front}개 → 뒤쪽 분산 추천';
    } else if (back >= 4) {
      pattern = 'back_heavy';
      message = '직전 패턴: 뒤쪽 집중(30~45) ${back}개 → 앞쪽 분산 추천';
    } else if (center >= 3) {
      pattern = 'center_heavy';
      message = '직전 패턴: 중간 집중(20~29) ${center}개 → 양쪽 분산 추천';
    } else if (front <= 1 && back <= 1) {
      pattern = 'spread';
      message = '직전 패턴: 고르게 분산 → 약간의 집중 추천';
    } else {
      pattern = 'normal';
      message = '';
    }

    final recentPattern = _analyzeRecentTrend(draws.take(3).toList());

    return {
      'pattern': pattern,
      'recentPattern': recentPattern,
      'dist': dist,
      'message': message.isNotEmpty ? message : null,
      'range': _getLegacyRange(dist),
    };
  }

  Map<String, int> _getDistribution(List<int> numbers) {
    return {
      'low': numbers.where((n) => n <= 9).length,
      'midLow': numbers.where((n) => n >= 10 && n <= 19).length,
      'mid': numbers.where((n) => n >= 20 && n <= 29).length,
      'midHigh': numbers.where((n) => n >= 30 && n <= 39).length,
      'high': numbers.where((n) => n >= 40 && n <= 45).length,
    };
  }

  String _analyzeRecentTrend(List<LottoDraw> recent) {
    if (recent.length < 2) return 'unknown';

    int frontTotal = 0, backTotal = 0, centerTotal = 0;
    for (final draw in recent) {
      final d = _getDistribution(draw.numbers);
      frontTotal += d['low']! + d['midLow']!;
      backTotal += d['midHigh']! + d['high']!;
      centerTotal += d['mid']!;
    }

    final avg = recent.length;
    if (frontTotal / avg >= 3.0) return 'front_trend';
    if (backTotal / avg >= 3.0) return 'back_trend';
    if (centerTotal / avg >= 2.0) return 'center_trend';
    return 'mixed';
  }

  String? _getLegacyRange(Map<String, int> dist) {
    if ((dist['low']! + dist['midLow']!) >= 4) return '앞쪽(1~19)';
    if (dist['mid']! >= 3) return '중간(20~29)';
    if ((dist['midHigh']! + dist['high']!) >= 4) return '뒤쪽(30~45)';
    return null;
  }

  double _getPatternBonus(int number, Map<String, dynamic> skewInfo) {
    final pattern = skewInfo['pattern'] as String;
    final recentPattern = skewInfo['recentPattern'] as String;

    double bonus = 1.0;

    switch (pattern) {
      case 'front_heavy':
        if (number >= 30) bonus *= 1.5;
        if (number <= 19) bonus *= 0.5;
        break;
      case 'back_heavy':
        if (number <= 19) bonus *= 1.5;
        if (number >= 30) bonus *= 0.5;
        break;
      case 'center_heavy':
        if (number <= 9 || number >= 40) bonus *= 1.4;
        if (number >= 20 && number <= 29) bonus *= 0.5;
        break;
      case 'spread':
        if (number >= 15 && number <= 35) bonus *= 1.2;
        break;
    }

    switch (recentPattern) {
      case 'front_trend':
        if (number >= 30) bonus *= 1.2;
        if (number <= 15) bonus *= 0.8;
        break;
      case 'back_trend':
        if (number <= 19) bonus *= 1.2;
        if (number >= 35) bonus *= 0.8;
        break;
      case 'center_trend':
        if (number <= 10 || number >= 40) bonus *= 1.2;
        if (number >= 20 && number <= 29) bonus *= 0.8;
        break;
    }

    return bonus;
  }

  // ============================================================
  //  번호 생성
  // ============================================================

  List<int> _generateRandom(Set<int> excludeNumbers) {
    final candidates = <int>[];
    for (int i = 1; i <= 45; i++) {
      if (!excludeNumbers.contains(i)) candidates.add(i);
    }
    candidates.shuffle(_random);
    return (candidates.take(6).toList())..sort();
  }

  /// ★ 핵심: 가중치 혼합 스마트 추천 ★
  List<int> _generateSmart({
    required Map<String, dynamic> analysis,
    required Set<int> excludeNumbers,
    required String method,
    Map<String, dynamic>? skewInfo,
    List<LottoDraw> recentDraws = const [],
  }) {
    final totalFreq = analysis['totalFreq'] as Map<int, int>;
    final recentFreq = analysis['recentFreq'] as Map<int, int>;
    final gap = analysis['gap'] as Map<int, int>;
    final pairs = analysis['pairs'] as Map<String, int>;
    final recentPairs = analysis['recentPairs'] as Map<String, int>;
    final cycle = analysis['cycle'] as Map<int, double>;
    final totalCount = analysis['totalCount'] as int;
    final recentCount = analysis['recentCount'] as int;

    final candidates = <int>[];
    for (int i = 1; i <= 45; i++) {
      if (!excludeNumbers.contains(i)) candidates.add(i);
    }

    final hasTotal = totalFreq.values.any((v) => v > 0);
    final hasRecent = recentFreq.values.any((v) => v > 0);

    // === 정규화 준비 ===
    final totalMax = totalFreq.values.fold(0, max);
    final totalMin = totalFreq.values.fold(totalMax, min);
    final recentMax = recentFreq.values.fold(0, max);
    final recentMin = recentFreq.values.fold(recentMax, min);
    final gapMax = gap.values.fold(0, max);

    // === [신규1] 이월번호: 직전 당첨번호 ===
    final prevNumbers = recentDraws.isNotEmpty
        ? recentDraws.first.numbers.toSet()
        : <int>{};

    // === 번호별 종합 점수 계산 ===
    final scores = <int, double>{};

    for (final num in candidates) {
      double score = 1.0;

      if (hasTotal && totalMax > totalMin) {
        final tFreq = totalFreq[num] ?? 0;
        final tNorm = (tFreq - totalMin) / (totalMax - totalMin);

        final rFreq = recentFreq[num] ?? 0;
        final rNorm = (hasRecent && recentMax > recentMin)
            ? (rFreq - recentMin) / (recentMax - recentMin)
            : 0.5;

        final gapVal = gap[num] ?? 0;
        final gapNorm = gapMax > 0 ? gapVal / gapMax : 0.0;

        if (method == '고빈도 위주') {
          score = tNorm * 2.0 + rNorm * 2.0 + gapNorm * 0.8;
        } else if (method == '저빈도 위주') {
          score = (1.0 - tNorm) * 1.5 + (1.0 - rNorm) * 1.5 + gapNorm * 2.0;
        } else {
          // ★★★ 통계 기반 추천 (가중치 혼합) ★★★
          //
          // [1] 전체 빈도 (35%)
          final totalScore = 0.5 + tNorm * 1.5;

          // [2] 최근 6개월 트렌드 (30%)
          final recentScore = 0.3 + rNorm * 1.7;

          // [3] 미출현 간격 (15%)
          double gapScore;
          if (gapNorm < 0.7) {
            gapScore = gapNorm * 2.0;
          } else {
            gapScore = 1.4 - (gapNorm - 0.7) * 1.0;
          }

          // 기본 혼합: 35% + 30% + 15% = 80%
          score = totalScore * 0.35 + recentScore * 0.30 + gapScore * 0.15;

          // [4] 이월번호 보너스 (10%)
          //     직전 당첨번호에 포함된 번호는 가산
          if (prevNumbers.contains(num)) {
            score += 0.20; // 이월 가산
          }

          // [5] 사이클 보너스 (10%)
          //     상승기 번호 선호, 하강기 감점
          final cycleVal = cycle[num] ?? 0.0;
          if (cycleVal > 0) {
            score += 0.08 * cycleVal; // 상승기: 가산
          } else if (cycleVal < 0) {
            score += 0.04 * cycleVal; // 하강기: 약간 감점
          }

          // [6] 직전 패턴 반전 보정
          if (skewInfo != null) {
            score *= _getPatternBonus(num, skewInfo);
          }
        }
      }

      scores[num] = score;
    }

    // === 최적 조합 탐색 (500번 시도) ===
    List<int>? bestCombo;
    double bestScore = -1;

    // 동반 출현 쌍: 전체(60%) + 최근(40%) 혼합
    final mixedPairs = <String, double>{};
    final allPairKeys = {...pairs.keys, ...recentPairs.keys};
    for (final key in allPairKeys) {
      final tVal = (pairs[key] ?? 0).toDouble();
      final rVal = (recentPairs[key] ?? 0).toDouble();
      final tNorm = totalCount > 0 ? tVal / totalCount : 0.0;
      final rNorm = recentCount > 0 ? rVal / recentCount : 0.0;
      mixedPairs[key] = tNorm * 0.6 + rNorm * 0.4;
    }

    for (int attempt = 0; attempt < 500; attempt++) {
      final combo = _weightedPick6(candidates, scores, prevNumbers);
      if (combo == null) continue;

      final quality = _evaluateCombo(combo, mixedPairs, prevNumbers);
      if (quality > bestScore) {
        bestScore = quality;
        bestCombo = combo;
      }
      if (quality >= 0.85) break;
    }

    return bestCombo ?? _generateRandom(excludeNumbers);
  }

  /// 가중치 기반 6개 번호 선택 (이월번호 고려)
  List<int>? _weightedPick6(
    List<int> candidates,
    Map<int, double> scores,
    Set<int> prevNumbers,
  ) {
    final selected = <int>[];
    final available = List<int>.from(candidates);

    // 이월번호 1~2개 우선 포함 시도 (70% 확률)
    if (prevNumbers.isNotEmpty && _random.nextDouble() < 0.70) {
      final prevList = prevNumbers.where((n) => available.contains(n)).toList();
      if (prevList.isNotEmpty) {
        prevList.shuffle(_random);
        final carryCount = _random.nextDouble() < 0.6 ? 1 : 2; // 60%:1개, 40%:2개
        for (int i = 0; i < carryCount && i < prevList.length; i++) {
          selected.add(prevList[i]);
          available.remove(prevList[i]);
        }
      }
    }

    while (selected.length < 6 && available.isNotEmpty) {
      final totalWeight =
          available.fold(0.0, (sum, n) => sum + (scores[n] ?? 1.0));
      if (totalWeight <= 0) break;

      double r = _random.nextDouble() * totalWeight;
      for (int i = 0; i < available.length; i++) {
        r -= scores[available[i]] ?? 1.0;
        if (r <= 0) {
          final picked = available.removeAt(i);
          if (!_wouldCreateTriple(selected, picked)) {
            selected.add(picked);
          }
          break;
        }
      }
    }

    while (selected.length < 6 && available.isNotEmpty) {
      selected.add(available.removeAt(_random.nextInt(available.length)));
    }

    if (selected.length < 6) return null;
    selected.sort();
    return selected;
  }

  /// 조합 품질 평가 (0.0 ~ 1.0) - 확장된 10가지 기준
  double _evaluateCombo(
    List<int> combo,
    Map<String, double> pairs,
    Set<int> prevNumbers,
  ) {
    double score = 0.0;
    int checks = 0;

    // [1] 번호 합: 100~175 범위
    final sum = combo.reduce((a, b) => a + b);
    checks++;
    if (sum >= 100 && sum <= 175) {
      score += 1.0;
    } else if (sum >= 80 && sum <= 195) {
      score += 0.5;
    }

    // [2] 홀짝 균형: 2~4개
    final oddCount = combo.where((n) => n % 2 == 1).length;
    checks++;
    if (oddCount >= 2 && oddCount <= 4) {
      score += 1.0;
    } else if (oddCount >= 1 && oddCount <= 5) {
      score += 0.4;
    }

    // [3] 고저 균형: 저(1~22) 2~4개
    final lowCount = combo.where((n) => n <= 22).length;
    checks++;
    if (lowCount >= 2 && lowCount <= 4) {
      score += 1.0;
    } else if (lowCount >= 1 && lowCount <= 5) {
      score += 0.4;
    }

    // [4] 끝자리 분산: 같은 끝자리 2개 이하
    final digitCounts = <int, int>{};
    for (final n in combo) {
      final d = n % 10;
      digitCounts[d] = (digitCounts[d] ?? 0) + 1;
    }
    checks++;
    final maxSameDigit = digitCounts.values.fold(0, max);
    if (maxSameDigit <= 2) {
      score += 1.0;
    } else if (maxSameDigit == 3) {
      score += 0.3;
    }

    // [5] AC값: 7 이상
    final ac = _calculateAC(combo);
    checks++;
    if (ac >= 7) {
      score += 1.0;
    } else if (ac >= 5) {
      score += 0.5;
    }

    // [6] 4구간 분포: 빈 구간 없음
    final ranges = [
      combo.where((n) => n <= 10).length,
      combo.where((n) => n >= 11 && n <= 20).length,
      combo.where((n) => n >= 21 && n <= 30).length,
      combo.where((n) => n >= 31 && n <= 45).length,
    ];
    final emptyRanges = ranges.where((r) => r == 0).length;
    checks++;
    if (emptyRanges == 0) {
      score += 1.0;
    } else if (emptyRanges == 1) {
      score += 0.6;
    }

    // [7] 동반 출현 쌍 (혼합 빈도)
    if (pairs.isNotEmpty) {
      checks++;
      int pairCount = 0;
      for (int i = 0; i < combo.length; i++) {
        for (int j = i + 1; j < combo.length; j++) {
          final key = '${combo[i]}-${combo[j]}';
          final val = pairs[key] ?? 0.0;
          if (val > 0) pairCount++;
        }
      }
      if (pairCount >= 3) {
        score += 1.0;
      } else if (pairCount >= 1) {
        score += 0.5;
      }
    }

    // [8] 이월번호: 1~2개 포함 여부
    if (prevNumbers.isNotEmpty) {
      checks++;
      final carryCount = combo.where((n) => prevNumbers.contains(n)).length;
      if (carryCount >= 1 && carryCount <= 2) {
        score += 1.0; // 1~2개 이월: 최적
      } else if (carryCount == 3) {
        score += 0.5; // 3개: 약간 많음
      } else {
        score += 0.2; // 0개 또는 4개+: 비전형적
      }
    }

    // [9] 소수(Prime) 비율: 2~3개
    checks++;
    final primeCount = combo.where((n) => _primes.contains(n)).length;
    if (primeCount >= 2 && primeCount <= 3) {
      score += 1.0;
    } else if (primeCount >= 1 && primeCount <= 4) {
      score += 0.5;
    }

    // [10] 연속번호 제어: 연속쌍 0~1개
    checks++;
    int consecutivePairs = 0;
    for (int i = 0; i < combo.length - 1; i++) {
      if (combo[i + 1] == combo[i] + 1) consecutivePairs++;
    }
    if (consecutivePairs <= 1) {
      score += 1.0;
    } else if (consecutivePairs == 2) {
      score += 0.4;
    }

    return checks > 0 ? score / checks : 0.0;
  }

  int _calculateAC(List<int> combo) {
    final diffs = <int>{};
    for (int i = 0; i < combo.length; i++) {
      for (int j = i + 1; j < combo.length; j++) {
        diffs.add((combo[j] - combo[i]).abs());
      }
    }
    return diffs.length - 5;
  }

  bool _wouldCreateTriple(List<int> current, int newNum) {
    final test = [...current, newNum]..sort();
    for (int i = 0; i < test.length - 2; i++) {
      if (test[i + 1] == test[i] + 1 && test[i + 2] == test[i] + 2) {
        return true;
      }
    }
    return false;
  }
}
