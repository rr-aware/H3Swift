# Extended engine implementation

This is a local extension of the vendored H3 C engine. It is not an upstream H3
index format or an assertion of interoperability at resolutions above 15.

`lib/*.c` compile the original source files a second time with `H3_EXTENDED` enabled.
They contain no duplicate algorithm implementations. `namespace.h` isolates every
external C symbol (including internal helpers and global tables), so standard and
extended engines can coexist in one process. The public bridge exposes only cells
and uses two 64-bit words, never `__uint128_t`, across the Swift/C boundary.

## Version 1 encoding

The internal unsigned 128-bit value has the following bit layout, numbered from
least significant bit zero. Bits 77...127 must be zero.

| Bits | Meaning |
| --- | --- |
| 0...56 | Nineteen 3-bit digits, resolution 19 at bits 0...2 |
| 57...63 | Base cell, 0...121 |
| 64...68 | Resolution, 0...19 |
| 69...71 | Reserved; zero for cells |
| 72...75 | Mode; 1 for cells |
| 76 | High bit; zero |

Used digits must be 0...6; unused digits must be 7. Pentagon deleted subsequences
are rejected. `H3ExtendedIndex.high` is bits 64...127 and `.low` is bits 0...63.
The Swift wire format is `h3x1:` followed by the lowercase hexadecimal value without
leading zeroes. The parser accepts either case in hex digits, rejects trailing data
and embedded NULs, validates the full cell, and requires the version prefix.
`Codable` uses this string, avoiding precision loss in JSON consumers.

## Geometry and range changes

- Maximum resolution 19; substrate tables extend through resolution 20.
- Extended IJK coordinates and arithmetic use 64-bit intermediates: pentagon
  substrate transforms at resolution 19 overflow 32-bit integers.
- Fine-resolution projection uses a stable chord-to-angle calculation near face
  centers and a Cartesian rotation near poles. Legacy resolutions retain the
  original projection path, including the resolution-15 boundary substrate.
- The power helper avoids its unused final square, which overflows when computing
  powers required by the new resolutions even though the result fits in `Int64`.
- The maximum-resolution cell count is 1,367,867,422,244,777,162. Disk-size arithmetic
  caps at this value before multiplication can overflow.
- Private statistics above 15 extrapolate aperture-7 ratios; private polyfill
  bounds extend the edge table and compute pole indexes at the requested resolution.
  These private polygon/statistics APIs are not part of the supported Swift bridge.

The public bridge validates cells before passing untrusted indexes to internal
geometry functions. Hierarchy enumeration is real H3 digit subdivision, including
pentagons; the four extra levels are not application-side aliases for level 15.

## Upstream updates

When adding/removing upstream source files, update the thin `lib/` wrappers and
regenerate `namespace.h` using `python3 scripts/update-extended-namespace.py` on
macOS. The generator builds only `CH3` and reads its defined external symbols.
Review the diff, especially any new assumptions about bit widths or resolutions.
Never expose the private extended `h3api.h` as the standard C module.

Run `swift test` and `scripts/test-extended-c.sh`. Swift tests cover legacy indexes,
all twenty levels, 15-to-19 descendants, all twelve pentagons, worldwide locations,
face centers, cell scale, serialization, and rejected inputs. The sanitizer harness
covers base-cell centers and neighbors, pentagons, 10,000 deterministic geographic
samples including near-pole points, buffer limits, and disk-size overflow limits.
