# Codex 独立レビュー用 引き継ぎ（Phase 0）

## 範囲
`git diff origin/main...claude/phase0-rhyme-engine -- scripts data tests project.godot scenes`（dev_format 由来のファイルは対象外）

## 見てほしい点
1. 仕様違反: 距離に「お題と回答以外」の入力（残り距離・打数・乱数・クラブ・風）が混ざっていないか（DistanceCalc / main.gd）
2. 韻判定: `RhymeEngine.analyze`（母音の最長共通連続。ん=N, っ=Q, 長音=直前母音）のエッジケース。拗音・小書き母音・長音
3. ルール: `HoleState.apply_shot` の OVER/OB/CUP_IN 境界、方向反転、打数上限
4. UI: 横画面でキーボード表示時に入力欄・ボタンが隠れないか（実機 iPhone 未確認）、安全領域（MARGIN=40 は仮）
5. 日本語IME: LineEdit の変換確定前の文字列の扱い（実機未確認）

## 既知の制限（Phase 0）
- 設計書 v1.0 は未確認。仮定は `docs/deviation_log.md`
- ゴルファーは仮モデル（プリミティブ）、アニメは10種ではなくスイングのみ
- 池・バンカー・保存・ラウンド中断は未実装
- 辞書は289語。辞書外の漢字は入力不可（かな入力は可）
- 実機確認は未実施（検証は Godot 4.4.1 ヘッドレス＋xvfb のスクリーンショットのみ。仕様は 4.7.2）
