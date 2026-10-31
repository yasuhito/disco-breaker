# Bundled fonts

- Roboto Regular/Bold: SIL Open Font License 1.1, `OFL.txt`. Retained for the existing wordmark artwork.
- Noto Sans CJK JP Regular 2.004: copyright 2014-2021 Adobe (http://www.adobe.com/), SIL Open Font License 1.1, `NotoSansJP-OFL.txt`. Japanese UI uses this local font, with a Godot FontVariation for slightly heavier headings. No system fallback or network font is required.

`NotoSansJP-Regular.otf` is the Japanese face (index 0) of Noto Sans CJK Regular, subset with FontTools to retain Latin, Japanese kana/kanji, punctuation and symbols rather than bundling the five-region collection. The source is the Arch Linux `noto-fonts-cjk` package's `/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc` (upstream: https://github.com/notofonts/noto-cjk).

Reproduce with:

```sh
pyftsubset /usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc \
  --font-number=0 \
  --unicodes='U+0000-00FF,U+2000-206F,U+2190-22FF,U+3000-30FF,U+31F0-31FF,U+3400-9FFF,U+FF00-FFEF' \
  --output-file=assets/fonts/NotoSansJP-Regular.otf
```
