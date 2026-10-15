/// RFC 5322 / RFC 2045 / RFC 2046 MIME message builder.
///
/// Implements the standard MIME (Multipurpose Internet Mail Extensions)
/// protocol for structured content serialization:
/// - RFC 5322: Internet Message Format (headers, folding)
/// - RFC 2045: MIME Part One (headers, Content-Transfer-Encoding)
/// - RFC 2046: MIME Part Two (media types, multipart boundaries)
/// - RFC 2047: MIME Part Three (encoded-word for non-ASCII headers)

/// An email address with optional display name.
pub(all) struct Mailbox {
  name : String
  email : String
}

/// A MIME body part.
pub(all) struct MimePart {
  content_type : String
  body : String
  encoding : String  // "base64" or "quoted-printable"
}

/// A complete RFC 5322 message.
pub(all) struct Message {
  from : Mailbox
  to : Mailbox
  subject : String
  date : String
  message_id : String
  text_body : String
  html_body : String
}

// ---------- RFC 2047: encoded-word for headers ----------

/// Encode a non-ASCII header value per RFC 2047.
pub fn encode_header_word(value : String) -> String {
  let mut is_ascii = true
  for c in value {
    if c.to_int() > 127 {
      is_ascii = false
    }
  }
  if is_ascii {
    return value
  }
  let encoded = base64_encode_string(value)
  "=?UTF-8?B?" + encoded + "?="
}

// ---------- RFC 4648: Base64 encoding ----------

/// Base64 encode a string (UTF-8 bytes).
pub fn base64_encode_string(input : String) -> String {
  let table_str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let table_chars : Array[Char] = []
  for c in table_str {
    table_chars.push(c)
  }
  let bytes : Bytes = b"\{input}"
  let len = bytes.length()
  let mut result = ""
  let mut i = 0
  while i < len {
    let b0 = bytes[i].to_int()
    let has_b1 = i + 1 < len
    let has_b2 = i + 2 < len
    let b1 = if has_b1 { bytes[i + 1].to_int() } else { 0 }
    let b2 = if has_b2 { bytes[i + 2].to_int() } else { 0 }
    let s0 = b0 >> 2
    let s1 = ((b0 & 0x03) << 4) | (b1 >> 4)
    let s2 = ((b1 & 0x0F) << 2) | (b2 >> 6)
    let s3 = b2 & 0x3F
    let c0 : String = [table_chars[s0]]
    let c1 : String = [table_chars[s1]]
    result = result + c0 + c1
    if has_b1 {
      let c2 : String = [table_chars[s2]]
      result = result + c2
    } else {
      result = result + "="
    }
    if has_b2 {
      let c3 : String = [table_chars[s3]]
      result = result + c3
    } else {
      result = result + "="
    }
    i = i + 3
  }
  result
}

// ---------- RFC 2045: Quoted-printable encoding ----------

/// Check if a byte should be encoded in quoted-printable.
fn qp_should_encode(b : Int) -> Bool {
  // '=' (61) must always be encoded
  if b == 61 {
    return true
  }
  // Printable ASCII (33-126) is safe
  if b >= 33 && b <= 126 {
    return false
  }
  // Space (32) and tab (9) are safe
  if b == 32 || b == 9 {
    return false
  }
  true
}

fn int_to_hex(n : Int) -> String {
  let hex_str = "0123456789ABCDEF"
  let hex_chars : Array[Char] = []
  for c in hex_str {
    hex_chars.push(c)
  }
  let d1 = n >> 4
  let d2 = n & 0x0F
  let c1 : String = [hex_chars[d1]]
  let c2 : String = [hex_chars[d2]]
  c1 + c2
}

/// Quoted-printable encode a string per RFC 2045.
pub fn quoted_printable_encode(input : String) -> String {
  let bytes : Bytes = b"\{input}"
  let len = bytes.length()
  let mut result = ""
  let mut line_len = 0
  let mut i = 0
  while i < len {
    let b = bytes[i].to_int()
    if qp_should_encode(b) {
      let enc = "=" + int_to_hex(b)
      if line_len + enc.length() > 76 {
        result = result + "=\n"
        line_len = 0
      }
      result = result + enc
      line_len = line_len + enc.length()
    } else {
      let c : String = [bytes[i].to_char()]
      if line_len + 1 > 76 {
        result = result + "=\n"
        line_len = 0
      }
      result = result + c
      line_len = line_len + 1
    }
    i = i + 1
  }
  result
}

// ---------- RFC 5322: Header folding ----------

/// Fold a header value at ~78 characters per RFC 5322.
fn fold_header(value : String) -> String {
  if value.length() <= 78 {
    return value
  }
  let mut result = ""
  let mut line = ""
  for c in value {
    let cs : String = [c]
    if line.length() + 1 > 76 {
      result = result + line + "\n "
      line = ""
    }
    line = line + cs
  }
  result = result + line
  result
}

// ---------- Message building ----------

/// Format a Mailbox for use in a From/To header.
fn format_mailbox(mb : Mailbox) -> String {
  if mb.name == "" {
    "<" + mb.email + ">"
  } else {
    let quoted_name = encode_header_word(mb.name)
    quoted_name + " <" + mb.email + ">"
  }
}

/// Build the complete RFC 5322 message as a string.
pub fn build_message(msg : Message) -> String {
  let boundary = "BOUNDARY_mooncampaign_2026"
  let mut s = ""
  s = s + "From: " + fold_header(format_mailbox(msg.from)) + "\n"
  s = s + "To: " + fold_header(format_mailbox(msg.to)) + "\n"
  s = s + "Subject: " + fold_header(encode_header_word(msg.subject)) + "\n"
  s = s + "MIME-Version: 1.0\n"
  s = s + "Date: " + msg.date + "\n"
  s = s + "Message-ID: " + msg.message_id + "\n"
  s = s + "Content-Type: multipart/alternative; boundary=\"" + boundary + "\"\n"
  s = s + "Content-Transfer-Encoding: 7bit\n"
  s = s + "\n"
  // text/plain part
  s = s + "--" + boundary + "\n"
  s = s + "Content-Type: text/plain; charset=UTF-8\n"
  s = s + "Content-Transfer-Encoding: base64\n"
  s = s + "\n"
  s = s + base64_encode_string(msg.text_body) + "\n"
  // text/html part
  s = s + "--" + boundary + "\n"
  s = s + "Content-Type: text/html; charset=UTF-8\n"
  s = s + "Content-Transfer-Encoding: base64\n"
  s = s + "\n"
  s = s + base64_encode_string(msg.html_body) + "\n"
  // closing boundary
  s = s + "--" + boundary + "--\n"
  s
}
