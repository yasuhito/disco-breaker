# Task
## Captain's intent
で、その調べとは別に、syndrome out のルールを子供でもわかるようにビジュアルに html にまとめてほしい。ぼくもルールをまだ理解してないから。

もうちょっと順を追って説明できないか？ 反転とかがわかりにくい。たとえばチュートリアルを作るとしたらこう、という意識で書き直し。

元のゲームでは、丸いボタンに置く X, Z, Y が文字ではなく、うまく視覚化されていたと思う。もう一度ソースコードを確認してビジュアルをアップデートして

元のゲームでは、赤い床に X! という文字は表示されていなかったと思う。元のソースコードを確認し、どういう視覚表現になっていたか確認し、この html を更新して。

本文中に X や Y などパウリの表現は一切使わないこと。ゲーム内の斜め線は custom element などで部品化して、文中にインラインできるようにすると文中でスムースに説明できると思う。べつに custom element を使わずに実現できるならそれでもよい。ベストな方法をえらんで

えっと、シンドロームワードですけど、ジャッジをした後の画面が、さっぱりわかんないんですけど、 まあその、 not optimalっていうのはなんか理解したんだけども、この画面をもって何を読み取ればいいんですかね、結局。 なんか、サクセスとnot optimalで、ボットがサクセス。結局これは何なのか、ゲームとして成り立っているのかも含めて、どういう意味合いを持てればいいか教えてください。

あとは、さっきの画面なんですけど、d=5、dって多分、なんだっけ、なんとか距離だと思うんだけども、dの説明もないし、p=0.10、pの説明もないですよね。 だから、全然全くわかんないと思うんですね。rとか、rとかeとか、bとかcとか。 で、これの画面の説明は脇に置いといて、今回作ろうとしている改良版のゲームでは、どうなるべきかっていうのも図解のHTMLに書いてください。 で、できれば、チュートリアル、新しく作るとしたらチュートリアルも含めて、どうすべきかっていうところまで、図解のHTMLに書いてください。

「入力の早見表」のセクションはいりません。操作方法は理解しているので、この HTML には入れなくて OK

Error outbreak のセクションは、簡易的でもいいのでタイトル画面、チュートリアル画面、実際の画面、judge 画面など、想定される画面をすべてビジュアルに説明してもらえますか。せっかく HTML を使っているのに文章で説明するのはもったいない。どういう視覚化で表面符号をゲームとしてわかりやすくするか、また error outbreak は syndrome out よりゲーム性が高くなるようにしてほしい。

「小さな合図から、見えない経路を封じこめる」これ、合図、見えない経路について何を指しているかさっぱりわからない。

ゲームのルールはだいたい理解したので、/ や \、X などの斜め線、そして量子ビットをあらわす丸が自然と理解できるような、アナロジーはないだろうか。今は病棟を使っているが、病棟の床が赤くなったり青くなったりというのがいまいちわからない。もっと自然に理解できるアナロジーを 3-5 個考えて

たとえば、床が光る → ディスコという案もあるよね。

えっとエラーアウトブレイクについては すごくいい案を思いつきました。で、テーマはですね 80年代ディスコの世界で ディスコの光る床があるじゃないですか、サタデーナイトフィーバーとかの。 あの光る床が壊れていると。で、それを修理する 人の大工さんかな、電気工事士かな その人のゲームにしましょう。 まずですね、昔のディスコって床がこう光っているんだけど でなんか、蛍光灯みたいにちょっとチカチカする 床の一部が赤でチカチカしたり青でチカチカしたりして うまくこう、床の光る演出が動かないので、他の床は真っ暗ね。 で、そのチカチカする床を、ちょうどその交差点のところには 要は量子ビットを表しているところに 配線をつなぎ直して消すと、うまく消すと いうゲームに、チカチカを消すというゲームにしたいと思います。 で、チカチカを消した後に必ずその電気工の人は 親方に確認してもらうんですね。 それがその元のゲームでいうジャッジの部分で で、親方がそのOKって言ったりダメって言ったりするっていうのはどうですか? で、ディスコにすることによって演出もいろいろ良くできて 修理中はですね、そこのディスコに来ているお客さんは 踊れないから、その四隅、四隅じゃないな、壁側に立って なんかざわざわして修理を待っているんですよね。 壁側、四つの壁に壁側に立ってなんかざわざわしてて、その修理を見てると。 で、DJが中央上側にいるんだけど、それもなんか音楽かけるのを止まってるんですよ。 で、修理が終わって、で、親方に見てもらって サクセスだったらまた床がですね、いろんな色のパターンで光りだして 人もフロアに戻って踊り出すと。で80年代なんで なんでしょう、ブレイクダンスをする人もいれば いろんな音楽のジャンルがありますよね。 なんだっけ、ディスクの時って80年代ってニューエナジーとか それによって踊り方が変わったりとかですね BGMも変わるヒップホップだったり ヒップホップだったらなんかそういう系の スピンをしたりダンスをしたりするし もう踊り方も変わるし、それで 成功した時の成功感の演出っていうのが大事なので もうさっき言ったみたいに床が光って、パターンで光って DJが音楽をかけ出して、でミラーボールくるくる回転してやったみたいな感じにする っていうのがいいと思います。どうでしょうか?

はい、お願いします。あとはですね、そのエラーアウトブレイクっていうのも名前を変えた方がいいと思うんですけども、名前何がいいですか? 何かいくつか案を欲しいんですけども、一番なんかウケそうなのは、日本語訳した場合にディスコの床修理、ディスコの床修理なんていうタイトルのゲームないし、直訳っぽくて面白いと思うんですけど、まその英語で言った時にかっこよくて、日本語にした時になんかダサいみたいなやつがいいと思います。

ブレーカー係ってなに？

disco breaker かっこいいと思うけど

では、ゲームの名前は「Disko Breaker」で決定にしましょう。 で、リポジトリの名前もDisko Breakerに変更してください。

いや、disco breaker で

それで、そのHTMLのデザインの画面案について、 文章とかはそのままでいいんですけど、画面の案はどうしてもコデックスで作るとデザインがあまりうまくないので、 アンソロピックのモデルで、画面デザインについてはすべてやり直してもらえますか。 一応iPhoneとかAndroidの縦画面を想定しているので、 縦画面のサイズに合うように、アンソロピックのモデルで、画面デザインだけはアンソロピックのモデルを使うようにしてやり直してもらえますか。

## Firstmate spec
Create a separate, self-contained Japanese visual explainer for SyndromeOut's actual rules, based on its current public source code and first-party repository material. Reconstruct the rules before designing the explanation: setup, board/state, player actions, turn or timing order, legal/illegal moves, spread or outbreak mechanics, containment/cure mechanics, scoring, win/loss conditions, and edge cases. Distinguish code-proven facts from inference and surface any unresolved ambiguity instead of inventing rules. The audience is a child and an adult who has never played: use short sentences, original diagrams, color plus shape/icon encoding, concrete before/after examples, and a guided sample turn. Make the HTML responsive, keyboard-readable, accessible, and self-contained with no external runtime dependencies. Do not copy project artwork or protected Dr. Mario presentation. Validate the rendered page visually at desktop and narrow mobile widths with chrome-devtools-axi, fixing clipping, density, contrast, and confusing hierarchy. Host a Lavish review loop if available and stay alive for captain iteration. This is knowledge-only and must not modify the error-outbreak project.
