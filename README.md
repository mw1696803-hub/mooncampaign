# mooncampaign

**RFC 5322 / MIME email message builder for MoonBit.**

Protocol-level MIME serialization: turn structured email data into standard-compliant bytes, ready for SMTP delivery. Compiles to Wasm — runnable in browsers, edge functions, or any MoonBit runtime.

> This is a **protocol implementation / foundational library**, not a specific product. It implements the MIME standard (RFC 5322 / 2045 / 2046 / 2047) so that any MoonBit project needing to construct email messages doesn't have to re-implement it from scratch.

## Repository layout

```
mooncampaign/
├── mime/                 ← main package: RFC 5322 MIME message builder
├── content-tools/        ← example layer: content orchestration built on top of mime
│   ├── core/             (Campaign/Issue/Block domain model, gates, QA)
│   ├── dsl/  gates/  links/  render/  qa/  retro/
├── cmd/main/             CLI entry point
└── examples/
    ├── mime-demo/        build a message with attachment + Chinese subject
    └── fictional-brand-demo/  content-tools usage demo
```

`mime` is the deliverable: a standalone, reusable protocol library. `content-tools` demonstrates one application of MIME message construction (a newsletter content pipeline) — it depends on `mime` and shows how the library is used in practice.

## What `mime` does

Builds a complete RFC-compliant email message from simple struct inputs:

```
From / To / Cc / Bcc / Subject / Date / Message-ID / custom headers
Content-Type: multipart/mixed; boundary="..."
  ├── multipart/alternative
  │   ├── text/plain part  (base64 or quoted-printable)
  │   └── text/html part   (base64)
  └── attachment part      (base64, Content-Disposition: attachment)
```

## Standards implemented

| RFC | What | Status |
|---|---|---|
| RFC 5322 | Internet Message Format (headers, folding, date format) | ✅ |
| RFC 2045 | MIME Part One (Content-Transfer-Encoding) | ✅ base64 + quoted-printable |
| RFC 2046 | MIME Part Two (multipart boundaries, nesting) | ✅ multipart/alternative + mixed |
| RFC 2047 | MIME Part Three (non-ASCII headers) | ✅ encoded-word (B encoding) |
| RFC 4648 | Base64 alphabet | ✅ |

## Ecosystem gap (mooncakes.io, Oct 2026)

No existing package implements MIME message construction. We fill this gap:

| Layer | Existing packages |
|---|---|
| HTML parsing | `moonbit-community/html` |
| Template engines | `moontemplate`, `mold` |
| **MIME message builder** | **❌ missing → this package** |

## Usage

```moonbit
let msg : Message = {
  from: { name: "Freshcia", email: "hello@freshcia.com" },
  to: [{ name: "Alice", email: "alice@example.com" }],
  cc: [],
  bcc: [],
  subject: "欢迎使用 Freshcia 手霜",     // non-ASCII → RFC 2047 auto-encoded
  date: format_rfc5322_date(2026, 10, 15, 12, 0, 0, 480),
  message_id: "<abc123@freshcia.com>",
  text_body: "Hello World",
  html_body: "<p>Hello World</p>",
  attachments: [{ filename: "catalog.pdf", content_type: "application/pdf", data: pdf_bytes }],
  extra_headers: [("List-Unsubscribe", "<https://freshcia.com/unsub>")],
}
let bytes = build_message(msg)
// → complete RFC 5322 message, ready for SMTP
```

Try the live demo:

```
moon run examples/mime-demo
```

## Benchmarks against other ecosystems

| Language | Library | Equivalent |
|---|---|---|
| Python (stdlib) | `email.mime` | MIME message construction |
| Node.js | `nodemailer` | MIME message construction |
| Rust | `lettre` | MIME message construction |
| **MoonBit** | **mooncampaign/mime** | **this package** |

## WebAssembly Component

`mime` is a pure, I/O-free protocol library, so it compiles to a **WebAssembly component** (Component Model) that any host runtime (Spin, Wasmtime, Wasmer) can consume directly — the direction MoonBit officially promotes (WIT + wit-bindgen, now in the Bytecode Alliance's official guide).

- Interface definition: [`wit/mime.wit`](wit/mime.wit) — `build-message`, `base64-encode`, `quoted-printable-encode`
- Build & consume walkthrough: [`examples/wasm-component/README.md`](examples/wasm-component/README.md)
- Stub forwarding example: [`examples/wasm-component/stub-forward-example.mbt`](examples/wasm-component/stub-forward-example.mbt)

```bash
wit-bindgen moonbit wit/mime.wit --out-dir wasm-component
moon build --target wasm
wasm-tools component embed wit _build/wasm/release/build/gen/gen.wasm \
  --encoding utf16 --output mime.wasm
wasm-tools component new mime.wasm --output mime.component.wasm
wasmtime run --invoke 'base64-encode("Hello")' mime.component.wasm
# SGVsbG8=
```

## Testing

1. **Golden fixture tests** (byte-level, 108 tests project-wide):
   - Base64 vectors (RFC 4648: `Man` → `TWFu`, `Ma` → `TWE=`, `M` → `TQ==`)
   - Quoted-printable encoding (RFC 2045: soft line breaks at 76 chars)
   - RFC 2047 encoded-word for non-ASCII headers
   - RFC 5322 date formatting (day-of-week computation, timezone offsets)
   - Multipart nesting (alternative inside mixed), attachments, multiple recipients
   - Custom headers, header folding
   - **CRLF line endings** (RFC 5322 compliance: zero naked LF in output)
   - **Header injection protection** (CR/LF in subject / names / values neutralized)
   - **Robustness/edge cases**: 1200-char subjects, emoji/CJK/combining/zero-width Unicode,
     empty and 100 KB attachments, CRLF in bodies, 50 recipients, exact folding/wrap boundaries

2. **Cross-verification against Python's standard library** (`examples/mime-demo/verify_with_python.py`):
   The output of `build_message` is parsed by Python `email` (strict RFC 5322 policy) and every field is checked for round-trip fidelity: headers, decoded RFC 2047 subject, multipart structure, base64-decoded body, attachment filename + content. **19/19 checks pass.**

## Performance

`moon bench bench/` (native, local machine, 2026-10):

| Benchmark | time (mean ± σ) |
|---|---|
| base64_encode_string (56-byte input) | ~10–14 µs |
| quoted_printable_encode (60-byte input) | ~10–14 µs |
| build_message (3 recipients + text/html bodies + PDF attachment) | ~13–20 ms |

## License

Apache-2.0
