# S-Map Codebase Intelligence MCP Server

Local MCP server tích hợp Antigravity để agent kiểm soát toàn bộ S-Map Flutter codebase.

## Cài đặt nhanh

```powershell
cd "tools\codebase_mcp"
pip install -r requirements.txt
python server.py  # test chạy thử
```

## Kiểm tra cài đặt

```powershell
python server.py --help
```

## Tools (8 tools, 3 phases)

### Phase 1 – Dart Analyzer
| Tool | Mục đích | Token cost |
|------|---------|-----------|
| `get_violations_summary` | Tổng quan violations từ `dart analyze` | ~200–600 |
| `run_dart_analyze` | Full violations list | ~200–2000 |

### Phase 2 – Repo Map & Symbol Graph
| Tool | Mục đích | Token cost |
|------|---------|-----------|
| `get_repo_map` | Aider-style structural overview toàn bộ 157 files | ~1500 (configurable) |
| `query_symbol` | Tìm định nghĩa + usages của class/function | ~100–300 |
| `get_file_dependencies` | Import relationships của 1 file | ~100–200 |
| `get_graph_stats` | Stats: circular deps, symbol count | ~100–400 |

### Phase 3 – Architecture Rules
| Tool | Mục đích | Token cost |
|------|---------|-----------|
| `check_architecture_rules` | Quét vi phạm layer + circular deps + god files | ~300–1500 |
| `get_architecture_report` | Tương tự, filter theo layer | ~200–800 |

## Layer Architecture S-Map

```
models        → Không import gì từ project
constants     → Không import models, logic
interfaces    → Chỉ import models
services      → Implements interfaces, không import screens/repos/blocs
repos         → Compose services qua interfaces, không import screens/blocs
commons_logic → commons/blocs + cubits, không import services trực tiếp
screens       → Presentation layer, inject service via DI
```

## Antigravity Integration

MCP server nằm trong repository để có thể khôi phục cùng source code. Cấu hình
MCP cho từng ứng dụng agent vẫn là cấu hình cục bộ của máy và cần trỏ tới
`tools/codebase_mcp/server.py` sau khi clone.

## Cấu trúc thư mục

```
tools/codebase_mcp/
├── server.py                 # FastMCP entry point (8 tools)
├── requirements.txt          # Dependencies
├── config/
│   └── architecture.yaml     # Layer rules S-Map
├── analyzers/
│   ├── dart_analyzer.py      # Phase 1: dart analyze wrapper
│   ├── repo_map.py           # Phase 2: Aider-style PageRank map
│   ├── symbol_graph.py       # Phase 2: Symbol graph + networkx
│   └── layer_checker.py      # Phase 3: Layer violation detector
└── utils/
    └── dart_parser.py        # tree-sitter-dart + regex fallback
```

## Workflow khuyến nghị cho agent

```
1. get_violations_summary()           → Xem health tổng quan
2. get_repo_map(focus_files=[...])    → Hiểu cấu trúc (~1500 tokens)
3. check_architecture_rules()         → Phát hiện vi phạm
4. query_symbol("ClassName")          → Deep dive vào 1 symbol cụ thể
5. Đọc file vi phạm → Sửa → run_dart_analyze() → Verify
```
