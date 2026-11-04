#!/usr/bin/env bash
# The checks are called indirectly through wait_for, which shellcheck cannot
# follow, so it flags them as dead code.
# shellcheck disable=SC2317,SC2329
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
CONTEXT="${KUBE_CONTEXT:-k3d-platform}"
DEMO_HOST="${DEMO_HOST:-demo.localtest.me}"
DEMO_PORT="${DEMO_PORT:-8080}"
PLATFORM_NAMESPACES=(ingress-nginx cert-manager monitoring demo)

SHORT_TIMEOUT="${SHORT_TIMEOUT:-90}"
LONG_TIMEOUT="${LONG_TIMEOUT:-180}"
INTERVAL=3

failures=0
current_step=0

k() {
  "$KUBECTL" --context "$CONTEXT" "$@"
}

title() {
  current_step=$((current_step + 1))
  printf '\n[%d/7] %s\n' "$current_step" "$1"
}

ok() {
  printf '  OK    %s\n' "$1"
}

fail() {
  printf '  FAIL  %s\n' "$1"
  printf '        expected: %s\n' "$2"
  printf '        got:      %s\n' "$3"
  failures=$((failures + 1))
}

# Retries until the command returns 0 or the time budget runs out. There is no
# fixed sleep up front: the bounded retry is what avoids both waiting too long
# and failing because the check started too early.
wait_for() {
  local limit="$1"
  shift
  local deadline=$((SECONDS + limit))

  while [ "$SECONDS" -lt "$deadline" ]; do
    if "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$INTERVAL"
  done

  return 1
}

nodes_ready() {
  local total ready
  total="$(k get nodes --no-headers | wc -l | tr -d ' ')"
  ready="$(k get nodes --no-headers | grep -c ' Ready ' || true)"
  [ "$total" -ge 3 ] && [ "$total" = "$ready" ]
}

pods_healthy() {
  local ns pending
  for ns in "${PLATFORM_NAMESPACES[@]}"; do
    pending="$(k get pods -n "$ns" --no-headers 2>/dev/null |
      awk '$3 != "Running" && $3 != "Completed" { print }' | wc -l | tr -d ' ')"
    [ "$pending" = "0" ] || return 1
  done
}

node_metrics_available() {
  k top nodes --no-headers | awk 'NF >= 5 { found = 1 } END { exit !found }'
}

issuer_ready() {
  [ "$(k get clusterissuer selfsigned \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ]
}

certificate_issued() {
  local name="$1"
  [ "$(k get certificate "$name" -n demo \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ]
}

demo_responds() {
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
    "http://${DEMO_HOST}:${DEMO_PORT}/")" = "200" ]
}

# status.currentMetrics exists as an empty list while the HPA has not measured
# anything yet, so the check has to go down to the percentage or it passes with
# TARGETS at <unknown>.
hpa_has_metrics() {
  local usage
  local path='{.status.currentMetrics[0].resource.current.averageUtilization}'
  usage="$(k get hpa demo -n demo -o jsonpath="$path")"
  [ -n "$usage" ] && [ "$usage" -ge 0 ] 2>/dev/null
}

printf 'platform smoke test, context %s\n' "$CONTEXT"

title 'nodes Ready'
if wait_for "$SHORT_TIMEOUT" nodes_ready; then
  ok "$(k get nodes --no-headers | wc -l | tr -d ' ') nodes Ready"
else
  fail 'cluster nodes' 'three nodes Ready' "$(k get nodes --no-headers || true)"
fi

title 'platform pods Running or Completed'
if wait_for "$LONG_TIMEOUT" pods_healthy; then
  ok 'all platform pods stable'
else
  fail 'platform pods' 'none outside Running or Completed' \
    "$(k get pods -A --field-selector=status.phase!=Running --no-headers || true)"
fi

title 'metrics-server returns data'
if wait_for "$LONG_TIMEOUT" node_metrics_available; then
  ok 'kubectl top nodes returns metrics'
else
  fail 'kubectl top nodes' 'one row per node with CPU and memory' \
    "$(k top nodes 2>&1 || true)"
fi

title 'ClusterIssuer Ready'
if wait_for "$SHORT_TIMEOUT" issuer_ready; then
  ok 'clusterissuer selfsigned ready'
else
  fail 'clusterissuer selfsigned' 'condition Ready=True' \
    "$(k get clusterissuer selfsigned -o wide 2>&1 || true)"
fi

title 'demo namespace certificates issued'
for certificate in wildcard-base-domain demo-tls; do
  if wait_for "$LONG_TIMEOUT" certificate_issued "$certificate"; then
    ok "certificate $certificate issued"
  else
    fail "certificate $certificate" 'condition Ready=True' \
      "$(k get certificate "$certificate" -n demo -o wide 2>&1 || true)"
  fi
done

title 'sample app responds through the Ingress'
if wait_for "$LONG_TIMEOUT" demo_responds; then
  ok "http://${DEMO_HOST}:${DEMO_PORT}/ returns 200"
else
  fail 'Ingress response' '200' \
    "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
      "http://${DEMO_HOST}:${DEMO_PORT}/" || true)"
fi

title 'HPA reports metrics'
if wait_for "$LONG_TIMEOUT" hpa_has_metrics; then
  ok "current target $(k get hpa demo -n demo --no-headers | awk '{ print $4 }')"
else
  fail 'HPA metrics' 'a CPU percentage' \
    "$(k get hpa demo -n demo --no-headers 2>&1 || true)"
fi

printf '\n'
if [ "$failures" -eq 0 ]; then
  printf 'smoke test: 7 of 7 checks green\n'
  exit 0
fi

printf 'smoke test: %d checks failed\n' "$failures"
exit 1
