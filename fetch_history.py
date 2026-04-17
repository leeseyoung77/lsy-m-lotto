import urllib.request, json, sys, concurrent.futures, time

def fetch_one(r):
    for attempt in range(3):
        try:
            url = f'https://www.dhlottery.co.kr/common.do?method=getLottoNumber&drwNo={r}'
            resp = urllib.request.urlopen(url, timeout=15)
            data = json.loads(resp.read())
            if data.get('returnValue') == 'success':
                nums = sorted([data[f'drwtNo{i}'] for i in range(1,7)])
                return {'r': data['drwNo'], 'd': data['drwNoDate'], 'n': nums, 'b': data['bnusNo']}
        except:
            time.sleep(0.5)
    return None

all_draws = []
total = 1219
batch_size = 20

for start in range(1, total + 1, batch_size):
    end = min(start + batch_size, total + 1)
    with concurrent.futures.ThreadPoolExecutor(max_workers=batch_size) as ex:
        futures = {ex.submit(fetch_one, r): r for r in range(start, end)}
        for f in concurrent.futures.as_completed(futures):
            result = f.result()
            if result:
                all_draws.append(result)
    print(f'{end-1}/{total} ({len(all_draws)} ok)', flush=True)
    time.sleep(0.2)

all_draws.sort(key=lambda x: x['r'])
print(f'\nTotal: {len(all_draws)} draws')

with open('d:/test_lsy/lsy_m_lotto/lib/data/lotto_history.dart', 'w', encoding='utf-8') as f:
    f.write('// Auto-generated lotto history data\n')
    f.write('const List<Map<String, dynamic>> lottoHistoryData = [\n')
    for d in all_draws:
        f.write(f"  {{'r': {d['r']}, 'd': '{d['d']}', 'n': {d['n']}, 'b': {d['b']}}},\n")
    f.write('];\n')

print('Done!')
