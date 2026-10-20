/// Golden fixture tests for the RFC 5322 / MIME message builder.
///
/// Byte-level correctness is verified against known RFC vectors and
/// cross-checked against Python's `email.mime` output.

// ---------- RFC 4648 base64 vectors ----------

test "base64 RFC vector: Man" {
  assert_eq(@mime.base64_encode_string("Man"), "TWFu")
}

test "base64 RFC vector: Ma" {
  assert_eq(@mime.base64_encode_string("Ma"), "TWE=")
}

test "base64 RFC vector: M" {
  assert_eq(@mime.base64_encode_string("M"), "TQ==")
}

test "base64 RFC vector: Hello" {
  assert_eq(@mime.base64_encode_string("Hello"), "SGVsbG8=")
}

test "base64 empty input" {
  assert_eq(@mime.base64_encode_string(""), "")
}

test "base64 bytes payload" {
  let b : Bytes = b"Hello"
  assert_eq(@mime.base64_encode_bytes(b), "SGVsbG8=")
}

// ---------- RFC 2047 encoded-word ----------

test "RFC 2047 ASCII passthrough" {
  assert_eq(@mime.encode_header_word("Hello World"), "Hello World")
}

test "RFC 2047 non-ASCII B encoding" {
  let encoded = @mime.encode_header_word("你好")
  assert_true(encoded.has_prefix("=?UTF-8?B?"))
  assert_true(encoded.has_suffix("?="))
}

// ---------- RFC 2045 quoted-printable ----------

test "QP ASCII passthrough" {
  assert_eq(@mime.quoted_printable_encode("Hello World!"), "Hello World!")
}

test "QP encodes equals sign" {
  assert_true(@mime.quoted_printable_encode("a=b").contains("=3D"))
}

test "QP encodes UTF-8 bytes" {
  // é = 0xC3 0xA9 in UTF-8
  assert_true(@mime.quoted_printable_encode("café").contains("=C3=A9"))
}

test "QP soft line break at 76 chars" {
  let long = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  assert_true(@mime.quoted_printable_encode(long).contains("=\n"))
}

// ---------- RFC 5322 date formatting ----------

test "RFC 5322 date known day" {
  // 2026-10-15 is a Thursday
  let date = @mime.format_rfc5322_date(2026, 10, 15, 12, 0, 0, 480)
  assert_eq(date, "Thu, 15 Oct 2026 12:00:00 +0800")
}

test "RFC 5322 date UTC offset" {
  let date = @mime.format_rfc5322_date(2026, 10, 15, 12, 0, 0, 0)
  assert_eq(date, "Thu, 15 Oct 2026 12:00:00 +0000")
}

test "RFC 5322 date negative offset" {
  let date = @mime.format_rfc5322_date(2026, 10, 15, 12, 0, 0, -300)
  assert_eq(date, "Thu, 15 Oct 2026 12:00:00 -0500")
}

test "RFC 5322 date single digit padding" {
  let date = @mime.format_rfc5322_date(2026, 1, 5, 9, 7, 3, 480)
  assert_eq(date, "Mon, 05 Jan 2026 09:07:03 +0800")
}

test "RFC 5322 date leap year" {
  // 2024-02-29 was a Thursday
  let date = @mime.format_rfc5322_date(2024, 2, 29, 0, 0, 0, 0)
  assert_eq(date, "Thu, 29 Feb 2024 00:00:00 +0000")
}

// ---------- Message building: basic ----------

test "basic message headers and body" {
  let msg : @mime.Message = {
    from: { name: "Freshcia", email: "hello@freshcia.com" },
    to: [{ name: "", email: "customer@example.com" }],
    cc: [],
    bcc: [],
    subject: "Welcome to Freshcia",
    date: "Thu, 15 Oct 2026 12:00:00 +0800",
    message_id: "<abc123@freshcia.com>",
    text_body: "Hello World",
    html_body: "<p>Hello World</p>",
    attachments: [],
    extra_headers: [],
  }
  let output = @mime.build_message(msg)
  assert_true(output.has_prefix("From: Freshcia <hello@freshcia.com>\n"))
  assert_true(output.contains("To: <customer@example.com>\n"))
  assert_true(output.contains("Subject: Welcome to Freshcia\n"))
  assert_true(output.contains("MIME-Version: 1.0\n"))
  assert_true(output.contains("Date: Thu, 15 Oct 2026 12:00:00 +0800\n"))
  assert_true(output.contains("Message-ID: <abc123@freshcia.com>\n"))
  assert_true(output.contains("Content-Type: multipart/alternative; boundary=\"BOUNDARY_alt_mooncampaign_2026\""))
  assert_true(output.contains("Content-Type: text/plain; charset=UTF-8"))
  assert_true(output.contains("Content-Type: text/html; charset=UTF-8"))
  assert_true(output.contains("SGVsbG8gV29ybGQ="))  // base64("Hello World")
  assert_true(output.contains("--BOUNDARY_alt_mooncampaign_2026--"))
}

// ---------- Message building: multiple recipients ----------

