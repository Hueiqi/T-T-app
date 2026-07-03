import json
import re
from pathlib import Path

def load_json(path: str) -> list:
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(path: str, data: list):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

base_dir = Path(r'C:\Users\Lenovo\Documents\CS SELF\FYP')
fitness_path = base_dir / 'lib' / 'assets' / 'fitness_data.json'
gifs_path = base_dir / 'assets' / 'gifs_data.json'

fitness_data = load_json(fitness_path)
gifs_data = load_json(gifs_path)

# Build a set of GIF titles for quick lookup
gif_titles = {e['title']: e for e in gifs_data}
gif_titles_lower = {e['title'].lower().strip(): e for e in gifs_data}

added = 0
for entry in fitness_data:
    if 'gif_url' not in entry:
        # Try to find a match one more time
        t = entry['title']
        tl = t.lower().strip()
        
        # Check if gif_titles has it
        match = gif_titles.get(t) or gif_titles_lower.get(tl)
        
        if not match:
            # Add a placeholder entry to gifs_data
            gifs_data.append({
                'id': entry['id'],
                'body_part': entry.get('body_part', '').lower(),
                'title': entry['title'],
                'gif_url': '',
            })
            added += 1

# Build gif lookup by id for quick id match
gif_by_id = {e['id']: e for e in gifs_data}

# Normalize IDs: use gif id when matched, otherwise keep existing
for entry in fitness_data:
    gif_url = entry.get('gif_url', '')
    if gif_url:
        continue  # already matched
    
    # Check if any gif entry has same title
    t = entry['title']
    for ge in gifs_data:
        if ge.get('title', '').lower().strip() == t.lower().strip():
            entry['gif_url'] = ge['gif_url']
            entry['id'] = ge['id']
            break

# Save both files
save_json(fitness_path, fitness_data)
save_json(gifs_path, gifs_data)

# Count how many fitness entries now have gif_url
with_gif = sum(1 for e in fitness_data if e.get('gif_url'))
without_gif = sum(1 for e in fitness_data if not e.get('gif_url'))

print(f"Fitness entries with gif_url: {with_gif}")
print(f"Fitness entries without gif_url: {without_gif}")
print(f"GIF entries added: {added}")
print(f"Total GIF entries: {len(gifs_data)}")
