import json
import re
import html
import os

def fix_candidates():
    # 1. Parse Ornito list with cp1254 (Turkish encoding)
    ornito_path = os.path.join('tools', 'model_staging', 'ornito_bird_list.html')
    with open(ornito_path, 'r', encoding='cp1254', errors='ignore') as f:
        ornito_html = f.read()

    ornito_map = {}
    rows = re.findall(r'<tr[^>]*>.*?</tr>', ornito_html, re.DOTALL)
    for r in rows:
        links = re.findall(r'<a href="/Bird/Detail/(\d+)">(.*?)</a>', r, re.DOTALL)
        if len(links) >= 3:
            orn_id = links[0][0]
            tr_name = html.unescape(re.sub(r'<[^>]+>', '', links[0][1])).strip()
            en_name = html.unescape(re.sub(r'<[^>]+>', '', links[1][1])).strip()
            sci_name = html.unescape(re.sub(r'<[^>]+>', '', links[2][1])).strip()
            ornito_map[sci_name.lower()] = {
                'scientificName': sci_name,
                'turkishName': tr_name,
                'englishName': en_name,
                'ornitoId': orn_id
            }

    print(f"Parsed {len(ornito_map)} species from Ornito HTML.")
    visc = ornito_map.get('turdus viscivorus')
    if visc:
        print("Turdus viscivorus Turkish name:", repr(visc['turkishName']))

    # 2. Fix candidates.json files
    target_files = [
        os.path.join('tools', 'model_staging', 'turkey_0.1.0', 'candidates.json'),
        os.path.join('tools', 'model_staging', 'bioclip2', 'turkey_regular_and_migrant_birds.json')
    ]

    for target in target_files:
        if not os.path.exists(target):
            continue
        with open(target, 'r', encoding='utf-8-sig', errors='ignore') as f:
            data = json.load(f)

        updated_count = 0
        for candidate in data.get('candidates', []):
            sci = candidate.get('scientificName', '').strip()
            sci_lower = sci.lower()
            if sci_lower in ornito_map:
                o_item = ornito_map[sci_lower]
                candidate['turkishName'] = o_item['turkishName']
                candidate['englishName'] = o_item['englishName']
                candidate['ornitoId'] = o_item['ornitoId']
                updated_count += 1

        # Write clean UTF-8 without BOM
        with open(target, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=4)
        print(f"Fixed {updated_count} candidates in {target} (Saved as clean UTF-8 without BOM).")

if __name__ == '__main__':
    fix_candidates()
