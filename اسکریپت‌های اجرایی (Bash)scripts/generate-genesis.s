#!/usr/bin/env bash
set -euo pipefail

CHAIN_ID="${CHAIN_ID:-apz-testnet-1}"
GENESIS_TIME="${GENESIS_TIME:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
OUT_DIR="${OUT_DIR:-./build/genesis}"
VALIDATOR_COUNT="${VALIDATOR_COUNT:-1}"

mkdir -p "$OUT_DIR"

echo "Generating genesis for chain_id=$CHAIN_ID at $GENESIS_TIME into $OUT_DIR"

cat > "$OUT_DIR/genesis.json" <<EOF
{
  "chain_id": "$CHAIN_ID",
  "genesis_time": "$GENESIS_TIME",
  "consensus_params": {
    "block": { "max_bytes": "22020096", "max_gas": "-1", "time_iota_ms": "1000" },
    "evidence": { "max_age_num_blocks": "100000", "max_age_duration": "172800000000000" },
    "validator": { "pub_key_types": ["ed25519"] }
  },
  "validators": [],
  "app_state": {
    "bank": { "balances": [] },
    "staking": { "params": { "unbonding_time": "1814400000000000", "max_validators": 100 } },
    "gov": { "deposit_params": { "min_deposit": [{ "denom": "apz", "amount": "1000000000000000000" }] } },
    "supply": { "total": [{ "denom": "apz", "amount": "1000000000000000000000000000" }] }
  }
}
EOF

echo "genesis.json created at $OUT_DIR/genesis.json"
echo "Next: populate validators and alloc with scripts/bootstrap-validator.sh or manually edit genesis.json."
