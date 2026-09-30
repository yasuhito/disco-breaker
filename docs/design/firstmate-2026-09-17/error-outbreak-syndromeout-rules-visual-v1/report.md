# SyndromeOut ルール再構成・ビジュアル説明資料レポート

## 成果物

- ビジュアル説明 HTML: `/home/yasuhito/Work/oss/firstmate/data/error-outbreak-syndromeout-rules-visual-v1/syndromeout-rules.html`
- この証拠レポート: `/home/yasuhito/Work/oss/firstmate/data/error-outbreak-syndromeout-rules-visual-v1/report.md`

HTML は単一ファイルで、外部フォント、外部画像、外部 CSS、JavaScript、実行時依存を持たない。プロジェクト画像や既存ゲーム作品の表現は使わず、盤面図はすべてインライン SVG と CSS で新規作成した。

## Captain review 後の改訂

2026-09-16 の Lavish feedback を受け、reference-first の構成から guided tutorial へ全面的に組み替えた。

- 最初は丸、四角、赤、赤い斜線の1概念ずつに限定し、再現番号 `000073` の1手を終えるまで技術記号と論理クラスを出さない。
- 抽象的な「反転」を説明文からなくし、「光っているタイルは消え、消えているタイルは光る」と、点灯・消灯の状態図で示す。
- 赤い斜線、青い斜線、2色の交差の各操作に、公開コードで再現した正確な BEFORE / AFTER 盤面を置く。
- 各概念の直後に native `details` の短い確認問題を置く。
- 全消灯と SUCCESS の違い、および I/X/Z/Y 論理クラスは3つの操作練習のあとに進む構成にする。

2026-09-16 の次の Captain feedback では、丸いボタンのしるしを再調査した。

- 文字 `X`、`Z`、`Y` を丸へ印字する図を廃止し、X は赤い斜線、Z は逆向きの青い斜線、Y は2色の交差として描き直した。
- BEFORE の `?` を、ゲームの cursor ring と同じ「外側の選択輪」という意味の金色リングへ変更した。
- 論理 X/Z/Y の小図も文字から方向付きの2色線へ変更した。
- 線の意味と向きだけを first-party 描画コードから採り、色調、線幅、カード、盤面レイアウトは教材用に独自作成した。

同日の追加 feedback で、タイル自体の `X!` 表示も再確認した。

- 実装では赤・青タイルの中に文字を描かない。点灯は色面と pulse glow、消灯は暗い面と色 outline で表す。
- hero、配置図、状態比較、3問の BEFORE 盤から、タイル内の `X!` / `Z!` をすべて除去した。
- 子ども向けの名前はタイルの外に置き、SVG の `title` / `desc` と caption で色の意味を言葉でも伝える。

同日の最終 visual-language feedback では、HTML 本文から Pauli letter notation を完全に除いた。

- custom element は採用しなかった。単一 HTML、JavaScript なしという制約では、semantic `<span role="img">` + reusable CSS が最も単純で堅牢だからである。
- `.op-mark` を基底 component にし、`.red-stroke`、`.blue-stroke`、`.cross-stroke`、`.large` だけで inline と大型の両方を描く。
- 本文、見出し、caption、SVG title/description、`aria-label` から operator letter を除去した。logical class も「安全」「赤い縦断」「青い横断」「2色の交差」に置き換えた。
- screen reader には「赤い斜め線」「青い斜め線」「赤と青の交差線」と読ませる。物理 keyboard の入力を伝える lowercase `x` / `z` / `y` は keycap 内だけに残した。

技術用語と source evidence を失わないよう、この report では Pauli notation をそのまま保持する。制限対象は子ども向け HTML の visible prose と accessible name である。

2026-09-16T21:36Z の post-JUDGE screenshot feedback では、再現 code `560F4A` の判定画面を教材へ追加した。

- 画面の最初に「成功。ただし4個より短い3個の成功例あり」という1文だけを出す。
- 次に player weight 4 と bot weight 3 を大きな数で比較し、`NOT OPTIMAL` は敗北でも点数でもなく、既知の軽い成功例があるという注意だと説明する。
- `bot: SUCCESS` は別の対戦相手の勝利ではなく、同じ syndrome への比較用 correction も安全だったという結果だと明記する。
- 4盤は「あなた」「機械のお手本」「隠れていた真相」「重ねた残り」の順に訳し、hidden error + player correction → harmless face → SUCCESS を矢印で示す。
- topology は「小さく閉じた面や輪は安全、端から端への横断線は危険」と子どもの言葉へ翻訳する。
- 現行 mechanic を「意味のある経路選択はあるが、同一 syndrome に異なる hidden logical class があり、合理的な選択でも失敗しうる確率パズル」と率直に評価する。

2026-09-16T21:59Z の追加 feedback では、成果物を2つの明確な領域へ分けた。

1. **source-proven SyndromeOut の判定画面解説**: code distance 5、per-data-qubit error probability 0.10、各 non-identity Pauli の `p/3`、reproducible seed、C/B/E/R、各 weight、logical effect、ML、SUCCESS、NOT OPTIMAL、bot SUCCESS、harmless face を progressive disclosure で説明する。子ども向け本文では「盤の一辺」「発生率」「再現番号」「4枚の役割」へ翻訳し、元記号は閉じた「おとな向け」disclosure に隔離した。
2. **`ERROR OUTBREAK: WARD ZERO` design proposal**: 現行仕様ではないことを黄色い `DESIGN PROPOSAL` で明示し、primary outcome、安全理由、efficiency comparison、next learning action の順に読む提案画面と、first interaction から advanced probability / code-distance concepts までの11段階 tutorial flow を追加した。

2026-09-16T22:24Z の feedback では、既に操作を理解している reviewer に不要な「入力の早見表」を全削除した。keyboard / mouse 操作一覧や代替 controls summary は置かず、section は source-proven setup と時間順だけを扱う「準備と時間の流れ」へ改名した。navigation anchor も `#setup` へ更新した。

2026-09-16T22:32Z の feedback では、WARD ZERO proposal を文章中心の説明から、10画面を連続して見られる visual storyboard へ全面改訂した。

- title、shift select / briefing、tutorial、live play、JUDGE ready、success、breach、debrief / retry、campaign progression、optional analysis をすべて game-screen mock として描いた。
- 丸を medical node、四角を room alarm、小さな輪を harmless remainder、長い横断線を breach とする visual language key を追加した。
- 5×5 playfield、lit alarm、placed colored stroke、ward boundary、integrity、response reserve、SCAN / SEAL を CSS artwork で可視化した。
- SyndromeOut より game性を上げる proposal として、3-wave shift、efficiency による resource carry-over、SCAN / SEAL の選択、ward integrity、campaign upgrade を追加した。
- hidden problem は各 wave 開始時に1回だけ固定し、thinking 中は pressure を進めない。確率 puzzle の fairness を壊さず、consequence は wave 間へ置く設計にした。
- 11-step tutorial も文章 card から、操作と残りの形を見せる visual filmstrip へ変更した。

2026-09-16T22:51Z の feedback では、「小さな合図」「見えない経路」と病棟の床が光る比喩が形に結びつかない問題を受け、5つの analogy candidate を visual comparison にした。

1. **織物・刺しゅう**: 丸=針穴、斜線=色糸、2色交差=重ね縫い、square=布目の張力警告、closed loop=補修、boundary path=端まで届く裂け目
2. **光学ラボ**: 丸=mirror mount、斜線=2色の光路、square=detector、closed loop=閉じこめた光、boundary path=漏出
3. **鉄道の分岐**: 丸=転てつ機、斜線=線路、square=閉塞信号、closed loop=構内線、boundary path=誤進路
4. **電気回路**: 丸=はんだ点、斜線=2系統の配線、square=diagnostic LED。ただし closed circuit が必ず安全とは限らず topology metaphor が弱い
5. **配管と圧力**: 丸=valve、斜線=2系統の pipe、square=pressure gauge、closed loop=循環、boundary path=外周への漏れ

最有力は織物・刺しゅうと判断した。既存の stroke geometry をそのまま thread として読め、丸、交差、安全な loop、危険な edge-to-edge tear を1つの物語で説明できる。HTML は5候補を同じ geometry の独自 CSS scene で比較し、病棟案の10画面は layout skeleton として残しつつ、theme reskin を推奨した。曖昧だった title copy は「光ったマスを、斜めの線で消していく」へ置き換えた。

2026-09-16T22:56Z の feedback で提示された disco analogy を第6候補として追加した。laser disco なら、丸は moving-head light、斜線は red/blue laser、square は safety sensor floor、closed loop は舞台内へ収まった光、boundary path は観客側へ漏れた危険光として読める。光る床、丸い fixture、斜線の visual fit は6候補中もっとも強い。一方、全消灯が通常の disco の目的と逆なので、floor light は演出ではなく laser leak warning と定義する必要がある。結論を「rule comprehension なら textile、game feel なら laser disco」と2軸に分けた。

2026-09-16T23:31Z と T23:34Z の feedback で、proposal の theme を generic 80s disco repair へ確定し、WARD ZERO を全面的に reskin した。

- player role は大工ではなく、床下の2系統の配線を扱う電気工事士とした。丸は床の接続箱、赤・青の四角は演出灯ではなく故障でちらつく floor panel、斜線は配線、closed loop は floor 内で閉じた安全な配線、boundary path は反対側の給電盤まで届く危険な通電経路である。
- repair 中は DJ が音楽を止め、客は四方の壁際で待つ。全 flicker を消して foreman を呼ぶ行為が JUDGE に相当し、foreman が OK / NG と safety inspection の理由を返す。
- SUCCESS では floor 全体が多色 pattern で点灯し、DJ が音楽を再開し、mirror ball が回り、客が floor へ戻る。club / music genre ごとに dance animation を変える campaign reward も提案した。
- 「全消灯なのになぜ disco なのか」という矛盾は、repair 中の light を通常演出ではなく fault signal と定義し、合格後に初めて通常の多色演出が戻ることで解消した。
- 特定の映画、既存ゲーム、project artwork は参照せず、generic な80年代 club の色、mirror ball、silhouette、floor grid を CSS だけで新規作成した。

名称候補は cool な英語と妙に直訳調の日本語を意図して6案に絞った。

1. **DISCO BREAKER**: 有力候補。電気を守る circuit breaker と、breakdance を踊る breaker の二重意味を持つ。
2. **FLOOR//FAULT / ディスコ床修理**: 短く、床と故障を同時に伝え、記号も arcade / technical tone に合う。
3. **REWIRE THE NIGHT / 夜の配線やり直し**: cinematic な候補。
4. **CIRCUIT BREAKDANCE / 回路ブレイクダンス**: circuit breaker と breakdance の wordplay をより明示する候補。
5. **NEON NIGHT SHIFT / 深夜ネオン床工事**: electrician の夜勤感を強める候補。
6. **AFTER HOURS: FLOOR CREW / 閉店後の床修理班**: crew campaign へ広げやすい候補。

2026-09-17T00:11Z の feedback では、**DISCO BREAKER** を「ブレーカー係」という日本語が分かりにくいだけで候補から弱めるべきではないと再評価した。英語題の wordplay と日本語題は独立して選び、最終選択までは仮タイトルとして扱った。

2026-09-17T00:17Z の最終選択と T00:19Z の綴り訂正で、英語題を **DISCO BREAKER**、日本語題を **ディスコ床修理** に確定した。英語題は standard spelling を使う。HTML から unresolved candidate language と他候補の比較 card を除き、proposal 見出し、final-title card、title-screen mock、navigation をすべてこの組み合わせへ統一した。repository の作成や rename は Firstmate 側で別に扱うため、この成果物では行わない。

2026-09-17T00:43Z の relaunch では、Captain の「画面案のデザインはすべて Anthropic のモデルでやり直し、iPhone / Android の縦画面に合わせる」という指示を受け、DISCO BREAKER の10画面 mock をゼロから描き直した。この改訂は Anthropic の Claude（Opus 5）が行った。説明文、caption、見出し、source-proven の教材部分は変えず、変えたのは画面案の視覚表現だけである。

