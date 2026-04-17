import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lotto_draw.dart';
import 'lotto_history.dart';

class LottoHistoryLoader {
  static List<LottoDraw>? _cache;
  static const _storageKey = 'new_draws';

  /// 캐시 초기화
  static void clearCache() {
    _cache = null;
  }

  /// 전체 당첨번호 로드 (내장 + 로컬 저장분)
  static Future<List<LottoDraw>> loadAll() async {
    if (_cache != null) return _cache!;

    // 1. 내장 데이터 로드
    final embedded = lottoHistoryData.map((d) {
      return LottoDraw(
        round: d['r'] as int,
        date: DateTime.parse(d['d'] as String),
        numbers: List<int>.from(d['n'] as List),
        bonusNumber: d['b'] as int,
      );
    }).toList();

    // 2. 로컬에 저장된 신규 회차 로드
    final saved = await _loadSavedDraws();

    // 3. 내장 데이터에 없는 신규 회차만 추가
    final embeddedRounds = embedded.map((d) => d.round).toSet();
    for (final draw in saved) {
      if (!embeddedRounds.contains(draw.round)) {
        embedded.add(draw);
      }
    }

    // 최신순 정렬
    embedded.sort((a, b) => b.round.compareTo(a.round));
    _cache = embedded;
    return _cache!;
  }

  /// 동기 로드 (캐시 있을 때만, 없으면 내장 데이터만)
  static List<LottoDraw> loadAllSync() {
    if (_cache != null) return _cache!;
    final embedded = lottoHistoryData.map((d) {
      return LottoDraw(
        round: d['r'] as int,
        date: DateTime.parse(d['d'] as String),
        numbers: List<int>.from(d['n'] as List),
        bonusNumber: d['b'] as int,
      );
    }).toList()
      ..sort((a, b) => b.round.compareTo(a.round));
    return embedded;
  }

  /// 신규 회차 저장 (API에서 가져온 데이터)
  static Future<void> saveNewDraw(LottoDraw draw) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await _loadSavedDraws();

    // 중복 체크
    if (saved.any((d) => d.round == draw.round)) return;

    saved.add(draw);

    // JSON으로 직렬화하여 저장
    final jsonList = saved.map((d) => {
          'r': d.round,
          'd': d.date.toIso8601String().substring(0, 10),
          'n': d.numbers,
          'b': d.bonusNumber,
        }).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));

    // 캐시 갱신
    _cache = null;
    await loadAll();
  }

  /// 로컬에 저장된 신규 회차 로드
  static Future<List<LottoDraw>> _loadSavedDraws() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return [];

    try {
      final jsonList = jsonDecode(jsonStr) as List;
      return jsonList.map((d) {
        return LottoDraw(
          round: d['r'] as int,
          date: DateTime.parse(d['d'] as String),
          numbers: List<int>.from(d['n'] as List),
          bonusNumber: d['b'] as int,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 특정 회차 조회
  static LottoDraw? findByRound(int round) {
    final all = _cache ?? loadAllSync();
    try {
      return all.firstWhere((d) => d.round == round);
    } catch (_) {
      return null;
    }
  }

  /// 최신 회차 번호
  static int get latestRound {
    final all = _cache ?? loadAllSync();
    return all.isEmpty ? 0 : all.first.round;
  }
}
