"""Run the language-service regression against the real mixed HDL tree."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import time
from typing import Any, Callable


TEST_ROOT = Path(__file__).resolve().parent
LANG_ROOT = TEST_ROOT.parent
SERVER_ROOT = Path(__file__).resolve().parents[8]
DEFAULT_SERVER = SERVER_ROOT / "target" / "debug" / "digital-server"
TIMEOUT_SECONDS = 20.0


def source_path(relative: str) -> Path:
    return LANG_ROOT / relative


class LspSession:
    def __init__(self, server: Path, root: Path) -> None:
        if not server.is_file():
            raise FileNotFoundError(
                f"digital-server is missing: {server}; build it with cargo build --bin digital-server"
            )
        self.process = subprocess.Popen(
            [os.fspath(server)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
        )
        self.root = root.resolve()
        self.next_id = 1
        self.notifications: list[dict[str, Any]] = []

    def _send(self, message: dict[str, Any]) -> None:
        payload = json.dumps(message, separators=(",", ":")).encode("utf-8")
        stream = self.process.stdin
        if stream is None:
            raise RuntimeError("digital-server stdin is closed")
        stream.write(f"Content-Length: {len(payload)}\r\n\r\n".encode("ascii"))
        stream.write(payload)
        stream.flush()

    def notify(self, method: str, params: dict[str, Any] | None = None) -> None:
        message: dict[str, Any] = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            message["params"] = params
        self._send(message)

    def _read_line(self, deadline: float) -> bytes:
        stream = self.process.stdout
        if stream is None:
            raise RuntimeError("digital-server stdout is closed")
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([stream], [], [], remaining)[0]:
            raise TimeoutError("timed out waiting for an LSP header")
        line = stream.readline()
        if not line:
            raise RuntimeError("digital-server exited before sending an LSP response")
        return line

    def _read_message(self, timeout: float = TIMEOUT_SECONDS) -> dict[str, Any]:
        deadline = time.monotonic() + timeout
        content_length: int | None = None
        while True:
            line = self._read_line(deadline).decode("ascii", errors="replace").strip()
            if not line:
                break
            if line.lower().startswith("content-length:"):
                content_length = int(line.split(":", 1)[1].strip())
        if content_length is None or content_length < 0:
            raise RuntimeError("LSP response did not include a valid Content-Length")
        stream = self.process.stdout
        if stream is None:
            raise RuntimeError("digital-server stdout is closed")
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([stream], [], [], remaining)[0]:
            raise TimeoutError("timed out waiting for an LSP body")
        body = stream.read(content_length)
        if body is None or len(body) != content_length:
            raise RuntimeError("digital-server sent a truncated LSP response")
        value = json.loads(body.decode("utf-8"))
        if not isinstance(value, dict):
            raise RuntimeError("LSP response is not a JSON object")
        return value

    def request(self, method: str, params: dict[str, Any] | None = None) -> Any:
        request_id = self.next_id
        self.next_id += 1
        message: dict[str, Any] = {"jsonrpc": "2.0", "id": request_id, "method": method}
        if params is not None:
            message["params"] = params
        self._send(message)
        while True:
            response = self._read_message()
            if "method" in response and "id" in response:
                self._send({"jsonrpc": "2.0", "id": response["id"], "result": None})
                continue
            if response.get("id") != request_id:
                self.notifications.append(response)
                continue
            if "error" in response:
                raise RuntimeError(f"{method} failed: {response['error']}")
            return response.get("result")

    def wait_for_notification(
        self,
        method: str,
        predicate: Callable[[dict[str, Any]], bool],
        timeout: float = TIMEOUT_SECONDS,
    ) -> dict[str, Any]:
        deadline = time.monotonic() + timeout
        while True:
            for index, message in enumerate(self.notifications):
                if message.get("method") == method and predicate(message):
                    return self.notifications.pop(index)
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(f"timed out waiting for {method}")
            self.notifications.append(self._read_message(remaining))

    def close(self) -> None:
        try:
            self.request("shutdown")
            self.notify("exit")
            self.process.wait(timeout=2)
        except (OSError, RuntimeError, TimeoutError, subprocess.TimeoutExpired):
            self.process.kill()
            self.process.wait()


def uri(path: Path) -> str:
    return path.resolve().as_uri()


def position(text: str, needle: str, offset: int = 0, last: bool = False) -> dict[str, int]:
    index = text.rfind(needle) if last else text.find(needle)
    if index < 0:
        raise AssertionError(f"source text is missing: {needle}")
    prefix = text[: index + offset]
    line = prefix.count("\n")
    line_start = prefix.rfind("\n") + 1
    character = len(prefix[line_start:].encode("utf-16-le")) // 2
    return {"line": line, "character": character}


def document_range(text: str) -> dict[str, dict[str, int]]:
    return {"start": {"line": 0, "character": 0}, "end": position(text, text, len(text))}


def text_document(path: Path, language_id: str) -> dict[str, Any]:
    return {"uri": uri(path), "languageId": language_id, "version": 1, "text": path.read_text()}


def open_document(session: LspSession, path: Path) -> None:
    suffix = path.suffix.lower()
    language_id = "vhdl" if suffix in {".vhd", ".vhdl"} else "verilog" if suffix == ".v" else "systemverilog"
    session.notify("textDocument/didOpen", {"textDocument": text_document(path, language_id)})


def items(response: Any) -> list[dict[str, Any]]:
    if isinstance(response, list):
        return [item for item in response if isinstance(item, dict)]
    if isinstance(response, dict) and isinstance(response.get("items"), list):
        return [item for item in response["items"] if isinstance(item, dict)]
    return []


def locations(response: Any) -> list[dict[str, Any]]:
    if not isinstance(response, list):
        return []
    return [item for item in response if isinstance(item, dict)]


def assert_nonempty(value: Any, description: str) -> None:
    if not value:
        raise AssertionError(f"{description} returned no result")


def request_until(
    session: LspSession,
    method: str,
    params: dict[str, Any],
    predicate: Callable[[Any], bool],
    description: str,
    timeout: float = 5.0,
) -> Any:
    deadline = time.monotonic() + timeout
    result: Any = None
    while time.monotonic() < deadline:
        result = session.request(method, params)
        if predicate(result):
            return result
        time.sleep(0.05)
    raise AssertionError(f"{description} did not become ready: {result!r}")


def assert_uri(response: Any, expected: Path, description: str) -> None:
    expected_uri = uri(expected)
    for location in locations(response):
        if location.get("uri") == expected_uri or location.get("targetUri") == expected_uri:
            return
    raise AssertionError(f"{description} did not target {expected_uri}: {response!r}")


def symbol_names(symbols: Any) -> set[str]:
    """Collect nested document-symbol names without depending on symbol shape."""
    names: set[str] = set()
    if not isinstance(symbols, list):
        return names
    for symbol in symbols:
        if not isinstance(symbol, dict):
            continue
        name = symbol.get("name")
        if isinstance(name, str):
            names.add(name)
        names.update(symbol_names(symbol.get("children")))
    return names


def initialize(session: LspSession) -> None:
    print("[lang-suite] initialize", flush=True)
    libraries = SERVER_ROOT / "tests" / "vhdl" / "vhdl_libraries"
    result = session.request(
        "initialize",
        {
            "processId": None,
            "rootUri": uri(session.root),
            "clientInfo": {"name": "digital-ide-mixed-lang-suite", "version": "1"},
            "capabilities": {
                "workspace": {"workspaceFolders": True},
                "textDocument": {
                    "completion": {"completionItem": {"labelDetailsSupport": True}},
                    "documentSymbol": {"hierarchicalDocumentSymbolSupport": True},
                    "publishDiagnostics": {"relatedInformation": True},
                },
            },
            "workspaceFolders": [{"uri": uri(session.root), "name": "mixed-lang"}],
            "initializationOptions": {
                "digital-ide.standard.systemverilog": "2023",
                "digital-ide.function.lsp.systemverilog.expandIncludes": True,
                "digital-ide.standard.vhdl": "2008",
                "digital-ide.lib.vhdl.path": os.fspath(libraries),
            },
        },
    )
    if not isinstance(result, dict):
        raise AssertionError(f"initialize returned {result!r}")
    session.notify("initialized", {})
    required = (
        "completionProvider", "definitionProvider", "referencesProvider", "renameProvider",
        "hoverProvider", "documentSymbolProvider", "workspaceSymbolProvider",
        "documentFormattingProvider", "typeDefinitionProvider", "semanticTokensProvider",
        "callHierarchyProvider",
    )
    missing = [name for name in required if result.get("capabilities", {}).get(name) is None]
    if missing:
        raise AssertionError(f"initialize is missing capabilities: {missing}")


def run_systemverilog_suite(session: LspSession, manifest: dict[str, Any]) -> None:
    print("[lang-suite] SystemVerilog providers", flush=True)
    query = manifest["queries"]["sv"]
    document = source_path(query["document"])
    types_document = source_path(query["types_document"])
    module_document = source_path(query["module_document"])
    hover_document = source_path(query["hover_document"])
    text = document.read_text()
    document_uri = uri(document)
    local = query["local_symbol"]
    rhs_position = position(text, local, len(local.split(" = ", 1)[0]) + len(" = "), True)

    completion = session.request("textDocument/completion", {
        "textDocument": {"uri": document_uri}, "position": rhs_position, "context": {"triggerKind": 1}
    })
    assert_nonempty(items(completion), "SystemVerilog local/package completion")

    system_task = session.request("textDocument/completion", {
        "textDocument": {"uri": document_uri},
        "position": position(text, query["system_task"], 1),
        "context": {"triggerKind": 2, "triggerCharacter": "$"},
    })
    if not any(str(item.get("label", "")) in {"display", "$display"} for item in items(system_task)):
        raise AssertionError(f"system-task completion is missing display: {system_task!r}")

    include_completion = session.request("textDocument/completion", {
        "textDocument": {"uri": document_uri},
        "position": position(text, query["include_directive"], len('`include "')),
        "context": {"triggerKind": 2, "triggerCharacter": '"'},
    })
    if not any("lang_sv_include.svh" in str(item.get("label", "")) for item in items(include_completion)):
        raise AssertionError(f"include completion is missing lang_sv_include.svh: {include_completion!r}")

    module_definition = request_until(session, "textDocument/definition", {
        "textDocument": {"uri": document_uri}, "position": position(text, query["module_use"])
    }, lambda value: bool(locations(value)), "SystemVerilog module definition")
    assert_uri(module_definition, module_document, "SystemVerilog module definition")

    type_definition = request_until(session, "textDocument/typeDefinition", {
        "textDocument": {"uri": document_uri}, "position": rhs_position
    }, lambda value: bool(locations(value)), "SystemVerilog type definition")
    assert_uri(type_definition, types_document, "SystemVerilog type definition")
    assert_nonempty(locations(session.request("textDocument/references", {
        "textDocument": {"uri": document_uri}, "position": rhs_position, "context": {"includeDeclaration": True}
    })), "SystemVerilog references")
    hover_text = hover_document.read_text()
    assert_nonempty(request_until(session, "textDocument/hover", {
        "textDocument": {"uri": uri(hover_document)},
        "position": position(hover_text, "hover_target =", len("hover_t"))
    }, bool, "SystemVerilog hover"), "SystemVerilog hover")
    assert_nonempty(session.request("textDocument/documentHighlight", {"textDocument": {"uri": document_uri}, "position": rhs_position}), "SystemVerilog highlights")
    assert_nonempty(session.request("textDocument/documentSymbol", {"textDocument": {"uri": document_uri}}), "SystemVerilog document symbols")
    assert_nonempty(session.request("workspace/symbol", {"query": "lang_sv_core"}), "SystemVerilog workspace symbols")
    assert_nonempty(session.request("textDocument/prepareRename", {"textDocument": {"uri": document_uri}, "position": rhs_position}), "SystemVerilog prepare rename")
    assert_nonempty(session.request("textDocument/rename", {"textDocument": {"uri": document_uri}, "position": rhs_position, "newName": "renamed_value"}), "SystemVerilog rename")
    if not isinstance(session.request("textDocument/formatting", {"textDocument": {"uri": document_uri}, "options": {"tabSize": 2, "insertSpaces": True}}), list):
        raise AssertionError("SystemVerilog formatting did not return edits")

    semantic_tokens = session.request("textDocument/semanticTokens/full", {"textDocument": {"uri": document_uri}})
    if not isinstance(semantic_tokens, dict) or not semantic_tokens.get("data"):
        raise AssertionError(f"SystemVerilog semantic tokens are empty: {semantic_tokens!r}")
    session.request("textDocument/semanticTokens/range", {"textDocument": {"uri": document_uri}, "range": {"start": {"line": 0, "character": 0}, "end": {"line": 100, "character": 0}}})
    delta = session.request("textDocument/semanticTokens/full/delta", {"textDocument": {"uri": document_uri}, "previousResultId": semantic_tokens.get("resultId")})
    if not isinstance(delta, dict) or not isinstance(delta.get("edits"), list):
        raise AssertionError(f"SystemVerilog semantic-token delta is invalid: {delta!r}")
    if not isinstance(session.request("textDocument/codeLens", {"textDocument": {"uri": document_uri}}), list):
        raise AssertionError("SystemVerilog CodeLens did not return a list")
    if not isinstance(session.request("textDocument/inlayHint", {"textDocument": {"uri": document_uri}, "range": document_range(text)}), list):
        raise AssertionError("SystemVerilog Inlay Hint did not return a list")
    hierarchy = session.request("textDocument/prepareCallHierarchy", {"textDocument": {"uri": document_uri}, "position": position(text, "lang_sv_core")})
    if not isinstance(hierarchy, list):
        raise AssertionError("SystemVerilog call hierarchy did not return a list")


def run_systemverilog_syntax_suite(session: LspSession, manifest: dict[str, Any]) -> None:
    """Check a functional fixture matrix derived from Slang's all.sv syntax families."""
    print("[lang-suite] SystemVerilog syntax coverage matrix", flush=True)
    coverage = manifest.get("syntax_coverage")
    if not isinstance(coverage, list) or not coverage:
        raise AssertionError("syntax_coverage matrix is empty")

    texts: dict[str, str] = {}
    for entry in coverage:
        if not isinstance(entry, dict):
            raise AssertionError(f"invalid syntax coverage entry: {entry!r}")
        files = entry.get("files")
        markers = entry.get("markers")
        if not isinstance(files, list) or not isinstance(markers, list):
            raise AssertionError(f"invalid syntax coverage shape: {entry!r}")
        combined = ""
        for relative in files:
            if not isinstance(relative, str):
                raise AssertionError(f"invalid syntax coverage path: {relative!r}")
            path = source_path(relative)
            if not path.is_file():
                raise FileNotFoundError(f"syntax coverage file is missing: {path}")
            text = texts.setdefault(relative, path.read_text())
            combined += text
        missing = [marker for marker in markers if not isinstance(marker, str) or marker not in combined]
        if missing:
            raise AssertionError(f"{entry.get('feature', 'syntax')} is missing markers: {missing}")

    query = manifest["queries"]["sv"]
    document = source_path(query["syntax_document"])
    text = document.read_text()
    document_uri = uri(document)
    symbols = session.request("textDocument/documentSymbol", {"textDocument": {"uri": document_uri}})
    names = symbol_names(symbols)
    required_symbols = {
        "lang_sv_advanced", "generated_bits", "generated_wide", "generated_narrow",
        "lang_checker", "syntax_coverage", "lang_specify_probe", "lang_nonansi_probe",
        "lang_bus_if", "lang_sv_feature_probe",
    }
    missing_symbols = sorted(required_symbols - names)
    if missing_symbols:
        raise AssertionError(f"syntax fixture symbols are missing: {missing_symbols}")

    tokens = session.request("textDocument/semanticTokens/full", {"textDocument": {"uri": document_uri}})
    if not isinstance(tokens, dict) or not tokens.get("data"):
        raise AssertionError("syntax fixture semantic tokens are empty")
    inlay = session.request(
        "textDocument/inlayHint",
        {"textDocument": {"uri": document_uri}, "range": document_range(text)},
    )
    if not isinstance(inlay, list):
        raise AssertionError("syntax fixture Inlay Hint response is not a list")

    # Ensure the syntax-heavy module participates in the real adder workspace,
    # rather than being an isolated parser sample.
    core = source_path(query["document"])
    core_text = core.read_text()
    definition = session.request(
        "textDocument/definition",
        {"textDocument": {"uri": uri(core)}, "position": position(core_text, "lang_sv_advanced #")},
    )
    assert_uri(definition, document, "syntax fixture module definition")


