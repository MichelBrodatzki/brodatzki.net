#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")


echo "----- [ FOUNDATION ] -----"
$SCRIPT_DIR/foundation.sh

echo "\n\n----- [ POLICIES ] -----"
$SCRIPT_DIR/policies.sh
