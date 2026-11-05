# RHYME GOLF（ライムゴルフ）

「韻を踏んだ結果が、そのままボールの飛距離になる」3Dギャグゴルフ。Godot 4.x / GDScript。iPhone 横画面・オフライン。
仕様の正本: 詳細設計書 v1.0（`docs/design_brief.md` に参照章。設計書全文は追加待ち）。設計書との差は `docs/deviation_log.md`。

## 実行
```bash
godot --headless --path . --import                              # 初回・class_name追加後
godot --path .                                                  # 起動（エディタで F5 でも可）
godot --headless --path . --script res://tests/run_tests.gd     # 自動テスト（151件）
godot --headless --path . --script res://tests/sim_scores.gd    # 飛距離分布（バランス調整用）
godot --headless --path . -- --autoplay --seed=42               # 1ホール自動プレイ（e2e）
python3 tools/build_lexicon.py && python3 tools/validate_lexicon.py   # 辞書の生成・検証
```

## 構成（設計書 §8 準拠、Phase 1 時点）
- `scripts/rhyme/` KanaNormalizer, MoraTokenizer, RhymeScorer（純粋計算・乱数なし）
- `scripts/data/` LexiconRepository, PromptDeck（乱数はここだけ）
- `scripts/golf/` GolfRules, CourseMapper, ShotResolver
- `scripts/core/` GameStateMachine, GameManager
- `scripts/view/CourseView.gd`（3D演出）, `scripts/ui/GameScreen.gd`（UI）
- `data/` lexicon_v1.json, prompt_pool_v1.json, category_distance_v1.json, scoring_config_v1.json, courses_v1.json
- `tools/` 辞書生成・検証（開発用 Python）, `tests/` rhyme / golf / integration

## 絶対条件
飛距離は (お題, 回答, 同一ホール再利用か) だけで決まる。クラブ・風・物理演算・残り距離による補正なし。採点後に演出を再生する。
