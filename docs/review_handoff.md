# Codex 独立レビュー用 引き継ぎ（Phase 0 + Phase 1 縦切り）

## 範囲
`git diff origin/main...HEAD -- scripts data tests tools project.godot scenes`（dev_format 由来の文書は対象外）

## 重点（設計書 §13 のレビュー担当）
1. 採点: `RhymeScorer`（5.2–5.5）。丸め `floorf(x*10+0.5)/10`、補正の積算順、N/Q の一致、長音・小書き仮名
2. 距離に残り距離・打数・乱数が混入していないか（`RhymeScorer.evaluate` の引数は prompt/answer/reused のみ）
3. `GolfRules`: OB/池のストローク数（1打＋罰1）、カップ半径0.8の境界、方向反転、15打
4. 二重実行: `GameManager.submit` の状態ガード（G06）、`GameStateMachine` の不正遷移
5. IME: `GameScreen._on_text_submitted` の回避策（G07）。**実機のみで検証可能**
6. 辞書権利: 現辞書は本リポジトリ作成者による自作の289語。外部辞書は未使用

## 既知の制限
- 設計書 §11 のうち G07(IME実機)・G08(保存復帰)は未検証/未実装（SaveManager は Phase 3）
- 辞書289語・お題180件（目標 3,000/300）。現辞書の最大飛距離は約178yd（`sim_scores.gd`）で、300yd級（L=6以上）は実質出ない → 辞書拡充と係数調整が必要
- ゴルファーは仮モデル、アニメはスイングのみ。直線コース1ホール
- 検証は Godot 4.4.1 ヘッドレス＋xvfb のみ。iPhone 実機・4.7.2 は未確認
