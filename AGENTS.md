# 项目协作规则

- 默认使用简体中文沟通和维护项目文档。
- 继续历史需求、讨论架构、处理跨模块任务或复核既有决策前，先读取 `.agentdocs/index.md`。
- 用户提供与项目有关的对话材料时，将可确认的原话记录到 `.agentdocs/conversations/`；将明确决定与仍待确认的问题分开记录到 `.agentdocs/decisions/`。
- 不把 OCR 猜测、助手推断或未获用户确认的建议写成已接受决策。无法可靠识别的内容必须标记为 `unverified`。
- 新增、移动或归档上述文档时，同步更新 `.agentdocs/index.md` 及对应子目录索引。
- 不在项目文档中保存 Token、密码、Cookie、私钥或无关个人信息。

## 上游工程约束

- 后端以 `langchain-ai/react-agent@7d1f9832f56d6d29ad9ae248caf0b263c5460145` 为基线；`langgraph.json` 中的 `clintrace` graph 和 HTTP app 是当前开发入口。
- `langchain-ai/retrieval-agent-template@d4f536236f8d5a0b0fd93fd6addd341548b94483` 是 RAG 参考来源。只有相关代码和验证实际进入当前工作树后，才能声明对应能力已经集成。
- `frontend/` 以 `langchain-ai/agent-chat-ui@d02580a1058d41fe579e477eb4f8706fabe6f09a` 为基线；保留 LangGraph SDK 的 thread、stream、interrupt 和 tool-call 契约，除非有迁移测试支持，不做纯改名式批量替换。
- Python 依赖和命令使用 `uv`：安装用 `uv sync`，本地 graph 用 `uv run langgraph dev`，后端验证运行相关 pytest 与 Ruff；具体范围以当前 `Makefile` 和 `pyproject.toml` 为准。
- 前端依赖和命令使用 `pnpm`：安装优先 `pnpm install --frozen-lockfile`，改动运行相关 lint/format check 和 `pnpm build`；只使用 `frontend/package.json` 中真实存在的脚本。
- 医疗 RAG 必须保存来源、版本和稳定定位；通用 web search 不得标成医疗知识库检索。
- 默认 BM25 top-k 为 5；触发规则的必要证据缺失时必须通过受控规则证据 ToolNode 补齐，不能仅扩大 top-k 或绕过引用门禁。
- 10-15 条运行时安全规则必须作为模型输出之外的确定性 graph 节点或等价执行层实现，不能只写进 system prompt。
- 自定义 HTTP 路由保持只读，但 CORS 必须覆盖 LangGraph SDK 的 thread/run 所需方法；修改 middleware 后运行 SDK preflight 回归与真实浏览器联调。
- `benchmark/baseline.json` 是版本化规则基线，`benchmark/latest.json` 是忽略的本地结果；规则 benchmark 不得表述为临床、完整 RAG 或真实模型验证。
- 未取得真实 API、临床规则审核和 benchmark 阈值前，不宣称真实回答质量、临床安全性或验收指标已经通过。
- Secret 只从本地或部署环境注入，不写入仓库、日志、前端公开变量或 `.agentdocs`。
- 保留根 `LICENSE`、`frontend/LICENSE` 和 `THIRD_PARTY_NOTICES.md` 中的上游版权与 MIT 归属；不把上游代码谎称为原创实现。
