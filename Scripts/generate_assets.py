#!/usr/bin/env python3
"""Original vector artwork and deterministic, non-sampled clap synthesis. No downloads."""
import json, math, random, struct, wave
from pathlib import Path

root = Path(__file__).resolve().parents[1]
layers = root / "Design/IconLayers"
layers.mkdir(parents=True, exist_ok=True)

def svg(name, body):
    (layers / name).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">' + body + '</svg>')

svg("01-GlassBody.svg", '''<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#d1fbff" stop-opacity=".94"/><stop offset=".38" stop-color="#81c8dd" stop-opacity=".75"/><stop offset="1" stop-color="#337590" stop-opacity=".92"/></linearGradient></defs><rect x="205" y="425" width="630" height="355" rx="56" fill="url(#g)" stroke="#e8feff" stroke-width="9"/><path d="M232 510H808M236 679H802M422 533V654M622 533V654" fill="none" stroke="#17435b" stroke-opacity=".62" stroke-width="9"/><path d="M250 708H564M250 739H438" stroke="#ddfaff" stroke-opacity=".75" stroke-width="10" stroke-linecap="round"/>''')

def stick(x, y, w, h, rotate=""):
    stripes = ''.join(f'<path d="M{xx} {y}h62l{-h*.6} {h}h-62z" fill="#f8fbff"/>' for xx in range(x-100,x+w+150,126))
    return f'<defs><clipPath id="clip"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14"/></clipPath></defs><g {rotate}><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="#10202e"/><g clip-path="url(#clip)">{stripes}</g><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="none" stroke="#dff9ff" stroke-width="6"/></g>'

svg("02-LowerStripes.svg", stick(205, 421, 630, 73))
svg("03-UpperClapper.svg", stick(205, 321, 630, 92, 'transform="rotate(-13 220 413)"'))
svg("04-Hinge.svg", '''<defs><linearGradient id="m" x2="1" y2="1"><stop stop-color="#d8eaf3"/><stop offset="1" stop-color="#536c82"/></linearGradient></defs><rect x="208" y="342" width="62" height="158" rx="15" fill="url(#m)" stroke="#f1fbff" stroke-width="5"/><circle cx="239" cy="373" r="10" fill="#1b3347"/><circle cx="239" cy="466" r="10" fill="#1b3347"/>''')

random.seed(10421)
rate, seconds = 48000, 0.24
samples = []
for i in range(int(rate * seconds)):
    t = i / rate
    attack = min(1, t / .0007)
    noise = random.uniform(-1, 1)
    click = noise * math.exp(-t * 115) * .64
    wood = (math.sin(2*math.pi*1350*t) * .22 + math.sin(2*math.pi*2180*t) * .14) * math.exp(-t*65)
    tail = noise * math.exp(-t*32) * .07
    signal = max(-.95, min(.95, attack * (click + wood + tail)))
    samples.append(int(signal * 32767))
audio = root / "GlassSlate/Resources/default-clap.wav"
with wave.open(str(audio), 'wb') as file:
    file.setnchannels(1); file.setsampwidth(2); file.setframerate(rate)
    file.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
print(f"Created 4 original SVG layers and {len(samples)/rate:.2f}s PCM WAV")
