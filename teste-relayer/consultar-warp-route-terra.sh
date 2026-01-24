#!/bin/bash

WARP_CONTRACT="terra1zlm0h2xu6rhnjchn29hxnpvr74uxxqetar9y75zcehyx2mqezg9slj09ml"
RPC_NODE="https://terra-classic-testnet-rpc.publicnode.com:443"

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  CONSULTAR WARP ROUTE TERRA CLASSIC                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

echo "Contrato: $WARP_CONTRACT"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Consultando 'domains'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DOMAINS=$(terrad query wasm contract-state smart "$WARP_CONTRACT" '{"domains":{}}' --node "$RPC_NODE" 2>&1)
echo "$DOMAINS" | head -50

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Consultando 'routing'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ROUTING=$(terrad query wasm contract-state smart "$WARP_CONTRACT" '{"routing":{}}' --node "$RPC_NODE" 2>&1)
echo "$ROUTING" | head -50

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Consultando 'remote_routing'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

REMOTE_ROUTING=$(terrad query wasm contract-state smart "$WARP_CONTRACT" '{"remote_routing":{}}' --node "$RPC_NODE" 2>&1)
echo "$REMOTE_ROUTING" | head -50

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Consultando 'remote_router'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

REMOTE_ROUTER=$(terrad query wasm contract-state smart "$WARP_CONTRACT" '{"remote_router":{}}' --node "$RPC_NODE" 2>&1)
echo "$REMOTE_ROUTER" | head -50

