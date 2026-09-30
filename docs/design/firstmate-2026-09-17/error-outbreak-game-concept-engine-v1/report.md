# error-outbreak ゲーム企画・エンジン選定レポート

調査日: 2026-09-16

## 結論

このレポートでは、**調査から得た技術評価**と**captain が選んだ実装方針**を分けて記録する。

- **技術評価**: `github.io` の短い初回ロード、Web 標準、決定論的テスト、TypeScript + Vite との親和性だけを重み付けすると、Phaser 4.2.1 が最も適合する。この比較結果と反証材料は後段に残す。
- **採用方針**: captain は 2026-09-16 に「Godot がいいな、せっかくなら」と選択した。したがって実装は **Godot 4.7.2、GDScript、Compatibility renderer、default single-thread Web export** で進める。
- **contingency**: Godot prototype が後述の GitHub Pages 即時プレイ基準を満たせない場合だけ、Phaser 4.2.1 + TypeScript + Vite を代替案として再評価する。

この選択は技術比較を覆い隠すものではなく、Godot の統合 2D editor、AnimationPlayer、Control node を活かして「せっかくならキャラクターと演出までゲームらしく作る」という product direction を優先したものである。Godot の現在デフォルトの single-thread Web export は特殊なレスポンスヘッダーなしで GitHub Pages に置けるため、最優先条件である「`github.io` の URL を開けば、インストールなしですぐ遊べること」と両立できる。WebAssembly と `.pck` の起動負荷、WebGL 2.0、Safari・モバイル上の制約は prototype の合否条件として明示的に測る。

ゲーム案は、落下カプセルや色合わせではなく、**見えている警報反応から見えない汚染を推定し、格子状の隔離区画を封鎖する「推理型封じ込めパズル」**とする。仮題は **ERROR OUTBREAK: WARD ZERO**。SyndromeOut の魅力である「全部消しただけでは安全とは限らない」を核に残しつつ、キャラクター、世界観、画面構成、ルール説明、アート、音楽、実装はすべて新規にする。

## 調査範囲と前提

