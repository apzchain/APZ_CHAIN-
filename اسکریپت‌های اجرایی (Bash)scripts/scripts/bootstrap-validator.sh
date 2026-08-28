#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-./build/genesis}"
VAL_NAME="${1:-validator-1}"
KEY_DIR="${KEY_DIR:-./build/keys}"
CHAIN_ID_FILE="${OUT_DIR}/genesis.json"

mkdir -p "$KEY_DIR" "$OUT_DIR"

echo "Bootstrapping validator: $VAL_NAME"
# generate keypair (ed25519) using openssl for placeholder (replace with node tool for production)
openssl genpkey -algorithm ed25519 -out "${KEY_DIR}/${VAL_NAME}_key.pem"
PUBKEY_BASE64=$(openssl pkey -pubout -in "${KEY_DIR}/${VAL_NAME}_key.pem" -outform PEM | tail -n +2 | head -n -1 | tr -d '\n' | base64 -w 0 || true)

if [ -z "$PUBKEY_BASE64" ]; then
  PUBKEY_BASE64="REPLACE_BASE64_PUBKEY_${VAL_NAME}"
fi

# create placeholder validator entry
jq --arg addr "REPLACE_VALIDATOR_ADDRESS_${VAL_NAME}" \
   --arg pubkey "$PUBKEY_BASE64" \
   --arg name "$VAL_NAME" \
   '.validators += [ { "address": $addr, "pub_key": { "type": "tendermint/PubKeyEd25519", "value": $pubkey }, "power": "1000", "name": $name } ]' \
   "$CHAIN_ID_FILE" > "${CHAIN_ID_FILE}.tmp" && mv "${CHAIN_ID_FILE}.tmp" "$CHAIN_ID_FILE"

echo "Validator entry added to $CHAIN_ID_FILE (use actual tendermint keygen to replace placeholders)."
echo "Generated keypair (PEM) in $KEY_DIR (for local dev)."
