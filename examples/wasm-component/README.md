# Wasm Component 适配

mooncampaign/mime 是纯函数、无 I/O 的协议库，天然可以编译为 **WebAssembly 组件**（Component Model），被 Spin、Wasmtime、Wasmer 等宿主运行时直接消费——这正是 MoonBit 官方主推的生态方向（WIT + wit-bindgen，已被 Bytecode Alliance 官方指南收录）。

## 为什么这对生态有意义

```
边缘函数 / 云端服务（Spin、Cloudflare Workers…）
        │  import
        ▼
  mime 组件（mooncampaign:mime@0.1.0）
        │  build-message(msg) -> 标准 RFC 5322 字节流
        ▼
  SMTP / ESP 发送
```

在无状态边缘环境里，用几 KB 的 Wasm 组件生成标准邮件消息，不需要常驻服务、不需要 SMTP 依赖——组件即插即用。

## 组件接口（`wit/mime.wit`）

```wit
package mooncampaign:mime@0.1.0;

interface mime-builder {
  record mailbox { name: string, email: string }
  record attachment { filename: string, content-type: string, data: list<u8> }
  record header { name: string, value: string }

  record message {
    from: mailbox,
    to: list<mailbox>,
    cc: list<mailbox>,
    bcc: list<mailbox>,
    subject: string,
    date: string,
    message-id: string,
    text-body: string,
    html-body: string,
    attachments: list<attachment>,
    extra-headers: list<header>,
  }

  build-message: func(msg: message) -> string;
  base64-encode: func(input: string) -> string;
  quoted-printable-encode: func(input: string) -> string;
}

world mime { export mime-builder }
```

## 构建组件（流程）

需要 Rust 工具链（cargo）安装两个 CLI：

```bash
cargo install wit-bindgen-cli
cargo install wasm-tools
```

然后：

```bash
# 1. 由 WIT 生成 MoonBit 绑定与项目骨架
wit-bindgen moonbit wit/mime.wit --out-dir wasm-component \
  --derive-eq --derive-show --derive-error --project-name mooncampaign

# 2. 填写生成的 stub（转发到 @mime 实现，参考 stub-forward-example.mbt）
#    并在 gen/moon.pkg 配置 wasm exports（见 stub-forward-example.mbt 注释）

# 3. 编译为 Wasm 并组装成组件
moon build --target wasm
wasm-tools component embed wit _build/wasm/release/build/gen/gen.wasm \
  --encoding utf16 --output mime.wasm
wasm-tools component new mime.wasm --output mime.component.wasm

# 4. 验证组件接口
wasm-tools component wit mime.component.wasm

# 5. 用 Wasmtime 直接测试
wasmtime run --invoke 'base64-encode("Hello")' mime.component.wasm
# 期望输出：SGVsbG8=
wasmtime run --invoke 'build-message' mime.component.wasm
```

## 消费示例（Spin）

```rust
// 一个 Spin HTTP 触发器中，导入 mime 组件生成邮件字节
use wasi::http::types::*;
use mooncampaign::mime::mime_builder::{build_message, message, mailbox};

#[http_handler]
async fn handle_request(req: IncomingRequest, resp: ResponseOutparam) {
    let msg = message {
        from: mailbox { name: "Freshcia", email: "hello@freshcia.com" },
        subject: "=?UTF-8?B?...?=".to_string(),
        // ...
    };
    let eml = build_message(&msg);   // 标准 RFC 5322 字节流
    // 交给 SMTP / ESP 发送
}
```

## 说明

- `wit/mime.wit` 是接口的**权威定义**，已提交入库。
- `stub-forward-example.mbt` 展示生成的 stub 如何转发到 `@mime` 真实实现；wit-bindgen 不同版本的生成代码（类型名、路径）可能有差异，以实际生成为准。
- 生成的绑定与组件产物属于构建产物，不提交入库（与 `_build/` 一致）。
