import 'package:flutter/material.dart';
import '../data/lotto_history_loader.dart';
import '../models/lotto_draw.dart';
import '../widgets/draw_result_row.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<LottoDraw> _allDraws = [];
  List<LottoDraw> _filtered = [];
  final _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final draws = await LottoHistoryLoader.loadAll();
    setState(() {
      _allDraws = draws;
      _filtered = draws;
      _isLoading = false;
    });
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = _allDraws);
    } else {
      setState(() {
        _filtered = _allDraws.where((d) => d.round.toString().contains(query)).toList();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141425),
        elevation: 0,
        title: const Text('당첨번호 이력', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF888898)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: TextField(
              controller: _searchController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '회차 번호 검색',
                hintStyle: const TextStyle(color: Color(0xFF444460), fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF444460), size: 18),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 0.5)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 0.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6C72CB), width: 1)),
              ),
              onChanged: _onSearch,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C72CB)))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Text('총 ${_filtered.length}회차', style: const TextStyle(color: Color(0xFF555570), fontSize: 12, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(
                        '${_allDraws.isNotEmpty ? _allDraws.last.round : 1}회 ~ ${_allDraws.isNotEmpty ? _allDraws.first.round : 0}회',
                        style: const TextStyle(color: Color(0xFF444460), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: DrawResultRow(draw: _filtered[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
