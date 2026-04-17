import 'package:flutter/material.dart';
import '../models/lotto_draw.dart';
import 'lotto_ball.dart';

class RecommendationRow extends StatelessWidget {
  final Recommendation recommendation;
  final int gameIndex;

  const RecommendationRow({
    super.key,
    required this.recommendation,
    required this.gameIndex,
  });

  @override
  Widget build(BuildContext context) {
    final r = recommendation;
    final sumOk = r.sum >= 100 && r.sum <= 175;
    final acOk = r.acValue >= 7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A40), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C72CB).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + gameIndex),
                    style: const TextStyle(
                      color: Color(0xFF6C72CB),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: r.numbers
                      .map((n) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: LottoBall(number: n, size: 30),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: [
              _tag('합${r.sum}', sumOk),
              _tag('홀${r.oddCount}짝${r.evenCount}', r.oddCount >= 2 && r.oddCount <= 4),
              _tag('저${r.lowCount}고${r.highCount}', r.lowCount >= 2 && r.lowCount <= 4),
              _tag('AC${r.acValue}', acOk),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, bool good) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: good
            ? const Color(0xFF2ECC71).withOpacity(0.1)
            : const Color(0xFFFFFFFF).withOpacity(0.03),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: good ? const Color(0xFF2ECC71) : const Color(0xFF444460),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
