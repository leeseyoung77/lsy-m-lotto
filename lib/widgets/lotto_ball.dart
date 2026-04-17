import 'package:flutter/material.dart';

class LottoBall extends StatelessWidget {
  final int number;
  final double size;

  const LottoBall({
    super.key,
    required this.number,
    this.size = 36,
  });

  static Color getColor(int number) {
    if (number <= 10) return const Color(0xFFFBB400);
    if (number <= 20) return const Color(0xFF4A9FE5);
    if (number <= 30) return const Color(0xFFEF5350);
    if (number <= 40) return const Color(0xFF9E9E9E);
    return const Color(0xFF66BB6A);
  }

  @override
  Widget build(BuildContext context) {
    final color = getColor(number);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.15)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.40,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0.5, 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