def run_verilog_suite(session: LspSession, manifest: dict[str, Any]) -> None:
    print("[lang-suite] Verilog providers", flush=True)
    query = manifest["queries"]["verilog"]
    document = source_path(query["document"])
    text = document.read_text()
    document_uri = uri(document)
    coverage = manifest.get("verilog_coverage")
    if not isinstance(coverage, dict) or coverage.get("file") != query["document"]:
        raise AssertionError("Verilog coverage metadata is missing or points at another file")
    for marker in coverage.get("required_markers", []):
        if not isinstance(marker, str) or marker not in text:
            raise AssertionError(f"Verilog fixture is missing marker: {marker!r}")
    for marker in coverage.get("forbidden_systemverilog_constructs", []):
        if not isinstance(marker, str) or marker in text:
            raise AssertionError(f"Verilog fixture contains SystemVerilog-only marker: {marker!r}")
    if document.suffix.lower() != ".v":
        raise AssertionError("Verilog fixture must use a .v suffix so it selects Verilog mode")
    diagnostics = session.wait_for_notification(
        "textDocument/publishDiagnostics",
        lambda message: message.get("params", {}).get("uri") == document_uri,
    )
    errors = [
        diagnostic
        for diagnostic in diagnostics.get("params", {}).get("diagnostics", [])
        if isinstance(diagnostic, dict) and diagnostic.get("severity") == 1
    ]
    if errors:
        raise AssertionError(
            "Verilog-2005 keyword identifiers were rejected by the Verilog parser: "
            f"{errors!r}"
        )
    definition = session.request("textDocument/definition", {"textDocument": {"uri": document_uri}, "position": position(text, query["module_name"])})
    assert_nonempty(locations(definition), "Verilog module definition")
    assert_nonempty(session.request("textDocument/documentSymbol", {"textDocument": {"uri": document_uri}}), "Verilog document symbols")
    completion = session.request("textDocument/completion", {"textDocument": {"uri": document_uri}, "position": position(text, "data_out", 5), "context": {"triggerKind": 1}})
    assert_nonempty(items(completion), "Verilog completion")
    assert_nonempty(session.request("textDocument/hover", {"textDocument": {"uri": document_uri}, "position": position(text, "data_in", 1)}), "Verilog hover")
    if not isinstance(session.request("textDocument/formatting", {"textDocument": {"uri": document_uri}, "options": {"tabSize": 2, "insertSpaces": True}}), list):
        raise AssertionError("Verilog formatting did not return edits")


