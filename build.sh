#!/bin/bash

# OpenCLI Zig Build Script
# Usage: ./build.sh [command]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# 未显式设置时，全局依赖缓存落在仓库内，避免必须写 ~/.cache/zig（CI、沙箱、只读家目录场景）
export ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$SCRIPT_DIR/.zig-global-cache}"

COMMAND=${1:-build}

print_header() {
    echo ""
    echo "================================"
    echo "  OpenCLI Zig Build System"
    echo "================================"
    echo ""
}

case $COMMAND in
    build)
        print_header
        echo "Building OpenCLI..."
        zig build -Doptimize=ReleaseFast
        echo "✓ Build complete"
        echo ""
        echo "Binary location: zig-out/bin/opencli"
        ;;
    
    debug)
        print_header
        echo "Building OpenCLI (Debug mode)..."
        zig build
        echo "✓ Build complete (Debug)"
        ;;
    
    test)
        print_header
        echo "Running tests..."
        zig build test
        echo ""
        echo "Running integration tests..."
        zig run test_main.zig
        echo "✓ All tests passed"
        ;;
    
    install)
        print_header
        echo "Installing OpenCLI..."
        zig build install
        
        # 创建配置目录
        mkdir -p ~/.opencli/clis
        mkdir -p ~/.opencli/plugins
        
        echo "✓ Installation complete"
        echo ""
        echo "Add to your shell:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
    
    clean)
        print_header
        echo "Cleaning build artifacts..."
        rm -rf zig-out
        rm -rf .zig-cache
        rm -rf .zig-global-cache
        echo "✓ Clean complete"
        ;;
    
    run)
        shift
        print_header
        echo "Running OpenCLI..."
        zig build run -- "$@"
        ;;
    
    help)
        print_header
        echo "Available commands:"
        echo ""
        echo "  build      - Build release binary"
        echo "  debug      - Build debug binary"
        echo "  test       - Run all tests"
        echo "  install    - Install to system"
        echo "  clean      - Clean build artifacts"
        echo "  run [args] - Build and run"
        echo "  help       - Show this help"
        echo ""
        echo "Examples:"
        echo "  ./build.sh build"
        echo "  ./build.sh run -- list"
        echo "  ./build.sh test"
        ;;
    
    *)
        echo "Unknown command: $COMMAND"
        echo "Run './build.sh help' for usage"
        exit 1
        ;;
esac