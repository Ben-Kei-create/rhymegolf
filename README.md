# RHYME GOLF（ライムゴルフ）

「韻を踏んだ結果が、そのままボールの飛距離になる」ゴルフゲーム。Godot 4.x / GDScript。横画面・iPhone 向け。

## 実行
```bash
godot --path .                                   # 起動（エディタで開いて F5 でも可）
godot --headless --path . --script res://tests/run_tests.gd   # 自動テスト（84件）
godot --headless --path . --script res://tests/sim_scores.gd  # 飛距離分布の確認（バランス調整用）
godot --headless --path . -- --autoplay          # 1ホール自動プレイ（e2e確認）
```
初回・新規 `class_name` 追加後は `godot --headless --path . --import` を一度実行する。

## 構成
- `scripts/core/` … 純粋ロジック（Kana, ReadingDict, RhymeEngine, DistanceCalc, TopicPicker）。決定論的、シーン非依存
- `scripts/game/` … HoleState（ルール）, CourseView（3D演出）, main.gd（UI・進行）
- `data/words.tsv` … 読み辞書（単語/読み/カテゴリ/頻度/出題フラグ）
- `tests/` … run_tests.gd, sim_scores.gd
- `docs/deviation_log.md` … 設計書が未確認のため置いた仮定の一覧（要レビュー）

## 絶対条件
飛距離 = `DistanceCalc.compute(お題, 入力)` のみ。クラブ・風・物理演算・残り距離による補正は無い（`test_no_hidden_correction` で確認）。
