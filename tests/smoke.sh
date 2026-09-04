#!/usr/bin/env bash
# Las verificaciones se llaman de forma indirecta desde esperar_a, que shellcheck
# no puede seguir y marca como codigo muerto.
# shellcheck disable=SC2317
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
CONTEXTO="${KUBE_CONTEXT:-k3d-plataforma}"
DEMO_HOST="${DEMO_HOST:-demo.localtest.me}"
DEMO_PUERTO="${DEMO_PUERTO:-8080}"
NAMESPACES_PLATAFORMA=(ingress-nginx cert-manager monitoring demo)

TIMEOUT_CORTO="${TIMEOUT_CORTO:-90}"
TIMEOUT_LARGO="${TIMEOUT_LARGO:-180}"
INTERVALO=3

fallos=0
paso_actual=0

k() {
  "$KUBECTL" --context "$CONTEXTO" "$@"
}

titulo() {
  paso_actual=$((paso_actual + 1))
  printf '\n[%d/7] %s\n' "$paso_actual" "$1"
}

ok() {
  printf '  OK    %s\n' "$1"
}

error() {
  printf '  FALLA %s\n' "$1"
  printf '        esperado: %s\n' "$2"
  printf '        obtenido: %s\n' "$3"
  fallos=$((fallos + 1))
}

# Reintenta hasta que el comando devuelva 0 o se agote el presupuesto de tiempo.
# No se usa un sleep fijo al principio: el reintento con limite es lo que evita
# tanto la espera de mas como el fallo por arrancar demasiado temprano.
esperar_a() {
  local limite="$1"
  shift
  local fin=$((SECONDS + limite))

  while [ "$SECONDS" -lt "$fin" ]; do
    if "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$INTERVALO"
  done

  return 1
}

nodos_listos() {
  local total listos
  total="$(k get nodes --no-headers | wc -l | tr -d ' ')"
  listos="$(k get nodes --no-headers | grep -c ' Ready ' || true)"
  [ "$total" -ge 3 ] && [ "$total" = "$listos" ]
}

pods_sanos() {
  local ns pendientes
  for ns in "${NAMESPACES_PLATAFORMA[@]}"; do
    pendientes="$(k get pods -n "$ns" --no-headers 2>/dev/null |
      awk '$3 != "Running" && $3 != "Completed" { print }' | wc -l | tr -d ' ')"
    [ "$pendientes" = "0" ] || return 1
  done
}

hay_metricas_de_nodos() {
  k top nodes --no-headers | awk 'NF >= 5 { encontrado = 1 } END { exit !encontrado }'
}

issuer_listo() {
  [ "$(k get clusterissuer selfsigned \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ]
}

certificado_emitido() {
  local nombre="$1"
  [ "$(k get certificate "$nombre" -n demo \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ]
}

demo_responde() {
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
    "http://${DEMO_HOST}:${DEMO_PUERTO}/")" = "200" ]
}

hpa_con_metricas() {
  local objetivos
  objetivos="$(k get hpa demo -n demo -o jsonpath='{.status.currentMetrics}')"
  [ -n "$objetivos" ] && [ "$objetivos" != "null" ]
}

printf 'smoke test de la plataforma, contexto %s\n' "$CONTEXTO"

titulo 'nodos en Ready'
if esperar_a "$TIMEOUT_CORTO" nodos_listos; then
  ok "$(k get nodes --no-headers | wc -l | tr -d ' ') nodos en Ready"
else
  error 'nodos del cluster' 'tres nodos en Ready' "$(k get nodes --no-headers || true)"
fi

titulo 'pods de plataforma en Running o Completed'
if esperar_a "$TIMEOUT_LARGO" pods_sanos; then
  ok 'todos los pods de plataforma estables'
else
  error 'pods de plataforma' 'ninguno fuera de Running o Completed' \
    "$(k get pods -A --field-selector=status.phase!=Running --no-headers || true)"
fi

titulo 'metrics-server devuelve datos'
if esperar_a "$TIMEOUT_LARGO" hay_metricas_de_nodos; then
  ok 'kubectl top nodes responde con metricas'
else
  error 'kubectl top nodes' 'una fila por nodo con CPU y memoria' \
    "$(k top nodes 2>&1 || true)"
fi

titulo 'ClusterIssuer en Ready'
if esperar_a "$TIMEOUT_CORTO" issuer_listo; then
  ok 'clusterissuer selfsigned listo'
else
  error 'clusterissuer selfsigned' 'condicion Ready=True' \
    "$(k get clusterissuer selfsigned -o wide 2>&1 || true)"
fi

titulo 'certificados del namespace demo emitidos'
for certificado in wildcard-base-domain demo-tls; do
  if esperar_a "$TIMEOUT_LARGO" certificado_emitido "$certificado"; then
    ok "certificado $certificado emitido"
  else
    error "certificado $certificado" 'condicion Ready=True' \
      "$(k get certificate "$certificado" -n demo -o wide 2>&1 || true)"
  fi
done

titulo 'la app de ejemplo responde por el Ingress'
if esperar_a "$TIMEOUT_LARGO" demo_responde; then
  ok "http://${DEMO_HOST}:${DEMO_PUERTO}/ devuelve 200"
else
  error 'respuesta del Ingress' '200' \
    "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
      "http://${DEMO_HOST}:${DEMO_PUERTO}/" || true)"
fi

titulo 'el HPA reporta metricas'
if esperar_a "$TIMEOUT_LARGO" hpa_con_metricas; then
  ok "objetivo actual $(k get hpa demo -n demo --no-headers | awk '{ print $4 }')"
else
  error 'metricas del HPA' 'un porcentaje de CPU' \
    "$(k get hpa demo -n demo --no-headers 2>&1 || true)"
fi

printf '\n'
if [ "$fallos" -eq 0 ]; then
  printf 'smoke test: 7 de 7 verificaciones en verde\n'
  exit 0
fi

printf 'smoke test: %d verificaciones fallaron\n' "$fallos"
exit 1
