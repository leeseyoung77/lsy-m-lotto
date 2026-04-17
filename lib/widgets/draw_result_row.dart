import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lotto_draw.dart';
import 'lotto_ball.dart';

class DrawResultRow extends StatelessWidget {
  final LottoDraw draw;

  const DrawResultRow({super.key, required this.draw});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(draw.date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A40), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${draw.round}회',
                style: const TextStyle(
                  color: Color(0xFF6C72CB),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: const TextStyle(
                  color: Color(0xFF555570),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...draw.numbers.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: LottoBall(number: n, size: 36),
                  )),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '+',
                  style: TextStyle(color: Color(0xFF444460), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              LottoBall(number: draw.bonusNumber, size: 36),
            ],
          ),
        ],
      ),
    );
  }
}
