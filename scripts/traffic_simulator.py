#!/usr/bin/env python3
"""
Gera três padrões de tráfego contra os serviços do cluster:

1. normal   - requisições espaçadas ao frontend (baseline)
2. burst    - rajada curta de requisições ao frontend (simula pico de carga)
3. blocked  - tentativa direta ao backend, que a NetworkPolicy deve recusar

O objetivo é ter, nos dashboards do Grafana e nos logs do Loki, exemplos
visíveis de tráfego permitido vs. tráfego bloqueado pela política de rede.
"""
import random
import socket
import sys
import time
import urllib.request

FRONTEND_URL = "http://frontend-web.frontend.svc.cluster.local"
BACKEND_URL = "http://backend-api.backend.svc.cluster.local"


def log(pattern, target, result):
    ts = time.strftime("%Y-%m-%dT%H:%M:%S")
    print(f'{{"ts":"{ts}","pattern":"{pattern}","target":"{target}","result":"{result}"}}', flush=True)


def request(url, timeout=2):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            return f"http_{resp.status}"
    except (socket.timeout, TimeoutError):
        return "timeout"
    except Exception as exc:  # noqa: BLE001 - queremos capturar qualquer falha de rede
        return f"error:{type(exc).__name__}"


def run_normal(n=10):
    for _ in range(n):
        result = request(FRONTEND_URL)
        log("normal", "frontend", result)
        time.sleep(random.uniform(0.5, 2))


def run_burst(n=30):
    for _ in range(n):
        result = request(FRONTEND_URL, timeout=1)
        log("burst", "frontend", result)


def run_blocked_attempt(n=3):
    # Espera-se "timeout" aqui: a NetworkPolicy do namespace backend
    # só libera ingress vindo do namespace frontend, não de traffic-sim.
    for _ in range(n):
        result = request(BACKEND_URL, timeout=3)
        log("blocked-attempt", "backend", result)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("normal", "all"):
        run_normal()
    if mode in ("burst", "all"):
        run_burst()
    if mode in ("blocked", "all"):
        run_blocked_attempt()
