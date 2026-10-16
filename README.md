# mooncampaign/mime

**RFC 5322 / MIME email message builder for MoonBit.**

Protocol-level MIME serialization: turn structured email data into standard-compliant bytes, ready for SMTP delivery. Compiles to Wasm — runnable in browsers, edge functions, or any MoonBit runtime.

> This is a **protocol implementation / foundational library**, not a specific product. It implements the MIME standard (RFC 5322 / 2045 / 2046 / 2047) so that any MoonBit project needing to construct email messages doesn't have to re-implement it from scratch.

## What it does

Builds a complete RFC-compliant email message (headers + multipart body) from simple struct inputs:

```
From / To / Subject / Date / Message-ID
Content-Type: multipart/alternative; boundary="..."
  ├── text/plain part  (base64 encoded)
  └── text/html part   (base64 encoded)
```

## Standards implemented

| RFC | What | Status |
|---|---|---|
| RFC 5322 | Internet Message Format (headers, folding) | ✅ |
| RFC 2045 | MIME Part One (Content-Transfer-Encoding) | ✅ base64 + quoted-printable |
| RFC 2046 | MIME Part Two (multipart boundaries) | ✅ multipart/alternative |
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
  to: { name: "", email: "customer@example.com" },
  subject: "Welcome to Freshcia",
  date: "Wed, 15 Oct 2026 12:00:00 +0800",
  message_id: "<abc123@freshcia.com>",
  text_body: "Hello World",
  html_body: "<p>Hello World</p>",
}
let bytes = build_message(msg)
// → complete RFC 5322 message string, ready for SMTP
```

## Benchmarks against other ecosystems

| Language | Library | Equivalent |
|---|---|---|
| Python (stdlib) | `email.mime` | MIME message construction |
| Node.js | `nodemailer` | MIME message construction |
| Rust | `lettre` | MIME message construction |
| **MoonBit** | **moonccampaign/mime** | **this package** |

## Testing

Golden fixture tests verify byte-level correctness against known RFC examples:

- Base64 vectors (RFC 4648: `Man` → `TWFu`, `Ma` → `TWE=`, `M` → `TQ==`)
- Quoted-printable encoding (RFC 2045: soft line breaks at 76 chars)
- RFC 2047 encoded-word for non-ASCII headers
- Full multipart/alternative message structure

Total: 75 tests passing.

## License

Apache-2.0
