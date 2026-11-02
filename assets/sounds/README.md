# Bundled sounds

`lesson1_success_bell.wav` is the success sound of lesson 1 (「赤いちらつきを直そう」). It plays once when that lesson passes (dark floor, safe inspection), together with 「いいぞ！ 赤い床のちらつきが直ったね！」. Every other lesson keeps the procedural stings in `src/reward_sound.gd`.

- Origin: original, synthesized in code for this project (no recordings, samples or third-party audio). The human chose it from three audition candidates (variant A, "bright bell") on 2026-11-02.
- Content: C6 then G6 (130 ms apart), inharmonic bell partials (1, 2, 3, 4.2, 5.4x), 4 ms raised-cosine attack, exponential decay, 80 ms fade to an exact zero; 48 kHz, 16-bit mono PCM, 0.75 s; sample peak -7.0 dBFS, no clipped samples, DC removed.
- SHA-256: `335f67f085799e8246fb18ae7dd7eb64cefeb2234fc68586acae61bb181da547`
- Reproduce: `cd tools/success_sound && python3 generate.py` (Python standard library only) writes the three candidates; `A_bright_bell.wav` is byte-identical to this file. Do not edit the WAV by hand.
- Import: `compress/mode=0` in the `.import` file keeps the PCM uncompressed, so the stream that plays is the generated samples; `tests/run_tests.gd` checks the hash and the imported data.

`title_tutorial_press.wav` is the press of the title's 「チュートリアル」 plate. It plays once for each accepted tap on that plate (entry, resume and replay from the title), never for other buttons, and not while muted.

- Origin: original, synthesized in code for this project (no recordings, samples or third-party audio). The human chose it from three audition candidates (variant A, 「コトッ♪」 short light woody press) on 2026-11-02.
- Content: damped 950 Hz and 2590 Hz wooden modes (12 / 5 ms decays) plus a 5 ms low-passed noise touch, 1.5 ms raised-cosine attack, fade to an exact zero; 48 kHz, 16-bit mono PCM, 0.09 s; sample peak -5.4 dBFS, no clipped samples, DC removed.
- SHA-256: `4d294a4c23eaa16c8c0ce12b74f7f682d936771ca530ca19d4bdbd037661636e`
- Reproduce: `cd tools/button_sound && python3 generate.py` (Python standard library only) writes the three candidates; `A_koto.wav` is byte-identical to this file. Do not edit the WAV by hand.
- Import: `compress/mode=0`, as for the bell; `tests/run_tests.gd` checks the hash and the imported data.
- Level: its player is at -4 dB, 4 dB above the other sounds' -8 dB (the human found it too quiet at -8 dB on 2026-11-02); the file itself is unchanged. With the -5.4 dBFS sample peak it peaks at about -9.4 dBFS.