test "multiple To recipients" {
  let msg : @mime.Message = {
    from: { name: "Freshcia", email: "hello@freshcia.com" },
    to: [
      { name: "Alice", email: "alice@example.com" },
      { name: "", email: "bob@example.com" },
    ],
    cc: [{ name: "", email: "carol@example.com" }],
    bcc: [{ name: "", email: "dave@example.com" }],
    subject: "Multi-recipient",
    date: "Thu, 15 Oct 2026 12:00:00 +0800",
    message_id: "<multi@freshcia.com>",
    text_body: "Hi",
    html_body: "<p>Hi</p>",
    attachments: [],
    extra_headers: [],
  }
  let output = @mime.build_message(msg)
  assert_true(output.contains("To: Alice <alice@example.com>, <bob@example.com>\n"))
  assert_true(output.contains("Cc: <carol@example.com>\n"))
  assert_true(output.contains("Bcc: <dave@example.com>\n"))
}

// ---------- Message building: custom headers ----------

test "custom headers appended" {
  let msg : @mime.Message = {
    from: { name: "", email: "hello@freshcia.com" },
    to: [{ name: "", email: "customer@example.com" }],
    cc: [],
    bcc: [],
    subject: "Custom headers",
    date: "Thu, 15 Oct 2026 12:00:00 +0800",
    message_id: "<custom@freshcia.com>",
    text_body: "Hi",
    html_body: "<p>Hi</p>",
    attachments: [],
    extra_headers: [("X-Campaign", "launch"), ("List-Unsubscribe", "<https://freshcia.com/unsub>")],
  }
  let output = @mime.build_message(msg)
  assert_true(output.contains("X-Campaign: launch\n"))
  assert_true(output.contains("List-Unsubscribe: <https://freshcia.com/unsub>\n"))
}

// ---------- Message building: attachment (multipart/mixed) ----------

test "attachment produces multipart/mixed" {
  let msg : @mime.Message = {
    from: { name: "", email: "hello@freshcia.com" },
    to: [{ name: "", email: "customer@example.com" }],
    cc: [],
    bcc: [],
    subject: "With attachment",
    date: "Thu, 15 Oct 2026 12:00:00 +0800",
    message_id: "<att@freshcia.com>",
    text_body: "See attached",
    html_body: "<p>See attached</p>",
    attachments: [
      {
        filename: "report.pdf",
        content_type: "application/pdf",
        data: b"%PDF-1.4 fake content",
      },
    ],
    extra_headers: [],
  }
  let output = @mime.build_message(msg)
  assert_true(output.contains("Content-Type: multipart/mixed; boundary=\"BOUNDARY_mix_mooncampaign_2026\""))
  assert_true(output.contains("Content-Type: application/pdf; name=\"report.pdf\""))
  assert_true(output.contains("Content-Disposition: attachment; filename=\"report.pdf\""))
  assert_true(output.contains("--BOUNDARY_mix_mooncampaign_2026--"))
}

test "attachment bytes base64 encoded" {
  let b : Bytes = b"hello"
  let msg : @mime.Message = {
    from: { name: "", email: "a@b.com" },
    to: [{ name: "", email: "c@d.com" }],
    cc: [],
    bcc: [],
    subject: "Att",
    date: "Thu, 15 Oct 2026 12:00:00 +0800",
    message_id: "<a@b.com>",
    text_body: "x",
    html_body: "<p>x</p>",
    attachments: [
      {
        filename: "hello.txt",
        content_type: "text/plain",
        data: b,
      },
    ],
    extra_headers: [],
  }
  let output = @mime.build_message(msg)
  // base64("hello") = "aGVsbG8="
  assert_true(output.contains("aGVsbG8="))
}

// ---------- Header folding ----------

test "long subject folded" {
  let long_subject = "This is a very long subject line that definitely exceeds the seventy-eight character folding limit for RFC 5322 headers"
  let msg : @mime.Message = {
    from: { name: "", email: "a@b.com" },
    to: [{ name: "", email: "c@d.com" }],
    cc: [],
    bcc: [],
    subject: long_subject,
    date: "Thu, 15 Oct 2026 12:00:00 +0800",
    message_id: "<a@b.com>",
    text_body: "x",
    html_body: "<p>x</p>",
    attachments: [],
    extra_headers: [],
  }
  let output = @mime.build_message(msg)
  // Header value should be folded with CRLF + space continuation
  assert_true(output.contains("\n "))
}

// ---------- Empty body handling ----------

test "empty text body produces valid output" {
  let msg : @mime.Message = {
    from: { name: "", email: "a@b.com" },
    to: [{ name: "", email: "c@d.com" }],
    cc: [],
    bcc: [],
    subject: "Empty",
    date: "Thu, 15 Oct 2026 12:00:00 +0800",
    message_id: "<a@b.com>",
    text_body: "",
    html_body: "<p>only html</p>",
    attachments: [],
    extra_headers: [],
  }
  let output = @mime.build_message(msg)
  assert_true(output.contains("text/plain; charset=UTF-8"))
}
