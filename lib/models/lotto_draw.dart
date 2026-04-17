class LottoDraw {
  final int round;
  final DateTime date;
  final List<int> numbers; // 6개 당첨번호 (정렬됨)
  final int bonusNumber;

  LottoDraw({
    required this.round,
    required this.date,
    required this.numbers,
    required this.bonusNumber,
  });

  factory LottoDraw.fromJson(Map<String, dynamic> json) {
    final numbers = <int>[
      json['drwtNo1'] as int,
      json['drwtNo2'] as int,
      json['drwtNo3'] as int,
      json['drwtNo4'] as int,
      json['drwtNo5'] as int,
      json['drwtNo6'] as int,
    ]..sort();

    return LottoDraw(
      round: json['drwNo'] as int,
      date: DateTime.parse(json['drwNoDate'] as String),
      numbers: numbers,
      bonusNumber: json['bnusNo'] as int,
    );
  }
}

class Recommendation {
  final List<int> numbers; // 6개 추천번호 (정렬됨)
  final String? alertMessage; // 쏠림 감지 메시지

  Recommendation({
    required this.numbers,
    this.alertMessage,
  });

  /// 번호 합계
  int get sum => numbers.reduce((a, b) => a + b);

  /// 홀수 개수
  int get oddCount => numbers.where((n) => n % 2 == 1).length;

  /// 짝수 개수
  int get evenCount => 6 - oddCount;

  /// 저번호(1~22) 개수
  int get lowCount => numbers.where((n) => n <= 22).length;

  /// 고번호(23~45) 개수
  int get highCount => 6 - lowCount;

  /// AC값 (Arithmetic Complexity)
  int get acValue {
    final diffs = <int>{};
    for (int i = 0; i < numbers.length; i++) {
      for (int j = i + 1; j < numbers.length; j++) {
        diffs.add((numbers[j] - numbers[i]).abs());
      }
    }
    return diffs.length - 5;
  }
}
