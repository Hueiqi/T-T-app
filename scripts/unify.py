import json
from pathlib import Path

base = Path(__file__).resolve().parent.parent
fitness_path = base / 'lib' / 'assets' / 'fitness_data.json'
gifs_path = base / 'assets' / 'gifs_data.json'

fitness_data = json.load(open(fitness_path, encoding='utf-8'))
gifs_data = json.load(open(gifs_path, encoding='utf-8'))

# 1. Add `name` to every fitness entry (= title)
for e in fitness_data:
    e['name'] = e['title']

# 2. Add `name` to every gif entry that has a matching fitness entry
fit_by_title = {}
for e in fitness_data:
    key = e['title'].lower().strip()
    fit_by_title[key] = e

gif_updated = 0
for e in gifs_data:
    key = e['title'].lower().strip()
    match = fit_by_title.get(key)
    if match:
        e['name'] = match['name']
        gif_updated += 1
    else:
        e['name'] = e['title']

# 3. Print summary
matched = sum(1 for e in fitness_data if e.get('gif_url'))
unmatched = sum(1 for e in fitness_data if not e.get('gif_url'))

print(f"Fitness entries: {len(fitness_data)}")
print(f"  - with gif_url: {matched}")
print(f"  - without gif_url: {unmatched}")
print(f"GIF entries: {len(gifs_data)}")
print(f"  - with matching name in fitness: {gif_updated}")

# Save
json.dump(fitness_data, open(fitness_path, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
json.dump(gifs_data, open(gifs_path, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
print("\nBoth files updated with consistent `id` and `name` fields.")
