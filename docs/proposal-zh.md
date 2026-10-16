# mooncampaign/mime —— RFC 5322 MIME 邮件消息构建库（申报书）

## 1. 基本信息

* 项目名称：mooncampaign/mime：RFC 5322 MIME 邮件消息构建库
* 参赛者：张思仪
* 联系方式：17188804556
* GitHub 仓库链接：[https://github.com/mw1696803-hub/mooncampaign](https://github.com/mw1696803-hub/mooncampaign)
* 项目方向：新生态项目建设（原创可复用库）
* 是否为原创项目：是（协议实现全部原创）

## 2. 项目简介

**项目定位：MoonBit 生态的 RFC 5322 / MIME 标准协议实现。**

把结构化邮件数据编码成标准 MIME 字节流（headers + multipart body + Content-Transfer-Encoding），可直接交给 SMTP 客户端或 ESP 发送。纯函数、无 I/O 依赖，编译成 Wasm 后可在浏览器、边缘函数或任何 MoonBit 运行时中使用。

**对标其他语言成熟生态库：**

| 参考库 | 语言/生态 | 性质 |
|---|---|---|
| `email.mime` | Python 标准库 | MIME 消息构建 |
| `nodemailer` | Node.js | MIME 消息构建 + SMTP |
| `lettre` | Rust | MIME 消息构建 + SMTP |
| **mooncampaign/mime** | **MoonBit** | **MIME 消息构建（本项目）** |

**实现的标准协议：**

| RFC | 内容 | 实现状态 |
|---|---|---|
| RFC 5322 | Internet Message Format（headers、折叠） | ✅ |
| RFC 2045 | MIME Part One（Content-Transfer-Encoding） | ✅ base64 + quoted-printable |
| RFC 2046 | MIME Part Two（multipart boundaries） | ✅ multipart/alternative |
| RFC 2047 | MIME Part Three（非 ASCII header 编码） | ✅ encoded-word (B 编码) |
| RFC 4648 | Base64 字母表 | ✅ |

**生态缺口（mooncakes.io 2026-10 检索）：**

MoonBit 生态已有 HTML 解析器（`moonbit-community/html`）、模板引擎（`moontemplate`、`mold`），但**没有 MIME 消息构建库**。任何需要在 MoonBit 中生成标准格式邮件的项目，都需要自己实现协议编解码——这是基础设施级的缺失。

**对 MoonBit 生态的贡献：**

① 补齐 MIME 协议这一互联网基础协议的 MoonBit 实现；② 纯函数/无 I/O，编译成 Wasm 后可在浏览器端邮件编辑器、边缘函数中使用；③ Golden fixture 测试验证字节级正确性，和 moonkafka 的协议编解码测试同等级别。

## 3. 预期使用场景

1. **任何需要在 MoonBit 中构建邮件消息的项目**：用 `moon add` 引入，直接得到 RFC 5322 标准输出，不用自己实现 MIME 编解码。

2. **Wasm 浏览器端邮件编辑器**：用户在网页上编辑邮件，Wasm 模块负责把内容编码成标准 MIME 格式。

3. **边缘函数邮件生成**：在 Cloudflare Workers / Spin 等 Wasm 运行时中，根据事件数据动态生成并发送通知邮件。

## 4. 拟实现的核心功能（已完成）

1. **Mailbox / Message 数据结构**：类型安全的邮件元数据模型
2. **Base64 编码器**：RFC 4648 标准，带 padding
3. **Quoted-printable 编码器**：RFC 2045 标准，76 字符软换行
4. **RFC 2047 encoded-word**：非 ASCII header 自动编码（=?UTF-8?B?...?=）
5. **Header 折叠**：RFC 5322 长 header 78 字符折行
6. **multipart/alternative 构建**：text/plain + text/html 双版本，boundary 自动生成
7. **Golden fixture 测试**：字节级正确性验证（base64 标准向量、QP 编码、完整消息结构）

**明确不做**：SMTP 客户端、IMAP、POP3、模板引擎、内容运营逻辑（这些是上层应用的事）。

## 5. 原创性说明

原创协议实现。mooncakes.io 检索确认：无现有包实现 MIME 消息构建。其他语言生态（Python/Node/Rust）均有成熟对标库，MoonBit 生态此层缺失。

## 6. 移植说明

不适用（无移植，协议实现全部原创）。

## 7. GitHub 仓库

[https://github.com/mw1696803-hub/mooncampaign](https://github.com/mw1696803-hub/mooncampaign)

* commits 持续更新中，核心 mime 包为独立功能模块；
* CI（GitHub Actions：moon check + moon test + moon build）已在 main 分支真实运行通过；
* 测试 75/75 通过；Apache-2.0 许可证；preferred_target=wasm。
