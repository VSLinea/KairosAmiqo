from tree_sitter import Language, Parser
from pathlib import Path
from typing import List, Dict
import ctypes

# Load precompiled Swift language library (tree-sitter 0.25+ API)
SWIFT_LANGUAGE_LIB = "racag/tree_sitter_languages/build/my-languages.so"

# Load the shared library
lib = ctypes.CDLL(SWIFT_LANGUAGE_LIB)
tree_sitter_swift = lib.tree_sitter_swift
tree_sitter_swift.restype = ctypes.c_void_p

# Create Language from pointer (tree-sitter 0.25+ API)
SWIFT = Language(tree_sitter_swift())

parser = Parser()
parser.language = SWIFT

def extract_code_chunks(file_path: str) -> List[Dict]:
    """
    Extracts Swift code chunks (classes, structs, functions) using Tree-sitter,
    and returns them in the unified RACAG schema.
    """
    path = Path(file_path)
    try:
        code = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        # Fallback for files with stray non-UTF8 bytes
        code = path.read_text(encoding="utf-8", errors="replace")
        print(f"⚠️ Non-UTF8 bytes replaced in {file_path}")
    tree = parser.parse(bytes(code, "utf8"))
    root_node = tree.root_node

    chunks = []

    def get_text(node):
        return code[node.start_byte:node.end_byte]

    def recurse(node, depth=0):
        if node.type in ["class_declaration", "struct_declaration", "function_declaration"]:

            chunk_text = get_text(node)
            chunk_id = f"{path.name}::{node.type}_{node.start_point[0]}"
            start_line = node.start_point[0] + 1  # Tree-sitter is zero-based
            end_line = node.end_point[0] + 1
            chunk_type = node.type.replace("_declaration", "")

            chunks.append({
                "chunk_id": chunk_id,
                "chunk_text": chunk_text,
                "language": "swift",
                "framework": "swiftui",
                "module": path.stem,
                "function": None,
                "file_path": str(path),
                "start_line": start_line,
                "end_line": end_line,
                "tags": [chunk_type],
                "lines": f"{start_line}-{end_line}",
            })

        for child in node.children:
            recurse(child, depth + 1)

    recurse(root_node)
    return chunks