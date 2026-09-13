# ClinTrace

ClinTrace 是一个以 MIT LangGraph library 为编排基底、自建 FastAPI runtime
的慢病用药安全 Agent 本科毕设。系统提供真实 thread/run/SSE/checkpoint、
Chat/Embedding/Reranker 模型控制、上传式 RAG、中文/英文 OCR、确定性安全
规则、引用门禁和人工审核闭环。

本项目只用于教学与研究，不用于诊断、处方、调整剂量或替代医生。当前规则
和 benchmark 未经医生或临床药师审核；工程测试通过不代表临床安全。

## 当前状态

| 能力          | 当前实现                                                                                                                                      |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Agent runtime | 自建 FastAPI runtime，持久化 threads、runs、SSE events、checkpoints、history、cancel、interrupt/resume；生产 graph 固定真实模型版本和知识快照 |
| 模型控制      | Chat、Embedding、Reranker 独立版本；加密凭据、自动发现、手填兜底、连接测试、CAS 激活/停用/回滚和审计                                          |
| 上传与 OCR    | MinIO quarantine、ClamAV、PDF/DOCX/TXT/MD、`pdftoppm`、Tesseract `chi_sim+eng`、异步 job 状态和失败关闭                                       |
| 持久 RAG      | PostgreSQL/pgvector、版本化 BM25、RRF、可选真实 Reranker、原子 snapshot、引用 handle、更新和删除门禁                                          |
| 身份与权限    | 本地毕设会话、短期内部 JWT、RBAC、资源所有权、PostgreSQL RLS；OIDC 是可替换增强项                                                             |
| Web 工作台    | 咨询、历史、人工审核、知识库、模型配置、系统状态和规则/benchmark 视图均连接真实 BFF/API                                                       |
| 本地交付      | Caddy、Next.js、API、Worker、PostgreSQL、Redis、MinIO、ClamAV、Ollama 的 Docker Compose 拓扑，支持健康检查和基础备份恢复                      |

本地 Embedding 默认使用 Compose 内部 Ollama `bge-m3:567m`；启动任务校验
固定模型 manifest，并在首次启动时通过真实 1024 维向量探针后才创建和激活
production 绑定。已有管理员 Embedding 绑定不会被覆盖。Chat 已预置 Luunix
OpenAI-compatible 地址和 `gpt-5.6-sol` 正式 model ID；model discovery、
forced tool-call 探针及真实 LangGraph Agent/RAG 已完成功能验证。2026-07-27
还在本地 Compose 真实验证了 image-only PDF 的扫描、`chi_sim+eng` OCR、
1024 维 Embedding、BM25 + pgvector + RRF 检索、页码定位和删除失效闭环。
对话中暴露的 Chat Secret 最终交付前仍需轮换，Reranker 尚未指定；当前不
声称真实回答质量或临床安全已经验收。

## 运行拓扑

```text
Browser
  -> Caddy (唯一宿主机入口)
     -> Next.js Web/BFF
        -> FastAPI self-hosted LangGraph runtime
        -> Model Control API / Knowledge API
           -> PostgreSQL + pgvector
           -> Redis
           -> MinIO quarantine/clean objects
           -> ClamAV + ingestion worker + Tesseract
           -> Luunix Chat / internal Ollama BGE-M3 / optional Reranker
```

只有 Caddy 默认绑定 `127.0.0.1`。Provider Secret、内部 JWT、数据库密码和
对象存储凭据只通过服务端环境或 Docker secrets 注入，不进入浏览器、仓库、
checkpoint 或审计 metadata。

## Docker Compose 启动

前置条件：Docker Desktop 或兼容的 Docker Engine + Compose plugin。

```sh
cp deploy/.env.local.example deploy/.env.local
deploy/bin/generate-local-secrets.sh
docker compose \
  --env-file deploy/.env.local \
  -f deploy/compose.yaml \
  -f deploy/compose.local.yaml \
  up --build --wait
```

默认地址：`http://127.0.0.1:8080`。

