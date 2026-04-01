#!/usr/bin/env bash
# Bluetooth pairing via bluetoothctl with auto-confirm agent.
# Usage: bt-pair.sh <mac-address> [timeout_seconds]
# Outputs: PAIRING, PAIRED, CONNECTED, FAILED
# Auto-confirms passkey/authorization prompts.

ADDR="$1"
TIMEOUT="${2:-30}"

[ -z "$ADDR" ] && echo "FAILED" && exit 1

echo "PAIRING"

# Use script(1) or expect-like approach via coproc
# bluetoothctl with --agent=NoInputNoOutput auto-accepts pairing
# For devices needing confirmation, use --agent=KeyboardDisplay

# Try pairing with auto-accept agent
{
    echo "agent on"
    echo "default-agent"
    sleep 0.3
    echo "pair $ADDR"
    # Auto-confirm any prompts
    for i in $(seq 1 "$TIMEOUT"); do
        echo "yes"
        sleep 1
        # Check if paired
        if bluetoothctl info "$ADDR" 2>/dev/null | grep -q "Paired: yes"; then
            echo "trust $ADDR"
            sleep 0.3
            echo "connect $ADDR"
            sleep 2
            break
        fi
    done
    echo "quit"
} | bluetoothctl 2>&1 | grep -v "^\[" &

BTPID=$!

# Wait for bluetoothctl to finish or timeout
ELAPSED=0
while kill -0 "$BTPID" 2>/dev/null && [ "$ELAPSED" -lt "$((TIMEOUT + 5))" ]; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done
kill "$BTPID" 2>/dev/null

# Check final status
if bluetoothctl info "$ADDR" 2>/dev/null | grep -q "Connected: yes"; then
    echo "CONNECTED"
    exit 0
elif bluetoothctl info "$ADDR" 2>/dev/null | grep -q "Paired: yes"; then
    echo "PAIRED"
    exit 0
else
    echo "FAILED"
    exit 1
fi
