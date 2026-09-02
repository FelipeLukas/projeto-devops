
$ErrorActionPreference = "Stop"

Write-Host "== [1/4] Criando cluster (se não existir) =="
if (-not (kind get clusters | Select-String "projeto-devops")) {
    kind create cluster --name projeto-devops --config .\kind-config.yaml
} else {
    Write-Host "Cluster já existe. Pulando criação."
}

Write-Host "== [2/4] Build das imagens =="
docker build -t testando:v1 .\testando
docker build -t melhorando:v1 .\melhorando
docker build -t confirmando:v1 .\confirmando

Write-Host "== [3/4] Carregando imagens no Kind =="
kind load docker-image testando:v1 --name projeto-devops
kind load docker-image melhorando:v1 --name projeto-devops
kind load docker-image confirmando:v1 --name projeto-devops

Write-Host "== [4/4] Aplicando manifests =="
kubectl apply -f .\deployments.yaml

Write-Host "== Status dos pods =="
kubectl get pods -o wide
Write-Host "== Services =="
kubectl get svc

#endereços para conseguir acessar os containers

Write-Host ""
Write-Host "Tente acessar no navegador:"
Write-Host " - Testando:   http://localhost:30001"
Write-Host " - Melhorando: http://localhost:30002"
Write-Host " - Confirmando:http://localhost:30003"
