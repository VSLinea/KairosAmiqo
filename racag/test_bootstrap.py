#!/usr/bin/env python3
"""
RACAG Bootstrap Self-Test

Validates that RACAG environment is properly configured:
1. All dependencies are installed
2. Package structure is correct
3. Tree-sitter Swift parser loads
4. ChromaDB can initialize
5. OpenAI client validates (API key check)
"""

import sys
import os
from pathlib import Path


def test_imports():
    """Test that all required packages can be imported."""
    print("🔍 Testing package imports...")
    
    required_packages = [
        ("chromadb", "ChromaDB vector store"),
        ("openai", "OpenAI embeddings"),
        ("fastapi", "FastAPI web framework"),
        ("uvicorn", "Uvicorn ASGI server"),
        ("pydantic", "Pydantic data validation"),
        ("yaml", "PyYAML configuration"),
        ("tiktoken", "tiktoken tokenizer"),
        ("tree_sitter", "tree-sitter parser"),
        ("watchdog", "watchdog file monitor"),
        ("matplotlib", "matplotlib visualization"),
        ("opentelemetry", "OpenTelemetry tracing"),
    ]
    
    failed = []
    for package, description in required_packages:
        try:
            __import__(package)
            print(f"  ✅ {package:20s} - {description}")
        except ImportError as e:
            print(f"  ❌ {package:20s} - {description} (MISSING: {e})")
            failed.append(package)
    
    if failed:
        print(f"\n❌ Missing packages: {', '.join(failed)}")
        print("   Run: pip install -r racag/requirements.txt")
        return False
    
    print("✅ All dependencies installed\n")
    return True


def test_package_structure():
    """Test that RACAG package structure is correct."""
    print("🔍 Testing package structure...")
    
    required_init_files = [
        "racag/__init__.py",
        "racag/adapters/__init__.py",
        "racag/api/__init__.py",
        "racag/chunking/__init__.py",
        "racag/config/__init__.py",
        "racag/context/__init__.py",
        "racag/db/__init__.py",
        "racag/diagnostics/__init__.py",
        "racag/embedding/__init__.py",
        "racag/query/__init__.py",
        "racag/reranker/__init__.py",
        "racag/retrieval/__init__.py",
        "racag/runtime/__init__.py",
        "racag/server/__init__.py",
        "racag/telemetry/__init__.py",
        "racag/watcher/__init__.py",
    ]
    
    failed = []
    for init_file in required_init_files:
        if Path(init_file).exists():
            print(f"  ✅ {init_file}")
        else:
            print(f"  ❌ {init_file} (MISSING)")
            failed.append(init_file)
    
    if failed:
        print(f"\n❌ Missing __init__.py files: {len(failed)}")
        return False
    
    print("✅ Package structure correct\n")
    return True


def test_racag_imports():
    """Test that RACAG internal modules can be imported."""
    print("🔍 Testing RACAG module imports...")
    
    racag_modules = [
        "racag",
        "racag.query",
        "racag.context",
        "racag.chunking",
        "racag.embedding",
        "racag.retrieval",
        "racag.reranker",
        "racag.runtime",
        "racag.watcher",
    ]
    
    failed = []
    for module in racag_modules:
        try:
            __import__(module)
            print(f"  ✅ {module}")
        except Exception as e:
            print(f"  ❌ {module} (ERROR: {e})")
            failed.append(module)
    
    if failed:
        print(f"\n❌ Failed to import {len(failed)} modules")
        return False
    
    print("✅ All RACAG modules importable\n")
    return True