```sh
docker compose \
  --env-file deploy/.env.local \
  -f deploy/compose.yaml \
  -f deploy/compose.local.yaml \
  ps
```

停止、重置、备份和恢复命令见
[`deploy/README.md`](deploy/README.md)。本地 Compose 是毕设交付环境，不包含
公网域名、TLS 证书、真实服务器部署或高可用承诺。

## 接入模型 API

### 本地 Embedding

Compose 首次启动会下载固定的 `bge-m3:567m` 到 `ollama_models` volume，校验
manifest SHA-256，并调用 `http://embedding:11434/v1/embeddings` 验证一条
1024 维有限向量。正式 Ollama 服务不发布宿主机端口，只连接内部 `models`
网络；下载任务单独使用一次性出站网络。任一校验失败都会阻断 API/Worker。

### Chat 与可选 Reranker

管理台允许在创建首个配置版本前提交 Provider、base URL、认证方式和临时
Secret，直接调用模型列表端点自动发现 model ID。Provider 不支持枚举、无权
访问或协议不兼容时，界面保留手工 model ID。

推荐顺序：

1. 分别选择 Chat、Embedding、Reranker capability。
2. 输入 Provider、HTTPS base URL、认证方式和只写 Secret。
3. 自动发现模型；失败时手工填写 Provider 返回的 model ID。
4. 保存不可变版本并执行对应能力测试。
5. 测试成功后激活；运行中会固定具体配置版本，不随管理台切换漂移。

Chat 测试必须返回真实 tool call；Embedding 测试记录并校验维度；Reranker
测试校验候选排序。自定义 Provider 主机还必须加入
`CLINTRACE_PROVIDER_HOST_ALLOWLIST`，生产环境拒绝 HTTP、loopback、metadata、
link-local 和未批准主机。Docker Desktop 使用合成地址代理公共 DNS 时，可在
`CLINTRACE_PROVIDER_DNS_PROXY_NETWORKS` 中显式配置
`198.18.0.0/15,fdfe:dcba:9876::/48`；该配置只接受上述 Docker 合成范围或其
子网，且不会绕过 HTTPS 与精确主机白名单。

Luunix Chat 使用 `https://luunix.com/v1`。对话中曾提交的 Secret 应视为已
暴露并先轮换；新 Secret 只通过管理台的只写字段录入，不写入 `.env`、仓库、
日志或项目文档。不要向未经确认数据处理边界的外部 Provider 发送真实患者数据。

## 上传式 RAG

```text
uploading -> quarantined -> scanning -> parsing -> ocr -> chunk
          -> embedding -> indexing -> ready / failed
```

- 浏览器通过短期预签名 URL 上传到隔离 bucket。
- Worker 核对哈希、MIME 和文件签名，再执行 ClamAV、解析和必要的 OCR。
- OCR 默认使用 `chi_sim+eng`，保存引擎、版本、语言和页码定位。
- 切块后必须使用已激活的真实 Embedding 配置；缺失时进入
  `waiting_dependency` / `awaiting_embedding`，不会伪造向量或把已完成的扫描、
  OCR 和切块标成失败。配置激活后由管理员续跑固定版本的 continuation job。
- 检索使用版本化 BM25 + pgvector + RRF；启用 Reranker 时记录前后顺序和版本。
- 删除文档后新检索和 citation evidence loader 都不能再解析对应正文。

版本化中英 image-only PDF OCR 夹具位于
[`datasets/fixtures/ocr-mixed-v1/`](datasets/fixtures/ocr-mixed-v1/)。

本地验收使用其中的 `ocr-mixed-image-only.pdf`：入库任务完成于 `index`，
OCR provenance 为 Tesseract `5.3.0` / `chi_sim+eng`。唯一短语检索同时获得
BM25 rank 1 与 pgvector rank 1，并解析到第 1 页；通过公开 BFF 删除文档后，
对原已退役 snapshot 的新检索为 0 命中，citation evidence loader 也返回 0 行。

