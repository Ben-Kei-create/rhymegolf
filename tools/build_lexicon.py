#!/usr/bin/env python3
"""tools/source/words.tsv から data/lexicon_v1.json と data/prompt_pool_v1.json を生成する（開発用）。
使い方: python3 tools/build_lexicon.py
頻度: freq 1/2/3 → frequency_percentile(珍しさ 0=頻出,1=珍しい) 0.2/0.5/0.85（暫定。独立した頻度資料に置換予定）
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mora import vowels, to_hira

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RARITY = {1: 0.2, 2: 0.5, 3: 0.85}
LEXICON_VERSION = "1.0.0"


def main():
    entries, seen = [], set()
    with open(os.path.join(ROOT, "tools/source/words.tsv"), encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            surface, reading, cat, freq, topic = line.split("\t")[:5]
            reading = to_hira(reading)
            v = vowels(reading)
            if v is None:
                sys.exit("bad reading: " + line)
            if surface in seen:
                sys.exit("duplicate surface: " + surface)
            seen.add(surface)
            entries.append({
                "entry_id": "W%06d" % (len(entries) + 1),
                "surface": surface,
                "reading_hira": reading,
                "vowels": v,
                "semantic_category": cat,
                "frequency_percentile": RARITY[int(freq)],
                "prompt_eligible": topic == "1",
                "approved": True,
                "aliases": [reading],
            })
    out = {"lexicon_version": LEXICON_VERSION, "entries": entries}
    with open(os.path.join(ROOT, "data/lexicon_v1.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    pool = {"lexicon_version": LEXICON_VERSION, "prompt_ids": [e["entry_id"] for e in entries if e["prompt_eligible"]]}
    with open(os.path.join(ROOT, "data/prompt_pool_v1.json"), "w", encoding="utf-8") as f:
        json.dump(pool, f, ensure_ascii=False, indent=1)
    print("entries=%d prompts=%d" % (len(entries), len(pool["prompt_ids"])))


if __name__ == "__main__":
    main()
