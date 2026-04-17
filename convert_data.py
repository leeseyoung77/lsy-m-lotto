import json

with open('d:/test_lsy/lsy_m_lotto/all_lotto.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print(f'Total draws: {len(data)}')
print(f'First: round {data[0]["draw_no"]}, Last: round {data[-1]["draw_no"]}')

with open('d:/test_lsy/lsy_m_lotto/lib/data/lotto_history.dart', 'w', encoding='utf-8') as f:
    f.write('// Auto-generated: Korean Lotto 6/45 historical data\n')
    f.write(f'// Rounds: {data[0]["draw_no"]} ~ {data[-1]["draw_no"]} ({len(data)} draws)\n\n')
    f.write('const List<Map<String, dynamic>> lottoHistoryData = [\n')
    for d in data:
        r = d['draw_no']
        nums = sorted(d['numbers'])
        b = d['bonus_no']
        date = d['date'][:10]  # 2002-12-07T00:00:00Z -> 2002-12-07
        f.write(f"  {{'r': {r}, 'd': '{date}', 'n': {nums}, 'b': {b}}},\n")
    f.write('];\n')

print('Done! Written to lib/data/lotto_history.dart')
