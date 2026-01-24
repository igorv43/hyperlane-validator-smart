#!/bin/bash

WARP_CONTRACT="terra1zlm0h2xu6rhnjchn29hxnpvr74uxxqetar9y75zcehyx2mqezg9slj09ml"
RPC_NODE="https://rpc.luncblaze.com"
SOLANA_DOMAIN=1399811150

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  CONSULTAR LINK DO WARP ROUTE TERRA -> SOLANA                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

echo "Contrato Terra Classic: $WARP_CONTRACT"
echo "Domain Solana: $SOLANA_DOMAIN"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Consultando 'remote_router' para Solana"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

REMOTE_ROUTER=$(terrad query wasm contract-state smart "$WARP_CONTRACT" "{\"remote_router\":{\"domain\":$SOLANA_DOMAIN}}" --node "$RPC_NODE" 2>&1)
echo "$REMOTE_ROUTER"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Consultando 'routing' para Solana"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ROUTING=$(terrad query wasm contract-state smart "$WARP_CONTRACT" "{\"routing\":{\"domain\":$SOLANA_DOMAIN}}" --node "$RPC_NODE" 2>&1)
echo "$ROUTING"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Consultando 'domains'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DOMAINS=$(terrad query wasm contract-state smart "$WARP_CONTRACT" '{"domains":{}}' --node "$RPC_NODE" 2>&1)
echo "$DOMAINS"