def run_vhdl_suite(session: LspSession, manifest: dict[str, Any]) -> None:
    print("[lang-suite] VHDL providers", flush=True)
    query = manifest["queries"]["vhdl"]
    document = source_path(query["document"])
    types_document = source_path(query["types_document"])
    entity_document = source_path(query["entity_document"])
    text = document.read_text()
    document_uri = uri(document)
    port_position = position(text, query["port_use"], len("input_a => "))
    assert_nonempty(items(session.request("textDocument/completion", {"textDocument": {"uri": document_uri}, "position": port_position, "context": {"triggerKind": 1}})), "VHDL completion")
    assert_uri(session.request("textDocument/definition", {"textDocument": {"uri": document_uri}, "position": position(text, query["entity_use"], len("entity work."))}), entity_document, "VHDL entity definition")
    hover_position = position(text, "entity work.lang_vhdl_stage", len("entity work."))
    assert_nonempty(session.request("textDocument/hover", {"textDocument": {"uri": document_uri}, "position": hover_position}), "VHDL hover")
    assert_nonempty(locations(session.request("textDocument/references", {"textDocument": {"uri": document_uri}, "position": port_position, "context": {"includeDeclaration": True}})), "VHDL references")
    assert_nonempty(session.request("textDocument/documentHighlight", {"textDocument": {"uri": document_uri}, "position": port_position}), "VHDL highlights")
    assert_nonempty(session.request("textDocument/documentSymbol", {"textDocument": {"uri": document_uri}}), "VHDL document symbols")
    assert_nonempty(session.request("workspace/symbol", {"query": "lang_vhdl_top"}), "VHDL workspace symbols")
    hierarchy = session.request("textDocument/prepareCallHierarchy", {"textDocument": {"uri": document_uri}, "position": position(text, "lang_vhdl_top", len("lang_vhdl_"))})
    if not isinstance(hierarchy, list):
        raise AssertionError("VHDL call hierarchy did not return a list")
    assert_nonempty(session.request("textDocument/prepareRename", {"textDocument": {"uri": document_uri}, "position": port_position}), "VHDL prepare rename")
    assert_nonempty(session.request("textDocument/rename", {"textDocument": {"uri": document_uri}, "position": port_position, "newName": "renamed_input_a"}), "VHDL rename")
    if not isinstance(session.request("textDocument/formatting", {"textDocument": {"uri": document_uri}, "options": {"tabSize": 2, "insertSpaces": True}}), list):
        raise AssertionError("VHDL formatting did not return edits")
    if session.request("textDocument/typeDefinition", {"textDocument": {"uri": document_uri}, "position": port_position}) not in (None, []):
        raise AssertionError("VHDL typeDefinition is expected to be unsupported")
    for method, params, label in (
        ("textDocument/semanticTokens/full", {"textDocument": {"uri": document_uri}}, "VHDL semantic tokens"),
        ("textDocument/codeLens", {"textDocument": {"uri": document_uri}}, "VHDL CodeLens"),
        ("textDocument/inlayHint", {"textDocument": {"uri": document_uri}, "range": document_range(text)}, "VHDL Inlay Hint"),
    ):
        if session.request(method, params) not in (None, []):
            raise AssertionError(f"{label} is expected to be empty")
    assert_uri(session.request("textDocument/definition", {"textDocument": {"uri": uri(types_document)}, "position": position(types_document.read_text(), "word_t")}), types_document, "VHDL package type definition")