- 横長の desktop 風 mock を捨て、iPhone 15（393×852pt）と Pixel 8（412×915dp）の縦画面比率の device frame に置き換えた。角丸、Dynamic Island / punch hole、状態バー、ホームバーまで含めて描き、iOS 風と Android 風を交互に使って両方を想定していることを示した。
- 画面内の寸法はすべて CSS container query unit（`cqw`、端末幅の %）で指定した。3列の desktop でも1列の narrow mobile でも、同じ画面が同じ比率で縮尺されるだけで、折り返しや欠けが起きない。
- 画面を「状態バー・見出し」「床・作業エリア」「親指ゾーン」の3段に固定し、押すものは下段、見るものは中段に置いた。ボタンと配線パレットは高さ 13% ≒ 52pt、接続箱の間隔は約 60pt で、44pt の touch target を満たす。
- 盤面 SVG は Python generator で、SyndromeOut `code.py` / `app.py` と同じ規則（`(i+j)` 偶数=赤面、上下境界=青の半面、左右境界=赤の半面、偶数ノードで赤線は TL-BR、奇数ノードで入れ替わる）から機械生成した。手描きによる傾きや境界の誤りを排した。
- 04〜08 の画面は1つの連続した scenario を使う。隠れた故障 3 本（重さ 3）、プレイヤーの配線 4 本（重さ 4、残りは上の半タイル 1 枚＝無害、SUCCESS だが NOT OPTIMAL）、失敗例 4 本（残りが上から下へつながる赤い縦断、FAIL）。この3つの Pauli を SyndromeOut 本体のコードで計算し、syndrome の一致、重さ、`stabilizer_faces`、`logical_effect` を確認した。
- 80年代 disco の art direction は、chrome gradient の italic ロゴ、magenta / cyan のネオン、琥珀色の親方、perspective で奥へ伸びる光る床、止まった / 回るミラーボール、壁際の客と DJ ブース、成功時の多色フロアとダンサーで表した。特定の映画や既存作品の意匠は使っていない。
- 画面の下に短い「デザイン上の判断」を添え、末尾に共通部品（配色 8 色、接続箱と配線、床パネル、ボタン 3 種、動き 3 種、文字の大きさ、レイアウトの決まり）をまとめた UI card を1枚加えた。
- 動きは故障のチカチカ、タップ先の脈動、成功時の回転の3種だけで、`prefers-reduced-motion` ではすべて止まる。

2026-09-17T01:24Z の feedback（title screen のみ）を反映した。

- 日本語副題「ディスコ床修理」の pill と、上部の `CLUB POWER // OFFLINE` chip を title screen から除いた。`NEON NIGHT REPAIR` の overline は残した。
- ミラーボールを最初から全点灯にした。回転する多色の球、9本の色つき光条（cyan / pink / yellow / violet / white、`mix-blend-mode: screen`、ゆっくり左右に振れる）、画面全体を流れる反射の光点（5層の radial-gradient を `background-position` で漂わせる）で、縦画面全体に祝祭感を広げた。ロゴの裏には暗い radial backdrop を敷き、光条の上でも可読性を保つ。
- 床の赤・青のちらつきは「固定の数枚」ではなく「場所を変えながら続く」ものにした。可視列に置いた20枚のタイルそれぞれに 12 秒周期の `steps()` keyframe（先頭 18% だけ4回点滅、残りは消灯）と異なる `animation-delay` を与え、任意の瞬間に光っている組が入れ替わる。DevTools で 3 秒おきに点灯タイルを採取すると `4,6,9,15` → `7,14,18` → `1,5,8,17` と変化した。script は使っていない。
- `prefers-reduced-motion` では全 animation を止め、代わりに中段の 4 枚（赤2・青2）を静的に点灯させて故障を示す。reduced-motion の media rule を注入して静止状態を目視確認した。
- title screen の caption 1文（「ミラーボールは停止状態から始まります」）は新しい状態と矛盾するため、「ミラーボールは最初から光り、床のちらつきだけが故障を告げます」へ改めた。ほかの本文は変えていない。

2026-09-17T01:27Z の用語決定を提案全体に適用した。表示される英語 `club` と日本語「クラブ」をすべて `disco` /「ディスコ」へ置き換えた: 画面の流れ `09 DISCO TOUR`、02 の app bar `DISCO TOUR`、ルート図の `DISCO SATURN`（02・09）、09 のボタン「次のディスコへ」、09 の caption「次のディスコへ」、campaign card の「新しいディスコ、曲、ダンス」。不可視の CSS class 名（`.ph-club`）は変えていない。build 時に body の可視テキストと `aria-label` に `club` / 「クラブ」が残っていないことを assert している。

2026-09-17T01:42Z の feedback（title screen の再改訂）と、同時刻の Lavish feedback（02 画面）を反映した。

