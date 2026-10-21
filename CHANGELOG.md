# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-10-21

### Added

- **RFC 5322 message parser** (`mime/parse.mbt`) — the inverse of `build_message`:
  - `parse_headers` — header block parsing with continuation-line unfolding
  - `get_header` — case-insensitive field lookup
  - `base64_decode_string` — RFC 4648 base64 decoding (line breaks ignored)
  - `quoted_printable_decode_string` — RFC 2045 QP decoding (soft breaks removed)
  - `decode_encoded_word` — RFC 2047 encoded-word decoding (B encoding)
  - `split_multipart` — MIME boundary splitting
- **Parser round-trip tests** (21 new, 129 project-wide): build → parse → identical
  fields, including a CJK subject decoded back from its RFC 2047 form, RFC base64/QP
  vectors, folded-header unfolding, and multipart splitting

## [0.1.0] - 2026-10-21

### Added

- **RFC 5322 MIME message builder** (`mime/`):
  - Headers with strict CRLF line endings (zero naked LF, byte-verified)
  - 78-character header folding (CRLF + space continuation)
  - RFC 5322 date formatting (Sakamoto day-of-week, timezone offsets)
  - Mailbox / Message types with To / Cc / Bcc recipient lists
- **RFC 2045 content-transfer encodings**:
  - Base64 with RFC 2045 76-column wrapping for MIME bodies
  - Quoted-printable with CRLF soft breaks
- **RFC 2047 encoded-word** (B encoding) for non-ASCII headers, kept single-line
- **Multipart nesting**: multipart/alternative (text+html) inside multipart/mixed, auto-generated boundaries
- **Attachments**: binary payload base64 encoding + Content-Disposition
- **Custom headers**: X-*, List-Unsubscribe, etc.
- **Header injection protection**: `sanitize_header_value` / `has_injection_chars`
- **WebAssembly Component Model interface** (`wit/mime.wit`) + build walkthrough (`examples/wasm-component/`)
- **Example layer** (`content-tools/`): content-orchestration demo built on `mime` (core / dsl / gates / links / render / qa / retro)
- **Tests**: 108 project-wide — golden fixtures, robustness/edge cases, plus Python `email.mime` cross-verification (19/19 checks)
- **Benchmarks**: `moon bench bench/` — base64 / quoted-printable / full message build

### Changed

- None (initial release).

### Fixed

- None (initial release).

[0.2.0]: https://github.com/mw1696803-hub/mooncampaign/releases/tag/v0.2.0
[0.1.0]: https://github.com/mw1696803-hub/mooncampaign/releases/tag/v0.1.0
