/// Benchmarks for the RFC 5322 / MIME message builder.
///
/// Run with:  moon bench bench/
///
/// Mirrors moonkafka's `bench/` + `make bench` convention: throughput
/// numbers belong in the README so users can see the cost of building
/// messages before they adopt the library.

fn sample_message() -> @mime.Message {
  let mbs : Array[@mime.Mailbox] = []
  mbs.push({ name: "Freshcia", email: "hello@freshcia.com" })
  mbs.push({ name: "Alice", email: "alice@example.com" })
  mbs.push({ name: "Bob", email: "bob@example.com" })
  let mut text = ""
  let mut i = 0
  while i < 200 {
    text = text + "Freshcia Solid Hand Cream keeps hands soft for 8 hours. "
    i = i + 1
  }
  let mut html = ""
  i = 0
  while i < 200 {
    html = html + "<p>Freshcia Solid Hand Cream keeps hands soft for 8 hours.</p>"
    i = i + 1
  }
  let att : @mime.Attachment = {
    filename: "freshcia-catalog.pdf",
    content_type: "application/pdf",
    data: b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n",
  }
  {
    from: { name: "Freshcia", email: "hello@freshcia.com" },
    to: mbs,
    cc: [],
    bcc: [],
    subject: "Spring launch: Freshcia Solid Hand Cream 春季新品发布 🎉",
    date: "Thu, 15 Oct 2026 12:00:00 +0800",
    message_id: "<bench@freshcia.com>",
    text_body: text,
    html_body: html,
    attachments: [att],
    extra_headers: [("List-Unsubscribe", "<https://freshcia.com/unsub>")],
  }
}

test (b : @bench.T) {
  b.bench(fn() {
    let _ = @mime.base64_encode_string("Freshcia Solid Hand Cream keeps hands soft")
  })
}

test (b : @bench.T) {
  b.bench(fn() {
    let _ = @mime.quoted_printable_encode("Freshcia Solid Hand Cream keeps hands soft for 8 hours")
  })
}

test (b : @bench.T) {
  let msg = sample_message()
  b.bench(fn() {
    let _ = @mime.build_message(msg)
  })
}
