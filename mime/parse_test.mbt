/// Tests for the RFC 5322 / MIME parser (parse.mbt) — the inverse of `build_message`.
///
/// Round-trip coverage: a message built by `build_message` parses back to the
/// same fields, including RFC 2047 encoded-word decoding of a CJK subject.

// ---------- RFC 4648 base64 decoding ----------

test "base64 decode RFC vector: Man" {
  assert_eq(@mime.base64_decode_string("TWFu"), "Man")
}

test "base64 decode RFC vector: Ma" {
  assert_eq(@mime.base64_decode_string("TWE="), "Ma")
}

test "base64 decode RFC vector: M" {
  assert_eq(@mime.base64_decode_string("TQ=="), "M")
}

test "base64 decode RFC vector: Hello" {
  assert_eq(@mime.base64_decode_string("SGVsbG8="), "Hello")
}

test "base64 decode ignores CRLF and spaces" {
  assert_eq(@mime.base64_decode_string("TWFu\r\nTWE=\n"), "ManMa")
}

test "base64 decode empty input" {
  assert_eq(@mime.base64_decode_string(""), "")
}

test "base64 decode CJK bytes" {
  // base64("中文") == "5Lit5paH"
  assert_eq(@mime.base64_decode_string("5Lit5paH"), "中文")
}

// ---------- RFC 2045 quoted-printable decoding ----------

test "QP decode =3D is =" {
  assert_eq(@mime.quoted_printable_decode_string("a=3Db"), "a=b")
}

test "QP decode soft line break removed" {
  assert_eq(@mime.quoted_printable_decode_string("long=\r\ncontinued"), "longcontinued")
}

test "QP decode UTF-8 bytes" {
  assert_eq(@mime.quoted_printable_decode_string("=E4=B8=AD=E6=96=87"), "中文")
}

test "QP decode literal equals before non-hex" {
  assert_eq(@mime.quoted_printable_decode_string("100%= ok"), "100%= ok")
}

// ---------- RFC 2047 encoded-word decoding ----------

test "encoded-word B encoding ASCII" {
  assert_eq(@mime.decode_encoded_word("=?UTF-8?B?SGVsbG8=?="), "Hello")
}

test "encoded-word B encoding CJK" {
  assert_eq(@mime.decode_encoded_word("=?UTF-8?B?5Lit5paH?="), "中文")
}

test "non encoded-word returned unchanged" {
  assert_eq(@mime.decode_encoded_word("plain text"), "plain text")
}

// ---------- header block parsing ----------

test "parse simple headers" {
  let headers = @mime.parse_headers("From: a@b.com\r\nTo: c@d.com\r\nSubject: hi\r\n")
  assert_eq(headers.length(), 3)
  assert_eq(@mime.get_header(headers, "From"), "a@b.com")
  assert_eq(@mime.get_header(headers, "subject"), "hi")
}

test "parse header with colon inside value" {
  let headers = @mime.parse_headers("Message-ID: <abc:123@x.com>\r\n")
  assert_eq(@mime.get_header(headers, "Message-ID"), "<abc:123@x.com>")
}

test "unfold folded continuation lines" {
  let headers = @mime.parse_headers(
    "Subject: first line\r\n\tsecond line\r\n  third\r\n",
  )
  assert_eq(headers.length(), 1)
  assert_eq(@mime.get_header(headers, "Subject"), "first line second line third")
}

test "parse empty header block returns no headers" {
  assert_eq(@mime.parse_headers("").length(), 0)
}

// ---------- multipart splitting ----------

test "split multipart parts by boundary" {
  let body =
    "preamble\r\n--BOUNDARY_x\r\npart one\r\n--BOUNDARY_x\r\npart two\r\n--BOUNDARY_x--\r\n"
  let parts = @mime.split_multipart(body, "BOUNDARY_x")
  assert_eq(parts.length(), 2)
  assert_eq(parts[0], "part one")
  assert_eq(parts[1], "part two")
}

// ---------- round-trip: build_message → parse ----------

test "round-trip: built message parses back to same fields" {
  let msg : @mime.Message = {
    from: { name: "Freshcia", email: "hello@freshcia.com" },
    to: [{ name: "Alice", email: "alice@example.com" }],
    cc: [],
    bcc: [],
    subject: "欢迎使用 Freshcia 手霜",
    date: @mime.format_rfc5322_date(2026, 10, 15, 12, 0, 0, 480),
    message_id: "<abc123@freshcia.com>",
    text_body: "Hello World",
    html_body: "<p>Hello World</p>",
    attachments: [],
    extra_headers: [],
  }
  let output = @mime.build_message(msg)
  let headers = @mime.parse_headers(output)
  assert_true(@mime.get_header(headers, "From").contains("hello@freshcia.com"))
  assert_true(@mime.get_header(headers, "To").contains("alice@example.com"))
  assert_eq(@mime.get_header(headers, "MIME-Version"), "1.0")
  assert_eq(@mime.get_header(headers, "Message-ID"), "<abc123@freshcia.com>")
  // RFC 2047 encoded-word must decode back to the original CJK subject
  assert_eq(
    @mime.decode_encoded_word(@mime.get_header(headers, "Subject")),
    "欢迎使用 Freshcia 手霜",
  )
}

test "round-trip with attachment and custom header" {
  let msg : @mime.Message = {
    from: { name: "Freshcia", email: "hello@freshcia.com" },
    to: [{ name: "Bob", email: "bob@example.com" }],
    cc: [],
    bcc: [],
    subject: "Invoice",
    date: @mime.format_rfc5322_date(2026, 10, 15, 9, 30, 0, 480),
    message_id: "<inv-7@freshcia.com>",
    text_body: "Please find attached.",
    html_body: "",
    attachments: [
      { filename: "catalog.pdf", content_type: "application/pdf", data: b"%PDF-1.4 fake" },
    ],
    extra_headers: [("List-Unsubscribe", "<https://freshcia.com/unsub>")],
  }
  let output = @mime.build_message(msg)
  let headers = @mime.parse_headers(output)
  assert_eq(@mime.get_header(headers, "List-Unsubscribe"), "<https://freshcia.com/unsub>")
  assert_true(@mime.get_header(headers, "Content-Type").contains("multipart/mixed"))
  assert_true(output.contains("--BOUNDARY_mix_mooncampaign_2026"))
  assert_true(output.contains("application/pdf"))
}
