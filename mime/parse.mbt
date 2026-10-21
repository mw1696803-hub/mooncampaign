/// RFC 5322 / MIME message parsing — the inverse of `build_message`.
///
/// Implements:
/// - Header block parsing with unfolded continuation lines
/// - Base64 decoding (RFC 4648, ignores line breaks)
/// - Quoted-printable decoding (RFC 2045, handles soft breaks)
/// - RFC 2047 encoded-word decoding (B encoding)
/// - Multipart part splitting on MIME boundaries
///
/// Together with `build_message`, a message can round-trip: build → parse →
/// identical fields.

fn b64_val(c : Char) -> Int {
  let n = c.to_int()
  if n >= 65 && n <= 90 {
    n - 65
  } else if n >= 97 && n <= 122 {
    n - 71
  } else if n >= 48 && n <= 57 {
    n + 4
  } else if n == 43 {
    62
  } else if n == 47 {
    63
  } else {
    -1
  }
}

fn bytes_from_ints(vals : Array[Int]) -> Bytes {
  let arr : Array[Byte] = []
  for v in vals {
    arr.push(v.to_byte())
  }
  Bytes::from_array(arr[:])
}

/// Decode an RFC 4648 base64 string to raw bytes.
/// CR/LF, spaces and tabs are ignored; `=` padding is dropped.
pub fn base64_decode_bytes(input : String) -> Bytes {
  let vals : Array[Int] = []
  for c in input {
    let v = b64_val(c)
    if v >= 0 {
      vals.push(v)
    }
  }
  let out : Array[Int] = []
  let mut i = 0
  while i + 4 <= vals.length() {
    let n = (vals[i] << 18) | (vals[i + 1] << 12) | (vals[i + 2] << 6) | vals[i + 3]
    out.push((n >> 16) & 0xFF)
    out.push((n >> 8) & 0xFF)
    out.push(n & 0xFF)
    i = i + 4
  }
  let rem = vals.length() - i
  if rem == 2 {
    let n = (vals[i] << 18) | (vals[i + 1] << 12)
    out.push((n >> 16) & 0xFF)
  } else if rem == 3 {
    let n = (vals[i] << 18) | (vals[i + 1] << 12) | (vals[i + 2] << 6)
    out.push((n >> 16) & 0xFF)
    out.push((n >> 8) & 0xFF)
  }
  bytes_from_ints(out)
}

/// Decode an RFC 4648 base64 string to a UTF-8 String.
pub fn base64_decode_string(input : String) -> String {
  @utf8.decode_lossy(base64_decode_bytes(input)[:])
}

fn hex_val(c : Char) -> Int {
  let n = c.to_int()
  if n >= 48 && n <= 57 {
    n - 48
  } else if n >= 65 && n <= 70 {
    n - 55
  } else if n >= 97 && n <= 102 {
    n - 87
  } else {
    -1
  }
}

/// Decode an RFC 2045 quoted-printable string to raw bytes.
/// Soft line breaks (`=\r\n` / `=\n`) are removed; `=XX` is decoded.
pub fn quoted_printable_decode_bytes(input : String) -> Bytes {
  let out : Array[Int] = []
  let chars : Array[Char] = []
  for c in input {
    chars.push(c)
  }
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '=' && i + 1 < chars.length() {
      // soft line break: =CRLF or =LF
      if chars[i + 1] == '\r' || chars[i + 1] == '\n' {
        i = i + 2
        if chars[i - 1] == '\r' && i < chars.length() && chars[i] == '\n' {
          i = i + 1
        }
      } else if i + 2 < chars.length() {
        let h1 = hex_val(chars[i + 1])
        let h2 = hex_val(chars[i + 2])
        if h1 >= 0 && h2 >= 0 {
          out.push((h1 << 4) | h2)
          i = i + 3
        } else {
          out.push(61)  // literal '='
          i = i + 1
        }
      } else {
        out.push(61)
        i = i + 1
      }
    } else {
      out.push(c.to_int())
      i = i + 1
    }
  }
  bytes_from_ints(out)
}

