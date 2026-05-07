import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lotto_draw.dart';
import '../data/lotto_history_loader.dart';
import '../services/lotto_api_service.dart';
import '../services/recommendation_engine.dart';
import '../services/update_service.dart';
import '../widgets/draw_result_row.dart';
import '../widgets/recommendation_row.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = LottoApiService();
  final _engine = RecommendationEngine();
  final _updateService = UpdateService();
  final _roundController = TextEditingController();

  LottoDraw? _latestDraw;
  List<LottoDraw> _recentDraws = [];
  List<Recommendation> _recommendations = [];
  int _gameCount = 5;
  bool _isLoading = false;
  String? _alertMessage;
  String? _errorMessage;

  String _method = '통계 기반 추천';
  final List<String> _methods = ['통계 기반 추천', '완전 랜덤', '고빈도 위주', '저빈도 위주'];

  @override
  void initState() {
    super.initState();
    _loadLatestDraw();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate({bool silent = true}) async {
    final info = await _updateService.checkForUpdate();
    if (!mounted) return;

    if (info == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('업데이트 확인에 실패했습니다'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    if (!info.hasUpdate) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('현재 최신 버전입니다 (v${info.currentVersion})'),
            backgroundColor: const Color(0xFF2ECC71),
          ),
        );
      }
      return;
    }

    _showUpdateDialog(info);
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.system_update_alt, color: Color(0xFF6C72CB), size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '새 버전이 있습니다',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재: v${info.currentVersion}  →  최신: ${info.latestVersion}',
              style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (info.releaseNotes.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF12121F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(color: Color(0xFFAAAACC), fontSize: 11, height: 1.5),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('나중에', style: TextStyle(color: Color(0xFF555570))),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final url = info.apkUrl ?? info.releasePageUrl;
              if (url.isNotEmpty) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
              navigator.pop();
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('업데이트'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C72CB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLatestDraw() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    LottoHistoryLoader.clearCache();

    final allDraws = await LottoHistoryLoader.loadAll();
    final currentLatest = allDraws.isEmpty ? 0 : allDraws.first.round;

    if (allDraws.isNotEmpty) {
      _latestDraw = allDraws.first;
      _recentDraws = allDraws;
      _roundController.text = '${_latestDraw!.round}';
    }

    int newCount = 0;
    try {
      for (int r = currentLatest + 1; r <= currentLatest + 5; r++) {
        final draw = await _apiService.fetchDraw(r);
        if (draw != null) {
          await LottoHistoryLoader.saveNewDraw(draw);
          newCount++;
        } else {
          break;
        }
      }

      if (newCount == 0) {
        final fallbackDraws = await _apiService.fetchNewDrawsFromFallback(currentLatest);
        for (final draw in fallbackDraws) {
          await LottoHistoryLoader.saveNewDraw(draw);
          newCount++;
        }
      }
    } catch (_) {}

    if (newCount > 0) {
      LottoHistoryLoader.clearCache();
    }
    final finalDraws = await LottoHistoryLoader.loadAll();
    if (finalDraws.isNotEmpty && mounted) {
      _latestDraw = finalDraws.first;
      _recentDraws = finalDraws;
      _roundController.text = '${_latestDraw!.round}';
    }

    if (_latestDraw == null) {
      _roundController.text = '${LottoApiService.estimateLatestRound()}';
      _errorMessage = '데이터를 불러올 수 없습니다.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSpecificRound() async {
    final round = int.tryParse(_roundController.text);
    if (round == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    var draw = LottoHistoryLoader.findByRound(round);
    if (draw == null) {
      draw = await _apiService.fetchDraw(round);
      if (draw != null) {
        await LottoHistoryLoader.saveNewDraw(draw);
      }
    }

    if (draw != null) {
      _latestDraw = draw;
      final allDraws = await LottoHistoryLoader.loadAll();
      _recentDraws = allDraws.where((d) => d.round <= round).toList();
      if (_recentDraws.isEmpty) {
        _recentDraws = allDraws;
      }
    } else {
      _errorMessage = '$round회차 데이터를 찾을 수 없습니다.';
    }

    setState(() => _isLoading = false);
  }

  void _generateRecommendations() {
    final results = _engine.generate(
      gameCount: _gameCount,
      recentDraws: _recentDraws,
      excludeNumbers: {},
      method: _method,
    );

    setState(() {
      _recommendations = results;
      _alertMessage = results.isNotEmpty ? results.first.alertMessage : null;
    });
  }

  void _showManualInputDialog() {
    final roundCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final numControllers = List.generate(6, (_) => TextEditingController());
    final bonusCtrl = TextEditingController();

    final nextRound = (_latestDraw?.round ?? 0) + 1;
    roundCtrl.text = '$nextRound';

    final now = DateTime.now();
    final daysUntilSat = (DateTime.saturday - now.weekday) % 7;
    final nextSat = now.add(Duration(days: daysUntilSat == 0 ? 0 : daysUntilSat));
    dateCtrl.text = '${nextSat.year}-${nextSat.month.toString().padLeft(2, '0')}-${nextSat.day.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '당첨번호 수동 입력',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _dialogField(roundCtrl, '회차', TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _dialogField(dateCtrl, 'YYYY-MM-DD', TextInputType.datetime)),
                ],
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('당첨번호 6개', style: TextStyle(color: Color(0xFF555570), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(6, (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 5 ? 4 : 0),
                    child: _dialogField(numControllers[i], '${i + 1}', TextInputType.number),
                  ),
                )),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('보너스', style: TextStyle(color: Color(0xFF555570), fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  SizedBox(width: 56, child: _dialogField(bonusCtrl, 'B', TextInputType.number)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Color(0xFF555570))),
          ),
          ElevatedButton(
            onPressed: () async {
              final round = int.tryParse(roundCtrl.text);
              final bonus = int.tryParse(bonusCtrl.text);
              final nums = numControllers.map((c) => int.tryParse(c.text)).toList();

              if (round == null || bonus == null || nums.any((n) => n == null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 항목을 숫자로 입력해주세요'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }

              final numbers = nums.cast<int>()..sort();
              if (numbers.any((n) => n < 1 || n > 45) || bonus < 1 || bonus > 45) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('번호는 1~45 사이여야 합니다'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }

              DateTime date;
              try {
                date = DateTime.parse(dateCtrl.text);
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('날짜 형식이 올바르지 않습니다'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }

              final draw = LottoDraw(round: round, date: date, numbers: numbers, bonusNumber: bonus);
              await LottoHistoryLoader.saveNewDraw(draw);
              LottoHistoryLoader.clearCache();
              final allDraws = await LottoHistoryLoader.loadAll();

              if (mounted) {
                setState(() {
                  _recentDraws = allDraws;
                  _latestDraw = allDraws.first;
                  _roundController.text = '${_latestDraw!.round}';
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${round}회차 저장 완료'), backgroundColor: const Color(0xFF2ECC71)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C72CB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF444460), fontSize: 11),
        filled: true,
        fillColor: const Color(0xFF12121F),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6C72CB), width: 1),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLatestDrawSection(),
                    const SizedBox(height: 12),
                    if (_errorMessage != null) _buildErrorBanner(),
                    if (_errorMessage != null) const SizedBox(height: 10),
                    if (_alertMessage != null) _buildAlert(),
                    if (_alertMessage != null) const SizedBox(height: 12),
                    if (_latestDraw != null) DrawResultRow(draw: _latestDraw!),
                    const SizedBox(height: 16),
                    if (_recommendations.isNotEmpty) ...[
                      const Text(
                        '추천 번호',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(
                        _recommendations.length,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: RecommendationRow(
                            recommendation: _recommendations[i],
                            gameIndex: i,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF141425),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A40), width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '번호 추천',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              SizedBox(
                height: 32,
                width: 32,
                child: IconButton(
                  onPressed: () => _checkForUpdate(silent: false),
                  icon: const Icon(Icons.system_update_alt, size: 16),
                  tooltip: '업데이트 확인',
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF888898),
                    backgroundColor: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                  },
                  icon: const Icon(Icons.format_list_numbered, size: 14),
                  label: const Text('당첨번호', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF888898),
                    side: const BorderSide(color: Color(0xFF2A2A40)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateRecommendations,
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('추천 받기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C72CB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2A40), width: 0.5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _method,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 12),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF555570), size: 18),
                      items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _method = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2A40), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Text('게임 수 ', style: TextStyle(color: Color(0xFF555570), fontSize: 12)),
                    SizedBox(
                      width: 26,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _gameCount,
                          dropdownColor: const Color(0xFF1A1A2E),
                          style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 12),
                          icon: const SizedBox.shrink(),
                          items: List.generate(10, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                          onChanged: (v) {
                            if (v != null) setState(() => _gameCount = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLatestDrawSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141425),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A40), width: 0.5),
      ),
      child: Row(
        children: [
          const Text('회차', style: TextStyle(color: Color(0xFF888898), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            height: 32,
            child: TextField(
              controller: _roundController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 0.5)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 0.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6C72CB), width: 1)),
              ),
              onSubmitted: (_) => _loadSpecificRound(),
            ),
          ),
          const SizedBox(width: 6),
          _iconBtn(Icons.search, const Color(0xFF555570), const Color(0xFF1A1A2E), _isLoading ? null : _loadSpecificRound),
          const SizedBox(width: 4),
          _iconBtn(Icons.refresh_rounded, const Color(0xFF6C72CB), const Color(0xFF6C72CB).withOpacity(0.1), _isLoading ? null : _loadLatestDraw),
          const SizedBox(width: 4),
          _iconBtn(Icons.edit_note_rounded, const Color(0xFFEF5350), const Color(0xFFEF5350).withOpacity(0.1), _showManualInputDialog),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color iconColor, Color bgColor, VoidCallback? onPressed) {
    return SizedBox(
      height: 32,
      width: 32,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6C72CB).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6C72CB).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, color: Color(0xFF6C72CB), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_alertMessage!, style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
