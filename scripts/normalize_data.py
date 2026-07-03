import json
import re
from pathlib import Path

def normalize(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r'[^a-z0-9\s-]', '', s)
    return re.sub(r'\s+', ' ', s).strip()

def strip_prefixes(s: str) -> str:
    s = re.sub(r'^(fyr\d*|holman|metaburn|hm|uns|up|kv|taylor|robertson|30)\s+', '', s, flags=re.IGNORECASE)
    s = re.sub(r'\s+(exercise|variation)$', '', s, flags=re.IGNORECASE)
    s = re.sub(r'^(dumbbell|barbell|kettlebell|cable|band)\s+fix\s+', '', s, flags=re.IGNORECASE)
    prefixes = [
        r'^dumbbell\s+', r'^barbell\s+', r'^kettlebell\s+', r'^cable\s+', r'^band\s+',
        r'^ez\s*bar\s+',
        r'^one\s+arm\s+', r'^two\s+arm\s+',
        r'^standing\s+', r'^seated\s+', r'^lying\s+',
        r'^single[-\s]arm\s+', r'^double\s+',
        r'^decline\s+', r'^incline\s+',
        r'^alternating\s+',
        r'^one[-\s]arm\s+',
    ]
    for p in prefixes:
        s = re.sub(p, '', s, flags=re.IGNORECASE)
    return s.strip()

def load_json(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

base = Path(__file__).resolve().parent.parent
fitness_path = base / 'lib' / 'assets' / 'fitness_data.json'
gifs_path = base / 'assets' / 'gifs_data.json'

fitness_data = load_json(fitness_path)
gifs_data = load_json(gifs_path)

# Build gif index
gif_by_title = {}
gif_by_norm = {}
gif_by_stripped = {}
for e in gifs_data:
    t = e['title']
    gif_by_title[t] = e
    norm = normalize(t)
    if norm not in gif_by_norm:
        gif_by_norm[norm] = e
    stripped = strip_prefixes(norm)
    if stripped not in gif_by_stripped:
        gif_by_stripped[stripped] = e

matched = 0
unmatched = []

for entry in fitness_data:
    t = entry['title']
    norm = normalize(t)
    stripped = strip_prefixes(norm)
    
    gif_entry = None
    
    # 1. Exact title
    gif_entry = gif_by_title.get(t)
    
    # 2. Normalized exact
    if not gif_entry:
        gif_entry = gif_by_norm.get(norm)
    
    # 3. Stripped prefix match (both stripped versions equal)
    if not gif_entry and stripped:
        gif_entry = gif_by_stripped.get(stripped)
    
    # 4. For prefix variations: e.g., "Dumbbell Fix Dumbbell Mountain Climber" -> "Mountain Climber"
    #    Try progressively stripping more prefixes
    if not gif_entry:
        progressive = norm
        # Keep stripping prefixes until we find a match or can't strip more
        while True:
            new = strip_prefixes(progressive)
            if new == progressive or not new:
                break
            progressive = new
            gif_entry = gif_by_stripped.get(progressive)
            if gif_entry:
                break
    
    if gif_entry:
        entry['id'] = gif_entry['id']
        entry['gif_url'] = gif_entry['gif_url']
        matched += 1
    else:
        unmatched.append(t)

save_json(fitness_path, fitness_data)

print(f"Total: {len(fitness_data)}")
print(f"Matched: {matched}")
print(f"Unmatched: {len(unmatched)}")
print("\n=== Unmatched ===")
for t in unmatched:
    print(f"  {t}")
