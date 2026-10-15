/// RFC 5322 / RFC 2046 MIME email message builder.
///
/// Builds a complete RFC-compliant email message (headers + multipart body)
/// that can be handed to any SMTP client or ESP.

/// An email address with optional display name.
pub(all) struct Mailbox {
  name : String
  email : String
}

/// A complete RFC 5322 message with headers and a multipart/alternative body.
pub(all) struct Message {
  from : Mailbox
  to : Mailbox
  subject : String
  date : String
  message_id : String
  text_body : String
  html_body : String
}

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

/// Base64 encode a string (UTF-8 bytes) per RFC 4648.
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
  s = s + "From: " + format_mailbox(msg.from) + "\n"
  s = s + "To: " + format_mailbox(msg.to) + "\n"
  s = s + "Subject: " + encode_header_word(msg.subject) + "\n"
  s = s + "MIME-Version: 1.0\n"
  s = s + "Date: " + msg.date + "\n"
  s = s + "Message-ID: " + msg.message_id + "\n"
  s = s + "Content-Type: multipart/alternative; boundary=\"" + boundary + "\"\n"
  s = s + "Content-Transfer-Encoding: 7bit\n"
  s = s + "\n"
  s = s + "--" + boundary + "\n"
  s = s + "Content-Type: text/plain; charset=UTF-8\n"
  s = s + "Content-Transfer-Encoding: base64\n"
  s = s + "\n"
  s = s + base64_encode_string(msg.text_body) + "\n"
  s = s + "--" + boundary + "\n"
  s = s + "Content-Type: text/html; charset=UTF-8\n"
  s = s + "Content-Transfer-Encoding: base64\n"
  s = s + "\n"
  s = s + base64_encode_string(msg.html_body) + "\n"
  s = s + "--" + boundary + "--\n"
  s
}