## 开源与公开数据

`datasets/manifest.json` 固定了 URL、版本、许可、字节数、SHA-256 和项目用途：

- Synthea 合成病例：权限、入库和 E2E 背景数据，不作为安全规则 ground truth。
- openFDA drug label：可复现的药品标签 RAG 输入。
- DailyMed 固定 SETID/version：原始 SPL 版本回链。
- Tesseract 官方英文 gold 与项目自有中英 OCR fixture：OCR 回归。

```sh
make data_list
make data_fetch DATASET_IDS="synthea-sample-csv-20260630 tesseract-phototest"
```

公开数据不等于临床验证。许可或再分发边界不清晰的内容只下载和校验，不重新
声明为 ClinTrace 自有数据。

### 固定 DailyMed 知识库

项目已固定并真实验证 16 份慢病常用药标签：Metformin、Lisinopril、
Simvastatin、Norvasc、Cozaar、Glucotrol XL、Lipitor、Jardiance、
Aldactone、Synthroid、Plavix、Lantus、Eliquis、Coreg、Lasix 和 Warfarin。
完整的下载、校验、准备、导入和终态等待命令见
[`datasets/README.md`](datasets/README.md)；逐项 SETID/version、原始 SHA、
转换 SHA、当前 snapshot 和检索结果见
[`REF-20260727-dailymed-knowledge-corpus.md`](.agentdocs/references/REF-20260727-dailymed-knowledge-corpus.md)。

当前同版本重建库实测为 16 个 ready 文档、567 个 active chunks，活动快照
确实覆盖 16 个文档版本；16 条英文关键词 smoke case 的目标来源均为 rank 1。
中文查询的目标来源只到 rank 2，无关的量子计算查询仍会返回药品结果，因此
低相关度拒答阈值、章节语义切块和可审计 RAG gold set 仍是明确开放项，不能
把 smoke 满分写成“结果可靠”。

## 本地开发与验证

Python 依赖使用 `uv`，前端依赖使用 `pnpm@10.5.1`。

```sh
uv sync --dev
uv run pytest tests
uv run ruff check .
uv run ruff format . --check
uv lock --check

cd frontend
pnpm install --frozen-lockfile
pnpm format:check
pnpm exec tsc --noEmit
pnpm lint
pnpm build
```

PostgreSQL/RLS 集成测试需要指向专用 `*_test` 数据库：

```sh
CLINTRACE_TEST_DATABASE_URL='postgresql://<user>:<password>@<host>/<name>_test' \
  uv run pytest tests/integration_tests/test_postgres_foundation.py \
    tests/integration_tests/test_model_control_integrity.py
```

确定性规则 benchmark：

```sh
make benchmark
```

`benchmark/baseline.json` 是版本化规则基线，`benchmark/latest.json` 是忽略的
本地结果。它不衡量完整 RAG、真实模型回答或临床安全。

## 上游与许可

- Backend baseline: [`langchain-ai/react-agent`](https://github.com/langchain-ai/react-agent) @ `7d1f9832f56d6d29ad9ae248caf0b263c5460145`
- Retrieval reference: [`langchain-ai/retrieval-agent-template`](https://github.com/langchain-ai/retrieval-agent-template) @ `d4f536236f8d5a0b0fd93fd6addd341548b94483`
- Web UI baseline: [`langchain-ai/agent-chat-ui`](https://github.com/langchain-ai/agent-chat-ui) @ `d02580a1058d41fe579e477eb4f8706fabe6f09a`

根 [`LICENSE`](LICENSE)、[`frontend/LICENSE`](frontend/LICENSE) 和
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) 保留上游 MIT 版权与归属；
本项目不把上游代码谎称为原创实现。

## 项目记录

需求原话、决策、架构、数据来源和实施门禁入口位于
[`.agentdocs/index.md`](.agentdocs/index.md)。当前生产化工作计划是
[`.agentdocs/workflow/260719-production-system.md`](.agentdocs/workflow/260719-production-system.md)。
