/// RFC 5322 / RFC 2045 / RFC 2046 / RFC 2047 MIME message builder.
///
/// Implements the standard MIME (Multipurpose Internet Mail Extensions)
/// protocol for structured content serialization:
/// - RFC 5322: Internet Message Format (headers, folding, date format, CRLF line endings)
/// - RFC 2045: MIME Part One (Content-Transfer-Encoding, 76-column line wrap)
/// - RFC 2046: MIME Part Two (media types, multipart boundaries)
/// - RFC 2047: MIME Part Three (encoded-word for non-ASCII headers)
///
/// Line endings follow RFC 5322: every line ends with CRLF (carriage return +
/// line feed). All header values are sanitized against CR/LF injection.

/// An email address with optional display name.
pub(all) struct Mailbox {
  name : String
  email : String
}

/// A file attachment (binary payload, base64-encoded on output).
pub(all) struct Attachment {
  filename : String
  content_type : String  // e.g. "application/pdf"
  data : Bytes           // raw file bytes
}

/// A complete RFC 5322 message.
pub(all) struct Message {
  from : Mailbox
  to : Array[Mailbox]
  cc : Array[Mailbox]
  bcc : Array[Mailbox]
  subject : String
  date : String                       // RFC 5322, e.g. "Wed, 15 Oct 2026 12:00:00 +0800"
  message_id : String                 // e.g. "<abc123@freshcia.com>"
  text_body : String
  html_body : String
  attachments : Array[Attachment]
  extra_headers : Array[(String, String)]  // custom headers, e.g. ("X-Campaign", "launch")
}

// ---------- Line ending ----------

/// RFC 5322 line terminator.
const CRLF : String = "\r\n"

// ---------- Header injection protection ----------

/// Check whether a string contains CR/LF that could inject header lines.
pub fn has_injection_chars(value : String) -> Bool {
  for c in value {
    if c == '\r' || c == '\n' {
      return true
    }
  }
  false
}

/// Replace CR/LF with spaces to neutralize header injection.
pub fn sanitize_header_value(value : String) -> String {
  let mut result = ""
  for c in value {
    if c == '\r' || c == '\n' {
      result = result + " "
    } else {
      let cs : String = [c]
      result = result + cs
    }
  }
  result
}

// ---------- RFC 4648: Base64 encoding ----------

fn base64_encode_internal(bytes : Bytes, wrap_lines : Bool) -> String {
  let table_str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let table_chars : Array[Char] = []
  for c in table_str {
    table_chars.push(c)
  }
  let len = bytes.length()
  let mut result = ""
  let mut col = 0
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
    col = col + 2
    if has_b1 {
      let c2 : String = [table_chars[s2]]
      result = result + c2
      col = col + 1
    } else {
      result = result + "="
      col = col + 1
    }
    if has_b2 {
      let c3 : String = [table_chars[s3]]
      result = result + c3
      col = col + 1
    } else {
      result = result + "="
      col = col + 1
    }
    // RFC 2045: lines must not exceed 76 characters
    if wrap_lines && col >= 76 {
      result = result + CRLF
      col = 0
    }
    i = i + 3
  }
  result
}

/// Base64 encode a Bytes payload (RFC 4648, no line wrapping).
pub fn base64_encode_bytes(bytes : Bytes) -> String {
  base64_encode_internal(bytes, false)
}

/// Base64 encode a string (RFC 4648, no line wrapping).
/// Used for RFC 2047 encoded-words which must stay on one line.
pub fn base64_encode_string(input : String) -> String {
  let bytes : Bytes = b"\{input}"
  base64_encode_internal(bytes, false)
}

/// Base64 encode with RFC 2045 76-column wrapping (for MIME body parts).
fn base64_encode_wrapped(bytes : Bytes) -> String {
  base64_encode_internal(bytes, true)
}

// ---------- RFC 2047: encoded-word for headers ----------

/// Encode a non-ASCII header value per RFC 2047 (B encoding).
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

