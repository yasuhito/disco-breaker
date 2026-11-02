# Bundled sounds

`lesson1_success_bell.wav` is the success sound of lesson 1 (「赤いちらつきを直そう」). It plays once when that lesson passes (dark floor, safe inspection), together with 「いいぞ！ 赤い床のちらつきが直ったね！」. Every other lesson keeps the procedural stings in `src/reward_sound.gd`.

- Origin: original, synthesized in code for this project (no recordings, samples or third-party audio). The human chose it from three audition candidates (variant A, "bright bell") on 2026-11-02.
- Content: C6 then G6 (130 ms apart), inharmonic bell partials (1, 2, 3, 4.2, 5.4x), 4 ms raised-cosine attack, exponential decay, 80 ms fade to an exact zero; 48 kHz, 16-bit mono PCM, 0.75 s; sample peak -7.0 dBFS, no clipped samples, DC removed.
- SHA-256: `335f67f085799e8246fb18ae7dd7eb64cefeb2234fc68586acae61bb181da547`
- Reproduce: `cd tools/success_sound && python3 generate.py` (Python standard library only) writes the three candidates; `A_bright_bell.wav` is byte-identical to this file. Do not edit the WAV by hand.
- Import: `compress/mode=0` in the `.import` file keeps the PCM uncompressed, so the stream that plays is the generated samples; `tests/run_tests.gd` checks the hash and the imported data.