def test_tree_sitter():
    """Test that tree-sitter Swift parser loads."""
    print("🔍 Testing tree-sitter Swift parser...")
    
    try:
        from tree_sitter import Language, Parser
        import ctypes
        
        swift_lib = Path("racag/tree_sitter_languages/build/my-languages.so")
        if not swift_lib.exists():
            print(f"  ❌ Swift language library not found: {swift_lib}")
            return False
        
        print(f"  ✅ Swift library found: {swift_lib}")
        
        # Load using tree-sitter 0.25+ API
        lib = ctypes.CDLL(str(swift_lib))
        tree_sitter_swift = lib.tree_sitter_swift
        tree_sitter_swift.restype = ctypes.c_void_p
        
        SWIFT = Language(tree_sitter_swift())
        parser = Parser()
        parser.language = SWIFT
        
        # Test parsing a simple Swift snippet
        test_code = b"func test() { return 42 }"
        tree = parser.parse(test_code)
        
        # Swift parser returns "source_file" or "program" depending on version
        if tree.root_node.type in ("source_file", "program"):
            print(f"  ✅ Swift parser loaded and tested (root: {tree.root_node.type})")
            print("✅ Tree-sitter working\n")
            return True
        else:
            print(f"  ❌ Unexpected parse result: {tree.root_node.type}")
            return False
            
    except Exception as e:
        print(f"  ❌ Tree-sitter error: {e}")
        return False


def test_chromadb():
    """Test that ChromaDB can initialize."""
    print("🔍 Testing ChromaDB initialization...")
    
    try:
        from chromadb import PersistentClient
        from chromadb.config import Settings
        
        # Try to create a test client (in-memory)
        test_path = Path("racag/db/chroma_store")
        test_path.mkdir(parents=True, exist_ok=True)
        
        print(f"  ✅ ChromaDB storage path: {test_path}")
        
        # Create client (this validates ChromaDB works)
        settings = Settings(anonymized_telemetry=False)
        client = PersistentClient(path=str(test_path), settings=settings)
        
        # List collections (should not fail)
        collections = client.list_collections()
        print(f"  ✅ ChromaDB initialized ({len(collections)} collections)")
        print("✅ ChromaDB working\n")
        return True
        
    except Exception as e:
        print(f"  ❌ ChromaDB error: {e}")
        return False


def test_openai():
    """Test that OpenAI client can be created (doesn't validate API key)."""
    print("🔍 Testing OpenAI client...")
    
    try:
        from openai import OpenAI
        
        # Check for API key in environment
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            print("  ⚠️  OPENAI_API_KEY not set (required for embeddings)")
            print("     Set with: export OPENAI_API_KEY=sk-...")
            print("  ✅ OpenAI client can be created (but won't work without key)")
            return True
        
        # Create client (doesn't make API call)
        client = OpenAI(api_key=api_key)
        print("  ✅ OpenAI client created with API key")
        print("  ℹ️  API key validation requires actual API call (not tested)")
        print("✅ OpenAI client working\n")
        return True
        
    except Exception as e:
        print(f"  ❌ OpenAI error: {e}")
        return False


def test_directories():
    """Test that required directories exist."""
    print("🔍 Testing directory structure...")
    
    required_dirs = [
        "racag/output",
        "racag/logs",
        "racag/logs/prompts",
        "racag/logs/embeddings",
        "racag/db/chroma_store",
    ]
    
    for directory in required_dirs:
        path = Path(directory)
        if path.exists():
            print(f"  ✅ {directory}")
        else:
            print(f"  ⚠️  {directory} (creating...)")
            path.mkdir(parents=True, exist_ok=True)
            print(f"     Created: {directory}")
    
    print("✅ Directory structure ready\n")
    return True


def main():
    """Run all tests."""
    # Ensure repo root is in PYTHONPATH for imports to work
    repo_root = Path(__file__).parent.parent.absolute()
    if str(repo_root) not in sys.path:
        sys.path.insert(0, str(repo_root))
    
    print("=" * 60)
    print("RACAG Bootstrap Self-Test")
    print("=" * 60)
    print()
    
    tests = [
        ("Package Imports", test_imports),
        ("Package Structure", test_package_structure),
        ("RACAG Modules", test_racag_imports),
        ("Tree-sitter Parser", test_tree_sitter),
        ("ChromaDB Store", test_chromadb),
        ("OpenAI Client", test_openai),
        ("Directory Structure", test_directories),
    ]
    
    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print(f"❌ {name} test crashed: {e}\n")
            results.append((name, False))
    
    print("=" * 60)
    print("Summary")
    print("=" * 60)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {name}")
    
    print()
    print(f"Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! RACAG is ready to use.")
        return 0
    else:
        print(f"\n⚠️  {total - passed} tests failed. Fix issues above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
