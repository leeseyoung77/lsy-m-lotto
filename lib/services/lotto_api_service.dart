import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lotto_draw.dart';

class LottoApiService {
  static const _baseUrl =
      'https://www.dhlottery.co.kr/common.do?method=getLottoNumber';
  static const _fallbackUrl =
      'https://smok95.github.io/lotto/results/all.json';

  /// 특정 회차 당첨번호 조회
  Future<LottoDraw?> fetchDraw(int round) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl&drwNo=$round'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['returnValue'] == 'success') {
          return LottoDraw.fromJson(json);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// GitHub Pages API에서 신규 회차 가져오기 (CORS 지원)
  Future<List<LottoDraw>> fetchNewDrawsFromFallback(int afterRound) async {
    try {
      final response = await http.get(
        Uri.parse(_fallbackUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List;
        final draws = <LottoDraw>[];
        for (final item in jsonList) {
          final round = item['draw_no'] as int;
          if (round > afterRound) {
            draws.add(LottoDraw(
              round: round,
              date: DateTime.parse(item['date'] as String),
              numbers: List<int>.from(item['numbers'] as List),
              bonusNumber: item['bonus_no'] as int,
            ));
          }
        }
        draws.sort((a, b) => b.round.compareTo(a.round));
        return draws;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 최근 N개 회차 당첨번호 조회
  Future<List<LottoDraw>> fetchRecentDraws(int latestRound, int count) async {
    final draws = <LottoDraw>[];
    final futures = <Future<LottoDraw?>>[];

    for (int i = 0; i < count && latestRound - i > 0; i++) {
      futures.add(fetchDraw(latestRound - i));
    }

    final results = await Future.wait(futures);
    for (final draw in results) {
      if (draw != null) {
        draws.add(draw);
      }
    }

    draws.sort((a, b) => b.round.compareTo(a.round));
    return draws;
  }

  /// 최신 회차 번호 추정 (날짜 기반)
  static int estimateLatestRound() {
    // 1회차: 2002-12-07, 매주 토요일 추첨
    final firstDraw = DateTime(2002, 12, 7);
    final now = DateTime.now();
    final diff = now.difference(firstDraw).inDays;
    return (diff / 7).floor();
  }
}
