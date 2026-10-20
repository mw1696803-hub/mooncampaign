fn main {
  let msg : @mime.Message = {
    from: { name: "Freshcia", email: "hello@freshcia.com" },
    to: [
      { name: "Alice", email: "alice@example.com" },
      { name: "", email: "bob@example.com" },
    ],
    cc: [{ name: "", email: "carol@example.com" }],
    bcc: [],
    subject: "欢迎使用 Freshcia 手霜",
    date: @mime.format_rfc5322_date(2026, 10, 15, 12, 0, 0, 480),
    message_id: "<demo-20261015@freshcia.com>",
    text_body: "Hello, this is the plain text version.",
    html_body: "<p>Hello, this is the <b>HTML</b> version.</p>",
    attachments: [
      {
        filename: "freshcia-catalog.pdf",
        content_type: "application/pdf",
        data: b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF",
      },
    ],
    extra_headers: [("X-Campaign", "launch-v1"), ("List-Unsubscribe", "<https://freshcia.com/unsub>")],
  }
  println(@mime.build_message(msg))
}
