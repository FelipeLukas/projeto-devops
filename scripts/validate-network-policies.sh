#!/usr/bin/env bash
# Roda um pod descartável em cada namespace relevante e testa conectividade
# real contra os serviços, comparando o resultado com o que a NetworkPolicy
# deveria permitir ou bloquear. Serve como evidência (print de terminal)
# de que o isolamento declarado nos manifests realmente está em vigor.
set -uo pipefail

run_test() {
  local description="$1" ns="$2" target="$3" expect="$4"
  echo -n "[${ns}] ${description} ... "
  if kubectl run netpol-test-$$ --rm -i --restart=Never --quiet \
      --namespace "${ns}" --image=busybox:1.36 --command -- \
      wget -q -T 3 -O- "${target}" >/dev/null 2>&1; then
    result="ALLOWED"
  else
    result="BLOCKED"
  fi

  if [ "${result}" = "${expect}" ]; then
    echo "OK (${result})"
  else
    echo "FALHOU - esperado ${expect}, obtido ${result}"
  fi
}

echo "== Validando NetworkPolicies do cluster netmon =="
run_test "frontend -> backend (deve ser permitido)" frontend "http://backend-api.backend.svc.cluster.local" "ALLOWED"
run_test "traffic-sim -> frontend (deve ser permitido)" traffic-sim "http://frontend-web.frontend.svc.cluster.local" "ALLOWED"
run_test "traffic-sim -> backend (deve ser bloqueado)" traffic-sim "http://backend-api.backend.svc.cluster.local" "BLOCKED"
run_test "backend -> frontend (deve ser bloqueado, egress não liberado)" backend "http://frontend-web.frontend.svc.cluster.local" "BLOCKED"
echo "== Fim da validação =="
