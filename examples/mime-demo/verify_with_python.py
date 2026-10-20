"""
Cross-verification: parse mooncampaign/mime output with Python's
standard library email module and verify every field round-trips.

This mirrors how moonkafka verifies protocol correctness against a
reference implementation: our bytes must be consumable by an
independent, battle-tested MIME implementation.
"""
import email
import email.policy
import sys

EML = r"C:\Users\21162\Doubao\chats\2026-10-01\new-chat\mooncampaign\examples\mime-demo\output.eml"

checks = []
def check(name, cond, detail=""):
    checks.append((name, cond, detail))

with open(EML, "r", encoding="utf-8") as f:
    raw = f.read()

# Parse with the strict RFC 5322 policy
msg = email.message_from_string(raw, policy=email.policy.default)

check("From header", msg["From"] == "Freshcia <hello@freshcia.com>", msg["From"])
# Python normalizes address formatting; verify address objects instead of raw string
to_addrs = [(a.display_name, a.addr_spec) for a in msg["To"].addresses]
check("To header", to_addrs == [("Alice", "alice@example.com"), ("", "bob@example.com")], str(to_addrs))
cc_addrs = [(a.display_name, a.addr_spec) for a in msg["Cc"].addresses]
check("Cc header", cc_addrs == [("", "carol@example.com")], str(cc_addrs))
check("MIME-Version", msg["MIME-Version"] == "1.0", msg["MIME-Version"])
check("Date header", msg["Date"] == "Thu, 15 Oct 2026 12:00:00 +0800", msg["Date"])
check("Message-ID", msg["Message-ID"] == "<demo-20261015@freshcia.com>", msg["Message-ID"])
check("X-Campaign custom header", msg["X-Campaign"] == "launch-v1", msg["X-Campaign"])
check("List-Unsubscribe", "https://freshcia.com/unsub" in msg["List-Unsubscribe"], msg["List-Unsubscribe"])

# Subject is RFC 2047 encoded-word — Python decodes it
check("Subject decoded (RFC 2047)", msg["Subject"] == "欢迎使用 Freshcia 手霜", msg["Subject"])

# Top-level must be multipart/mixed (has attachment)
check("Top-level is multipart/mixed", msg.is_multipart() and msg.get_content_type() == "multipart/mixed",
      msg.get_content_type())

# First subpart must be multipart/alternative (the body)
body = msg.get_payload()[0]
check("Body is multipart/alternative", body.get_content_type() == "multipart/alternative",
      body.get_content_type())

# Decode text/plain and text/html
text_part = html_part = None
for p in body.get_payload():
    if p.get_content_type() == "text/plain":
        text_part = p
    elif p.get_content_type() == "text/html":
        html_part = p

check("text/plain part exists", text_part is not None)
check("text/html part exists", html_part is not None)
if text_part:
    text = text_part.get_content()
    check("text/plain decodes correctly", text == "Hello, this is the plain text version.", repr(text))
if html_part:
    html = html_part.get_content()
    check("text/html decodes correctly", html == "<p>Hello, this is the <b>HTML</b> version.</p>", repr(html))

# Attachment part
attachments = [p for p in msg.get_payload() if p.get_content_type() == "application/pdf"]
check("PDF attachment exists", len(attachments) == 1, str(len(attachments)))
if attachments:
    att = attachments[0]
    check("Attachment filename", att.get_filename() == "freshcia-catalog.pdf", att.get_filename())
    data = att.get_payload(decode=True)
    check("Attachment decodes from base64", data.startswith(b"%PDF-1.4"), repr(data[:20]))
    check("Attachment full content round-trips",
          data == b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF",
          repr(data))

print(f"{'PASS' if all(c[1] for c in checks) else 'FAIL'} — {sum(1 for c in checks if c[1])}/{len(checks)} checks passed")
failed = [c for c in checks if not c[1]]
for name, _, detail in failed:
    print(f"  ✗ {name}: {detail}")
sys.exit(0 if not failed else 1)
