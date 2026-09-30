# Dify Track A · 多模态文档转写

把上传的文档先交给视觉语言模型转写成统一 Markdown，再进入 Dify 原有的清洗与向量化流程。原始文档里的图片链接在转写结果中逐字保留，前端渲染不受影响。

本仓库是 **Dify 1.17.0 的补丁包**，不是 Dify 的完整副本。它只包含 Track A 相关的改动，用于在任意一份干净的 Dify 1.17.0 检出上复现这套解析逻辑。

## 包结构

```
dify-track-a/
├── README.md                          本文件
├── patches/
│   ├── 01-track-a.patch               Track A 主补丁，11 个文件
│   └── 02-weaviate-delete-fix.patch   Weaviate 删除修复，独立可选
├── files/                             改动后的完整文件，与仓库相对路径一致
├── env/
│   └── transcribe.env.snippet         docker/.env 需要追加的配置
└── scripts/
    ├── apply.sh / rollback.sh         Linux、macOS
    └── apply.ps1 / rollback.ps1       Windows
```

`patches/` 与 `files/` 是同一份改动的两种形态。补丁适合在已有仓库上增量应用，文件副本适合直接覆盖，或在无法使用 git 的环境里手工比对。

## 改动清单

补丁基于 Dify 1.17.0 标签（commit `09a855dcef`）生成，仅对该版本可以干净应用。

Track A 主体，11 个文件：

| 文件 | 类型 | 作用 |
| --- | --- | --- |
| `api/core/rag/extractor/transcribe_service.py` | 新增 | 转写服务主体，对外只暴露 `is_transcription_enabled()` 与 `transcribe_documents()` |
| `api/core/rag/extractor/pptx_extractor.py` | 新增 | pptx 解析，含装饰性图片的两遍视觉判定 |
| `api/core/rag/extractor/extract_processor.py` | 修改 | 解析入口接入转写，`.pptx` 分支挂到 `PptxExtractor` |
| `api/core/rag/extractor/pdf_extractor.py` | 修改 | 按内容 sha1 去重，同一 Logo 不再逐页重复落盘 |
| `api/core/rag/splitter/fixed_text_splitter.py` | 修改 | Markdown 结构感知切分，标题栈与章节路径注入 |
| `api/core/rag/index_processor/index_processor_base.py` | 修改 | 切分器调用处传入 `markdown_aware=True` |
| `api/core/indexing_runner.py` | 修改 | 同上，另一处切分器调用点 |
| `api/configs/feature/__init__.py` | 修改 | 新增 10 个 `TRANSCRIBE_*` 配置项，默认全部关闭 |
| `api/core/llm_generator/prompts.py` | 修改 | 新增 `DEFAULT_TRANSCRIBE_PROMPT` |
| `api/constants/__init__.py` | 修改 | 文档扩展名白名单加入 `pptx` |
| `api/tests/unit_tests/core/rag/splitter/test_text_splitter.py` | 修改 | 切分器用例，6 个新增 |

Weaviate 修复，1 个文件，与 Track A 没有依赖关系：

| 文件 | 类型 | 作用 |
| --- | --- | --- |
| `api/providers/vdb/vdb-weaviate/src/dify_vdb_weaviate/weaviate_vector.py` | 修改 | 写入时优先使用 `metadata["doc_id"]` 作为对象 id，删除时按 `doc_id` 属性批量清理 |

原实现写入用内容哈希（UUID5）生成对象 id，删除时收到的却是 Dify 节点 id，两者永远对不上，重复索引会不断累积无人引用的残留向量。改动后写入与删除共用同一个 id，并在删除失败时打 warning 而不是静默吞掉。

如果只需要转写能力，可以不应用 `02-weaviate-delete-fix.patch`。

## 运行前提

- 一份 Dify 1.17.0 的完整检出，工作区干净
- 一个可用的视觉模型，且已在 Dify 控制台完成 provider 配置与 API Key 绑定
- `python-pptx` 无需额外安装，1.0.2 已经在 `api/uv.lock` 中锁定

## 安装

两种方式任选其一。

### 补丁法

Linux 或 macOS：