- **照明用語**: 光る床の標準用語は "illuminated dance floor"（一般には "light-up dance floor"、現代の製品は "LED dance floor"）で、1970 年代の床は色ガラス板の下の白熱電球であり、ネオン管ではない（[Wikipedia: Illuminated dance floor](https://en.wikipedia.org/wiki/Illuminated_dance_floor)、[pro-toplight](https://www.pro-toplight.com/light-up-dance-floor/)）。overline は `NEON NIGHT REPAIR` から、最短で自然な **`LIGHT-UP FLOOR REPAIR`** へ置き換えた。候補にした `ILLUMINATED DANCE FLOOR REPAIR` は正確だが長く、`DANCE FLOOR REPAIR` は照明の要素が落ちるため採らなかった。
- **ミラーボール**: 天井プレート → 金属の支柱 → 取付カラー → 球、の順で吊り下げた。球は 82 枚の鏡面（緯度 0 / ±22.5 / ±45 / ±67.5 度の 7 リング＋両極のキャップ）を `rotateY(経度) rotateX(緯度) translateZ(半径)` で球面に配置し、`transform-style: preserve-3d` の親を `rotateY` で 14 秒周期に回す（支柱＝鉛直軸まわりの水平回転）。裏側の鏡面は `backface-visibility: hidden` で隠し、内側に暗い芯球を置いて鏡面の隙間を暗くした。回転しない陰影オーバーレイ（左上のハイライト、周縁の減光、左右からのピンクとシアンの環境光）を重ねるので、鏡面が光の中を通り過ぎるときに輝きが変わる。CSS 3D の一般的な手法（facet を rotateY/rotateX/translateZ で配置し preserve-3d の親を回す）を確認した上で、独自に実装した。外部依存や script はない。
- **光条と光点**: 9 本の光条は球の中心を起点にし、各自の基準角の周りを ±9 度、球と同じ 14 秒周期で位相をずらして往復する。反射の光点は同じ 14 秒周期で横方向にだけ流れ（回る球の反射は横へ流れる）、球からの距離に応じて radial mask で減衰する。
- **粒子の範囲**: 光点のレイヤーは本文上端から 106% の高さまでに限定し、下端 16% を線形 mask で消す。床の見取り図はその後ろではなく後で描くので、床の上や下に粒子が出ない。
- **02 画面**（Lavish feedback）: 「待っている客」の数はゲーム性に寄与しないので削除。ステージで変わらない固定 to-do（壁際の客を戻す等）も削除。作業指示書は「今夜の床」の仕様表に作り替え、ステージごとに変わる情報だけを載せた: ディスコの広さ 5 × 5（右に床の見取り図）、直す区画 3、ちらつく床（赤 3・青 2）、予備の配線 6 本。
- 検証: 390×844×2 と 412×915×2.6 で横はみ出しなし、各画面の最後のフロー要素は body 内（7 px 以上の余白、10 の診断シートは下端まで）。reduced-motion の media rule を注入すると球・光条・光点・床の animation はすべて `none` になり、床は 4 枚だけ静的に点灯。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。可視テキストの `neon` / `club` / 「クラブ」: 0。

2026-09-17T01:56Z の feedback で、プレイヤーに見える `WIRING SCHOOL` をすべて `TUTORIAL` に置き換えた: title screen の 2 番目のボタン、03 画面の app bar、画面の流れの chip `03 TUTORIAL`。screen card の説明見出し「床下配線のチュートリアル」や 08 の `WIRING OVERLAY` は対象外なので変えていない。build 後の HTML に `WIRING SCHOOL` は 0 件。

2026-09-17T02:00Z の Lavish feedback と inbox 024 を反映した。

- **状態バーのアイコン**: CSS の clip-path と gradient で描いていた電波・Wi-Fi・電池を、データ URI の SVG を `mask` に使う描画へ置き換えた。Wi-Fi は 3 本の同心弧＋点、電池は半透明の外枠＋端子＋中央に揃った白い残量。390×844×3 の拡大で形と位置を目視確認した。
- **title screen のボタン**: `HOW IT WORKS` を削除し、`REPAIR THE FLOOR`（ピンクの主ボタン、高さ 15%）と `TUTORIAL`（枠だけ、高さ 14%）の 2 つだけにした。間隔を 2.6% に広げ、下端の親指ゾーンに固定したまま。代替のメニュー項目は足していない。`aria-label` を「2つのボタン」に、デザイン注記を 2 ボタン構成の説明に改めた。build 後の HTML に `HOW IT WORKS` は 0 件。

2026-09-17T02:03Z の inbox 025 で Wi-Fi アイコンを描き直した。3 本の同心弧（半径 3 / 6.6 / 10.2、線幅 2、弧の間隔 1.6）と中心の点を 20×15 の viewBox に置き、表示サイズを 5.2% × 3.9% に広げた。電波と電池は変えていない。10 画面すべてが同じ状態バー部品を共有するので一括で反映され、390×844 の 2x / 3x と 1280 の 1x の拡大で 3 本の弧が分離して見えることを確認した。10 画面の最後のフロー要素はすべて body 内、横はみ出しなし、reduced-motion には影響しない。

2026-09-17T02:08Z の inbox 026 で、title screen の `TUTORIAL` ボタンから副題 `基礎 3/3` を外した。チュートリアルは何度でも遊べるので、達成率や完了バッジなど「終わった」と読める文言は置かない。ボタンは `TUTORIAL` のラベルだけで、文字は高さ 14% のボタンの中央に揃う（計測オフセット 0 px）。`aria-label` とデザイン注記に進捗の記述はない。build 後の HTML に `基礎 3/3` は 0 件（残る `3 / 3` は 09 画面の「合格した区画」で、別の意味）。

2026-09-17T02:11Z の inbox 027 で、04（実際のプレイ画面）を作り直した。

- 下段の「チカチカ」「配線」「評判」カード、赤・青・2色のパレット、その操作ヒントを削除した。配線の在庫は SyndromeOut の操作に存在しないので導入していない。
- 接続箱は箱そのものをタップして「なし → 赤 → 青 → 2色 → なし」と巡回し、状態は箱の上の斜め線だけで示す。道具を選ぶ UI はない。この巡回は床の下の小さな帯に、タップの輪と4つの接続箱の絵と矢印だけで示し、文字は使わない（`role="img"` と日本語 `aria-label` を付けた）。SyndromeOut 本体では x / z / y キーで同じ箱に赤・青・両方を置くので、巡回はその3状態＋空を順に回す touch 版の操作である。
- 空いた分で床を 84% 幅に広げ、舞台と巡回帯のあいだの 1fr 行で縦の中央に置いた。接続箱の中心間隔は 390 幅で 57 px、412 幅で 57 px（≒ 60pt）。
- 上段は絵だけの舞台にした: 左に消灯した灰色のミラーボール（短い支柱、静止）、中央に DJ ブース。2 台のターンテーブルを近づけてミキサーを挟み、その後ろに頭・ヘッドホン・肩の人物を置いた。`DJ PAUSED` の文字は消した。実在の人物や作品の意匠は使っていない。
- 観客は 3 つの壁沿いに 21 人を不均等な群れで配置し、3 種の姿勢（立つ、腕を上げる、もたれる）、拡大率、傾き、3 色の組み合わせで変化を付けた。床のタイルは隠れない。
- 無効表示だった「親方を呼ぶ」ボタンは 04 から外した。全消灯後に 05 で琥珀色のボタンとして現れる流れは変えていない。05 は同じ舞台・観客・床の compact 版を使い、それ以外（バナー、チェック、親方の吹き出し、ボタン）は据え置いた。05 の「残りの配線 2 本」は在庫表示なので、次の見直し候補として残している。
- 04 の caption は変えず、`aria-label` とデザイン注記をタップ巡回と「絵だけで止まった雰囲気を伝える」内容に改めた。削除したカウンターや操作には触れていない。05 の注記の「無効だったボタンが点灯する」も、新しい流れに合わせた。
- 検証: 390×844×2 と 412×915×2.6 で横はみ出しなし、10 画面の最後のフロー要素は body 内。追加した舞台・観客は静止画で reduced-motion に影響しない。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T02:25Z の inbox 028 で、04 をさらに改めた（停電中のディスコとして）。

- 観客と DJ ブース（ターンテーブル・人物）をすべて外し、上段は消灯した灰色のミラーボール 1 つだけにした。停電の合図はこれだけで足りる。
- 床の下の巡回の帯（`ph-cycle`）を完全に削除した。タップ巡回は caption と注記で説明し、画面には状態＝箱の上の斜め線しか置かない。
- 選択中を示す脈打つ輪（`cursor-ring`）を 04 から外した。接続の状態は各箱の斜め線だけで読む。03 の練習床の輪はそのまま。
- 下段に `CALL THE FOREMAN / 親方を呼ぶ` を戻した。実際の `<button disabled aria-disabled="true">` にし、光沢なし・くすんだ面・薄い枠の無効表示で、理由は `親方を呼ぶ · ちらつきが残っています` の 1 行だけ。大きな HUD は作っていない。05 では同じ位置のボタンが琥珀色に有効化される流れ。
- 04 の caption を「ディスコは真っ暗で、消えたミラーボールだけが停電を告げます。ちらつきが残る間は親方を呼べません」に改め、`aria-label` と注記から DJ・観客・凡例の記述を消した。05 は同じ暗い床＋消えたミラーボールの compact 版を共有し、`aria-label` と注記も合わせた。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる（04 のボタン高さ 50 px）。build 後の HTML に `ph-cycle`、観客レイヤー、DJ ブース、`DJ PAUSED` は 0 件、04 の床に `cursor-ring` なし。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0（無効ボタンは axe の contrast 対象外だが、文字色は 4.6:1 程度を保っている）。

2026-09-17T02:34Z の inbox 029 で、04 を仕上げた。

- 無効ボタンを高さ 17%（≒ 58 px @390）に大きくし、表示は英語の `CALL THE FOREMAN` だけにした。日本語の副題と理由の 1 行は外し、無効は native `disabled` と、くすんだ面・薄い枠・光沢なしの見た目だけで示す。認識を助けるため受話器のアイコン（データ URI の SVG を mask にした 5.6% のマーク、`aria-hidden`）をラベルの前に添えた。
- DJ ブースを「無人・無電源」の姿で戻した。近づけた 2 台のターンテーブルとミキサー、暗い台だけで、人物も文字も光もない。上段右側に置き、停電中でもディスコと分かる。
- 消灯したミラーボールを直径 17%（≒ 58 px @390）に拡大し、上段左に吊った。成功後の主役資産として存在感を出しつつ、灰色の面・暗い影・光沢なしで「消えている」ことを保ち、床（84% 幅）には重ねない（412 幅で球の下端と床の上端の間隔 96 px）。
- 観客、巡回の帯、黄色い選択の輪は置いていない。
- 04 の caption を「消えたミラーボールと無人の DJ ブースが停電を告げます」に、`aria-label` と注記も大きなミラーボール・無人ブース・英語だけの無効ボタンを述べる内容に改めた。05 は同じ舞台の compact 版を共有する（05 の有効ボタンは従来どおり日本語副題つきで、変更していない）。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T02:36Z の Lavish feedback で、04 の app bar 右上の `NO TIMER` chip を外した。04 を薄く敷いた 10（診断シート）の背景も同じ app bar なので合わせて外し、build 後の HTML に `NO TIMER` は 0 件。時間制限がないことは本文の「ターンもタイマーもない」で説明済みで、画面には出さない。

2026-09-17T03:04Z の inbox 030 で、06（成功画面）を 04 の構図の上に作り直した。

- 04 と同じ骨格: app bar（`GIG 02 · REPAIR 1/3` と英語の `FOREMAN: OK` chip）、上段にミラーボールとブース、中央に 84% 幅の床、下に高さ 17% の 1 ボタン。
- 電話 UI の中の説明文を全部外した: `FLOOR ONLINE` の見出し、「よし、安全だ。電源を入れろ」、「残りは床の中で閉じた配線」の証明カード、「あなたの配線 4 / 親方の見本 3」の比較、`DJ STARTS` ボタン、DJ の帯、踊る客。06 の電話 UI に日本語は 0 文字。
- ミラーボールはタイトル画面と同じ 3D 部品（`mirror_ball_3d()`、82 枚の鏡面、`rotateY` 回転、固定の陰影オーバーレイ）を、04 で消えていた球と同じ位置（上段左、支柱つき）に半径 8.5% で吊り直した。消えた球と光る球が同じ場所で対になる。上段には球から出る短い光条を `conic-gradient` で薄く敷き、床には重ねない。
- ブースは 04 と同じ無人の形のまま通電させた: ターンテーブルが多色で回り、ミキサーの LED がシアンに点き、台の縁がピンクに光る。人物や文字はない。
- 床は多色の party 状態（脈動の最小不透明度を .72 に上げて濁りを抑えた）、給電盤の rail は明るい琥珀にした。
- 下の主ボタンは英語の `NEXT GIG` 1 つ（副題なし、高さ 58 px @390、62 px @412）。
- 06 の caption・`aria-label`・注記を新しい構図（04 との対、説明文なし、タイトルと同じミラーボール）に合わせて改めた。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。reduced-motion の media rule を注入すると球の回転・ターンテーブル・床の脈動はすべて `none`。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T03:12Z の inbox 031 で、06 を成功の主役画面として強めた。

- 舞台の枠で切れていた光条を、舞台の外側（`.ph-club.live.on` 全体）に置いた 8 本の光条レイヤーへ移した。球の位置を起点に -58° から 76° へ扇状に広がり、ブースと床の上を通って club の下端まで届く（長さ 200%、`mix-blend-mode: screen`、下へ向かって減衰）。各光条はタイトル画面と同じ 14 秒周期で ±9° 往復する。
- 床の上に色つきの光だまり（シアン・ピンク・黄・紫・白の 5 つの楕円、`screen` 合成、ゆっくり漂う）と、球からの距離で減衰する反射の光点レイヤーを重ねた。タイルの色と丸は下に透けて読める。
- 光る球の drop-shadow を 3 段（白・ピンク・シアン）に増やし、ブースの下に光のにじみを敷いた。
- ブースと床のあいだに、タイトルロゴと同じ 80 年代の表示言語（italic 950、金のクローム gradient、紫の落ち影、ピンクとシアンの光）で `DISCO!` の祝いの文字を置いた。少し傾け、ゆっくり弾む。`role="img"` と日本語の `aria-label` を付け、電話 UI 内の可視テキストは英語のみ（日本語 0 文字）。
- 04 由来の配置（上に球とブース、中央に床、下に `NEXT GIG`）はそのまま。
- reduced-motion では光条・光だまり・光点・球・ターンテーブル・床の脈動・文字の弾みがすべて止まり、静止画として光が残る状態を目視確認した。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T03:16Z の inbox 032 で、06 の床にプレイヤーの配線の結果を残した。

- 06 の床だけ、接続箱を空にせず、04〜08 と同じ scenario のプレイヤー配線 `C_PLAYER`（赤 (2,2)、赤と青の交差 (0,3)、赤 (0,2)、赤 (4,1) の 4 か所、重さ 4）をそのまま描く。これは本体コードで SUCCESS（NOT OPTIMAL）を確認済みの配線であり、位置は床の中で散らばっている。
- 印は説明文や凡例ではなく、接続箱の上の永続的な斜め線として描く。明るい床の反射の上でも読めるよう、印のある箱だけ白い縁と白い光のにじみを付け、線を太く（10）、赤と青を少し濃い色にした。床の SVG を光だまり・光点より前面に置き、タイルは .92 の不透明度で光を透かす。
- reduced-motion でも印は静止した SVG なのでそのまま見える。
- 06 の床 SVG の `aria-label` と電話全体の `aria-label` に「あなたの配線の印 4 つが残る」を加えた。ほかの画面（04・05・07・08・10 の床）は変えていない。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T03:41Z の inbox 033 と T03:43Z の inbox 034 で、source に根拠のない「道具・工具箱・アップグレード・予備配線・持ち越し」の仕組みを成果物全体から取り除いた。

- **09**: `TOOLBOX UPGRADE` の見出し、TESTER / FUSE の 2 択カード、選択中の枠、「余った配線」を削除。空いた場所には既に確立した「3 区画の修理が終わった」事実だけを置く: `ELECTRIC PALACE · 3 / 3 REPAIRED` の下に、合格した 3 つの床（1 = プレイヤーの配線、2 = 親方の見本、3 = 別の 2 か所）を小さく並べ、`PASSED` 札を付けた。ボタンは英語の `NEXT DISCO` 1 つ（副題なし、高さ 17%）。代わりの資源や強化は足していない。
- **02**: 作業指示書から「予備の配線 6 本」を外し、広さ・区画数・ちらつく床の 3 行にした。caption「短い配線で余ったケーブルと工具を、次のフロアへ持ち越します」を「3つとも親方の検査に合格すると、次のディスコへ進みます」に改めた。
- **05**: チェックリストから「残りの配線 2 本」を外した。
- **07**: 「予備ヒューズ 1 使用可」のカードを外し、評判のカードだけを 1 列で残した。
- **08**: `WIRE +1 …テスターを使える` の報酬帯を外した。
- **説明セクション**: 「4つの仕組み」を「2つの仕組み」に改め、「短い配線が資源になる」と「テスターかヒューズか」のカードを削除。「1晩3区画」の本文は「評判と工具を次のフロアへ持ち越します」から「3区画を直して次のディスコへ進みます。区画ごとに床は新しくなります」に改めた。「評判と新しい音楽」は残した。
- **UI kit**: シアンの説明「選択中の道具」を「選択中の項目」にした。
- 残したもの: 接続箱に配線の印を置いて巡回する core 操作、06 に残る配線の結果、赤・青の故障色、親方の検査の流れ、ディスコの舞台、評判の星と音楽・ダンスの解放（これらは削除対象の道具・資源ではない）。
- 残存検索: build 時に `toolbox / tester / fuse / テスター / ヒューズ / 工具 / upgrade / 予備の配線 / 余った配線 / 残りの配線 / 持ち越 / ケーブル / WIRE +1` を可視テキストで assert し、さらに `資源 / 報酬 / 在庫 / spool / inventory / carry` を含めて手で確認した。一致は「薬・体力・封じこめゲージ: 実装された資源はありません」（source-proven の否定文）だけ。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T03:56Z の inbox 035 で、Captain 提供の判定後 screenshot（`/tmp/pi-clipboard-080f6901-0fd0-4184-b8d2-6e41d3145c64.png`、909×1044、`stn.github.io/SyndromeOut/560F4A`）を固定 commit の source と突き合わせ、HTML の「判定画面の読み方」に「画面の地図」と「設計の提案」の 2 記事を追加し、提案画面の 08 / 10 を検査報告に作り替えた。

### screenshot の source 照合（事実）

再現番号 560F4A を本体の `unpack_seed` → `Board.new` で復元し、次を得た（座標は (行, 列)、0 始まり）。

| 表示 | 値 | source |
|---|---|---|
| 隠れていた故障 E | 赤 (1,0)、青 (4,2)、2色 (4,3)、重さ 3 | `game.py:112` sample_depolarizing |
| 機械のお手本 B | E と同じ 3 か所（この盤では一致）、重さ 3 | `game.py:114-117`、`decoder.py:52-54`、`decoder_pymatching.py:19-26` |
| 最尤クラスの代表 ML | 同上 | `game.py:118-121`、`decoder.py:267-303` |
| 点灯していた面 | 赤 (0.5,0.5)、赤 (3.5,3.5)、青の下半面 j=1・j=3、赤の左半面 i=1 | `code.py:72-94`、`game.py:150-151` |
| あなたの配線 C（画像から読み取り） | 赤 (1,0)、青 (4,2)、青 (4,3)、赤 (4,4)、重さ 4 | 画像の黄色い輪と斜線 |
| 残り R = E × C | 赤 (4,3)、赤 (4,4) = 下の半面 j=3 の stabilizer 1 枚 → SUCCESS、NOT OPTIMAL | `game.py:194-241`、`judge.py:20-28` |

C の読み取りは E × R = C で整合する（(4,3) で 2色 × 赤 = 青、(4,4) で 赤）。画面の 10 か所の意味は次のとおり（HTML の表と同じ内容、出典は `file:line`）。

1. **左上 C your correction |C|=4**: プレイ中に置いた印。黄色い輪は view の色。|C| は印のある丸の数（2色も 1）。`app.py:92-97`、`app.py:438-441`、`game.py:203`。
2. **右上 B bot |B|=3**: 最小重さの訂正。純 Python の frontier sweep が赤・青を独立に解き、PyMatching が import できれば `bot (MWPM)` と表示が変わる。同点の候補は決め打ちで 1 つだけ返す（`decoder.py:75, 167, 261`）。したがって bot は対戦相手ではなく、「知られている最短の一例」であり、唯一性や大域最適の証明ではない。`game.py:15-23`、`game.py:114-117`、`decoder.py:1-14`。
3. **左下 E true error |E|=3**: 発生率 p の独立ノイズから生成した真の故障。判定前は見えない。`game.py:112`。
4. **右下 R = 1 face: harmless**: syndrome ゼロの残りを「壁から壁への文字列 × 面の積」に分解し、成功なら面だけを緑で囲む。失敗なら赤い点線の文字列と `R = X path + 2 faces` 形式。`game.py:206-241`、`app.py:424-436`、`app.py:442-452`。
5. **d=5 p=0.10 seed 560F4A**: d は距離 3/5/7/9、p は 0.05/0.10/0.15（非恒等 Pauli は各 p/3）、seed は d・p・raw seed を pack した 6 桁。`game.py:26-27, 30-50`、`app.py:465`。
6. **凡例 `0 X err: put X (L)` / `0 Z err: put Z (R)`**: 先頭の数は現在点灯している赤（Z-type 面）／青（X-type 面）の数。判定後は 0 なので薄色。`(L)`/`(R)` は左右クリック。`app.py:468-478`、`game.py:139-142`。
7. **SUCCESS / NOT OPTIMAL**: SUCCESS は `logical_effect(E*C) == NONE`。NOT OPTIMAL は `weight > min(|E|, |B| if bot_success)`、ここでは 4 > 3。表示なし＝最短の証明ではない。`(but not ML: …)` は成功したが最尤クラスが別だった補助表示。`game.py:54-86`、`app.py:482-488`。
8. **bot: SUCCESS**: `logical_effect(E*B) == NONE` の比較表示。失敗なら `bot: FAIL X error`。プレイヤーの結果を変えない。`game.py:67-69, 201`、`app.py:493-494`。
9. **RETRY (r)**: 判定前は `JUDGE (Enter)`。判定後は `verdict_is_final()`（NOT OPTIMAL なしの成功、または `failed_as_ml`）なら `NEW (n)`、そうでなければ `RETRY (r)`。RETRY = `Board.reset()`: 同じ seed、correction を identity に、verdict と undo/redo を消す。案内の overlay は存在しない。判定後の toggle と undo/redo は無視される。`app.py:292-308`、`game.py:155-190`。
10. **操作の助け 6 行**: `app.py:505-511`。d / p は新しい盤を生成する（`app.py:256-262`）。

### 設計の提案（事実ではない）

- HTML の「設計の提案」記事に 7 原則を置いた: まず結果・次に学び / bot を「親方が知っている最短の安全な修理」と翻訳し役に立つときだけ見せる / 1 段ずつ明かす / 残りは形（緑の閉じた輪・赤い壁から壁の線）で説明 / NOT OPTIMAL は失敗ではない（琥珀の注意、赤は使わない）/ 開発者向け記号（C/B/E/R、ML、確率）は子どもの画面に出さない / やり直しは元のゲームのまま（同じ床を配線ゼロから、案内の重ね表示なし、資源・強化・ヒントを足さない）。
- **08 INSPECTION REPORT**（旧「親方の講評とやり直し」を置換）: `PASSED` chip、3 段の帯（YOUR WIRING 4 → HIDDEN FAULT 3 → LEFTOVER 1 LOOP。3 段目が選択中）、残りの床（緑で囲んだ半面 1 枚と薄い残りの印）、`LEFTOVER: 1 CLOSED LOOP · SAFE` の 1 行、`FOREMAN KNOWS A SHORTER SAFE REPAIR · 3 / SEE IT ›` の琥珀の注意、`NEXT GIG` と `RETRY THIS FLOOR`。UI 内は英語のみ。
- **10 FOREMAN'S REPAIR**（旧「電気工事士の診断画面」を置換）: `BOTH PASSED` chip、YOURS 4 / FOREMAN 3 の 2 床（両方 PASSED）、差を重ねた床（黄色い輪 2 つと緑の枠 1 つ）、`DIFFERENCE: 1 CLOSED LOOP`、`SHORTER · NOT THE ONLY WAY`、作業札 `FLOOR 5×5 · FAULT 10% · JOB 560F4A`、`NEXT GIG`。最尤クラスや ML は出さない。役に立つとき（bot が成功かつプレイヤーより軽い＝NOT OPTIMAL のとき）だけ開く画面と caption に明記。
- 旧 08 の混乱（重ねた床を「案内つきのやり直し」と読める）は、報告書（08）と見本の比較（10）を分け、10 の注記と本文に「重ねた床は 2 つの成功例の差が無害な閉じた輪であることの説明で、元の RETRY にそのような overlay はない」と書いて解消した。
- 04〜07、09 の画面は変えていない。画面の流れの札を `08 REPORT` / `10 FOREMAN` に、学習フィルムの 11 段目を「親方の見本 役に立つときだけ比べる」に改めた。
- 見取り図は元画像を写さず、配置・文言・印の位置だけを SVG で描いた（`role="img"` と title/desc つき）。表は横スクロール容器に入れ、390 幅でも本文がはみ出さない。
- 表記について: 035 は「すべての表示を説明せよ」なので、この記事では元画面の文字列（C/B/E/R、`X err: put X`、d/p/seed）を「翻訳対象の表示」として引用した。意味の欄では operator letter を使わず色の言葉で書き、提案画面（`#ward-zero`）の可視テキストと `aria-label` に単独の英字記号がないことは引き続き assert している。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。可視テキストの club / neon / 道具・資源の残存 0、duplicate id 0、script 0。

2026-09-17T04:47Z の inbox 036（Captain 確認 037）で、判定の流れを提案全体に明示した。source 上の判定（`Board.judge` は全消灯が前提、`logical_effect(E*C)` が NONE なら SUCCESS、それ以外は FAIL。`game.py:194-206`、`judge.py:20-28`）をそのまま DISCO BREAKER に写している。目に見える変更は次のとおり。

- **判定の流れの図（新規、提案節の先頭）**: `04 REPAIR → 全部消えた → 05 READY FOR INSPECTION（消灯＝準備完了。合格ではない）→ 親方を呼ぶ → 親方の検査（隠れていた故障 × あなたの配線、壁から壁へ届く線はあるか？）→ ない: 06 FLOOR ONLINE / ある: 07 INSPECTION FAILED → RETRY: 同じ床を配線ゼロから → 04`。08 / 10 は破線の任意の枝。図の下に「消灯は合格ではありません」の注意文。
- **05**: バナーを緑の `FLOOR DARK // READY` から琥珀の `LIGHTS OFF · READY FOR INSPECTION` に変更（合格の緑は使わない）。app bar を `GIG 02 · REPAIR 1/3 / LIGHTS 0 / 0` に統一。caption を「消灯は『検査の準備ができた』という意味だけで、合格ではありません。親方が隠れていた故障とあなたの配線を重ねて調べ、壁から壁へ届く線がなければ 06、あれば 07 へ進みます」に、`aria-label` と注記も同じ趣旨に改めた。
- **06**: 画面は変えていない（残りの輪の表示はすでにない）。注記に「壁から壁へ届く線がなかったときだけこの画面へ来る。残りに小さな閉じた輪があっても合格で、主な流れではそれを見せない」を加えた。
- **07**: 見出し下の文を「床は暗かった。でも赤い配線が、床を上から下まで横切っていた」に、親方の吹き出しを「隠れていた故障とおまえの配線を重ねたら、赤い線が上の給電盤から下の給電盤まで通っていた。その線だけ光らせたぞ」に変更。横切った線を目立たせるため、床のタイルを .55、印を .3 の不透明度に沈めた（線と上下の給電盤だけが赤く光る）。RETRY の副題を「同じ床で長い配線を小さな輪へ変える」から「同じ床を配線ゼロから」に変更（source の `Board.reset` と一致）。caption・`aria-label`・注記を「床はすべて暗かったのに不合格になる例」として書き直した。
- **08**: caption を「主な流れの外にある任意の報告書です（06 や 07 のあとに開けます）… 閉じた輪の説明はここにだけ置きます」に変更。画面自体は据え置き（閉じた輪の説明は任意の分析としてここに残す）。
- **視覚言語の札**: 「小さな輪」の説明を「床の中だけで閉じた配線。合格の理由として、任意の報告書にだけ出す」に変更。
- **学習フィルム**: 7 段目を「小さな配線の輪 / 床内で閉じれば安全」から「横切る線がない / 親方が合格を出す」（緑の合格札）に変更。8 段目「給電盤を横断 / 反対側まで届くと危険」は据え置き。
- 05 / 06 / 07 の電話 UI と `aria-label` に `LEFTOVER` / `CLOSED LOOP` / 閉じた輪 / 小さな輪 の語がないことを確認した（06 の注記にある「閉じた輪」は「見せない」という説明）。新しい仕組みは足していない。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T04:52Z の inbox 038 で、評判の仕組みを成果物全体から取り除いた。代わりの得点・残機・ランク・通貨・メーター・進行の仕組みは置いていない（設計は保留）。

- **02**: app bar 右の評判の星（`aria-label` 評判 星3つ）を削除。
- **07**: 「評判 ★★☆ 残り2」のカードを削除。注記「評判の減りは星の消灯で示し…」を「減点や数字は出さない。不合格の理由は絵と 1 文だけ」に変更。
- **09**: app bar 右の「客の評価 星2つ」を削除。caption「合格数で新しい音楽ジャンルとダンス演出も開きます」（評判に結びつく解放の主張）を「合格した 3 つの床をそのまま並べて見せます」に変更。完了した床と次のディスコへの移動は残した（評判の gate を含まない）。
- **説明セクション**: 「評判と新しい音楽」（不合格で評判を 1 つ失う、3 区画後に解放）のカードを削除。見出しを「ディスコ床修理を一晩のゲームにする仕組み」にし、残る「1晩3区画」のカードに「得点や進行の仕組みは、まだ決めていません」を添えた。
- **CSS / 部品**: `stars()` 生成関数、`.ph-stars` / `.star` / `.heart-line` の rule を削除。build 時の可視テキスト assert に `reputation / 評判 / ★` を追加した。
- 手で確認した残存: 「正直な評価」（判定画面の読み方の小見出し。評判ではなく「率直な評価」の意味）と、報告書の説明「…そのあとに開く任意の報告書」（「開く」＝ open、解放ではない）だけ。星や心の装飾は残っていない。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T04:59Z の inbox 039 で、07 を Captain の注記どおりに整えた。

- 見出しを `INSPECTION FAILED` から **`POWER LEAK`**（11% の赤い italic、光る）に変更。子どもが読めるディスコの電気の言葉で、抽象的な「検査不合格」を避けた。`CROSS-FLOOR SHORT` より短く、床の絵（上下の給電盤をつなぐ赤い線）と直結するので `POWER LEAK` を採った。
- 見出し下の独立した文「床は暗かった。でも赤い配線が、床を上から下まで横切っていた。」は親方と重複するので削除。app bar 右の `TRACE LIVE WIRE` も削除。
- 親方の吹き出しを 1 文に: **「電気が反対側まで漏れている。配線をやり直そう。」**（原因＋次の行動）。電話 UI の可視テキストは `FOREMAN: NG / POWER LEAK / 親方 / 電気が反対側まで漏れている。配線をやり直そう。/ RETRY / 同じ床を配線ゼロから` だけで、同じ原因は繰り返していない。光る横断線が視覚の説明を担う。
- 数学的な規則は電話の外に置いた: caption に「画面では『電気が反対側まで漏れた』というディスコの言葉で言い、数学では隠れていた故障とあなたの配線を重ねた残りに壁から壁へ届く線（論理的な横断）が含まれたということ」と書いた。`aria-label` と注記も更新。判定の流れの図の 07 の箱を `07 POWER LEAK` に合わせた。
- 検証: 390 で横はみ出しなし、10 画面が body 内に収まる。

2026-09-17T05:02Z の inbox 040 で、08 を「故障と配線を重ねた 1 枚の床」に作り替え、07 を同じ表現に揃えた。

- **表現の規則（成分ごと）**: 接続箱ごとに、隠れていた故障 E とあなたの配線 C を赤成分・青成分に分けて比べる。両成分が一致（打ち消し）なら**緑の輪＋✓**、一致しない成分が残れば**赤の輪＋✕**、片方の成分だけ一致した箱は赤の輪に**内側の点線の緑の輪と ✓✕ の札**を付け、一致した線を薄い緑、残った線を色つきで描く（例: 故障が 2 色、配線が青だけ → 青は打ち消し、赤が残る）。残った赤成分の集合が判定に使う残り R = E × C そのものである。緑/赤の輪を主とし、✓ / ✕ / ✓✕ の札と点線が色に依存しない手がかり。
- **08 INSPECTION REPORT**: `LEFTOVER` の帯、3 段の小さな盤、閉じた輪の表示と説明、重ね表示をすべて外し、82% 幅の 1 枚の床だけにした。上に `✓ MATCH / ✕ MISMATCH` の凡例、床の下に `2 MISMATCHES · NO CROSSING` の 1 行。scenario では (2,2) と (4,1) が緑、(0,2) が赤、(0,3) が部分（青は打ち消し、赤が残る）で、赤は上下の給電盤のどちらにもつながらないので合格。`FOREMAN KNOWS A SHORTER SAFE REPAIR · 3 / SEE IT` の注意と `NEXT GIG` / `RETRY THIS FLOOR` は据え置き。親方の文は繰り返していない。
- **07 POWER LEAK**: 同じ重ねた床にした。(0,3) は青どうしで緑、(0,0) (1,1) (2,2) (3,2) (4,1) は赤の残りで赤の輪。残った赤が上の給電盤から下の給電盤までつながるので、その線を光る赤い点線で強調し給電盤も赤にする。親方の 1 文は変えていない。
- 判定の流れの図の 08 の箱を「任意。緑＝打ち消し、赤＝残り」に、注意文を「残った赤が壁から壁へつながるかどうかだけが合否を分けます」に、視覚言語の「小さな輪」を「画面には出さず、本文の判定の説明にだけ残す」に、設計 7 原則の 4 つ目を「重ねた床で説明する」に改めた。08 の caption・`aria-label`・注記も新表現に合わせた。10（親方の見本）は変えていない。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。08 の電話 UI に `LEFTOVER` / `LOOP` / 閉じた輪の語はない（注記の「閉じた輪の説明は画面に置かない」は説明）。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T05:30Z の inbox 041 と T05:32Z の inbox 042 で、横断の言葉と 07 / 08 の色の意味を、source の判定（残りの論理クラス＝成分ごとの横断の偶奇）に合わせて正した。

### 規則の正確な形（事実）

- 判定は `logical_effect(E*C)`（`judge.py:20-28`）: 残りが論理 Z と反交換すれば X 成分の横断が奇数本、論理 X と反交換すれば Z 成分の横断が奇数本。両方奇数なら Y。0 本や対になる 2 本（偶数）は stabilizer に落ちて SUCCESS。「壁から壁へ届く線が見えるか」という到達可能性の判定ではない。
- 画面の赤い線は判定のあとに選ぶ代表（witness）で、分け方は 1 通りではない。source の `_decompose_residual`（`game.py:206-241`）は行・列のまっすぐな線のうち面が最少になるものを選ぶ。07 の scenario（E = 赤(2,2)・青(0,3)・赤(4,1)、C' = 赤(3,2)・赤(1,1)・赤(0,0)・青(0,3)）を source で分解すると、代表は列 1 のまっすぐな X 線（(0,1)〜(4,1)）＋面 2 つ（内側 X 面 (2.5,1.5) と上の半面 j=0）になる。08 の scenario は横断 0 本で、残りは上の半面 j=2 の 1 面（SUCCESS）。
- 本体コードで再計算: `logical_effect(E*C') = X`、`logical_effect(E*C) = NONE`。

### 変えた表現

- **色の意味（07 / 08）**: 「緑＝位置が一致、赤＝不一致」をやめ、**緑＝安全な分（打ち消し合った箱、対になって消える横断、面の分）、赤＝偶奇の判定で奇数と決まったあとに選ぶ代表の通り抜け 1 本だけ**にした。非色の手がかりは緑 ✓ / 赤 ✕。部分一致の ✓✕ 札と点線の輪は不要になったので削除。08 の凡例は `✓ SAFE / ✕ LEAK PATH`、床の下の 1 行は `NO LEAK · ALL SAFE`。
- **08 の例**: 4 つの箱がすべて緑（2 つは打ち消し、2 つは残った配線だが面の分で安全）。赤はない。
- **07 の例**: 安全な分（青が打ち消し合った (0,3)）は緑、赤成分の横断が 1 本（奇数）なので、残りの支持そのもの（(0,0)(1,1)(2,2)(3,2)(4,1) のジグザグ）を代表の通り抜けとして赤の輪と赤い線で示した。これは残りの支持と一致する別の代表であり、source の列 1 のまっすぐな代表と同じ論理クラスである。caption に「赤い線は判定後に選ぶ代表で、分け方は 1 通りではない（元のゲームなら列 1 の線と面 2 つ）」と明記した。赤成分と青成分の両方が奇数なら代表を 1 本ずつ赤にし、残りは緑のまま（論理的には 2 色の交差）と caption・注記に書いた。
- **文言**: 「壁から壁へ届く線がある／ない」を、画面の流れの図（「残りの壁から壁への通り抜けは奇数本か？（0・2 本なら合格）」、分岐の札を「偶数 / 奇数」）、判定の流れの注意文、05 / 06 / 07 / 08 の caption・`aria-label`・注記、学習フィルム（「通り抜けなし → 合格」「壁から壁へ通り抜け: 奇数本なら電気が漏れる」）、判定画面の読み方（SUCCESS の説明を「横断が偶数本」に、残りの形の説明に「2 本なら打ち消し合って安全」を追加、表 7 行目を反交換による判定に）、設計原則 4、そして新しい「偶奇の注意（規則の正確な形）」の注意文（`judge.py:20-28` を引用）に置き換えた。子ども向けの主な例は「電気が反対側まで漏れる／通り抜ける」の言葉のまま簡単に保った。
- 残存確認: 提案節以降に「壁から壁へ届く線」「つながれば／つながらな」「MATCH / MISMATCH」「打ち消した箱は緑」「残った箱は赤」の語はない。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T05:48Z の inbox 043 で、04 を正準の舞台として 05 / 06 / 07 / 08 の物理配置を完全に揃えた。

- **共有部品**: `scene(board, top=…, bottom=…, on=…)` が 1 つの DOM（舞台 → 床 → 上の空き → 下の空き）を生成し、CSS の座標契約 `.ph-club.live.ph-scene` で絶対配置する。契約（端末幅 % = cqw）: 舞台は上端から高さ 25、床は幅 84 で舞台上端から 47.9 下、上の空き（overlay slot）は 25〜47.9、下の空き（overlay slot）は 131.9〜下端。空きに置くもの（バナー、見出し、親方の吹き出し、凡例、注意、副ボタン）は絶対配置なので、舞台・床・app bar・下の主ボタン（高さ 17）を動かさない。
- **04**: 生成部品を使うだけで見た目は不変（床の上端が 73.5 → 73.78 cqw、約 1 px の丸め差）。
- **05**: 小さかった compact 舞台（球 10、床 70）を捨てて 04 と同じ舞台・床にし、バナーを上の空き、親方の吹き出しを下の空きへ。チェックリスト（ちらつく床 0 枚／使った接続箱 4 か所）は空きに収まらず、app bar の `LIGHTS 0 / 0` とバナーが同じ情報を持つので外した。ボタンは高さ 17 の琥珀色に統一。
- **06**: DISCO! を上の空きに移し、光る 3D の球を消えた球と同じ中心（上 4.2、半径 8.5）と支柱（高さ 4.5）に合わせた。光条・光だまり・光点は舞台全体の絶対配置のまま。
- **07**: 独立した `.ph-club quiet`（床 70、舞台なし）をやめ、04 と同じ舞台・床（床が下へ移動）にし、POWER LEAK を上の空き、親方の 1 文を下の空きへ。RETRY は高さ 17。
- **08**: 別の `ph-report-stage`（床 82）をやめて同じ舞台・床にし、凡例と親方の注意を上の空き、`NO LEAK · ALL SAFE` と `RETRY THIS FLOOR`（高さ 11 の副ボタン）を下の空き、NEXT GIG を主ボタンの位置へ。
- **ほかの画面の監査**: 01（タイトル）、02（作業札の床の見取り図）、03（3×3 の練習床）、09（合格した床の縮小 3 枚）、10（比較用の縮小床と重ねた床）は同じ物理的な舞台を描いていないので変えていない。
- **画素検証**: DOM の bounding rect を phone-screen 基準で比較。390×844×2 では 04〜08 すべてで球 16.84/30.08/17×17、ブース 42.42/36.89/42×13、床 5.61/73.78/84×84、主ボタン 4.5/186.5/86.21×17（cqw）。412×915×2.6 では球 61.3/109.4/61.9、ブース 154.5/134.2/152.9×47.3、床 20.4/268.5/305.8、主ボタン 16.4/678.9/313.8×61.9（CSS px）で 5 画面完全一致。各 phone の固定サイズ render を切り出し、04 と 05〜08 を 50% で重ねた合成画像（`blend-390-*.png` / `blend-412-*.png`）で、球・ブース・床の格子・app bar・主ボタンが二重にならず、光・印・文字だけがずれることを目視確認した。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

2026-09-17T06:41Z の inbox 044 / 045（同文）と T06:43Z の inbox 046 で、レビューの 6 項目を反映した。

- **05**: 上の空きの `LIGHTS OFF · READY FOR INSPECTION` バナーを削除。app bar 右の `LIGHTS 0 / 0` を削除。`CALL THE FOREMAN` の副題「親方を呼ぶ」を削除。吹き出しを「ぜんぶ消えたね。呼んでくれたら電気を入れて確かめるよ」にし、「親方」の名札を外して、電源プラグの印（SVG mask、`aria-hidden`）を添えた。
- **07**: 吹き出しを「電気が反対側までもれちゃった。配線をやり直そう！」にし、名札を外して、稲妻（漏電）の印を添えた。
- **03**: 同じ吹き出し部品なので名札を外し、タップの印を添えた。3 つの凡例（赤・青・2色のレッスン行）と「自分で1回やってみる / ガイド表示 ON」のボタンを削除。練習床を 74% 幅で画面中央に置き（中心 x = 画面中心）、吹き出しの終わりに接続箱をそのまま 1 回タップすれば赤い配線になる流れにした。進み具合は上の 3 つの点と `STEP 1 / 3` だけ。代わりの操作や仕組みは足していない。
- 判定の流れの図の 05 の箱を `05 CALL THE FOREMAN` にした（画面にその語がなくなったため）。本文の「親方」という呼び名は説明文に残す。
- 05〜08 の共有舞台の座標契約は変えていない（球 16.84/30.08/17×17、ブース 42.42/36.89/42×13、床 5.61/73.78/84×84、主ボタン 4.5/186.5/86.21×17 cqw で再確認）。副題つきの大ボタン（07 の RETRY）が横並びになる不具合を直し、縦組みに戻した。
- 検証: 390 / 412 で横はみ出しなし、10 画面が body 内に収まる。Lighthouse mobile は Accessibility 100、Failed 0。

2026-09-17T06:49Z の Lavish feedback（チュートリアル 2/3 と 3/3 も追加。必要なら増やしてよい。実際の分量を確かめたい）と、inbox 047 / 048（同文: 吹き出しの印を外す、1 段目の吹き出しを上げて LOAD THE VAN と同じ位置に OK を置く）を反映した。

- **チュートリアルを 6 段に拡張**（03、03-2 〜 03-6 の 6 枚）。分量を確かめる目的なので、省ける段も含めて全部描いた。
  1. 赤は 1 回タップ（3×3、赤 2 枚、まんなかの箱が脈打つ）。
  2. 青は 2 回タップ（青 2 枚、箱のそばに `×2` の札）。巡回（なし → 赤 → 青 → 2色 → なし）と、1 回目の赤では青が消えないことを体で覚える。
  3. 赤と青は 3 回タップ（4 枚、`×3` の札）。本文の練習 3 と同じ形。
  4. 消えたら検査を呼ぶ（全消灯、赤と青の交差線が残る）。「消えただけでは合格じゃない」を先に言い、ここで初めて琥珀色の CALL THE FOREMAN が現れる。
  5. 消えても、もれることがある（角と角の赤 2 か所で消したが、隠れていた故障 = まんなかの赤と重ねると壁から壁へ 1 本通り抜ける → POWER LEAK の見た目）。本文の「タイルが全部暗い ≠ かならず成功」を最小の 3×3 で体験させる。07 と同じ表現（緑 = 安全、赤 = 代表の通り抜け）。この例の残りは X(0,0)·X(1,1)·X(2,2) の対角線で、上下の境界に触れる奇数本の横断。
  6. 本番と同じ 5×5 で 1 回（04 の開始状態、無効の CALL THE FOREMAN）。省いても成り立つ段と caption に明記。
- **吹き出し**: 印（電源プラグ・稲妻・タップ）を外し、文字だけにした（03 系・05・07 すべて）。名札は引き続きなし。
- **1〜3・5 段目の構成**: 練習床（70% 幅）を画面中央、吹き出しはその直下、いちばん下に `OK`（高さ 13%、02 の LOAD THE VAN と同じ y = 189.5 cqw、同じ幅）。OK で吹き出しが消え、接続箱を直接タップする流れは保った。4・6 段目の下は CALL THE FOREMAN。
- **画面数**: 提案画面は 10 + チュートリアル 5 枚 = 15 枚の phone。画面の流れの札は `03 TUTORIAL` の 1 つのまま。枠の説明を「10 画面（チュートリアルは 6 段）」に改めた。
- 共有舞台（04〜08）の座標契約は変えていない。
- 検証: 390 / 412 で横はみ出しなし、15 画面が body 内に収まる。OK ボタンの位置は 02 の LOAD THE VAN と一致（4.5/189.5/86.21/13 cqw）。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。提案節の単独英字 0、duplicate id 0。

2026-09-17T07:01Z の inbox 049 で、検査係（親方）の顔を作り直した。

- 旧: CSS の円 2 つと帯で描いた顔（ミートボールに見える）。新: 64×64 の viewBox に描いた独自のインライン SVG マスコット。平らなポップ調で、色数を絞り輪郭を太くして小さくても読めるようにした。Duolingo は「明るく平らで読みやすい」品質の参考にしただけで、キャラクターや素材は使っていない。
- 部品構成（すべて別の `<g>` / 要素）: `fm-badge`（丸い台）、`fm-body`（オレンジのベストと反射帯）、`fm-head`（耳、肌、頬）、`fm-eyes`（白目・瞳・ハイライト）、`fm-brows`（眉 2 本）、`fm-stache`（口ひげ）、`fm-mouth`（唇の線＋舌）、`fm-hat`（黄色いヘルメットのドーム・つば・前帯）。
- 動き: 吹き出しがあるあいだは `.fm.talking` が付き、`fm-mouth` だけが `scaleY` で 0.55 秒周期に開閉し、舌の不透明度が連動する（`transform-box: fill-box` で口の上端を軸にする）。眉・目も別部品なので同じ方法で動かせる。`prefers-reduced-motion` では止まる（DOM で `animationName: none` を確認）。
- 表示箇所: 03 の 6 段、05、07 の吹き出し（計 9 か所）と UI kit の「検査係のマスコット」（話している状態と黙っている状態を並べ、部品の説明を添えた）。吹き出しの顔の大きさを 11% → 13% に広げた。共有舞台の座標契約と各画面の配置は変えていない（05 / 07 の下の空きに収まることを 390 / 412 で確認）。
- 検証: 390 / 412 で横はみ出しなし、15 画面が body 内に収まる。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。

## 結論の要約

Syndrome Out は「感染が広がるゲーム」ではない。現在の公開実装は、回転表面符号を使った 1 人用の訂正パズルである。

1. 開始時に、各データ量子ビットへ隠れた Pauli エラー `E` が 1 回だけ標本化される。
2. プレイヤーには `E` の位置ではなく、周囲の偶奇を表すシンドロームタイルだけが見える。
3. プレイヤーは各量子ビットに `X`、`Z`、`Y` の訂正 `C` を自由に toggle する。
4. 全タイルが暗いときだけ JUDGE できる。
5. `R = E * C` が安定化子クラス `I` なら SUCCESS。論理 `X`、`Z`、`Y` を含むなら FAIL。

最重要点は「全消灯は判定の前提であり、勝利条件そのものではない」である。シンドロームを出さない論理演算子が残るため、全消灯のまま失敗できる。

## 調査スナップショット

- 公開リポジトリ: https://github.com/stn/SyndromeOut
- 調査対象 commit: [`a1a3c53cdc07f15e472b204eba478ec0420c1a92`](https://github.com/stn/SyndromeOut/commit/a1a3c53cdc07f15e472b204eba478ec0420c1a92)
- commit 日時: 2026-09-13T05:17:10Z
- 調査日: 2026-09-16
- main の GitHub Pages deployment: [run 34739945740](https://github.com/stn/SyndromeOut/actions/runs/34739945740)、build と deploy がともに success
- GitHub Releases: なし
- tags: なし
- ローカル検証: `uv run pytest -q` で `65 passed, 1 skipped`
- 視覚再検証時の remote main: `a1a3c53cdc07f15e472b204eba478ec0420c1a92`。固定 commit と一致

GitHub 操作は `gh-axi` で行い、`gh-axi repo clone stn/SyndromeOut` で固定 commit のローカル検査環境を作った。

## 検査した一次資料

| 資料 | 検査内容 |
|---|---|
| [`README.md`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md) | ゲーム目的、操作、判定後表示、ML、既知 seed |
| [`game.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py) | 状態機械、設定値、seed、操作、undo/redo、判定、勝敗補助ラベル |
| [`app.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py) | 無文字タイルの色面・glow・outline、丸いボタンの円・斜線・選択輪、入力、判定後画面 |
| [`code.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/code.py) | d×d 盤、面、境界、論理演算子、シンドローム計算 |
| [`noise.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/noise.py) | 隠れたエラーの確率モデル |
| [`pauli.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/pauli.py) | I/X/Z/Y、積、重さ、同じ操作が打ち消し合う根拠 |
| [`judge.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/judge.py) | residual の I/X/Z/Y クラス判定 |
| [`decoder.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/decoder.py) | bot の最小重さ訂正、ML クラス、同率時の規則 |
| [`tests/test_game.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/tests/test_game.py) | toggle、判定 gate、全消灯失敗、reset、seed 実例 |
| [`tests/test_code.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/tests/test_code.py) | 面数、境界、単一エラーの点灯数、論理演算子 |
| [`tests/test_decoder.py`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/tests/test_decoder.py) | decoder の訂正能力、検出不能な論理エラー、ML |
| [score 削除 commit](https://github.com/stn/SyndromeOut/commit/bad60e2dde4e37607378087001093ec9592138c6) | 現在のルールに得点がないことの履歴上の確認 |

画像ファイルはゲームルールの確認用に存在を確認しただけで、成果物にはコピーも変形利用もしていない。

## 盤面描画の再検証

### タイル

**`app.py:340-383` でコードから確定。**

- 点灯前の face は `TILE_OFF` の暗い長方形で、種類に応じた赤または青の outline だけを持つ。
- 点灯中は長方形全体を赤または青で塗り、1 px / 2 px を周期的に切り替える pulse glow を外側へ描く。
- 判定後に再点灯表示する face は落ち着いた dim 色 + 通常色 outline になる。
- hover 中に影響する face は、さらに外側へ `TEXT` 色の outline を描く。
- タイル内部へ `X!`、`Z!`、その他の文字を描く処理はない。

### 丸いボタン

**`app.py:398-421` でコードから確定。**

- 空の量子ビットは円形ボタンで、I/X/Z/Y の文字はボタン内に描かれない。
- X は赤い太線。現在地に接する赤タイプ面どうしを結ぶ斜め方向へ描く。
- Z は青い太線。X と反対の斜め方向へ描く。
- Y は赤線と青線を両方描くため、2色の交差に見える。
- どちらの斜めが赤かは `(row + column) % 2` で交互に入れ替わる。これは市松配置で、同じ色の面へ線を向けるためである。
- keyboard cursor はボタンより外側の ring、mouse hover は button highlight、press 中は半径を 1 px 小さくして表す。

根拠は [`app.py:340-421`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L340-L421)。HTML はこの interaction semantics を再現したが、Pyxel の pixel art、palette、寸法は複製していない。タイルは CSS / SVG の色面と静的 halo、線は太い独自 stroke、選択輪は tutorial 用の金色で新規作成した。

## 再構成した実ルール

### 1. セットアップ

**コードで確定。**

- 盤の距離 `d` は `3, 5, 7, 9`。エラー率 `p` は `0.05, 0.10, 0.15`。[`game.py:25-28`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L25-L28)
- 既定値は `d=5, p=0.10`。[`README.md:11-16`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L11-L16)
- 盤は d×d 個のデータ量子ビットを持つ。d は 3 以上の奇数でなければならない。[`code.py:35-56`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/code.py#L35-L56)
- X-type 面と Z-type 面は各 `(d² - 1) / 2` 個、合計 `d² - 1` 個。境界面は 2 量子ビット、内部面は 4 量子ビット。[`test_code.py:18-23`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/tests/test_code.py#L18-L23)
- 各量子ビットは独立に、確率 `1-p` で I、`p/3` ずつで X、Y、Z になる。[`noise.py:11-28`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/noise.py#L11-L28)
- 6 桁の hex code は d index 2 bit、p index 2 bit、raw RNG seed 20 bit をまとめる。同じ code で同じ盤を再現できる。[`game.py:30-50`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L30-L50)
- 初期状態では隠れたエラー `E` を標本化し、プレイヤー訂正 `C` は identity `I` から始まる。[`game.py:90-117`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L90-L117)

### 2. 盤面と見える状態

**コードで確定。**

- プレイヤーが見る点灯状態は隠れた `E` そのものではなく、`R = E * C` の syndrome。[`game.py:129-145`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L129-L145)
- X-type 面は Pauli の Z 成分を検出し、Z-type 面は X 成分を検出する。計算は mod 2 の偶奇。[`code.py:134-142`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/code.py#L134-L142)
- UI は「その合図を消す訂正」の色で表す。赤タイルは X 成分の合図で X を置く。青タイルは Z 成分の合図で Z を置く。[`README.md:20-23`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L20-L23)、[`app.py:109-112`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L109-L112)
- 点灯タイルは無文字の赤または青の色面 + pulse glow、消灯タイルは暗い面 + 種類色 outline。タイル内に `X!` / `Z!` は表示しない。[`app.py:366-383`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L366-L383)
- 1 個の X または Z 成分は対応色の面を 1 個か 2 個点灯させる。盤の外周でない量子ビットなら必ず 2 個。[`test_code.py:74-87`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/tests/test_code.py#L74-L87)
- 複数エラーは偶奇で合成される。同じ面に寄与する成分が偶数なら消え、奇数なら点灯する。このため点灯面から原因位置は一意に決まらない。

### 3. プレイヤー行動

**コードで確定。**

- 判定前は任意の量子ビットで X、Z、Y を toggle できる。Y は同じ量子ビットの X 成分と Z 成分の両方。[`game.py:156-167`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L156-L167)
- 左クリックまたは `x` は X、右クリックまたは `z` は Z、`y` は Y。[`README.md:25-30`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L25-L30)
- 丸いボタンでは X を赤い斜線、Z を逆向きの青い斜線、Y を両方の交差として描く。斜線は、その操作で変わる同色面の方向に沿う。[`app.py:398-421`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L398-L421)
- Pauli の積は binary vector の XOR。したがって X×X、Z×Z、Y×Y は消え、同じ位置の X と Z は Y になる。位相は扱わない。[`pauli.py:24-42`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/pauli.py#L24-L42)
- undo / redo がある。新しい move は redo stack を消す。判定後は undo / redo できない。[`game.py:164-181`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L164-L181)
- Retry は同じ seed と同じ E を保持し、C、verdict、undo/redo を初期化する。[`game.py:183-190`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L183-L190)
- `n` は新しい random seed。`d` と `p` は設定を cycle したうえで新しい random seed の盤を作る。[`app.py:228-273`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L228-L273)
- キーボードカーソルは矢印または hjkl で移動し、端では modulo により反対側へ wrap する。[`app.py:228-246`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L228-L246)

### 4. ターン・時間順

**現在のコードから確定。**

明示的なターン、タイマー、敵行動、経過時間による状態変化はない。`Board` の可変状態は C、verdict、residual 表示、undo/redo であり、入力は update loop から直ちに toggle へ渡る。[`game.py:90-107`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L90-L107)、[`app.py:207-263`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L207-L263)

実際の順番は次のとおり。

1. `E` と最初の syndrome を生成。
2. プレイヤーが任意回数 C を toggle、undo、redo。
3. 全面消灯になる。
4. JUDGE。
5. verdict を固定し、C、B、E、R を表示。
6. RETRY または NEW。

### 5. 合法・不合法な操作

**コードで確定。**

- 判定前の X/Z/Y toggle は任意位置で合法。手数上限はない。
- 全タイルが暗くないと `judge()` は `None` を返す。UI は拒否音を出し、JUDGE ボタンも出さない。[`game.py:194-207`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L194-L207)、[`app.py:310-318`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L310-L318)、[`app.py:497-503`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L497-L503)
- 判定後の toggle は無視され、UI は拒否音を出す。undo / redo も false を返す。[`game.py:156-181`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L156-L181)、[`app.py:275-289`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L275-L289)
- 判定後に JUDGE をもう一度呼んでも同じ verdict を返し、再判定しない。[`game.py:194-199`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L194-L199)

### 6. spread / outbreak

**実装されていないことをコードで確認。**

- `E` は `Board.__post_init__` で 1 回生成され、その後の move や frame update では変更されない。[`game.py:109-117`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L109-L117)
- Retry は `E` を再標本化しない。[`game.py:183-190`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L183-L190)
- 待機、手番、誤操作による感染拡大、outbreak meter、連鎖増殖はない。

タイトルから感染物語を推測できるが、公開コードはそのような物語ルールを定義していない。HTML の source-proven tutorial では「アラーム」を説明用の比喩として明記し、感染拡大を実ルールにしていない。分離したディスコ床修理 proposal の故障パネルも、追加物語として明示している。

### 7. containment / cure

**実装上は「治療」ではなく訂正。**

プレイヤーは E を直接削除しない。C を構成し、見えている `syndrome(E*C)` を変える。全消灯後、`E*C` が harmless stabilizer class に入るようにするのが実質的な containment である。[`game.py:129-145`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L129-L145)、[`judge.py:11-28`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/judge.py#L11-L28)

薬、体力、資源、封じこめゲージはない。

### 8. 勝敗

**コードで確定。**

- JUDGE 前提: syndrome がすべて 0、つまり全タイル消灯。
- 判定対象: `R = E * C`。
- SUCCESS: `logical_effect(R) == I`。R は identity でなくても、面 stabilizer の積なら成功。[`game.py:62-68`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L62-L68)、[`judge.py:11-28`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/judge.py#L11-L28)
- FAIL X: R が列を上下に横切る論理 X と面の積。
- FAIL Z: R が行を左右に横切る論理 Z と面の積。
- FAIL Y: 論理 X と論理 Z の両方を含む。
- 判定後の R 表示は、失敗なら横切る logical path と face 群、成功なら face 群だけへ分解する。[`game.py:209-241`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L209-L241)

README も「全消灯と成功は同じでない」と明記し、seed 50009C で全消灯の FAIL Z を示す。[`README.md:97-106`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L97-L106)

### 9. 得点、重さ、ML

**現在の版に点数はない。**

- 現在の `Verdict` に score field はない。持つのは effect、player weight、bot weight、bot effect、ML effect、hidden error weight。[`game.py:53-60`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L53-L60)
- score は commit [`bad60e2`](https://github.com/stn/SyndromeOut/commit/bad60e2dde4e37607378087001093ec9592138c6) で明示的に削除された。
- Pauli weight は X または Z 成分を持つ量子ビット数。Y は 1 量子ビットなので 1 と数える。[`pauli.py:59-68`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/pauli.py#L59-L68)
- `NOT OPTIMAL` は、成功した C より軽い成功例が hidden E または成功した bot B として既知のときだけ出る。[`game.py:80-86`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L80-L86)
- `NOT OPTIMAL` が出ないことは、C が大域最小だという証明ではない。これはコードから分かる重要な制限である。
- ML は、同じ syndrome と整合する全エラーを I/X/Z/Y クラスごとに合計した depolarizing posterior が最大のクラス。Y は 1 回の `p/3` factor として数える。[`decoder.py:37-49`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/decoder.py#L37-L49)、[`README.md:44-51`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L44-L51)
- ML likelihood が同率なら lighter class、さらに同率なら lower internal class index I, X, Z, Y を選ぶ。[`decoder.py:267-274`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/decoder.py#L267-L274)
- `SUCCESS (but not ML: Z)` と `FAIL Z error (but ML)` は補助ラベルであり、実際の勝敗を変更しない。[`game.py:70-78`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L70-L78)
- bot B は最小重さ訂正。PyMatching optional extra があればそれを使い、なければ内蔵 decoder を使う。同じ重さの tie-break で形が異なることはある。[`game.py:15-23`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L15-L23)

### 10. 判定後画面

**コードと README で確定。**

判定後は 2×2 に次を表示する。

- C: your correction
- B: bot の minimum-weight correction
- E: true error
- R: residual `E*C`

README の説明は [`README.md:37-52`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/README.md#L37-L52)。UI 定義は [`app.py:88-101`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/app.py#L88-L101)。

### 11. エッジケース

1. **同じ操作を 2 回**: XOR で打ち消す。
2. **X と Z を同じ位置**: Y になる。Y を 2 回なら消える。
3. **新しい move の後の redo**: redo stack は消える。
4. **最初から全消灯**: すぐ JUDGE できる。
5. **全消灯の clean board に論理列を置く**: 全消灯のまま FAIL できる。[`test_game.py:72-84`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/tests/test_game.py#L72-L84)
6. **全消灯の clean board に stabilizer 面を置く**: SUCCESS だがより軽い identity があるため NOT OPTIMAL。[`test_game.py:59-69`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/tests/test_game.py#L59-L69)
7. **判定前に点灯が残る**: JUDGE 無効。
8. **判定後**: move と undo/redo は無効。
9. **hidden logical error**: syndrome 0 なので decoder から検出不能。[`test_decoder.py:81-87`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/tests/test_decoder.py#L81-L87)
10. **successful residual が非 identity**: stabilizer 面の積なら安全。
11. **ML 同率**: lighter class、その後 lower class index。
12. **bot tie**: backend により同重さの別形状を選びうるが、bot weight は同じ。

## HTML に使った具体例の再検証

### seed 000073

固定 commit のコードで `Board.new(3, 0.05, 115)` を生成し、pack code `000073` を確認した。

- hidden E: `IIIIXIIII`
- E weight: 1
- X は中央 qubit index 4
- 初期 lit faces: `[0, 3]`
- lit counts `(X-type, Z-type)`: `(0, 2)`、つまり赤が 2、青が 0
- 中央に X を置いた後: `all_clear == True`
- residual: `IIIIIIIII`
- verdict: effect I、player weight 1、bot weight 1、ML effect I

この例を HTML の guided sample turn に使った。図の左上と右下の赤面、中央 X、全消灯 SUCCESS は実データと一致する。

### seed 0001C5

固定 commit のコードで `Board.new(3, 0.05, 453)` を生成し、pack code `0001C5` を確認した。

- hidden E: `IIIIZIIII`
- E weight: 1
- Z は中央 qubit index 4
- 初期 lit faces: `[1, 2]`
- 青が 2、赤が 0
- 中央に Z を置いた後: `all_clear == True`
- residual: `IIIIIIIII`
- verdict: effect I、weight 1

この例を練習2に使った。図の右上と左下の青面、中央 Z、全消灯 SUCCESS は実データと一致する。

### seed 0000FA

固定 commit のコードで `Board.new(3, 0.05, 250)` を生成し、pack code `0000FA` を確認した。

- hidden E: `IIIIYIIII`
- E weight: 1
- Y は中央 qubit index 4
- 初期 lit faces: `[0, 1, 2, 3]`
- 赤が 2、青が 2
- 中央に Y を置いた後: `all_clear == True`
- residual: `IIIIIIIII`
- verdict: effect I、weight 1

この例を練習3に使った。中央を囲む赤2面と青2面、中央 Y、全消灯 SUCCESS は実データと一致する。

### seed 000001

固定 commit のコードで `Board.new(3, 0.05, 1)` を生成した。

- hidden E: identity
- 開始時 `all_clear == True`
- 何も置かない判定: SUCCESS、weight 0
- 左端の列 3 個へ X を置く: `all_clear == True` のまま logical effect X、`FAIL X error`

この例を「最初から全部暗い」エッジケースに使った。

### post-JUDGE screenshot: seed 560F4A

Captain 提供の screenshot と固定 commit の実装を照合した。`unpack_seed(0x560F4A)` と盤の再計算結果は次のとおり。

- `d=5`, `p=0.10`, raw RNG seed `0x60F4A`、decimal `397130`
- data qubit は25個、code distance は5
- hidden E: `IIIIIXIIIIIIIIIIIIIIIIZYI`、weight 3
- hidden E の非 identity 位置: q5=`X`、q22=`Z`、q23=`Y`
- initial lit counts: X-type 2、Z-type 3、lit face indices `[0, 15, 17, 19, 21]`
- screenshot の player C: q5=`X`、q22=`Z`、q23=`Z`、q24=`X`、weight 4
- residual `R=E*C`: bottom boundary の X stabilizer face index 19、q23/q24 の2 support。logical effect `I`、face count 1
- bot B は hidden E と同形で weight 3。bot residual は identity、bot logical effect `I`
- ML logical effect は `I`
- verdict: player SUCCESS、NOT OPTIMAL、bot SUCCESS

したがって screenshot の `|C|=4`、`|B|=3`、`|E|=3`、`R = 1 face harmless` と3つの status はすべて実装と一致する。ここで `1 face` は residual weight 1 ではなく、stabilizer face 1個への分解である。player の weight 4 が bot の成功 weight 3 と hidden E weight 3 より大きいため、`Verdict.not_optimal` が true になる。[`game.py:53-86`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L53-L86)、[`game.py:194-241`](https://github.com/stn/SyndromeOut/blob/a1a3c53cdc07f15e472b204eba478ec0420c1a92/syndrome-out/syndrome_out/game.py#L194-L241)

HTML の主表示では source symbols を直接使わず、最初に「成功。ただし4個より短い3個の成功例あり」と要約した。その後に設定、field dictionary、4対3、4枚の盤、residual flow、mechanic assessment の順で段階的に説明する。C/B/E/R、`d`、`p`、logical effect、ML の原語と数式は閉じた advanced disclosure に残した。

## ゲーム mechanics の評価

### source-proven facts

- 同じ syndrome と整合する error は複数あり、4 logical classes に分かれる。
- player は visible syndrome から correction route と logical class を選ぶ。
- 同じ logical class 内では stabilizer face を掛けた複数の correction が同じ成功判定を持ちうる。
- decoder は syndrome と `p` から ML class を計算できるが、実際に標本化された hidden E の class を常に特定できるわけではない。
- hidden logical error は syndrome 0 で、visible information から検出不能である。

### 解釈と design judgment

この mechanic には意味のある選択がある。player は syndrome endpoints をどの route でつなぐか、どの homology class を選ぶか、weight をどこまで減らすかを決める。一方で observation が同じなのに hidden class が異なる instance を完全には区別できず、Bayes-optimal な選択でも個別試行は失敗しうる。

したがって、決定論的で唯一解の logic puzzle として提示すると不公平感が生じる。確率モデルを使って risk を選び、判定後に hidden state と residual を振り返る puzzle と明示すれば成立する。これは source rule ではなく、source-proven underdetermination に基づく design assessment である。

## `DISCO BREAKER: ディスコ床修理` design proposal の境界

この名称、80s disco repair の物語、画面案、tutorial flow は SyndromeOut repository に存在しない。HTML では黄色い `DESIGN PROPOSAL` label と「source-proven rule ではない」の文で、実ルールから明確に分離した。

修理中の床で光る赤・青は show lighting ではなく flickering fault panel である。全消灯後に foreman が通電検査し、合格後だけ正常な多色 pattern が戻る。この2段階により「disco なのに光を消す」という目的の矛盾を避けた。配線の closed loop と edge-to-edge path は数学を説明するための metaphor であり、電気工学上の一般法則だとは主張しない。

10画面の inventory は次のとおり。

1. final `DISCO BREAKER` title screen
2. club tour / repair briefing
3. red、blue、combined wiring tutorial
4. live dance-floor repair with paused DJ and wall-side crowd
5. all-flicker-clear / call-the-foreman
6. floor online / music and dance restart
7. inspection failed / unsafe live-wire trace
8. inspection report: one combined floor (true fault × player repair; green = safe contributions, red = the representative witness crossing only when the per-component crossing parity is odd), retry = same floor from zero
9. disco-tour progression (passed floors, next disco)
10. foreman's shortest-known safe repair, shown only when useful

result hierarchy は foreman verdict、safety reason、efficiency comparison、next repair action、optional diagnostics の順である。tutorial は first connection から probability / code-distance concepts まで11段階を visual filmstrip で示す。C/B/E/R/d/p は proposed beginner result screen へ出さない。

追加 game system は、1 night 3 floor zones だけである（2026-09-17 の Captain 決定で spare wire の持ち越し、TESTER / FUSE、toolbox upgrade、3-point reputation と unlock を削除した。得点・進行の設計は保留）。これは source rule ではない。一方で hidden error を repair 内で固定し、thinking time を無制限にするため、観測途中に真相が変わる不公平は導入しない。

### 縦画面 mock の仕様（2026-09-17 改訂）

| 項目 | 値 |
|---|---|
| device frame | 393:852（iPhone 15 相当）。Android 想定の画面は punch hole と角丸 10% で区別 |
| 単位 | 画面内はすべて `cqw`（端末幅の %）。`.phone-wrap` を `container-type: inline-size` にし、frame 自身の余白と角丸もその幅で決める |
| 段構成 | 状態バー 12%、本文、ホームバー 7.5%。主ボタンは `margin-top: auto` で親指ゾーンへ固定 |
| touch target | ボタン・パレット 13% ≒ 52pt、接続箱の中心間隔 100/532 × 板幅 ≒ 60pt |
| 文字 | ロゴ 17.5%、見出し 5.4%、本文 3.7%、注記 3.1%（393pt で 69 / 21 / 14.5 / 12pt） |
| 配色 | 故障の赤 `#ff4d5e` と青 `#4da6ff` は SyndromeOut の `X_LIT` / `Z_LIT` をそのまま採用。進む=ピンク、検査=琥珀、合格=緑 |
| 盤面 | `gen_screens.py` の `board_svg()` で生成。半面、rail（給電盤）、mark、cursor ring、chain、party、framed face を class で切り替え |

04〜08 の scenario は SyndromeOut 本体（commit `a1a3c53`）で次のとおり検証した。

| Pauli | 接続箱 | 重さ | 結果 |
|---|---|---|---|
| 隠れた故障 E | 赤(2,2)、青(0,3)、赤(4,1) | 3 | 点灯: 赤 (1,1) (2,2) (3,1)、青 (0,3) と上の半面 j=2 |
| プレイヤー C | 赤(2,2)、2色(0,3)、赤(0,2)、赤(4,1) | 4 | syndrome(C)=syndrome(E)。`E*C` = 上の半面 j=2 の stabilizer 1 枚、`logical_effect` = NONE → SUCCESS、NOT OPTIMAL |
| 失敗例 C' | 赤(3,2)、赤(1,1)、赤(0,0)、青(0,3) | 4 | syndrome(C')=syndrome(E)。`E*C'` は stabilizer でなく `logical_effect` = X → FAIL（赤い縦断） |

座標は (行, 列)、0 始まり。07 の画面で光らせた経路 (0,0)-(1,1)-(2,2)-(3,2)-(4,1) は `E*C'` の赤い support そのもので、上下の給電盤に触れる形で描いた。08 の画面で緑の枠を付けた半タイルは `E*C` の stabilizer face である。

## あいまいさと、勝手に決めなかったこと

### A1. 参照される spec が公開されていない

`code.py`、`game.py`、`judge.py`、tests のコメントは `spec 3.1`、`spec 6.1` などを参照する。しかし現行ツリーと全 commit の file list に spec、plan、design 文書はない。README と実行コードを優先し、欠落仕様書の内容は推測しなかった。

### A2. README の「赤のとなりに X error」は短縮表現

README は赤タイルを「X error sits next to it」と説明する。しかし実装が示すのは隣接 X 成分の mod 2 parity であり、具体的なエラー位置や個数ではない。複数の X 成分が偶数個なら消える。

HTML の tutorial ではまず「赤には X」という操作だけを教え、正確な偶奇の説明は後半の evidence に分離した。X error の場所が一意に分からない点も後半で明示した。

### A3. outbreak / 感染物語は未定義

公開資料には時間拡大、感染、薬、封じこめ資源のルールがない。source-proven tutorial の「アラーム」「追い出す」は説明用の比喩としてラベル付けした。電気工事士、親方、DJ、客、クラブ巡業、工具資源は、黄色い DESIGN PROPOSAL 内だけの追加物語である。

### A4. `FAIL Z error` は physical Z 1 個を意味しない

UI の `FAIL Z error` は residual の logical effect Z を意味する。単一の physical Z が残ったという意味ではない。HTML は「Z クラス」「左右を横切る Z の線と同じ働き」と表現した。

### A5. `NOT OPTIMAL` は片方向の警告

コードは hidden E と、成功時の bot B だけを比較する。表示が出れば軽い成功訂正は確実に存在するが、表示が出ないから大域最小とは限らない。HTML にこの非対称性を明記した。

### A6. README の「losing board」の意味

`FAIL ... (but ML)` でも hidden E 自体を C として置けば成功できる。したがって「絶対に成功手がない盤」ではなく、「見えている syndrome と確率モデルだけから ML を選んでも実際の hidden class を外した盤」と解釈した。HTML では「合理的でも外れる」と説明し、不可能盤とは呼ばなかった。

### A7. bot の形は環境依存になりうる

PyMatching が import 可能なら B は PyMatching、そうでなければ内蔵 frontier decoder。同じ最小重さでも tie-break が異なり、B の配置が変わる可能性がある。ルール上安定しているのは minimum weight である。

### A8. 公式の版番号付き rulebook はない

公開資料は README、ゲーム内 help、コード、tests であり、release と tag はない。このため本レポートは commit `a1a3c53` に固定した。将来 main が変われば再検証が必要。

これら以外に、現在の core loop、合法操作、勝敗を左右する未解決点は見つからなかった。

## HTML への対応

| HTML セクション | 検証済みルールの対応 |
|---|---|
| まずは、やることだけ | 丸と四角、赤い inline stroke、見る・選ぶ・押す・確かめる順序 |
| 盤の見方 | 3×3 の実配置、無文字タイルの色面/halo/outline、空の丸、赤い方向線 component |
| 練習1: 赤い線で消す | 再現番号 000073 の正確な before / after、選択輪、inline 赤線 |
| 成功の中身 | 初回成功後に hidden problem、player answer、leftover の3概念を普通の言葉で説明 |
| 練習2・3 | 再現番号 0001C5 の青線、0000FA の2色交差、それぞれの正確な before / after |
| 本当の勝ちと負け | 安全/赤い縦断/青い横断/2色の交差、全消灯と成功の違い |
| 判定画面の読み方 | 560F4A の1文 outcome、設定辞書、4対3、4盤、residual flow、fairness、閉じた technical notation |
| DISCO BREAKER への提案 | source rule でない明示、決定した英語題と日本語題、80s disco repair scene、縦画面 device frame の10画面 storyboard と UI kit、床下配線の visual language、4つの campaign mechanics、11段階 visual tutorial |
| 準備と時間の流れ | 盤の一辺、発生率、再現番号、ターン・timer 不在。input quick-reference は置かない |
| こんなときは？ | cancellation、boundary、initial clear、judge gate、frozen state、stabilizer success |
| 実装されていないもの | spread、outbreak turn、cure resource、score/lives/move limit の不在 |
| どこまで確実？ | code-proven、説明用比喩、未公開 spec の区別 |

実ゲーム同様にタイル内の文字はなくしたが、色の意味はすぐ隣の本文、caption、SVG description で重ねて伝えた。操作と論理クラスは reusable stroke component の色 + 向き + 単線/交差で表し、operator letter に依存しない。

## HTML の技術仕様

- `lang="ja"`
- semantic `header`、`nav`、`main`、`section`、`footer`
- h1 1 個、各主要領域に h2
- skip link `本文へスキップ`
- native `details/summary` による補足、JavaScript 不要
- SVG に `role="img"`、`title`、`desc`
- reusable `.op-mark` は inline `<span role="img">` と日本語 `aria-label`。custom element や script は不要
- logical-path 図にも `role="img"` と operator letter を使わない日本語 `aria-label`
- visible `:focus-visible` outline
- `prefers-reduced-motion` 対応。mock 内の flicker / pulse / spin animation もすべて停止
- title screen のミラーボールは CSS 3D transform（`preserve-3d`、`perspective`、`backface-visibility`）だけで構成
- 画面 mock は CSS container query（`container-type: inline-size` と `cqw`）で縮尺。`:has()` は診断シート画面のホームバー配色にだけ使い、非対応でも内容は欠けない
- print style
- 390 px 以下を含む responsive layout
- nav は narrow mobile で意図的な横スクロール、それ以外の本文は横はみ出しなし
- system font のみ
- inline data URI favicon を含め、local render の 404 も除去
- HTML サイズ: 335,846 bytes
- SHA-256: `a332a15dc0bebc281cd6a1c1aab08f2c3b03b28d1cf5e61850ca62ae136a1bc7`

## 視覚・アクセシビリティ検証

`chrome-devtools-axi` でローカル HTTP 配信した最終 HTML を検査した。

### Desktop

- CSS viewport: 1440×1000
- document width: 1440、viewport width: 1440
- document height: 21640
- document-level horizontal overflow: なし
- 11 section、7 SVG、47 `.op-mark` instance、12 native disclosure を DevTools と parser で検査
- 判定画面の3-column settings、2-column field dictionary、2×2 board guide、5-part arrow flow を確認
- DISCO BREAKER proposal のfinal-title card、1 disco repair hero scene、10 mock screen、4-item visual language、4 campaign mechanics、11-frame tutorial を確認
- storyboard は 2026-09-17 の改訂で縦画面 phone frame の3列 reel に変更した（下の「縦画面 mock 改訂の検証」を参照）
- 赤の 45° stroke、青の -45° stroke、交差 mark の両 stroke を computed style で確認
- favicon は inline data URI で、console error は 0

### Narrow mobile

- emulated CSS viewport: 390×844、mobile、touch
- document width: 390、viewport width: 390
- document height: 38912
- `main` 配下の最大右端: 379 px、document-level horizontal overflow: なし
- 判定画面の settings、field dictionary、4 board roles、arrow flow はすべて332 pxの1列
- DISCO BREAKER のfinal-title card、disco repair scene、10 mock screen、visual language、campaign mechanics、11-frame tutorial はすべて1列。2026-09-17 改訂後の phone frame は 390 px 幅で 342 px、外側 card は 368 px
- screen inventory は折り返し、本文内に横スクロールや画面外要素を残さない
- 2 column / 3 column / 4 column content はすべて1 column 化
- BEFORE / AFTER は縦並びに変わり、状態比較、mark 説明、操作 callout も1列化
- nav 内の jump list だけが必要時に横スクロールできる設計

### Accessibility tree と keyboard

- accessibility snapshot で banner、navigation、main、11 region、contentinfo を確認
- 7 SVG、47 inline/large mark、3 logical-path 図、disco scene、party scene、2 floor board、1 reserve indicator を含む合計62個が image name または title/description を持つことを確認
- accessible name の standalone `I` / `X` / `Y` / `Z`: 0
- child-facing prose の standalone `B` / `C` / `E` / `R` / `I` / `X` / `Y` / `Z`: 0。C/B/E/R と d/p は閉じた advanced disclosure 内だけ
- 12 個の `details` が native disclosure として parse されることを確認
- skip link を focus して Enter、URL が `#main` になり本文位置へ移動することを確認
- native links と summary のため keyboard 操作に custom script は不要

### Lighthouse

最終 HTML、desktop navigation audit:

- Accessibility: 100
- Best Practices: 100
- SEO: 100
- Agentic Browsing: 100
- Passed: 50
- Failed: 0

### 縦画面 mock 改訂の検証（2026-09-17）

`chrome-devtools-axi` で `http://127.0.0.1:8765/syndromeout-rules.html` を再検査した。

- desktop 1280×900: screen reel は3列（各 phone 325 px 幅）、UI kit card は2列分。document-level horizontal overflow なし
- tablet 820×1180: 2列（375.5 px ×2）、UI kit は行いっぱい。overflow なし
- iPhone 相当 390×844×2 mobile/touch: 1列、phone 342 px 幅、画面内の基準文字 12.65 px。`scrollWidth` = `clientWidth` = 390
- Android 相当 412×915×2.6 mobile/touch: 1列、phone 364 px 幅。`scrollWidth` = `clientWidth` = 412
- 10 画面すべてで `.ph-body` の `scrollHeight - clientHeight` = 0（390 / 412 / 1280 の各幅）。つまり frame 内で切れている要素はない
- before / after の可視テキスト diff: 消えたのは旧 mock 内の UI ラベル 35 行だけで、caption・見出し・本文は同一。追加は新 mock の UI ラベル、デザイン注記、UI kit
- 提案セクションの可視テキストと `aria-label` に standalone の operator letter や `d` / `p` 記号: 0
- 各 phone は `role="group"` と日本語 `aria-label`、各盤面 SVG は `role="img"` と状態を述べる `aria-label`、装飾要素は `aria-hidden`
- Lighthouse（navigation）: mobile と desktop の両方で Accessibility 100、Best Practices 100、SEO 100、Passed 50、Failed 0。最初の run で出た `aria-prohibited-attr`（`role` のない span への `aria-label`）3 件と、診断シートの緑文字の contrast 1 件は修正済み
- `<script>` 0、外部 stylesheet 0、duplicate `id` 0、em dash 0、Python `html.parser` で parse 完了
- scenario 検証: `uv run --directory SyndromeOut/syndrome-out python` で `SurfaceCode(5)`、`Pauli`、`stabilizer_faces`、`logical_effect` を呼び、上の表の値を得た
- title screen 改訂後（2026-09-17T01:24Z / T01:27Z 反映）: 390×844×2 と 412×915×2.6 で横はみ出しなし。title の主ボタン stack は body 下端の 7 px 内側に収まる（`.ph-body` の scrollHeight 差 15 px は、傾けて振る光条レイヤーの bounding box で、`overflow: hidden` により不可視）。Lighthouse は mobile / desktop とも Accessibility 100、Failed 0。可視テキストと `aria-label` の `club` / 「クラブ」: 0

### Console と self-contained 検査

- Chrome console error: 0
- hero / state tile の textContent: すべて空
- SVG tile 内の `!` 文字: 0
- child-facing visible prose の source letter notation: 0
- accessible name の Pauli letter notation: 0
- `.op-mark` 47個すべてに `role="img"` と日本語 `aria-label`
- `<script>`: 0
- external stylesheet: 0
- duplicate `id`: 0
- em dash: 0
- 未説明の「反転」: 0
- Python `html.parser` で parse 完了

## プロジェクトへの影響

error-outbreak プロジェクトの追跡ファイルは変更していない。調査用 worktree 内で public source を clone し、成果物 2 ファイルだけを指定 data directory へ書いた。push、PR、remote 変更は行っていない。

今回の調査で、SyndromeOut 本体へ ship すべき明確な不具合は見つからなかった。README の「X error sits next to it」は数学的には parity の短縮表現だが、ゲーム内 help も入門向けの表現として同じ意図を持つため、ここでは upstream 修正提案ではなく本説明資料で補足した。
