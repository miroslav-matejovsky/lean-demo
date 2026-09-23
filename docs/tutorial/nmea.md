# 04 - AIS on the wire

Proofs about real protocol code. Every AIS message on a serial line or a UDP
feed looks like this:

```text
!AIVDM,1,1,,B,177KQJ5000G?tO`K>RA1wUbN0TKH,0*5C
```

Two small algorithms matter:

- the **checksum** after `*` is the XOR of every character between `!` and `*`,
- the **payload** uses 6-bit armoring: one character carries 6 bits.

Build this lesson alone:

```powershell
cd lean; lake build Tutorial.Nmea
```

```lean
--8<-- "lean/Tutorial/Nmea.lean"
```

## What to take away

**Proofs expose weaknesses, not only strengths.**
`detects_single_change` proves that any single corrupted character is caught.
`misses_transposition` proves that swapped characters are *never* caught, and
`misses_double_change` shows two errors cancelling out. Both are facts about
the NMEA 0183 design. A test suite that passes tells you none of this.

**Finite domains are proven by exhaustion.**
`unarmor_armor` checks all 64 values with `decide`. The kernel re-checks the
computation, so this counts as a proof. It is cheap and convincing for small
lookup tables, codecs and enum mappings.

**`#guard` turns examples into build failures.**
The field decoder is checked against a known sentence: MMSI 477553000, moored,
near Seattle. If a refactoring breaks the decoder, `lake build` fails.

!!! question "Exercise"
    Prove that the checksum of a sentence with a correct `*hh` suffix does not
    depend on the suffix: `body` stops at `*`. Then write `field` for a signed
    rate of turn (8 bits at offset 42) and `#guard` it on the example payload.
