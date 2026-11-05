#!/usr/bin/env python3
"""辞書・お題プール・カテゴリ表の整合性検証。使い方: python3 tools/validate_lexicon.py （エラーで終了コード1）"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mora import vowels

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
load = lambda p: json.load(open(os.path.join(ROOT, p), encoding="utf-8"))


def main():
    lex, pool, cats = load("data/lexicon_v1.json"), load("data/prompt_pool_v1.json"), load("data/category_distance_v1.json")
    errs, ids, surfaces = [], set(), set()
    known = {c for g in cats["groups"].values() for c in g}
    for e in lex["entries"]:
        if e["entry_id"] in ids: errs.append("dup id " + e["entry_id"])
        ids.add(e["entry_id"])
        if e["surface"] in surfaces: errs.append("dup surface " + e["surface"])
        surfaces.add(e["surface"])
        if vowels(e["reading_hira"]) != e["vowels"]: errs.append("vowels mismatch " + e["surface"])
        if e["semantic_category"] not in known: errs.append("unknown category %s (%s)" % (e["semantic_category"], e["surface"]))
        if not 0.0 <= e["frequency_percentile"] <= 1.0: errs.append("bad freq " + e["surface"])
        if not e["approved"]: errs.append("unapproved entry shipped " + e["surface"])
    for pid in pool["prompt_ids"]:
        if pid not in ids: errs.append("pool id missing " + pid)
    if pool["lexicon_version"] != lex["lexicon_version"]: errs.append("version mismatch")
    for e in errs: print("ERROR:", e)
    print("OK" if not errs else "FAILED", "entries=%d prompts=%d" % (len(lex["entries"]), len(pool["prompt_ids"])))
    sys.exit(1 if errs else 0)


main()
