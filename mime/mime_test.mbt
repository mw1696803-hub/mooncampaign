/// Golden fixture tests for RFC 5322 MIME message builder.
///
/// These tests verify that our output matches the expected RFC-compliant
/// byte-for-byte, similar to how moonkafka uses golden test data.

test "base64 encode Hello" {
  let encoded = base64_encode_string("Hello")
  assert_eq(encoded, "SGVsbG8=")
}

test "base64 encode empty" {
  let encoded = base64_encode_string("")
  assert_eq(encoded, "")
}

test "base64 encode 3 bytes exact" {
  // "Man" -> "TWFu" (RFC 4648 example)
  let encoded = base64_encode_string("Man")
  assert_eq(encoded, "TWFu")
}

test "base64 encode 2 bytes padding" {
  // "Ma" -> "TWE=" (RFC 4648 example)
  let encoded = base64_encode_string("Ma")
  assert_eq(encoded, "TWE=")
}

test "base64 encode 1 byte padding" {
  // "M" -> "TQ==" (RFC 4648 example)
  let encoded = base64_encode_string("M")
  assert_eq(encoded, "TQ==")
}

test "header word ASCII passthrough" {
  let encoded = encode_header_word("Hello World")
  assert_eq(encoded, "Hello World")
}

test "header word non-ASCII RFC 2047" {
  let encoded = encode_header_word("你好")
  // Should be =?UTF-8?B?...?= format
  assert_true(encoded.starts_with("=?UTF-8?B?"))
  assert_true(encoded.ends_with("?="))
}

test "build message basic structure" {
  let msg : Message = {
    from: { name: "Freshcia", email: "hello@freshcia.com" },
    to: { name: "", email: "customer@example.com" },
    subject: "Welcome to Freshcia",
    date: "Wed, 15 Oct 2026 12:00:00 +0800",
    message_id: "<abc123@freshcia.com>",
    text_body: "Hello World",
    html_body: "<p>Hello World</p>",
  }
  let output = build_message(msg)
  // Check headers present
  assert_true(output.contains("From: Freshcia <hello@freshcia.com>"))
  assert_true(output.contains("To: <customer@example.com>"))
  assert_true(output.contains("Subject: Welcome to Freshcia"))
  assert_true(output.contains("MIME-Version: 1.0"))
  assert_true(output.contains("Date: Wed, 15 Oct 2026 12:00:00 +0800"))
  assert_true(output.contains("Message-ID: <abc123@freshcia.com>"))
  assert_true(output.contains("Content-Type: multipart/alternative"))
  // Check boundary
  assert_true(output.contains("boundary=\"BOUNDARY_mooncampaign_2026\""))
  assert_true(output.contains("--BOUNDARY_mooncampaign_2026"))
  assert_true(output.contains("--BOUNDARY_mooncampaign_2026--"))
  // Check parts
  assert_true(output.contains("Content-Type: text/plain; charset=UTF-8"))
  assert_true(output.contains("Content-Type: text/html; charset=UTF-8"))
  assert_true(output.contains("Content-Transfer-Encoding: base64"))
  // base64 of "Hello World" should be present
  assert_true(output.contains("SGVsbG8gV29ybGQ="))
}
