#!/usr/bin/env python3
"""Three original, code-synthesized press sounds for the title's 「チュートリアル」
button (audition only). Python stdlib only. 48 kHz 16-bit mono PCM.

  A 「コトッ♪」  short, light, woody press: a damped wooden knock (two
                 inharmonic modes) plus a soft, low-passed noise touch.
  B 「ピコッ♪」  small, bouncy electronic blip: a sine that glides up and
                 settles, with a quiet octave.
  C 「カチッ・ポン♪」 a soft tactile click, then 45 ms later a gentle pop (a sine
                 that drops in pitch).

All are single short events (no two-note chime), so they stay distinct from
the lesson 1 success bell. Every attack is a raised-cosine ramp of at least
1 ms, every file ends with a raised-cosine fade to an exact zero, DC is
removed, and all variants are scaled to the same ungated K-weighted loudness
(BS.1770 filter) with the sample peak kept at or below -3 dBFS.

    python3 generate.py   # A_koto.wav, B_piko.wav, C_kachi_pon.wav, checks.json
"""
import json
import math
import struct
import wave

RATE = 48000
TARGET_LKFS = -22.0
PEAK_LIMIT = 10 ** (-3.0 / 20)


def ramp(t, attack):
    return 1.0 if t >= attack else 0.5 - 0.5 * math.cos(math.pi * t / attack)


def noise(count, seed):
    # Deterministic LCG white noise in [-1, 1].
    state = seed
    out = []
    for _ in range(count):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        out.append(state / 0x3FFFFFFF - 1.0)
    return out


def lowpass(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / RATE)
    y, prev = [], 0.0
    for v in x:
        prev = (1 - a) * v + a * prev
        y.append(prev)
    return y


def variant_a(total):
    # Woody knock: modes at 950 Hz and 2590 Hz (2.73x), 12 ms / 5 ms decays,
    # 1.5 ms attack, plus 5 ms of low-passed noise for the contact.
    hiss = lowpass(noise(total, 7), 3500)
    out = []
    for n in range(total):
        t = n / RATE
        env = ramp(t, 0.0015)
        v = math.sin(2 * math.pi * 950 * t) * math.exp(-t / 0.012)
        v += 0.45 * math.sin(2 * math.pi * 2590 * t) * math.exp(-t / 0.005)
        v += 0.7 * hiss[n] * math.exp(-t / 0.005)
        out.append(v * env)
    return out


def variant_b(total):
    # Bouncy blip: pitch glides 900 -> 1500 Hz in 25 ms (exponential),
    # holds briefly, 40 ms decay, quiet octave; 2 ms attack.
    out, phase = [], 0.0
    for n in range(total):
        t = n / RATE
        freq = 1500 - 600 * math.exp(-t / 0.008)
        phase += 2 * math.pi * freq / RATE
        env = ramp(t, 0.002) * math.exp(-max(0.0, t - 0.03) / 0.04)
        out.append(env * (math.sin(phase) + 0.18 * math.sin(2 * phase)))
    return out


def variant_c(total):
    # Soft click (2.5 ms band-limited noise, 1 ms attack), then at 45 ms a
    # pop: a sine dropping 1100 -> 700 Hz with a 30 ms decay and 3 ms attack.
    hiss = lowpass(noise(total, 11), 4000)
    out, phase = [], 0.0
    for n in range(total):
        t = n / RATE
        click = hiss[n] * ramp(t, 0.001) * math.exp(-t / 0.0025) * 0.9
        pop = 0.0
        tp = t - 0.045
        if tp >= 0:
            freq = 700 + 400 * math.exp(-tp / 0.015)
            phase += 2 * math.pi * freq / RATE
            pop = math.sin(phase) * ramp(tp, 0.003) * math.exp(-tp / 0.03)
        out.append(click + pop)
    return out


def finish(signal, fade):
    mean = sum(signal) / len(signal)
    signal = [v - mean for v in signal]
    n_fade = int(fade * RATE)
    total = len(signal)
    for i in range(n_fade):
        signal[total - n_fade + i] *= 0.5 + 0.5 * math.cos(math.pi * (i + 1) / n_fade)
    signal[0] = 0.0
    return signal


def biquad(x, b, a):
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        out = b[0] * v + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1, y2, y1 = x1, v, y1, out
        y[i] = out
    return y


def k_weighted_lkfs(x):
    shelf = biquad(x, (1.53512485958697, -2.69169618940638, 1.19839281085285), (1.0, -1.69065929318241, 0.73248077421585))
    hp = biquad(shelf, (1.0, -2.0, 1.0), (1.0, -1.99004745483398, 0.99007225036621))
    return -0.691 + 10 * math.log10(sum(v * v for v in hp) / len(hp))


VARIANTS = [
    ("A_koto", variant_a, 0.09, 0.03, "「コトッ♪」 light woody press: damped 950 Hz and 2590 Hz wooden modes with a 5 ms low-passed noise touch, 1.5 ms attack."),
    ("B_piko", variant_b, 0.13, 0.03, "「ピコッ♪」 small bouncy electronic blip: sine gliding 900 to 1500 Hz in about 25 ms with a quiet octave, 2 ms attack."),
    ("C_kachi_pon", variant_c, 0.17, 0.04, "「カチッ・ポン♪」 soft 2.5 ms band-limited click, then at 45 ms a gentle pop dropping 1100 to 700 Hz."),
]


def main():
    report = {"sample_rate": RATE, "target_ungated_lkfs": TARGET_LKFS, "variants": []}
    for name, make, seconds, fade, description in VARIANTS:
        total = int(seconds * RATE)
        signal = finish(make(total), fade)
        gain = 10 ** ((TARGET_LKFS - k_weighted_lkfs(signal)) / 20)
        peak = max(abs(v) for v in signal) * gain
        limited = peak > PEAK_LIMIT
        if limited:
            gain *= PEAK_LIMIT / peak
        signal = [v * gain for v in signal]
        samples = [int(round(max(-1.0, min(1.0, v)) * 32767)) for v in signal]
        with wave.open(f"{name}.wav", "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(b"".join(struct.pack("<h", s) for s in samples))
        report["variants"].append({
            "file": f"{name}.wav", "description": description, "duration_s": round(total / RATE, 3),
            "sample_peak_dbfs": round(20 * math.log10(max(abs(s) for s in samples) / 32767), 2),
            "peak_limited": limited,
            "clipped_samples": sum(1 for s in samples if abs(s) >= 32767),
            "dc_offset": round(sum(samples) / len(samples) / 32767, 7),
            "first_sample": samples[0], "last_sample": samples[-1],
            "max_step_first_1ms": max(abs(samples[i + 1] - samples[i]) for i in range(48)),
            "ungated_lkfs": round(k_weighted_lkfs(signal), 2),
        })
    with open("checks.json", "w") as out:
        json.dump(report, out, indent=2, ensure_ascii=False)
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