- SyndromeOut は公開リポジトリ `stn/SyndromeOut` の commit [`a1a3c53`](https://github.com/stn/SyndromeOut/tree/a1a3c53cdc07f15e472b204eba478ec0420c1a92) を `gh-axi` で取得し、ゲーム状態、UI、デコーダー、テスト、Web ビルドを読んだ。
- ライセンスは [MIT](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/LICENSE) である。ただし本企画ではコードや画像をコピー、インポート、改変利用しない。メカニクスの観察資料としてのみ扱う。
- `uv run pytest -q` の結果は **65 passed, 0 failed, 1 skipped** だった。
- 公開版 `https://stn.github.io/SyndromeOut/50009C` も `chrome-devtools-axi` で起動し、Canvas、音声開始のクリック、ネットワーク要求を確認した。
- 比較対象は Phaser 4、Godot、Unity、LÖVE。一次資料は各公式ドキュメント、公式リリース、公式ソースを優先した。
- error-outbreak の worktree は `.git` 以外に製品ファイルがなく、維持すべき既存実装 stack はない。初期の ecosystem 比較は captain の TypeScript + Vite 希望と GitHub Pages 最優先条件に対して行い、その evidence を保持した上で、後続の captain 選択により Godot を実装方針とした。

## SyndromeOut から学ぶべきこと

### 1. 中核メカニクス

SyndromeOut は、回転表面符号を Lights Out 型の操作にしたゲームである。盤面のデータ点に X、Z、Y の補正を置くと、隣接する対応色の面が反転する。見えるのは hidden error 自体ではなく syndrome、つまり周辺に異常があることを示す反応だけである。

根拠:

- README は「点灯した stabilizer face を X/Z 補正で消す」と定義している: [README.md:7-13](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L7-L13)
- 操作は X、Z、両方の Y、undo/redo、判定、同じ seed の retry、新規 seed からなる: [README.md:20-35](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L20-L35)
- `Board` は hidden error、player correction、bot correction、verdict、undo/redo を UI から分離している: [game.py:90-121](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L90-L121)
- 表示中の反応は `syndrome(error * correction)` であり、全消灯が判定の前提である: [game.py:128-149](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L128-L149)

特に優れているのは、**全消灯が勝利ではなく、判定可能になっただけ**という二段階構造である。全消灯でも、残差が盤面の端から端へ抜ける logical path なら失敗になる。単純な消去パズルに「見えない原因の推定」と「局所的に正しく見えても全体では危険」という奥行きが生まれている。

- 判定後は player correction、bot、true error、residual を比較する: [README.md:37-42](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L37-L42)
- 全消灯なのに logical Z で失敗する具体例がある: [README.md:95-104](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L95-L104)
- `judge()` 自体も全消灯時だけ logical effect を評価する: [game.py:194-207](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L194-L207)

### 2. 情報モデル

プレイヤーが扱う情報は次の三層に分かれる。

1. **見えるもの**: 2 種類の警報面、置いた補正、残数、seed。
2. **操作から予測できるもの**: ある点がどの面を反転するか、現在の補正 weight、全消灯か。
3. **判定まで隠すもの**: true error、残差の位相クラス、安全な補正だったか。

4 つの logical class を最尤確率で比較し、Y を X と Z の二重コストではなく 1 個の joint error として数える点も重要である: [decoder.py:1-14](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/decoder.py#L1-L14)、[decoder.py:296-304](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/decoder.py#L296-L304)。

ただし、ゲームとしては「最善の推定をしても実際の hidden error と違い、失敗になる」盤面がある。[README.md:44-53](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L44-L53) はこの性質を明示している。これは教材として面白いが、通常のキャンペーンで連勝を失わせると不公平感が強い。新作では後述のように、キャンペーンと研究モードで扱いを分けるべきである。

### 3. インタラクションと画面構造

現行 UI は 360 x 240 の固定 Canvas で、左に盤面、右に数値・凡例・ボタンを置く: [app.py:25-29](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L25-L29)。判定後は盤面を 2 x 2 に分ける: [app.py:137-154](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L137-L154)。キーボードとマウスの両方を実装し、hover 中は影響面を示す。[app.py:207-267](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L207-L267)

取り入れるべき点:

- 置く前に影響範囲が分かる preview。
- mouse と keyboard の同等操作。
- undo/redo と同一 seed retry。
- 判定後に「なぜ成功・失敗したか」を可視化する postmortem。
- seed が盤面条件を完全に再現し、共有できること。seed の round-trip もテストされている: [test_game.py:194-210](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/tests/test_game.py#L194-L210)。

そのまま持ち込まない点:

- 文字と抽象図形だけの固定レイアウト。
- 判定後の 2 x 2 比較画面。新作では scanner の時間順リプレイに置き換える。
- X/Z/Y、stabilizer、logical error といった用語を最初から前面に出すこと。
- Canvas だけでアクセシビリティ情報を持たない構成。

### 4. 現行 Web 版から見える技術制約

現行ビルドは Pyxel app を Pyodide でブラウザ実行し、NumPy も CDN からロードする: [README.md:87-93](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L87-L93)、[build_web.py:1-14](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/scripts/build_web.py#L1-L14)。任意の seed path を GitHub Pages で開くため `index.html` と `404.html` を同内容にしている: [build_web.py:42-49](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/scripts/build_web.py#L42-L49)。

公開版を 1 回コールド起動した観察では、Pyxel wheel、Python standard library、Pyodide wasm、NumPy wheel の 4 つだけで圧縮転送サイズが合計 **13,836,256 bytes、約 13.2 MiB** だった。これに JS やアプリ本体が加わる。起動前には `CLICK TO START` が出る。これは既存作の欠点というより、Python/Pyodide 方式のコストである。まっさらから Web 向けに作る本作では、このランタイムを持ち込まない価値が大きい。

## 新ゲーム案: ERROR OUTBREAK: WARD ZERO

### 独自の世界観とキャラクター

舞台は、未知の「グリッチ胞子」を隔離する軌道上研究区画 WARD ZERO。プレイヤーは医者ではなく**封鎖技師**である。実物の胞子は配管内部に隠れており、観測窓に出る「反応体」だけを手掛かりに封鎖フィールドを置く。

キャラクター案:

- **カク**: 橙色、角張った輪郭と三角の瞳を持つ高熱反応体。短く震え、隣の junction をにらむ。
- **モヤ**: 青緑色、半透明で丸い低温反応体。ゆっくり膨らみ、波紋を出す。
- **ツヅリ**: 2 種類の性質が同じ junction に重なったとき、判定リプレイだけに現れる二重らせん状の隠れ胞子。
- **WARD コア**: チュートリアルを行う施設 AI。Dr. Mario のような人間の医師役は出さない。

キャラクターは単なる色玉ではない。輪郭、瞳、動き、模様、効果音を種別ごとに変え、色覚に依存せず判別できるようにする。封じ込め時は消滅・殺傷ではなく、小さな保存容器へ吸い込まれて眠る演出にする。

避ける表現:

- 落下する薬・カプセル、瓶、同色 4 個消し、医師風の主人公。
- Dr. Mario のバイ菌に似たシルエット、顔、配色、ポーズ、画面構成、旋律。
- SyndromeOut の名称、画像、配色、2 x 2 判定画面、コード、音素材。

### 1 プレイの流れ

1. **SCAN**: seed から hidden outbreak を生成し、カクとモヤの警報反応だけを観測窓に出す。
2. **TRACE**: junction を hover、focus、tap すると、どの観測窓が反転するかを光る配管で preview する。
3. **SEAL**: α seal、β seal、両方を兼ねる dual seal のいずれかを junction に置く。同じ seal を再度置けば外れる。
4. **ADJUST**: undo/redo、seal の交換、同一 seed retry を自由に行う。
5. **LOCKDOWN**: すべての反応体が眠ったときだけ最終封鎖を実行できる。
6. **AUDIT**: scanner が「観測反応 -> プレイヤーの seal -> 実際の胞子 -> 残差経路」を時間順に重ねて表示する。
7. **RESULT**: 安全なら次区画へ。端から端へ残差経路が抜けたら breach として、経路ヒント付きで同じ盤面を再試行する。

α/β/dual は内部モデルでは 2 bit の操作だが、UI では量子用語を使わない。上級者向けの「研究ノート」で初めて parity、4 class、maximum likelihood を説明する。

### 勝敗と「不公平な失敗」への対策

**キャンペーン:**

- 勝利は「全反応を停止し、残差が安全 class」である。
- 全消灯前は LOCKDOWN を押せない。手数超過を即失敗にはしない。
- 生成時に、true class が一意な maximum-likelihood class と一致する盤面だけを採用する。少なくとも教材キャンペーンでは「最善の推定でも運悪く失敗」を起こさない。
- breach 時は残差経路を見せ、同じ seed をすぐ retry できる。ライフ消費は設けない。

**DAILY LAB / 研究モード:**

- hidden reality と maximum-likelihood の不一致を許す。
- ランキング相当の主評価は「観測情報に対して最尤 class を選んだか」で決め、実際の outbreak が外れたケースは `RARE SAMPLE` として記録する。運で streak を失わせない。
- GitHub Pages だけでは改ざん耐性のあるオンライン順位表は作れないため、最初はローカル記録と共有用 result code のみとする。

### スコア、コンボ、リプレイ性

最終スコアの優先順位は以下とする。

1. 安全に封鎖したか。
2. seal weight が既知の最小安全 weight にどれだけ近いか。
3. 初回判定で成功したか。
4. 任意のスタイルボーナス。

星評価:

- 3 星: 最小安全 weight。
- 2 星: 最小 +1。
- 1 星: それ以上でも安全。
- breach: 0 星、同一 seed retry。

**Containment Chain** は、連続して active reaction 数を減らした操作に 1、2、3... の視聴覚フィードバックを付ける。途中で一度増やす必要がある解法もあるため、chain は最終評価の小さな加点にとどめる。undo で状態と chain を同時に巻き戻し、同じ状態の往復では加点しない。これで undo や seal の付け外しによる稼ぎを防ぐ。

リプレイ性は campaign、seed challenge、daily lab の 3 本に限定する。盤面共有は path ルーティングではなく `?v=1&seed=...&mode=...` を使い、GitHub Pages の 404 fallback に依存しない。

### 難易度曲線

1. **導入 1-3**: 3 x 3、カクだけ。1 手で反転する窓を preview で学ぶ。
2. **導入 4-6**: モヤを追加。α と β が別の窓に効くことを学ぶ。
3. **区画 2**: dual seal を追加。2 種が同じ junction に重なる意味を学ぶ。
4. **区画 3**: 「全消灯でも breach」が初登場。必ず短い境界経路で、audit を一目で理解できる盤面にする。
5. **区画 4**: 5 x 5、seal weight と 3 星解法。
6. **区画 5**: 7 x 7、より高い outbreak rate、複数の安全解法。
7. **研究モード**: 9 x 9、最尤 class、rare sample、共有 seed。

盤面サイズと outbreak rate を同時に上げず、新しい概念を 1 つずつ導入する。最初から数式を読ませない。

## 映像・音響設計

### 視覚フィードバック

- idle: カクは細かく震え、モヤは呼吸する。すべて 1-2 px 相当の小さな動きに抑える。
- preview: 影響する観測窓まで配管が発光し、キャラクターが junction の方を見る。
- seal: junction が沈み、対応する形の紋章が残る。
- containment: キャラクターが容器へ吸い込まれ、窓は暗くなる。
- misstep: 新たに反応が出ても罰音ではなく、短い警報と脈動で知らせる。
- lockdown: 全窓が静止し、1 拍の無音後に scanner が走る。
- safe: 緑だけに頼らず、閉じた六角形と上向き和音を出す。
- breach: 境界を横断する太い破線、方向矢印、低い下降音で理由を示す。

判定後の比較は 4 面同時表示にせず、同一盤面上でレイヤーを順に再生し、任意の段階へ戻れる scrubber を付ける。モバイルでも盤面を小さくし過ぎず、「なぜ」の理解を優先できる。

### BGM レイヤー

最初の playable では外部 audio middleware は不要で、Godot の `AudioStreamPlayer` と事前レンダリング済み stem で足りる。3 本を同時開始し、Audio bus または各 player の volume だけを変える。Web export は default の Sample playback を使い、初期段階では Web 非対応の AudioEffects、reverb、procedural audio に依存しない。

同じ BPM・同じ長さの 3 stem を用意する。

1. **Base**: 低い marimba / soft synth。常時ループ。
2. **Pulse**: 未解決 reaction 数が増えると音量が上がる軽い打楽器。
3. **Tension**: 盤面サイズ、残り reaction、lockdown 可能状態に応じて薄く加える持続音。

状態変化は次の小節境界で 150-300 ms crossfade し、stem の再スタートによる位相ずれを避ける。全消灯で Pulse を落とし、LOCKDOWN で 1 拍無音、safe/breach は専用 stinger、その後同じ transport へ復帰する。

SFX は hover/focus、α、β、dual、undo、reaction 出現、reaction 封鎖、lockdown denied、safe、breach を分ける。同じ短音を連打するときは 2-3 種の微差を用意するが、ランダム pitch は cosmetic RNG に限定し、ゲーム seed へ影響させない。

ブラウザは原則として user gesture 前の音声再生を止める。Godot の Web export 公式 docs も、splash screen 上の click/tap/key で音を有効化する方法を推奨する: [Godot Web export - Audio](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#audio)。したがって custom HTML shell の `START / 音声を有効化` を最初の明示操作にし、そこから Godot Engine を起動する。ミュートでも開始でき、BGM と SFX の Audio bus 音量、mute は別々に保存する。

### アクセシビリティ

- 色に加えて、カク=角形/斜線/高音、モヤ=円形/点模様/低音で区別する。
- colorblind preset、高 contrast、reduced motion、screen shake off、flash off を用意する。
- デフォルトでは制限時間を付けない。daily の timer も pause 可能にする。
- keyboard、pointer、touch、gamepad を同じ `GameAction` に正規化する。
- desktop は矢印/WASD で移動、1/2/3 で seal、Enter で lockdown、Ctrl+Z/Y で undo/redo。
- mobile は右クリックを要求せず、tap で junction 選択、画面下の α/β/dual ボタンで配置する。操作対象は最低 44 CSS px 相当を確保する。
- BGM/SFX 個別音量、全 SFX の visual counterpart、字幕相当の status log を付ける。
- Godot の Web Canvas とは別に semantic HTML の操作面を持ち、盤面の focus、選択 junction、reaction 数、lockdown 結果を `aria-live` で通知する。Canvas 描画を直接 screen reader に読ませようとしない。
- custom HTML shell の semantic HTML は core state の別 renderer として実装し、Godot の Control UI と同じ action を dispatch する。これにより accessibility が描画コードの後付けにならない。

## 最初に固める AI の「目と手」

captain の方針どおり、gameplay を増やす前に、agent が画面を見て通常操作で検証できることを最初の基盤にする。ただし独自の daemon、WebSocket RPC、test dashboard、別ルールの test mode は作らない。Godot と browser の通常機能を、1 つの小さく深い interface へ接続する。

### seam と interface

seam は `ValidationSurface` とし、interface は次の 3 操作だけにする。

```text
launch(RunSpec)
observe() -> PublicSnapshot
perform(InputStep)
```

- `RunSpec`: `schema_version`、`puzzle_version`、`level_id`、`seed`、viewport size。
- `PublicSnapshot`: `seq`、`phase`、`ready`、`visual_settled`、seed、公開盤面、置かれた seal、reaction 数、選択対象、可能な action、verdict、`state_hash`、semantic target の id/label/rect/enabled。
- `InputStep`: keyboard key、pointer click、touch tap のいずれかと、必要なら stable target id。複数 step の JSON Lines がそのまま replay trace になる。

interface の不変条件:

- `observe()` は read-only で、AUDIT 前の hidden outbreak や正解 class を返さない。release Web で cheat interface にしない。
- accepted input ごとに `seq` が単調増加する。`state_hash` は animation time ではなく公開 logical state から作る。
- `perform()` は `GameSession` を直接書き換えず、必ず通常の `InputMap` / `_input` / Control signal を通す。
- target id は `screen/start`、`seal/alpha`、`junction/2/1`、`command/undo`、`command/lockdown` のように schema-versioned で安定させる。座標は観測値であり identity ではない。
- screenshot は `visual_settled=true` を待ってから撮る。animation を test 専用に skip しない。
- unknown target、無効な action、schema mismatch は明示的に失敗し、黙って no-op にしない。

この module を削除すると、seed 起動、semantic observation、accessibility mirror、replay、failure 診断の複雑さが各 test と各 UI に散る。そのため interface の小ささに対して十分な Depth があり、native と Web の 2 adapter を置く実在する seam になる。

### Native debug adapter

- 起動は Godot 標準 CLI の user args を使う。例: `godot --path . -- --puzzle-version=1 --level=intro-01 --seed=42 --trace=/tmp/run.jsonl`。ゲーム本体も共有 URL も同じ `RunSpec` parser を使う。
- trace runner は `InputStep` を `InputEventKey`、`InputEventMouseButton`、`InputEventScreenTouch` に変換し、Godot 標準の [`Input.parse_input_event()`](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-parse-input-event) へ渡す。action reducer の直呼びはしない。
- target id 指定は最新 `PublicSnapshot.targets` の rect 中央へ解決してから pointer/touch event にする。layout が変わっても trace の意味が保たれる。
- semantic snapshot は 1 行 1 JSON で stdout と artifact file に出す。live socket は作らない。agent は trace を 1 step 追加して再実行すればよく、seed と state hash により再実行コストは小さい。
- 静止画は root `Viewport` の texture を `Image.save_png()` で checkpoint ごとに保存する。連続 frame が必要な失敗だけ Godot 標準の [`--write-movie` と `--fixed-fps`](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html#command-line-usage) を使う。

### GitHub Pages Web adapter

- 起動は `?v=1&level=intro-01&seed=42`。path routing は使わない。
- custom HTML shell に、実際の accessibility にも使う semantic mirror を置く。要素には `data-eo-id="junction/2/1"` のような stable selector、button label、disabled state を持たせる。
- Godot 側は公式の [`JavaScriptBridge`](https://docs.godotengine.org/en/stable/tutorials/platform/web/javascript_bridge.html) で公開 snapshot を mirror へ送り、mirror の click/focus action を通常の `GameAction` 入力へ戻す。custom shell は Godot 公式の [Web export template 機構](https://docs.godotengine.org/en/stable/tutorials/platform/web/customizing_html5_shell.html) を使い、生成後 HTML を patch しない。
- Playwright は `locator('[data-eo-id="..."]')`、`page.keyboard`、`page.mouse`、mobile context の `touchscreen.tap` を使う。semantic selector の完走 test と、Canvas 上の実 pointer/touch hit test を両方 1 本ずつ持つ。
- `page.screenshot()`、Playwright trace/video、console、network、最終 `PublicSnapshot` を通常の Playwright artifact として保存する。独自 screenshot server は作らない。

### replay と failure artifact

`InputStep` の JSON Lines は native と Web で共有する。adapter は同じ target id を native InputEvent または Playwright 操作へ変換する。成功 run には seed、trace、最終 state hash だけを残し、失敗時は以下を 1 directory に集める。

```text
metadata.json        commit, Godot version, platform, viewport, seed
input-trace.jsonl    replayable InputStep
state.jsonl          seq ごとの PublicSnapshot
last-frame.png       failure 時の画面
engine.log           native の stdout/stderr または browser console
playwright-trace.zip Web の場合のみ
network.json         Web の 404 と response 情報
```

assertion は可能な限り semantic state に対して行い、pixel comparison は layout 崩れを見る少数の golden screenshot に限定する。AI の画像理解は最終的な見た目の批評に使い、ゲーム状態の正しさを画像認識だけで推測させない。

### ordinary tooling のままにするもの

- process 起動、ログ、headless export は Godot CLI。
- scene/node authoring、animation、layout は Godot editor。
- input は InputMap、InputEvent、Control signal。
- native frame capture は Viewport / Movie Maker。
- Web の操作、screenshot、video、trace、network は Playwright と browser DevTools。
- build/deploy artifact は GitHub Actions / Pages。

作らないものは、常駐 controller、独自 remote protocol、scene tree 全公開、hidden state を読む release hook、test 専用の勝利 shortcut、別 physics clock、独自 selector query language である。

## 最初の playable slice

実装前に作る範囲を次に固定する。

### 含める

- Godot 4.7.2 standard build、GDScript、Compatibility renderer、single-thread Web export を固定した project/export preset。
- `ValidationSurface`、native trace runner、Web semantic mirror、共通 replay trace、failure artifact。
- タイトル、custom HTML の click-to-start / 音声 unlock、設定。
- 手作業で選んだ 3 面。3 x 3 を 2 面、5 x 5 を 1 面。
- カク、モヤ、ツヅリの AnimatedSprite2D / AnimationPlayer による placeholder animation。
- α/β/dual seal、preview、undo/redo、restart。
- 全消灯 gating、safe 1 面、breach 1 面。
- scanner の時間順 audit。
- weight による 1-3 星と Containment Chain。
- 3 つの AudioStreamPlayer による Base/Pulse/Tension の短い仮 stem、主要 SFX。
- desktop keyboard/mouse、`InputEventScreenTouch` と mobile browser 相当 touch layout。
- Control UI と custom HTML semantic mirror の同一 action、reduced motion、mute、高 contrast。
- query string seed、versioned `user://` save。
- GitHub Pages への single-thread Web build の Actions deploy と Playwright E2E。

### 含めない

- procedural campaign generator。
- 実行時の exact maximum-likelihood solver。
- アカウント、サーバー、オンライン leaderboard。
- PWA/offline、native release package、課金。
- 常駐 automation daemon、独自 RPC/control plane、test 専用 gameplay 分岐。
- 完成アート、多言語、9 x 9。

最初の 3 面は level data に正解 class と最小安全 weight を持たせる。decoder を先に本実装せず、操作感と「全消灯なのに危険」の納得感を検証する。ゲーム性が通った後に、独自に仕様を書き直した generator/solver を実装する。

### playable の受け入れ条件

- `https://<user>.github.io/error-outbreak/` を直接開いて遊べる。
- `/error-outbreak/` 配下で HTML、JS、wasm、pck、sprite、font、audio の 404 が 0 件。
- clean profile を 10 Mbps / 40 ms latency に制限した desktop/mobile browser で、START から interactive board まで cold 8 秒以内、warm reload 3 秒以内とする。1 秒以内に loading progress を出し、その後 1 秒を超える無表示停止を作らない。Godot blank export と playable の転送量を別々に artifact へ記録し、engine baseline と game asset 増分を混同しない。
- 390 x 844 と 844 x 390 の両方で、盤面と操作ボタンが欠けない。`canvas_items` + `expand` と Control anchor で成立する。
- mouse を使わず 3 面完走できる。touch の right-click 代替を必要としない。
- mute 状態でも全情報が得られ、色を grayscale にしても 2 種を識別できる。
- 同じ `puzzleVersion + seed + input-trace` を native debug と Web で再生し、各 accepted input 後の public `state_hash` と最終 verdict が一致する。
- agent が seed 指定で起動し、ready を観測し、keyboard で 1 面、pointer で 1 面、touch で 1 面を完走し、各 phase の screenshot を取得できる。
- わざと誤った期待値を 1 回与えると、seed、replay trace、semantic state、last frame、log、Web trace が failure artifact に揃う。
- release Web の `PublicSnapshot` から AUDIT 前の hidden outbreak を取得できない。
- tab 非表示から復帰しても BGM stem が二重再生せず、パズル状態が進まない。

## エンジン比較

### 比較表

| 基準 | Phaser 4.2.1 + TS + Vite | Godot 4.7.2 | Unity 6 系 | LÖVE 11.5 |
|---|---|---|---|---|
| iteration speed | Vite HMR と browser reload。pure TS は最速 | scene editor と one-click Web preview が強い | Editor import と Web build が重い | Lua の native 実行は速いが Web 変換が別工程 |
| 2D animation | sprite、atlas、animation、tween、particle が十分。visual editor はない | 専用 2D renderer、AnimationPlayer、particle、scene editor が最も強い | Sprite、Tilemap、Animator、2D URP と機能は豊富だが過大 | draw API は軽いが、animation/editor は自作または library |
| UI | Canvas + DOM/CSS の二層。accessible UI を Web 標準で作れる | Control node と theme が強い | uGUI/UI Toolkit が強いが選択肢が複雑 | 標準 widget/layout が弱い |
| audio middleware | 内蔵 Sound Manager で 3 stem に十分。外部不要 | Audio bus は強い。ただし Web Sample mode は effect 非対応 | FMOD 統合済みだが Web は basic subset。今回には過大 | native audio API は簡潔。love.js compatibility は audio に難あり |
| target | desktop/mobile browser が主。native は third-party wrapper | Web、desktop、mobile を公式 export | Web、desktop、mobile、console まで広い | desktop/mobile は公式、Web は非公式 love.js |
| deterministic logic | Phaser 非依存の pure TS、整数、seeded PRNG にしやすい | pure GDScript で可能。C# は Godot 4 Web export 不可 | pure C# で可能。物理は Web と他 platform で差があり得る | pure Lua で可能 |
| testing | Vitest が Vite config を共有。Playwright を足しやすい | GUT/GdUnit 等の addon と headless runner が必要 | Unity Test Framework が Edit/Play Mode に対応 | community test library が必要 |
| asset pipeline | Vite import/hash と Phaser Loader。atlas/font 最適化は構成が必要 | importer、resource、atlas、scene の統合が強い | importer、Addressables 等が最も豊富だが複雑 | filesystem 中心で手作業が多い |
| GitHub Pages | `dist/` をそのまま配置。subpath は Vite `base` | single-thread export は静的配置可能。gzip も Pages 対応 | 静的配置可能だが compression header/fallback 設定が必要 | love.js が必要。thread 版は COOP/COEP が必要 |
| build/start size | 公式 demo 実測 1.7 MiB raw、約 649 KiB gzip | wasm + pck。公式 docs も「通常大きい」とし gzip を推奨 | wasm + framework + data。一般に初回起動負荷が大きい | love.js runtime wasm 約 4.7 MB raw + JS + game |
| license | MIT | MIT | proprietary。Personal は過去 12 か月の revenue/funding 20 万 USD 未満 | zlib/libpng |
| maintainability / fit | 初期希望の TS + Vite。Web の通常ツールで保守可能 | GDScript と binary runtime は増えるが、captain 選択と editor-driven character 制作に合う | 小規模 Web パズルには運用面が過大 | 小さく美しいが「URL 即プレイ」と公式 support が噛み合わない |

### Phaser 4 の根拠とリスク

Phaser 自身が「Web browser を第一対象とする 2D framework」で、desktop/mobile browser、JavaScript/TypeScript を対象としている: [What is Phaser?](https://docs.phaser.io/phaser/getting-started/what-is-phaser)。最新 stable は [4.2.1、2026-07-09](https://phaser.io/download/release/v4.2.1) で、[MIT license](https://github.com/phaserjs/phaser/blob/v4.2.1/LICENSE.md) である。mouse/touch を同じ pointer API に統合する: [Input](https://docs.phaser.io/phaser/concepts/input)。Scale Manager は FIT、resize、orientation change を持つ: [Scale Manager](https://docs.phaser.io/phaser/concepts/scale-manager)。

公式 `template-vite-ts` も TypeScript、Vite、hot reload、production build、asset copy を案内している: [README](https://github.com/phaserjs/template-vite-ts/blob/d1d7d58acfcf47f97642bcb8b4967071b85f8db9/README.md)。ただし現状を無批判には採用できない。

実地確認した反証材料:

- Phaser 4.0.0 の正式リリースは [2026-04-10](https://phaser.io/download/release/v4.0.0) で、メジャー版としてまだ約 5 か月しか経っていない。
- 4.2.1 の release note には ESM build を壊す namespace access、親 container への ScaleManager resize、Tween startDelay などの修正がある: [v4.2.1 release](https://github.com/phaserjs/phaser/releases/tag/v4.2.1)。今回使う ESM、responsive layout、tween に直結するため、prototype で重点確認が必要である。
- 公式 template の `package.json` は Phaser 4.0.0 だが、同 commit の lockfile は Phaser 3.88.2 のままで、`npm ci` は `lock file's phaser@3.88.2 does not satisfy phaser@4.0.0` と失敗した。
- Phaser 4.2.1 に更新後の `npm audit` は build dependency に high 5 件を報告した。`npm audit --omit=dev` は 0 件だったが、template が pin する Vite 6.3.1 等は古い。
- 公式インストールページ内にも Phaser 3.86 の CDN 例が残る: [Installing](https://docs.phaser.io/phaser/getting-started/installation)。v4 API は型定義と release note を照合する必要がある。

したがって、contingency として Phaser を採る場合も **公式 template を clone してそのまま始めない**。最新 Vite の `vanilla-ts` を最小構成で作り、`phaser@4.2.1`、TypeScript、Vitest、Playwright を明示 pin し、lockfile を CI で `npm ci` 検証する。template の匿名 telemetry 用 `log.js` も持ち込まない。

測定値は、公式 demo を Phaser 4.2.1 に直して `npm run build-nolog` した結果である。

- `dist/`: 1.7 MiB raw。
- Phaser chunk: 1,376,411 bytes raw。
- JS 全体: gzip -9 で 353,879 bytes。
- demo 画像等を含む全ファイル合計: gzip -9 で 664,398 bytes、約 649 KiB。

これは完成ゲームの保証値ではなく baseline だが、公開中 SyndromeOut の Pyodide 系 unique payload 約 13.2 MiB より小さく、URL 即プレイの方向に合う。

### Phaser と Godot Web export の直接比較

Godot の現行 stable 系は [4.7.2](https://godotengine.org/download/archive/4.7.2-stable)。公式 docs によれば Web export は WebAssembly と WebGL 2.0 を必要とし、Godot 4.3 以降は single-thread が default かつ推奨で、special header を不要にした: [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。したがって「Godot は GitHub Pages に置けない」は誤りである。置ける。

具体的な差:

- **static hosting**: Phaser は JS/CSS/asset、Godot は HTML/JS/wasm/pck を配置する。Godot docs は GitHub Pages が gzip on-the-fly を提供すると明記する。
- **cross-origin isolation**: Phaser はこのゲームでは不要。Godot も default single-thread なら不要。Godot で thread または GDExtension を有効にすると COOP/COEP が必要で、PWA service worker workaround もあるが、この軽量パズルでは thread を有効にしない方が単純である。
- **browser**: Phaser は Canvas/WebGL の通常 JS app。Godot 4 は Compatibility renderer の WebGL 2.0 のみで、公式 docs は Safari に他 browser より問題があると注意する。
- **mobile**: Phaser は desktop/mobile browser を主対象とし、input も pointer 統合。Godot Web も mobile で動くが、公式 docs は native より大幅に遅く、WebAssembly では CPU/GPU がより厳しいとする。
- **初回 download/start**: Phaser demo の JS 全体は gzip 約 346 KiB。Godot は wasm と pck が通常大きく、公式 docs は wasm が gzip で約 1/4 まで圧縮されるとしても server compression を強く推奨する。Godot 公式 export templates 一式は release asset 上 1,281,349,702 bytes で、CI cache も Phaser の npm install より重い。これは runtime payload の値ではない点に注意が必要である。
- **audio**: 両方 user gesture が必要。Godot default Sample mode は low latency だが AudioEffects、reverb、procedural audio が非対応。Stream mode は全機能を使える代わりに、thread 無効時の latency が上がる。3 stem の volume crossfade ならどちらでも足りる。
- **save**: Phaser は `localStorage`、Godot Web の `user://` は IndexedDB。Godot docs は cookies/IndexedDB 拒否と private mode で persistence が失われると警告する。どちらも保存失敗 fallback が必要。
- **build reproducibility**: Phaser は Node と lockfile を pin して `npm ci && npm test && npm run build`。Godot は editor と export template の完全一致を pin し、`godot --headless --export-release` を使う。CLI export は公式に CI 用途をサポートする: [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html#exporting)。
- **testing**: pure TS + Vitest は engine を起動せず高速に parity test を回せる。Godot は [GUT](https://godotengine.org/asset-library/asset/1709) などの addon が必要になる。
- **2D 制作**: Godot の専用 2D renderer、Control node、theme、AnimationPlayer は Phaser より明確に優れる: [2D](https://docs.godotengine.org/en/stable/tutorials/2d/index.html)、[UI](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)。大量の演出を非プログラマーが editor 上で調整する段階では差が広がる。
- **言語**: Godot 4 の C# project は現在 Web export 不可と公式 docs にあるため、採用実装は GDScript 前提になる。

**比較 evidence の結論**として、軽い盤面パズルを最短・最小で github.io に出す条件だけなら Phaser の方が小さく単純である。一方、Godot も技術的に成立し、captain は 2D editor と演出制作を含む product direction を重視して Godot を選択した。以降の実装設計はその選択に従う。

### Unity と LÖVE を選ばない理由

Unity は [2D、Sprite、Tilemap、2D physics](https://docs.unity3d.com/Manual/Unity2D.html) と [Unity Test Framework](https://docs.unity3d.com/Packages/com.unity.test-framework@1.4/manual/index.html) が強い。Web は desktop に加えて iOS Safari 15+ と Android Chrome 58+ を公式 support する: [Web browser compatibility](https://docs.unity3d.com/Manual/webgl-browsercompatibility.html)。一方、Web build は wasm、framework、data を持ち、compression と `Content-Encoding`、decompression fallback の選択が必要になる: [Deploy a Web application](https://docs.unity3d.com/Manual/webgl-deploying.html)。Web audio も FMOD そのものではなく basic Web Audio backend に制限される: [Audio in Web](https://docs.unity3d.com/Manual/webgl-audio.html)。Unity Personal は過去 12 か月の revenue/funding が 20 万 USD 未満という条件付きである: [Unity Personal](https://unity.com/products/unity-personal)。今回の静的 2D パズルには build、editor、license 運用が過大である。

LÖVE は Lua の軽快な 2D framework で、Windows/macOS/Linux/Android/iOS を公式対象とし、zlib/libpng license である: [love2d.org](https://love2d.org/)。しかし Web は公式 target に含まれず、community の [love.js](https://github.com/Davidobot/love.js) が必要になる。love.js の最新 master commit は 2024-05-13、公式 release はなく、README 自身が compatibility build の audio を `dodgy`、thread build は `SharedArrayBuffer` と COOP/COEP が必要と説明する。runtime の `love.wasm` は repository tree 上約 4.7 MB raw である。GitHub Pages 最優先という条件で選ぶ理由がない。

## 採用アーキテクチャ: Godot 4.7.2

Godot は scene/render/input/audio の adapter として使い、パズルルールを SceneTree から分離する。GDScript の core module と `ValidationSurface` を同じ `GameSession` interface に接続し、通常プレイと agent 検証で別のゲーム挙動を作らない。

```text
project.godot
export_presets.cfg
src/
  core/
    model/             board_state.gd, action.gd, verdict.gd
    rules/             reducer.gd, parity.gd, scoring.gd
    generation/        seeded_rng.gd, curated_level.gd
    persistence/       save_schema.gd, replay_codec.gd
  session/
    game_session.gd    state/action/snapshot の唯一の owner
    run_spec.gd        CLI/query の共通 parser
  presentation/
    board_view.gd      Node2D/AnimatedSprite2D renderer
    ui/                Control scenes と theme
    audio/             music_director.gd, sfx_director.gd
  validation/
    validation_surface.gd
    native_trace_runner.gd
    web_mirror.gd
scenes/
  boot.tscn
  title.tscn
  play.tscn
  audit.tscn
  result.tscn
web/
  shell.html           start、semantic mirror、aria-live
assets/
tests/
  test_runner.gd
  golden/
```

原則:

- `core/` は `Node`、SceneTree、render/audio object を参照しない `RefCounted` / pure function の module とする。入力 state と `GameAction` から新しい state/result を返す。
- 盤面は 9 x 9 で 64 bit を超えるため、単一整数ではなく `PackedByteArray` 等の明示 bit vector を使う。
- game RNG は algorithm と overflow semantics を固定した独自 versioned seeded PRNG にし、Godot の global RNG や frame time に依存しない。visual/audio の揺らぎは別 RNG にする。
- `GameSession` だけが current state と undo/redo command log を所有し、Control、Node2D、audio、validation adapter は action を渡して snapshot を受け取る。
- animation completion は `visual_settled` には影響しても勝敗を変更しない。logical state は frame rate と無関係にする。
- save は `{schema_version, puzzle_version, level_id, seed, moves, settings}`。hidden board 全体を保存せず seed と move list から再計算する。`ConfigFile` または JSON を `user://` に保存し、Web では IndexedDB persistence を使う。
- `OS.is_userfs_persistent()` の結果と save error を確認し、private mode や storage 拒否時は session memory に落として警告する。Godot 公式 docs も Web の `user://` persistence が IndexedDB/cookie policy に依存すると説明する: [Web export limitations](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#using-cookies-for-data-persistence)。
- exact solver が重くなった場合だけ worker/thread の必要性を再評価する。default single-thread を崩して cross-origin isolation を持ち込む前に、level data の事前計算を優先する。

テスト:

- headless GDScript test runner: 同じ seal を 2 回置くと元に戻る、操作順を交換しても同じ結果、hidden error と同じ correction は安全、全消灯前は judge 不可、seed replay 一致。
- golden test: curated 3 面の reaction、最小 weight、verdict、public state hash。
- native replay E2E: InputEvent 経由で 3 input modality を再生し、semantic state と frame artifact を確認。
- Playwright: GitHub Pages と同じ subpath の Web export を serve し、wasm/pck 404、keyboard 完走、Canvas pointer、touch emulation、`user://` reload、audio unlock、resize、semantic mirror を確認。
- browser matrix: Chromium、Firefox、WebKit。最低 1 台の実機 iOS Safari でも startup、音、touch を確認する。

## GitHub Pages 配信設計: Godot Web export

### export preset と subpath

`Web` export preset を version control に含め、次を固定する。

- Godot 4.7.2 standard build と同じ version の export templates。
- Rendering Method は **Compatibility**。Godot 4 Web は WebGL 2.0 の Compatibility renderer だけを support する。
- **Thread Support off**、**Extensions Support off**。default single-thread のままにし、GitHub Pages で設定できない COOP/COEP に依存しない。
- 最初は PWA off。service worker cache が古い build を残す変数を排除する。offline が実要件になってから別途検証する。
- output は `build/web/index.html`。Godot が同じ basename で生成する `.js`、`.wasm`、`.pck`、`.png` を rename せず同じ directory に置く。公式 docs も export file 群を名前を変えず隣接配信するよう説明する: [Serving the files](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#serving-the-files)。
- Godot の生成参照は同 directory に対する相対 URL なので、Vite の `base` 相当は不要。`https://<user>.github.io/error-outbreak/` の実 subpath で必ず E2E する。
- share link は `?v=1&level=...&seed=...` とし、404 rewrite を必要とする path routing は使わない。
- custom HTML shell に START、loading progress、Canvas、semantic mirror、aria-live を置く。export 後 HTML を文字列置換せず、Godot の `$GODOT_URL` / `$GODOT_CONFIG` placeholder を使う。
- base window は desktop landscape を基準にしつつ、2D は `canvas_items`、aspect は `expand`、Control anchor/container で portrait へ再配置する。公式の [Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) も mobile の複数 aspect ratio にこの構成を推奨する。
- runtime は完全 static。server secret、database、dynamic API を前提にしない。sprite、font、audio は `.pck` に含め、初回 slice では third-party CDN を使わない。

GitHub Pages は `.wasm` / `.pck` の gzip on-the-fly hosting として Godot 公式 docs に明記されている。default single-thread なら cross-origin isolation header は不要である。もし将来 thread を有効にするなら PWA workaround も存在するが、今回の軽い turn-based puzzle では採用理由がない。

### Actions の最小経路

1. checkout。
2. official Godot 4.7.2 editor と同 version の export templates を checksum 検証付きで取得し、version keyed cache を使う。
3. `godot --headless --path . --import` で resource import を完了させる。
4. headless core/golden test と native replay smoke を実行する。
5. `godot --headless --path . --export-release "Web" build/web/index.html`。
6. `build/web/` を `/error-outbreak/` subpath で local serve し、Playwright の semantic/keyboard/pointer/touch、console、network 404、screenshot test を実行する。
7. `actions/configure-pages`。
8. `actions/upload-pages-artifact` で `build/web/` を upload。
9. `actions/deploy-pages` で `github-pages` environment へ deploy。

Godot の `--headless --export-release` は公式に CI 用として説明されている: [Command line export](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html#exporting)。editor binary と export template の version mismatch は hard failure にし、`latest` download は使わない。

権限は `contents: read`、`pages: write`、`id-token: write` のみ。main push と manual dispatch を入口にし、concurrency group `pages` で古い deploy を cancel する。GitHub の公式 custom workflow は configure/upload/deploy とこれらの権限を説明している: [Using custom workflows with GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)。実装時は action を commit SHA に pin し、Dependabot 等で更新する。

## 実装前の throwaway prototype で否定すべき仮説

prototype は本番コードの先行実装ではなく、以下を短い playable で否定するためのものにする。

1. **agent loop**: agent が native debug と deployed Web を seed 指定で起動し、`ready` を semantic に観測し、通常 input で 1 面を解き、result と screenshot を回収できるか。
2. **cross-platform determinism**: 同じ RunSpec と replay trace で、native と Web の全 accepted step の `seq/state_hash` と verdict が一致するか。
3. **3 種の手**: keyboard、pointer、touch がそれぞれ InputMap/_input/Control の通常経路を通り、undo history も同じになるか。
4. **failure diagnosis**: 意図的な assertion failure から 1 回の再実行で seed、trace、state、frame、log、network/Playwright trace が揃い、別 daemon なしに再現できるか。
5. **ルール理解**: 量子用語なしで 2 分以内に「キャラは原因ではなく反応」「junction の seal が複数窓を反転」を理解できるか。
6. **核心の納得感**: 全消灯後の breach を、驚きではあっても理不尽とは感じないか。`true outcome 判定` と `ML class 判定` の 2 variant を比較する。
7. **キャラクターの可読性**: 顔と動きが盤面の parity、境界、seal mark を隠さないか。縮小した phone で確認する。
8. **Godot Web の安定性**: Compatibility + single-thread export が Chromium/Firefox/WebKit、portrait/landscape、GitHub Pages subpath で一貫して起動・resize するか。
9. **音**: custom shell の user gesture 後に 3 stem が聴感上同期し、tab 復帰、mute、iOS Safari で破綻しないか。Sample mode の制約内で成立するか。
10. **起動性能**: Godot blank export と playable の両方を同条件で測り、asset 増分、time-to-first-progress、time-to-interactive、warm reload を artifact に残せるか。
11. **アクセシビリティ二重 renderer**: Godot Control と semantic HTML mirror が同じ PublicSnapshot からずれず、keyboard/screen reader の action も同じ undo history に入るか。
12. **solver 不要の検証**: curated 3 面だけで core fun を評価できるか。できなければ generator/decoder の実装を増やす前にルールを見直す。

最初の prototype の合格は 1-4 と 8-11 が自動検証で通り、5-7 を人間の観察 test に渡せる状態である。目と手が未完成のまま campaign、solver、完成 art を増やしてはいけない。

### Phaser contingency を開く条件

Godot 採用は決定済みであり、bundle が Phaser より大きいという既知の事実だけでは戻さない。次のいずれかが最小 prototype で再現し、asset 削減や設定修正で解消しない場合だけ Phaser を再評価する。

- 10 Mbps / 40 ms latency の cold profile で START から interactive まで 8 秒を超える、または warm reload が 3 秒を超える。
- current iOS Safari / WebKit で起動失敗、入力欠落、audio crash が再現可能に残る。
- GitHub Pages の static hosting で `.wasm` / `.pck` 配信を安定させられない。
- native と Web に共通する `ValidationSurface` が、独自 RPC/control plane や test 専用 gameplay 分岐なしでは成立しない。

条件を満たす限り、Godot の visual editor と character animation の利点を優先して実装を続ける。

## 推奨する次の一手

1. Godot 4.7.2 standard、GDScript、Compatibility renderer、single-thread Web の最小 project と reproducible export preset を作る。
2. gameplay より先に `RunSpec -> ValidationSurface -> native trace/Web semantic mirror -> failure artifact` の縦 1 本を通す。最初は START と 1 個の button だけでよい。
3. 3 x 3 の 1 面だけを SceneTree 非依存の GDScript reducer と仮図形で作り、同じ replay が native/Web で同じ state hash になることを証明する。
4. GitHub Pages subpath へ deploy し、Playwright と phone 実機で startup、keyboard/pointer/touch、screenshot、audio unlock、resize、wasm/pck path を先に通す。
5. safe/breach の 2 面と scanner audit を追加し、5 人程度の観察 test で「不公平感」を確認する。
6. そこで初めて character art、3 stem BGM、campaign generator、solver の順に広げる。

本件は greenfield として進めるべきで、SyndromeOut の Python/Pyxel コードや画像を移植する必要はない。持ち込むのは「局所警報を消す操作」と「全消灯後にも全体的な封鎖判定がある」という抽象的な学びだけである。

## 実行した主な確認コマンド

```text
gh-axi repo view stn/SyndromeOut
gh-axi repo clone stn/SyndromeOut
cd SyndromeOut && git rev-parse HEAD
cd SyndromeOut && uv run pytest -q
chrome-devtools-axi open https://stn.github.io/SyndromeOut/50009C
chrome-devtools-axi network

gh-axi api /repos/phaserjs/phaser/releases/latest
gh-axi repo clone phaserjs/template-vite-ts
cd template-vite-ts && npm ci
# lockfile mismatch を確認後、調査用 clone のみ更新
npm install phaser@4.2.1 --save-exact
npm run build-nolog
npm audit --omit=dev
npm audit

gh-axi api /repos/godotengine/godot-builds/releases/tags/4.7.2-stable
gh-axi api /repos/love2d/love/releases/latest
gh-axi api /repos/Davidobot/love.js/git/trees/master?recursive=1
```

ソース調査用 clone と測定用 build 以外に、error-outbreak の製品コード変更は行っていない。