/// Quoted-printable encode a string per RFC 2045 (soft breaks use CRLF).
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
        result = result + "=" + CRLF
        line_len = 0
      }
      result = result + enc
      line_len = line_len + enc.length()
    } else {
      let c : String = [bytes[i].to_char()]
      if line_len + 1 > 76 {
        result = result + "=" + CRLF
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

/// Fold a header value at ~78 characters per RFC 5322 (CRLF + space continuation).
fn fold_header(value : String) -> String {
  if value.length() <= 78 {
    return value
  }
  let mut result = ""
  let mut line = ""
  for c in value {
    let cs : String = [c]
    if line.length() + 1 > 76 {
      result = result + line + CRLF + " "
      line = ""
    }
    line = line + cs
  }
  result = result + line
  result
}

// ---------- RFC 5322: Date formatting ----------

fn weekdays() -> Array[String] {
  ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
}

fn months() -> Array[String] {
  ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
}

/// Day-of-week index (0=Sunday) via Sakamoto's algorithm.
fn day_of_week(y : Int, m : Int, d : Int) -> Int {
  let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let adjusted_y = if m < 3 { y - 1 } else { y }
  (adjusted_y + adjusted_y / 4 - adjusted_y / 100 + adjusted_y / 400 + t[m - 1] + d) % 7
}

fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

/// Format a timezone offset in minutes as RFC 5322 "+0800" / "-0500".
fn format_tz_offset(offset_minutes : Int) -> String {
  let abs = if offset_minutes < 0 { -offset_minutes } else { offset_minutes }
  let sign = if offset_minutes < 0 { "-" } else { "+" }
  let hours = abs / 60
  let minutes = abs % 60
  sign + pad2(hours) + pad2(minutes)
}

/// Format a date/time as an RFC 5322 date string.
/// `tz_offset_minutes` is the offset east of UTC (e.g. +480 for UTC+8).
pub fn format_rfc5322_date(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
  tz_offset_minutes : Int
) -> String {
  let wd = weekdays()[day_of_week(year, month, day)]
  let mon = months()[month - 1]
  wd + ", " + pad2(day) + " " + mon + " " + year.to_string() + " " +
    pad2(hour) + ":" + pad2(minute) + ":" + pad2(second) + " " +
    format_tz_offset(tz_offset_minutes)
}

// ---------- Message building ----------

/// Format a Mailbox for use in a From/To header (injection-safe).
fn format_mailbox(mb : Mailbox) -> String {
  let safe_name = sanitize_header_value(mb.name)
  let safe_email = sanitize_header_value(mb.email)
  if safe_name == "" {
    "<" + safe_email + ">"
  } else {
    let quoted_name = encode_header_word(safe_name)
    quoted_name + " <" + safe_email + ">"
  }
}

/// Format a list of mailboxes for To/Cc/Bcc headers.
fn format_mailbox_list(mbs : Array[Mailbox]) -> String {
  let parts : Array[String] = []
  for mb in mbs {
    parts.push(format_mailbox(mb))
  }
  let mut result = ""
  let mut first = true
  for p in parts {
    if !first {
      result = result + ", "
    }
    first = false
    result = result + p
  }
  result
}

/// Build a single MIME part header block.
fn build_part(content_type : String, transfer_encoding : String, extra : String, body : String) -> String {
  let mut s = ""
  s = s + "Content-Type: " + content_type + CRLF
  if extra != "" {
    s = s + extra + CRLF
  }
  s = s + "Content-Transfer-Encoding: " + transfer_encoding + CRLF
  s = s + CRLF
  s = s + body + CRLF
  s
}

/// Build the complete RFC 5322 message as a string (CRLF line endings).
///
/// If there are attachments, the top level is multipart/mixed containing a
/// nested multipart/alternative body plus attachment parts. Otherwise the
/// message is a plain multipart/alternative.
pub fn build_message(msg : Message) -> String {
  let boundary_alt = "BOUNDARY_alt_mooncampaign_2026"
  let mut s = ""

  // Headers — all values sanitized against CR/LF injection
  let safe_subject = sanitize_header_value(msg.subject)
  let safe_date = sanitize_header_value(msg.date)
  let safe_message_id = sanitize_header_value(msg.message_id)
  s = s + "From: " + fold_header(format_mailbox(msg.from)) + CRLF
  s = s + "To: " + fold_header(format_mailbox_list(msg.to)) + CRLF
  if msg.cc.length() > 0 {
    s = s + "Cc: " + fold_header(format_mailbox_list(msg.cc)) + CRLF
  }
  if msg.bcc.length() > 0 {
    s = s + "Bcc: " + fold_header(format_mailbox_list(msg.bcc)) + CRLF
  }
  s = s + "Subject: " + fold_header(encode_header_word(safe_subject)) + CRLF
  s = s + "MIME-Version: 1.0" + CRLF
  s = s + "Date: " + safe_date + CRLF
  s = s + "Message-ID: " + safe_message_id + CRLF
  for (name, value) in msg.extra_headers {
    let safe_name = sanitize_header_value(name)
    let safe_value = sanitize_header_value(value)
    s = s + safe_name + ": " + fold_header(safe_value) + CRLF
  }

  // Body: nested alternative inside mixed if attachments exist
  if msg.attachments.length() > 0 {
    let boundary_mix = "BOUNDARY_mix_mooncampaign_2026"
    s = s + "Content-Type: multipart/mixed; boundary=\"" + boundary_mix + "\"" + CRLF
    s = s + "Content-Transfer-Encoding: 7bit" + CRLF
    s = s + CRLF
    s = s + "--" + boundary_mix + CRLF
    s = s + "Content-Type: multipart/alternative; boundary=\"" + boundary_alt + "\"" + CRLF
    s = s + CRLF
    s = s + build_alternative_parts(msg, boundary_alt)
    s = s + "--" + boundary_mix + CRLF
    for att in msg.attachments {
      let safe_filename = sanitize_header_value(att.filename)
      let safe_content_type = sanitize_header_value(att.content_type)
      s = s + "Content-Type: " + safe_content_type + "; name=\"" + safe_filename + "\"" + CRLF
      s = s + "Content-Transfer-Encoding: base64" + CRLF
      s = s + "Content-Disposition: attachment; filename=\"" + safe_filename + "\"" + CRLF
      s = s + CRLF
      s = s + base64_encode_wrapped(att.data) + CRLF
      s = s + "--" + boundary_mix + CRLF
    }
    s = s + "--" + boundary_mix + "--" + CRLF
  } else {
    s = s + "Content-Type: multipart/alternative; boundary=\"" + boundary_alt + "\"" + CRLF
    s = s + "Content-Transfer-Encoding: 7bit" + CRLF
    s = s + CRLF
    s = s + build_alternative_parts(msg, boundary_alt)
  }
  s
}

/// Build the text/plain + text/html alternative parts (without outer headers).
fn build_alternative_parts(msg : Message, boundary : String) -> String {
  let mut s = ""
  s = s + "--" + boundary + CRLF
  s = s + build_part(
    "text/plain; charset=UTF-8",
    "base64",
    "",
    base64_encode_wrapped(b"\{msg.text_body}"),
  )
  s = s + "--" + boundary + CRLF
  s = s + build_part(
    "text/html; charset=UTF-8",
    "base64",
    "",
    base64_encode_wrapped(b"\{msg.html_body}"),
  )
  s = s + "--" + boundary + "--" + CRLF
  s
}
