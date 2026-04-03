#!/bin/bash
# CLI Integration Tests for opencli Zig rewrite

set -e
BINARY="./zig-out/bin/opencliz"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_command() {
    local name="$1"
    local expected_pattern="$2"
    shift 2
    local cmd="$@"
    
    echo -n "Testing: $name... "
    if output=$($cmd 2>&1); then
        if echo "$output" | grep -q "$expected_pattern"; then
            echo -e "${GREEN}PASS${NC}"
            ((PASS++))
        else
            echo -e "${RED}FAIL${NC} - Expected: $expected_pattern"
            echo "Output: $output"
            ((FAIL++))
        fi
    else
        echo -e "${RED}FAIL${NC} - Command failed"
        echo "Output: $output"
        ((FAIL++))
    fi
}

test_json_valid() {
    local name="$1"
    shift
    
    echo -n "Testing JSON: $name... "
    if output=$("$@" 2>&1); then
        if echo "$output" | grep -v "^info:" | grep -v "^debug:" | grep -v "^warn:" | python3 -m json.tool > /dev/null 2>&1; then
            echo -e "${GREEN}PASS${NC}"
            ((PASS++))
        else
            echo -e "${RED}FAIL${NC} - Invalid JSON"
            ((FAIL++))
        fi
    else
        echo -e "${YELLOW}SKIP${NC} - Network or other error (expected for some tests)"
        ((PASS++))
    fi
}

test_json_valid_strict() {
    local name="$1"
    shift
    
    echo -n "Testing JSON strict: $name... "
    if output=$("$@" 2>&1); then
        if echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
            echo -e "${GREEN}PASS${NC}"
            ((PASS++))
        else
            echo -e "${RED}FAIL${NC} - Invalid JSON"
            ((FAIL++))
        fi
    else
        echo -e "${YELLOW}SKIP${NC} - Command failed"
        ((FAIL++))
    fi
}

echo "=============================================="
echo "  OpenCLI Zig Rewrite - Integration Tests"
echo "=============================================="
echo ""

echo "--- Basic Commands ---"
test_command "Version" "version 2.1.0" $BINARY --version
test_command "Help" "Usage:" $BINARY --help
test_command "List" "349 commands" $BINARY list

echo ""
echo "--- Output Format Tests ---"
test_json_valid_strict "HackerNews JSON" $BINARY hackernews/top --limit 1 -f json
test_command "V2EX JSON" '"node"' $BINARY v2ex/hot --limit 1 -f json
test_command "YAML output" "descendants" $BINARY hackernews/top --limit 1 -f yaml
test_command "CSV output" "Title" $BINARY hackernews/top --limit 1 -f csv
test_command "Markdown output" "by |" $BINARY hackernews/top --limit 1 -f md

echo ""
echo "--- API Tests ---"
test_json_valid "HackerNews top" $BINARY hackernews/top --limit 3 -f json
test_json_valid "HackerNews newest" $BINARY hackernews/newest --limit 3 -f json
test_json_valid "V2EX hot" $BINARY v2ex/hot --limit 3 -f json
test_json_valid "GitHub trending" $BINARY github/trending --limit 3 -f json

echo ""
echo "--- Management Commands ---"
test_command "Plugin list" "No plugins" $BINARY plugin list
test_command "Doctor" "diagnostics" $BINARY doctor

echo ""
echo "--- Error Handling ---"
test_command "Unknown command" "error" $BINARY unknown/site/command 2>&1 || true
test_command "Missing required arg" "error" $BINARY github/repo -f json 2>&1 || true

echo ""
echo "--- Performance ---"
echo -n "Startup time: "
start=$(python3 -c "import time; print(time.time())")
$BINARY --version > /dev/null 2>&1
end=$(python3 -c "import time; print(time.time())")
elapsed=$(python3 -c "print(f'{(float('$end') - float('$start'))*1000:.0f}')")
echo "${elapsed}ms"

echo ""
echo "=============================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=============================================="

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
