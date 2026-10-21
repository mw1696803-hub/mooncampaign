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



| 参考库                   | 语言 / 生态     | 性质                 |
| --------------------- | ----------- | ------------------ |
| `email.mime`          | Python 标准库  | MIME 消息构建          |
| `nodemailer`          | Node.js     | MIME 消息构建 + SMTP   |
| `lettre`              | Rust        | MIME 消息构建 + SMTP   |
| **mooncampaign/mime** | **MoonBit** | **MIME 消息构建（本项目）** |

**实现的标准协议：**



| RFC      | 内容                                                     | 实现状态                        |
| -------- | ------------------------------------------------------ | --------------------------- |
| RFC 5322 | Internet Message Format（headers、CRLF 行结束、78 字符折叠、日期格式） | ✅                           |
| RFC 2045 | MIME Part One（Content-Transfer-Encoding、76 列换行）        | ✅ base64 + quoted-printable |
| RFC 2046 | MIME Part Two（multipart boundaries）                    | ✅ alternative + mixed（含附件）  |
| RFC 2047 | MIME Part Three（非 ASCII header 编码）                     | ✅ encoded-word (B 编码)       |
| RFC 4648 | Base64 字母表                                             | ✅ 含 MIME 76 列分行版本           |

**生态缺口（mooncakes.io 2026-10 检索）：**

MoonBit 生态已有 HTML 解析器（`moonbit-community/html`）、模板引擎（`moontemplate`、`mold`），但**没有 MIME 消息构建库**。任何需要在 MoonBit 中生成标准格式邮件的项目，都需要自己实现协议编解码 —— 这是基础设施级的缺失。

**对 MoonBit 生态的贡献：**

① 补齐 MIME 协议这一互联网基础协议的 MoonBit 实现，且**构建 + 解析双向闭环**（对标库 email.mime / lettre 均为双向）；② 纯函数 / 无 I/O，编译成 Wasm 组件后可在浏览器端邮件编辑器、边缘函数（Spin/Wasmtime）中使用，已提供 WIT 组件接口定义（`wit/mime.wit`）与构建示例；③ Golden fixture 测试验证字节级正确性（CRLF 行结束、header 注入防护、编码-解码往返），和 moonkafka 的协议编解码测试同等级别。

## 3. 预期使用场景



1. **任何需要在 MoonBit 中构建邮件消息的项目**：用 `moon add` 引入，直接得到 RFC 5322 标准输出，不用自己实现 MIME 编解码。

2. **Wasm 浏览器端邮件编辑器**：用户在网页上编辑邮件，Wasm 模块负责把内容编码成标准 MIME 格式。

3. **边缘函数邮件生成**：在 Cloudflare Workers / Spin 等 Wasm 运行时中，根据事件数据动态生成并发送通知邮件。

## 4. 拟实现的核心功能（已完成）

**主包&#x20;**`mime/`**（协议实现）：**

**协议编码层：**



1. **Base64 编码器**：RFC 4648 标准，带 padding，支持 Bytes / 字符串输入；MIME body 自动 76 列分行（RFC 2045）

2. **Quoted-printable 编码器**：RFC 2045 标准，76 字符软换行（`=\r\n`）

3. **RFC 2047 encoded-word**：非 ASCII header 自动编码（=?UTF-8?B?...?=），encoded-word 保持单行

**协议解码层（RFC 5322 解析，构建的逆过程）：**

4\. **Base64 解码器**：RFC 4648 反向，忽略行分隔符与 padding

5\. **Quoted-printable 解码器**：RFC 2045 反向，处理软换行与 =XX 转义

6\. **RFC 2047 encoded-word 解码**：=?UTF-8?B?...?= 还原为可读文本（中文 subject 往返验证）

7\. **Header 解析**：header 块解析 + 折叠续行展开（RFC 5322 unfolding），大小写不敏感字段查找

8\. **Multipart 拆分**：按 boundary 切分 MIME 各部分

**消息结构层：**

9\. **Mailbox / Message 数据结构**：类型安全的邮件元数据模型，支持 To/Cc/Bcc 多收件人

10\. **RFC 5322 日期格式化**：Sakamoto 星期计算 + 时区偏移（+0800/-0500）

11\. **Header 折叠**：RFC 5322 长 header 78 字符折行（CRLF + 空格续行）

12\. **multipart 嵌套构建**：multipart/alternative（text+html）与 multipart/mixed（含附件），boundary 自动生成

13\. **附件支持**：二进制 payload base64 编码 + Content-Disposition

14\. **自定义 headers**：X-\*、List-Unsubscribe 等透传

**正确性与安全：**

15\. **CRLF 行结束**：全部输出严格 CRLF（RFC 5322），零裸 LF（字节级验证）

16\. **Header 注入防护**：`sanitize_header_value` / `has_injection_chars`，subject、收件人姓名 / 邮箱、自定义 header 名值、附件文件名均中和 CR/LF，杜绝伪造 header

17\. **Golden fixture 测试**：mime 包 66 个字节级测试（base64/QP/encoded-word 编解码标准向量、日期已知星期、CRLF 合规、注入中和、健壮性/边界、**构建→解析往返**——中文 subject 经 RFC 2047 编码再解码还原一致）+ Python `email.mime` 交叉验证（19/19 往返检查通过）+ `moon bench` 性能基准（base64 / QP / build_message 吞吐）

18\. **Wasm 组件接口（WIT）**：`wit/mime.wit` 定义组件接口（build-message /base64-encode /quoted-printable-encode），可编译为 Wasm 组件部署到 Spin/Wasmtime 等边缘运行时

**仓库结构**：`mime/` 为独立可复用协议库（含 WIT 组件接口）；`content-tools/` 为构建于 mime 之上的内容编排示例层（领域模型、门禁、QA），演示库的实际用法。

**明确不做**：SMTP 客户端、IMAP、POP3、模板引擎（这些是上层应用的事）。

## 5. 原创性说明

原创协议实现。mooncakes.io 检索确认：无现有包实现 MIME 消息构建。其他语言生态（Python/Node/Rust）均有成熟对标库，MoonBit 生态此层缺失。

## 6. 移植说明

不适用（无移植，协议实现全部原创）。

## 7. GitHub 仓库

[https://github.com/mw1696803-hub/mooncampaign](https://github.com/mw1696803-hub/mooncampaign)



* 32 commits，mime 为主包（协议实现 + RFC 5322 解析器），content-tools 为上层示例层；

* CI（GitHub Actions：moon check + moon test + moon build）已在 main 分支真实运行通过；

* 测试 129/129 通过（mime 66 个字节级测试 + Python email.mime 交叉验证 19/19 + moon bench 基准）；Apache-2.0 许可证；preferred\_target=wasm。