def run(manifest_path: Path, server: Path) -> None:
    manifest = json.loads(manifest_path.read_text())
    if manifest.get("version") != 2:
        raise AssertionError(f"unsupported manifest version: {manifest.get('version')!r}")
    files = [source_path(relative) for relative in manifest.get("files", [])]
    missing = [path for path in files if not path.is_file()]
    if missing:
        raise FileNotFoundError(f"manifest files are missing: {missing}")
    session = LspSession(server, LANG_ROOT)
    try:
        initialize(session)
        # Force the deferred workspace preload to settle before provider checks.
        session.request("process/request")
        session.request("hdlparams/request")
        for path in files:
            open_document(session, path)
        hover_document = source_path(manifest["queries"]["sv"]["hover_document"])
        session.wait_for_notification(
            "textDocument/publishDiagnostics",
            lambda message: message.get("params", {}).get("uri") == uri(hover_document),
        )
        run_systemverilog_suite(session, manifest)
        run_systemverilog_syntax_suite(session, manifest)
        run_verilog_suite(session, manifest)
        run_vhdl_suite(session, manifest)
        print(f"PASS: {len(files)} real mixed-HDL files and all language-service provider checks")
    finally:
        session.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", type=Path, default=DEFAULT_SERVER)
    parser.add_argument("--manifest", type=Path, default=Path(__file__).with_name("manifest.json"))
    args = parser.parse_args()
    try:
        run(args.manifest.resolve(), args.server.resolve())
    except (AssertionError, FileNotFoundError, OSError, RuntimeError, TimeoutError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