```bash
bash scripts/apply.sh /path/to/dify
```

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\apply.ps1 D:\dify
```

脚本会先 `git apply --check` 预检，通过后再实际应用，最后打印改动文件列表。手工执行等价于：

```bash
cd /path/to/dify
git apply /path/to/dify-track-a/patches/01-track-a.patch
git apply /path/to/dify-track-a/patches/02-weaviate-delete-fix.patch
```

补丁以 LF 存储，仓库若开启 `core.autocrlf=true`，检出时会自动转成 CRLF，不需要额外处理。

### 覆盖法

把 `files/` 下的目录树整体拷到检出根目录，覆盖同名文件：

```bash
cp -r dify-track-a/files/. /path/to/dify/
```

目录结构与仓库一致，例如 `files/api/core/rag/extractor/transcribe_service.py` 对应 `api/core/rag/extractor/transcribe_service.py`。这种方式不校验版本，适用于目标不是 1.17.0、补丁无法直接应用的场合，需要自行确认上下文一致。

## 环境变量

`docker/.env` 被 `docker/.gitignore` 的 `*.env` 规则排除，因此不在补丁里。把 `env/transcribe.env.snippet` 的内容手工追加到 `docker/.env` 末尾：

```
TRANSCRIBE_ENABLED=true
TRANSCRIBE_MODEL_PROVIDER=langgenius/openai_api_compatible/openai_api_compatible
TRANSCRIBE_MODEL_NAME=qwen3.8-27b
TRANSCRIBE_LANGUAGE=中文
TRANSCRIBE_IMAGE_DETAIL=low
TRANSCRIBE_MAX_CHARS_PER_CHUNK=12000
TRANSCRIBE_MAX_CHUNKS=0
TRANSCRIBE_PAGE_OFFSET=1
```

各变量的含义：

| 变量 | 默认值 | 含义 |
| --- | --- | --- |
| `TRANSCRIBE_ENABLED` | `false` | 总开关，关闭时 `transcribe_documents()` 直接返回 `None`，走原生解析 |
| `TRANSCRIBE_MODEL_PROVIDER` | 空 | provider id，需与控制台中已配置的 provider 一致 |
| `TRANSCRIBE_MODEL_NAME` | 空 | 模型名，需是所选 provider 下的视觉模型 |
| `TRANSCRIBE_PROMPT` | 空 | 自定义提示词，留空使用 `DEFAULT_TRANSCRIBE_PROMPT`，支持 `{language}` 占位 |
| `TRANSCRIBE_LANGUAGE` | 空 | 输出语言，留空跟随原文 |
| `TRANSCRIBE_TEMPERATURE` | 空 | 采样温度，留空用模型默认 |
| `TRANSCRIBE_IMAGE_DETAIL` | `low` | 图片细节档位 |
| `TRANSCRIBE_MAX_CHARS_PER_CHUNK` | `12000` | 超长文档的分片阈值，转写按片进行 |
| `TRANSCRIBE_MAX_CHUNKS` | `0` | 分片数上限，`0` 表示不限制 |
| `TRANSCRIBE_PAGE_OFFSET` | `1` | 页码起始值，用于生成 `<!-- page: n -->` 标记 |

`TRANSCRIBE_MODEL_PROVIDER` 与 `TRANSCRIBE_MODEL_NAME` 留空时转写会被跳过并回落到原生解析，不会报错。

## 构建与重启

配置项由 api 与 worker 读取，两个服务都要重建：

```bash
docker compose build api worker
docker compose up -d api worker
```

## 验证

确认配置已生效：

```bash
docker compose exec api python -c "from configs import dify_config; print(dify_config.TRANSCRIBE_ENABLED)"
```

跑切分器用例：

```bash
docker compose exec api uv run pytest tests/unit_tests/core/rag/splitter/test_text_splitter.py -q
```

功能侧：在知识库中上传一份带图片的 pptx 或 pdf，索引完成后查看 api 日志中的转写记录，并确认文档分段里出现了 `【章节路径】` 前缀、页面标记 `<!-- page: n -->`。

## 回滚

```bash
bash scripts/rollback.sh /path/to/dify
```

默认反向应用两个补丁，保留你在同一仓库里的其他改动。加 `--hard` 会额外执行 `git reset --hard` 并清理新增文件所在目录，回到干净的 HEAD。

若只想关掉转写而保留代码，把 `TRANSCRIBE_ENABLED` 改成 `false` 并重启 api 与 worker 即可。

## 边界与注意事项

- **不含 Track B。** 包内只有 Track A，`fixed_text_splitter.py` 里没有任何语义分块逻辑。`index_processor_base.py` 与 `indexing_runner.py` 中留有 4 处 `Track A+B 改造` 注释，是历史命名遗留，不影响行为。
- **失败不阻断。** 转写服务不向上抛异常，模型超时、provider 缺失、返回内容不合规都会被拦下并回落到原生解析结果。
- **图片链接是硬约束。** 转写输出若丢失原文中的图片链接，该结果会被整体丢弃。唯一例外是装饰性图片，它们在切分前就被剥离。装饰性判定分两处：pdf 侧按内容 sha1 去重，pptx 侧用视觉模型两遍判定。
- **`docker-compose.override.yaml` 不在包内。** 该文件被根目录 `.gitignore` 排除，属于部署环境配置，与本次改动无关。
- **补丁版本敏感。** `01-track-a.patch` 只针对 1.17.0 生成，其他版本请用覆盖法并自行核对上下文。
