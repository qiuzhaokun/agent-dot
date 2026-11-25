#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product AgentDot
exec .build/debug/AgentDot "$@"
