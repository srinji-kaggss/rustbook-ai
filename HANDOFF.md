# rustbook-ai — Context Handoff

> **Status**: FUNCTIONAL — all gates pass, 83/83 tests green  
> **Version**: v0.3.1  
> **Date**: 2026-07-19  
> **Binary**: `target/release/rustbook-ai` (arm64 Mach-O, ~4.3 MB)

## What This Is

An AI-first computational notebook in Rust. Mouse-driven TUI (ratatui + crossterm), DAG-based cell graph (petgraph), Rhai embedded scripting engine, structured JSON command protocol for AI agents.

## Quick Start

```bash
cd /Users/srinji/rustbook-ai
cargo run --release
```

**Keybindings**:
- `j/k` or `↑/↓` — navigate cells
- `i` or `Enter` — edit cell (Esc to exit)
- `Ctrl+E` or `e` — execute cell
- `n` — new code cell
- `m` — new markdown cell
- `d` — delete cell
- `a` — AI intent bar (natural language or JSON commands)
- `s` — generate LLM context snapshot → `/tmp/rustbook_context.md`
- `Ctrl+S` — save notebook → `/tmp/rustbook_notebook.json`
- `Ctrl+O` — load notebook
- `q` — quit

**Mouse**: Click toolbar buttons (▶ ✕ ▲ ▼), right-click for context menu, drag headers to reorder, scroll to navigate.

## Architecture

```
App
├── CellGraph (petgraph::StableGraph)
│   ├── Cell[] — code, output, staleness, checksums
│   ├── symbol_table: HashMap<symbol → (NodeIx, type_hint)>
│   ├── display_order: Vec<NodeIx> (toposort)
│   ├── system_logs: Vec<String> (execution audit trail)
│   └── exec_counter: usize
├── SecuritySandbox
│   ├── Rhai Engine (eval disabled, op limit, string limit)
│   └── isolation_rules: Vec<String> (content-based blocking)
├── Scope<'static> (Rhai variable state)
├── ContextEngine → LLM-optimized markdown snapshots
├── IntentRouter → natural language → cell graph mutations
└── ReactiveNotebookEngine (public API wrapper)
```

## Gate Status

| Gate | Result |
|------|--------|
| `cargo build --release` | 0 errors |
| `cargo fmt --all -- --check` | Clean |
| `cargo clippy --release` | 0 errors |
| Integration tests (original) | 57/57 |
| MatrixEvalSuite (gemini spec) | 26/26 |

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `engine.disable_symbol("eval")` | Rhai's `eval()` allows arbitrary code execution — must be disabled |
| Edge direction: dependency→dependent | `def_node → use_node` so toposort puts definitions before uses |
| Semicolon-split for `extract_definitions` | `let a = 1; let b = 2;` on one line needs per-statement parsing |
| Transitive closure for staleness | BFS from edited node through all transitive dependents |
| Best-effort compile in `update_cell_code` | Don't block DAG updates for valid Rhai with unresolved cross-references |
| Content-based isolation rules | Block `std::fs::write`, `/etc/passwd`, `std::process`, `std::net`, `std::os` in cell code |
| `memory_sandbox_checksum: u64` | Monotonic counter for AI agent integrity verification |

## New in v0.3.1 (Production Hardening)

1. **`EvalError` enum** — 5 typed error variants matching gemini evaluation spec
2. **`UserProfile` enum** — 4 interaction profiles (DeepFocusArchitect, AdhdExplorer, AutonomousAgent, SecOpsAuditor)
3. **`ReactiveNotebookEngine`** — unified public API wrapping CellGraph + SecuritySandbox + Scope
4. **`MatrixEvalSuite`** — structured test runner validating all 4 user profiles
5. **Content-based sandbox** — `isolation_rules` in SecuritySandbox block dangerous patterns
6. **System logs** — execution audit trail recorded per-cell, included in context snapshots
7. **Persistence** — save/load notebook state to/from JSON (`Ctrl+S` / `Ctrl+O`)
8. **Context snapshot enrichment** — system logs now appear in LLM-optimized markdown

## Known Limitations

1. **Display index instability**: `App.selected: usize` can point to wrong cell after `recompute_order()`. Fix: track `selected_node: NodeIx`.
2. **Rhai Scope not cleaned**: When definitions are removed, Rhai `Scope` retains old values. Rhai has no `Scope::remove()` API.
3. **No `.ipynb` import/export**, no syntax highlighting, no rich output (images), no nested-`let` extraction.
4. **`ReactiveNotebookEngine` not wired into TUI `App`** — exists as public API for external consumers. TUI uses internal components directly.

## AI Command Protocol

AI agents interact via JSON commands. Write to `/tmp/rustbook_ai_cmd.json` (polled every 500ms). Responses appear in `/tmp/rustbook_ai_resp.json`.

Supported commands:
- `{"command":"create_cell","type":"code","code":"...","after":0}`
- `{"command":"execute_cell","cell_id":2}`
- `{"command":"execute_all_stale"}`
- `{"command":"get_state"}` → full notebook state
- `{"command":"get_context"}` → LLM-optimized markdown snapshot
- `{"command":"delete_cell","cell_id":2}`
- `{"command":"restart_kernel"}`
- `{"command":"set_cell_code","cell_id":2,"code":"..."}`

## File Layout

```
rustbook-ai/
├── Cargo.toml          # 6 deps: ratatui, crossterm, rhai, petgraph, serde, serde_json
├── Cargo.lock
├── HANDOFF.md           # This file
├── .gitignore
└── src/
    └── main.rs          # 3,439 lines — single-file implementation
```

## Test Suites

- `/tmp/test_eval/` — Original 57-test integration suite (`cargo run --release --bin rustbook-eval`)
- `/tmp/test_eval/src/matrix_eval.rs` — 26-test MatrixEvalSuite (`cargo run --release --bin matrix-eval`)

## Invariants

- `App.selected` is always a valid index into `graph.display_order`
- `App.scroll` never exceeds `total_height - viewport_height`
- Symbol table is always consistent with cell `defined_symbols` sets
- Staleness is transitive: if A→B→C and A is edited, both B and C are stale
- Mutex poisoning is impossible: sandbox callbacks only `push_str`
- No `unsafe` blocks. No panics across user/runtime boundaries
- Rhai `Scope` is the single source of truth for variable values
- `hit_map` is recomputed on every render; click coordinates are always valid
