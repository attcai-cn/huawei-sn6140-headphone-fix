# Huawei YTG-XXX / 擎云G540 Gen2 (Conexant SN6140) — headphone jack fix

擎云G540 Gen2 耳机孔在Linux下不识别修复补丁

Headphone jack is silent / not detected on Linux. This directory contains both a
ready-to-use workaround and a kernel patch suitable for upstream submission.

## Hardware

| Item | Value |
|---|---|
| System | HUAWEI `YTG-XXX` / `M1010` / board `YTG-XXX-PCB` |
| Audio controller | Intel Raptor Lake-P/U/H cAVS `8086:51ca` |
| Codec | Conexant SN6140, vendor `0x14f11f87`, subsystem `0x19e53e6d`, address 0 |
| Driver stack | SOF + ASoC (`snd_soc_skl_hda_dsp`, `snd_soc_hdac_hda`) |

## Root cause

The BIOS marks pin **NID 0x18** as `[N/A]`:

```
Node 0x18 [Pin Complex]
  Pincap     0x0001133c: IN OUT HP EAPD Detect
  Pin Default 0x40f001f0: [N/A] Other at Ext N/A
  Pin-ctls   0xc0: OUT HP VREF_HIZ
```

Because of that the codec parser reports `hp_outs=0`:

```
snd_hda_codec_conexant ehdaudio0D0: autoconfig for SN6140: line_outs=1 (0x17/0x0/0x0/0x0/0x0) type:speaker
snd_hda_codec_conexant ehdaudio0D0:    hp_outs=0 (0x0/0x0/0x0/0x0/0x0)
```

No `Headphones` output is created, and audio only ever goes to the internal
speakers.

The jack itself is present and wired to 0x18. Verified by reading the pin sense
register directly while plugging/unplugging headphones:

```
hda-verb /dev/snd/hwC0D0 0x18 0x0f09 0   # GET_PIN_SENSE
  plugged    -> 0x80000000   (presence bit set)
  unplugged  -> 0x00000000
```

## Fix

Override the pin default config of NID 0x18 to `0x03211020`
(HP Out, jack, 1/8", black, association 2) and enable `auto_mute`, so the
speaker is muted while headphones are plugged in.

This is the same fix that was accepted upstream for subsystem `0x19e5:0x3289`
(another Huawei MateBook with the same codec), but the quirk does not match this
machine because its subsystem ID is `0x19e5:0x3e6d`.

## Files

| File | Purpose |
|---|---|
| `hda-jack-retask.fw` | HD-audio firmware patch applied at codec probe |
| `hda-jack-retask.conf` | modprobe option wiring the firmware patch into SOF |
| `hda-jack-retask.initramfs-hook` | makes sure the firmware is in the initramfs |
| `install.sh` / `uninstall.sh` | install / roll back the workaround (root) |
| `0001-...-quirk-for-Huawei-MateBook-YTG-XXX.patch` | minimal kernel patch on top of upstream `d152afd1cd7a6` |
| `0002-...-pin-quirk-standalone.patch` | self-contained kernel patch for kernels without that commit |
| `evidence/` | codec dump, mixer state and summary captured before the fix |

## Workaround (no kernel rebuild) 安装步骤

```sh
sudo ./install.sh
sudo reboot
```

How it works: `snd_soc_hdac_hda` (used by SOF to drive HDA codecs) has a
`patch` module option whose array index is the codec address. The option loads
`/lib/firmware/hda-jack-retask.fw` before the codec is configured, which is the
same mechanism `hdajackretask` uses ("Early Patching" in the kernel docs).

Note: the section name is `[hint]` (singular) per
`Documentation/sound/hd-audio/notes.rst`. The kernel also accepts `[hints]`.

### Verify after reboot 验证

```sh
dmesg | grep hp_outs
# expect: hp_outs=1 (0x18/0x0/0x0/0x0/0x0)

amixer -c0 controls | grep -i headphone
# expect: 'Headphone Playback Switch' / 'Headphone Playback Volume'
#         and a 'Headphone Jack' card control

pactl list sinks | grep -i headphone
```

Then plug in headphones: the internal speaker should mute automatically and
audio should come out of the headphones.

### Roll back 回退

```sh
sudo ./uninstall.sh
sudo reboot
```

## Kernel patch

Build-tested form is in the two `.patch` files. Fill in your name/e-mail in the
`Signed-off-by:` line before sending it.

- Use `0001-...` if the tree already contains `CXT_FIXUP_HUAWEI_MATEBOOK_HP`
  (mainline since commit `d152afd1cd7a6`, Aug 2026). It only adds the quirk
  entry for the new subsystem ID.
- Use `0002-...` for older/stable trees such as `7.2.13-x64v3-xanmod1`, which
  does not contain that commit yet.

Send to `alsa-devel@alsa-project.org` (Cc `tiwai@suse.de`), with the codec dump
from `evidence/` attached.

## References

- SOF issue #10687 — *Headphone jack (Pin 0x18) not detected on Huawei Matebook
  (Conexant SN6140)*: <https://github.com/thesofproject/sof/issues/10687>
- Upstream commit `d152afd1cd7a6` — *ALSA: hda/conexant: Add pin config quirk for
  Huawei Matebook*: matches `0x19e5:0x3289`, pins `{ 0x18, 0x03211020 }`
- Launchpad #2055135 — Huawei MateBook `19e5:3e5f`, SN6140, same codec family
- Kernel docs, *Early Patching*: <https://docs.kernel.org/sound/hd-audio/notes.html>
