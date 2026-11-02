#!/usr/bin/env python3
"""Three original, code-synthesized rising two-note success sounds ("ピンポン♪")
for audition only. Python stdlib only (math, wave, struct, json).

Each variant is two notes a perfect fifth apart (rising), with a soft attack,
an exponential decay and an 80 ms raised-cosine fade to exact silence. Every
render is band-limited by construction (sums of sines below 20 kHz), has its DC
removed and is scaled so that its K-weighted loudness (ITU-R BS.1770 filter,
computed here, ungated over the whole sound) matches the others, with the
sample peak kept below -3 dBFS.

    python3 generate.py            # writes A_bright_bell.wav, B_playful_game.wav,
                                   # C_gentle_marimba.wav and checks.json
"""
import json
import math
import struct
import wave

RATE = 48000
TARGET_LKFS = -20.0      # ungated K-weighted loudness, the same for every variant
PEAK_LIMIT = 10 ** (-3.0 / 20)


def note(freq, start, length, partials, attack, total, decay_scale=1.0):
    """partials: (frequency ratio, amplitude, decay time constant s)."""
    out = [0.0] * total
    first = int(start * RATE)
    count = min(total - first, int(length * RATE))
    for ratio, amp, tau in partials:
        f = freq * ratio
        if f >= 20000:
            continue
        w = 2 * math.pi * f / RATE
        k = 1.0 / (tau * decay_scale * RATE)
        for n in range(count):
            t = n / RATE
            env = math.exp(-n * k)
            if t < attack:  # raised-cosine attack: no click
                env *= 0.5 - 0.5 * math.cos(math.pi * t / attack)
            out[first + n] += amp * env * math.sin(w * n)
    return out


def mix(*tracks):
    return [sum(v) for v in zip(*tracks)]


def finish(signal, fade=0.08):
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
    # BS.1770-4 K-weighting coefficients at 48 kHz.
    shelf = biquad(x, (1.53512485958697, -2.69169618940638, 1.19839281085285), (1.0, -1.69065929318241, 0.73248077421585))
    hp = biquad(shelf, (1.0, -2.0, 1.0), (1.0, -1.99004745483398, 0.99007225036621))
    power = sum(v * v for v in hp) / len(hp)
    return -0.691 + 10 * math.log10(power)


def variant_a(total):
    # Bright bell: inharmonic bell-like partials (1, 2.0, 3.0, 4.2, 5.4),
    # high register C6 -> G6, quick shimmer decay.
    partials = [(1.0, 1.0, 0.17), (2.0, 0.45, 0.11), (3.0, 0.22, 0.07), (4.2, 0.14, 0.05), (5.4, 0.08, 0.035)]
    return mix(note(1046.50, 0.00, 0.75, partials, 0.004, total), note(1567.98, 0.13, 0.75, partials, 0.004, total, 1.15))


def variant_b(total):
    # Playful clean game-like: band-limited square-ish tone (odd harmonics 1/k
    # up to the 9th) E5 -> B5, short sustain then a quick decay.
    partials = [(k, 1.0 / k, 0.13) for k in (1, 3, 5, 7, 9)]
    return mix(note(659.26, 0.00, 0.60, partials, 0.006, total), note(987.77, 0.11, 0.60, partials, 0.006, total, 1.15))


def variant_c(total):
    # Gentle woody marimba: fundamental plus the marimba-like 3.93 and 10.6
    # overtones that die fast, G5 -> D6, slightly slower 8 ms mallet attack.
    partials = [(1.0, 1.0, 0.15), (3.93, 0.30, 0.025), (10.6, 0.06, 0.008)]
    return mix(note(783.99, 0.00, 0.75, partials, 0.008, total), note(1174.66, 0.14, 0.75, partials, 0.008, total, 1.2))


VARIANTS = [
    ("A_bright_bell", variant_a, 0.75, "Bright bell: C6 then G6 (130 ms apart), inharmonic bell partials, 4 ms attack, shimmering decay."),
    ("B_playful_game", variant_b, 0.60, "Playful clean game-like: E5 then B5 (110 ms apart), band-limited square-ish tone (odd harmonics to the 9th), 6 ms attack."),
    ("C_gentle_marimba", variant_c, 0.75, "Gentle woody marimba: G5 then D6 (140 ms apart), fundamental with fast-dying 3.93x and 10.6x overtones, 8 ms mallet attack."),
]


def main():
    report = {"sample_rate": RATE, "target_ungated_lkfs": TARGET_LKFS, "variants": []}
    for name, make, seconds, description in VARIANTS:
        total = int(seconds * RATE)
        signal = finish(make(total))
        gain = 10 ** ((TARGET_LKFS - k_weighted_lkfs(signal)) / 20)
        peak = max(abs(v) for v in signal) * gain
        if peak > PEAK_LIMIT:
            gain *= PEAK_LIMIT / peak
        signal = [v * gain for v in signal]
        frames = b"".join(struct.pack("<h", int(round(max(-1.0, min(1.0, v)) * 32767))) for v in signal)
        with wave.open(f"{name}.wav", "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(frames)
        samples = [int(round(max(-1.0, min(1.0, v)) * 32767)) for v in signal]
        report["variants"].append({
            "file": f"{name}.wav", "description": description, "duration_s": round(total / RATE, 3),
            "sample_peak_dbfs": round(20 * math.log10(max(abs(s) for s in samples) / 32767), 2),
            "clipped_samples": sum(1 for s in samples if abs(s) >= 32767),
            "dc_offset": round(sum(samples) / len(samples) / 32767, 7),
            "first_sample": samples[0], "last_sample": samples[-1],
            "max_step_first_1ms": max(abs(samples[i + 1] - samples[i]) for i in range(48)),
            "ungated_lkfs": round(k_weighted_lkfs(signal), 2),
            "level_at_fade_start_db_re_peak": round(20 * math.log10(max(abs(v) for v in signal[total - int(0.08 * RATE) - 480: total - int(0.08 * RATE)]) / max(abs(v) for v in signal)), 1),
        })
    with open("checks.json", "w") as out:
        json.dump(report, out, indent=2, ensure_ascii=False)
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
