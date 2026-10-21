# Testing Guide

How `mime` is tested, and how to run the suite yourself. The test strategy
mirrors what mature protocol libraries do (e.g. `moonkafka`): **RFC vectors
for encodings, byte-level golden assertions for the message structure, and
cross-verification against an independent standard implementation.**

## Three layers

### 1. Golden fixture tests (`mime/mime_test.mbt`, `mime/parse_test.mbt`)

Byte-level assertions against known-good RFC outputs:

- **RFC 4648 base64 vectors**: `Man` → `TWFu`, `Ma` → `TWE=`, `M` → `TQ==`, and the
  decode inverse back to the original bytes.
- **RFC 2045 quoted-printable**: soft line breaks (`=\r\n`), `=XX` escapes, UTF-8 byte sequences.
- **RFC 2047 encoded-word**: `=?UTF-8?B?...?=` encode *and* decode — a CJK subject
  round-trips through its encoded form and comes back identical.
- **RFC 5322 structure**: date formatting against known weekdays (Sakamoto algorithm),
  78-character header folding with exact 77/78 boundary assertions, CRLF line endings
  (zero naked LF, verified byte-by-byte).
- **Multipart**: `multipart/alternative` inside `multipart/mixed`, attachments,
  boundary markers, and `split_multipart` inverse splitting.
- **Header injection protection**: CR/LF in subject, names, custom headers and
  filenames is neutralized — the output never contains a raw injection sequence.

### 2. Robustness / edge cases (`mime/robustness_test.mbt`)

What happens at the boundaries of the protocol:

- 1200-character subjects (multi-line folding still CRLF-valid)
- Emoji, CJK, combining characters, zero-width space (all stay single-line in encoded-words)
- Empty and 100 KB attachments (base64 lines stay ≤ 76 columns)
- CRLF inside body text (base64 makes it invisible to the wire format)
- 50 recipients (To header folds and keeps every address)
- A fully-empty message (no panic)

### 3. Cross-verification against Python's stdlib (`examples/mime-demo/verify_with_python.py`)

The strongest check: `build_message` output is parsed by Python's `email` module
(strict RFC 5322 policy) and **19/19 round-trip checks pass** — headers, decoded
RFC 2047 subject, multipart nesting, base64-decoded body, attachment filename and
content. If our bytes deviated from the standard in any observable way, an
independent implementation would reject or misread them.

## Running the suite

```bash
# everything
moon test

# only the mime protocol package
moon test mime/

# benchmarks (base64 / quoted-printable / full message build)
moon bench bench/

# cross-verification with Python's standard library
moon run examples/mime-demo   # writes output.eml
python examples/mime-demo/verify_with_python.py
```

## What is intentionally not covered

- **SMTP / IMAP / POP3**: the library is message-construction only; transport
  protocols are a separate concern (the parser covers the message wire format, not
  server dialogs).
- **Exotic charsets**: encoded-words are decoded for UTF-8 (the B encoding this
  builder emits); other charsets are returned unchanged rather than guessed.
- **Full mailbox-address grammar**: `From`/`To` values are parsed as opaque header
  values, not tokenized into display-name + addr-spec (that is a parser layer above
  the wire format).

## CI

`.github/workflows/ci.yml` runs `moon check`, `moon test` and `moon build` on every
push to `main` — the 129-test suite must pass before the status badge turns green.