/// Decode an RFC 2045 quoted-printable string to a UTF-8 String.
pub fn quoted_printable_decode_string(input : String) -> String {
  @utf8.decode_lossy(quoted_printable_decode_bytes(input)[:])
}

/// Decode an RFC 2047 encoded-word (`=?charset?B?data?=`) to a String.
/// If the value is not an encoded-word, it is returned unchanged.
pub fn decode_encoded_word(input : String) -> String {
  if input.length() < 10 {
    return input
  }
  if !input.has_prefix("=?") || !input.has_suffix("?=") {
    return input
  }
  // Split on "?": =? charset ? B ? data ?=
  let parts = input.split("?").map(fn(p) { p.to_owned() }).to_array()
  // ["=", "UTF-8", "B", "data", "="]  (for a well-formed encoded-word)
  if parts.length() < 5 {
    return input
  }
  if parts[0] != "=" || parts[2].length() != 1 {
    return input
  }
  let enc = parts[2]
  if enc == "B" || enc == "b" {
    // B encoding: base64 of UTF-8 bytes
    let data = parts[3]
    return base64_decode_string(data)
  }
  input
}

/// A parsed header field (folded continuation lines unfolded).
pub(all) struct ParsedHeader {
  name : String
  value : String
}

/// Parse the header block of an RFC 5322 message (before the first blank line).
/// Continuation lines (starting with space or tab) are unfolded into value.
pub fn parse_headers(input : String) -> Array[ParsedHeader] {
  let lines = input.split("\r\n").map(fn(l) { l.to_owned() }).to_array()
  let out : Array[ParsedHeader] = []
  let mut cur_name = ""
  let mut cur_value = ""
  let mut in_header = true
  for line in lines {
    if in_header {
      if line.length() == 0 {
        in_header = false
      } else if line[0] == ' ' || line[0] == '\t' {
        // continuation: unfold by joining with the previous value
        cur_value = cur_value + " " + line.trim().to_owned()
      } else {
        // new header field
        if cur_name != "" {
          out.push({ name: cur_name, value: cur_value })
        }
        let segs = line.split(":").map(fn(p) { p.to_owned() }).to_array()
        if segs.length() >= 2 {
          cur_name = segs[0].trim().to_owned()
          cur_value = segs[1].trim().to_owned()
          let mut i = 2
          while i < segs.length() {
            cur_value = cur_value + ":" + segs[i]
            i = i + 1
          }
        } else {
          cur_name = line
          cur_value = ""
        }
      }
    }
  }
  if cur_name != "" {
    out.push({ name: cur_name, value: cur_value })
  }
  out
}

/// Look up a header field by name (case-insensitive). Returns "" if absent.
pub fn get_header(headers : Array[ParsedHeader], name : String) -> String {
  let lower = name.to_lower()
  for h in headers {
    if h.name.to_lower() == lower {
      return h.value
    }
  }
  ""
}

/// Split a multipart body into its parts by `--boundary` markers.
/// Returns the part payloads (boundary delimiter lines removed), including
/// the trailing part before the closing `--boundary--`.
pub fn split_multipart(body : String, boundary : String) -> Array[String] {
  let lines = body.split("\r\n").map(fn(l) { l.to_owned() }).to_array()
  let marker = "--" + boundary
  let out : Array[String] = []
  let mut current : Array[String] = []
  let mut in_part = false
  for line in lines {
    if line == marker {
      if in_part {
        out.push(string_from_lines(current))
        current = []
      }
      in_part = true
    } else if line == marker + "--" {
      if in_part {
        out.push(string_from_lines(current))
      }
      in_part = false
    } else {
      if in_part {
        current.push(line)
      }
    }
  }
  out
}

fn string_from_lines(lines : Array[String]) -> String {
  let mut s = ""
  let mut first = true
  for l in lines {
    if !first {
      s = s + "\r\n"
    }
    first = false
    s = s + l
  }
  s
}
