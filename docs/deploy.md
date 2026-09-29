# ChaosOps Platform — Infra, Deployment & Monitoring

Everything after CI (build/test/push, already in `.github/workflows/ci.yml`):
provisioning AWS infra, standing up a self-managed Kubernetes cluster,
deploying the app, and monitoring it — Terraform, Ansible, Kubernetes,
Prometheus, Grafana, AWS. No Helm, no ArgoCD, no Operators — everything is
plain `kubectl apply` manifests.

```
Terraform (AWS: VPC, EC2 x3, SG, key pair)
        |  writes ansible/inventory/hosts.ini automatically
        v
Ansible (containerd, kubeadm, kubelet/kubectl, kubeadm init, Calico, join workers)
        |  produces /tmp/ansible-fetched/kubeconfig
        v
kubectl (deploy app, install metrics-server, apply raw Prometheus + Grafana manifests)
        |
        v
Prometheus + Grafana (node + cluster metrics now; app metrics after /metrics is added)
```

## 0. Prerequisites

- AWS account + credentials (`aws configure`, or exported `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`)
- Terraform >= 1.5, Ansible >= 2.15, kubectl
- Your public IP: `curl -s https://checkip.amazonaws.com`

## 1. Provision AWS infra

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set my_ip_cidr to your real IP/32

terraform init
terraform plan
terraform apply
```

Creates a VPC, one public subnet, a security group scoped to your IP
(SSH + API server + NodePort range only), a generated SSH key pair
(`terraform/chaosops-key.pem`), 1 master + 2 worker EC2 instances, and
writes `ansible/inventory/hosts.ini` with their real IPs.

## 2. Bootstrap the Kubernetes cluster

```bash
cd ../ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

Installs containerd + kubeadm/kubelet/kubectl on every node, runs
`kubeadm init` on the master, applies Calico as the CNI, joins both workers.
Idempotent — safe to re-run if a step fails partway.

Point kubectl at the cluster:

```bash
mkdir -p ~/.kube
cp /tmp/ansible-fetched/kubeconfig ~/.kube/config
sed -i "s/127.0.0.1/$(head -n1 inventory/hosts.ini | tail -n1 | cut -d' ' -f1)/" ~/.kube/config
kubectl get nodes    # master + 2 workers, all Ready within ~1-2 min
```

## 3. Deploy the app

Edit `k8s/base/deployment.yaml`, replace `<dockerhub-username>` with your
real DockerHub username (same one CI pushes to), then:

```bash
kubectl apply -k k8s/base/
kubectl get pods -n chaosops -w
```

Reach it at `http://<any-node-public-ip>:30080/`.

## 4. Install metrics-server (needed for the HPA)

Not a Helm chart — it's a plain manifest from the project's GitHub releases:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p="$(tail -n +5 k8s/monitoring/metrics-server.yaml)"
kubectl top nodes   # returns numbers once ready
```

(The patch adds `--kubelet-insecure-tls`, needed because kubeadm kubelets
use self-signed certs metrics-server doesn't trust by default — unlike
EKS/GKE.)

## 5. Install Prometheus + Grafana (raw manifests)

Apply in order — files are numbered so `kubectl apply -f k8s/monitoring/`
naturally applies them correctly, except the Grafana secret which you
create directly rather than commit:

```bash
kubectl create secret generic grafana-admin \
  --namespace monitoring \
  --from-literal=admin-password='<pick-a-real-password>'

kubectl apply -f k8s/monitoring/00-namespace.yaml
kubectl apply -f k8s/monitoring/01-prometheus-rbac.yaml
kubectl apply -f k8s/monitoring/02-prometheus-configmap.yaml
kubectl apply -f k8s/monitoring/03-prometheus-deployment.yaml
kubectl apply -f k8s/monitoring/04-node-exporter.yaml
kubectl apply -f k8s/monitoring/05-grafana-datasource-configmap.yaml
kubectl apply -f k8s/monitoring/07-grafana-deployment.yaml

kubectl get pods -n monitoring -w
```

- Prometheus: `http://<any-node-public-ip>:30090` — check **Status > Targets**;
  you should see `kubernetes-nodes`, `kubernetes-cadvisor`, and `node-exporter`
  all `UP` within a minute.
- Grafana: `http://<any-node-public-ip>:30030` (user `admin`, the password
  you set above). The Prometheus datasource is pre-provisioned — go to
  **Dashboards > New > Import** and use community dashboard ID `1860`
  (Node Exporter Full) to get real graphs immediately without building
  panels by hand.

## 6. (Optional) Scrape app-level metrics

`app/app.py` doesn't expose Prometheus metrics yet. `k8s/base/deployment.yaml`
already carries the `prometheus.io/scrape` annotations Prometheus's
`kubernetes-pods` job looks for — it'll start scraping automatically the
moment `/metrics` exists. Two-line addition to the app:

```python
from prometheus_flask_exporter import PrometheusMetrics
metrics = PrometheusMetrics(app)   # auto-adds request count/latency at /metrics
```

Add `prometheus-flask-exporter` to `requirements.txt`, push through CI, then
`kubectl rollout restart deployment/chaosops-app -n chaosops` — no changes
needed on the Prometheus side, the annotation-based discovery just picks it up.

## 7. Load test / trigger the HPA

```bash
# install hey: go install github.com/rakyll/hey@latest  (or apt/brew)
hey -z 60s -c 20 http://<any-node-public-ip>:30080/cpu
kubectl get hpa -n chaosops -w    # watch replicas scale 2 -> up to 6
```

## 8. Tear down (avoid ongoing AWS cost)

```bash
cd ../terraform
terraform destroy
```

Everything on top (pods, deployments) goes with the EC2 instances.

## Cost note

3x t3.medium in ap-south-1 runs roughly $0.12–0.15/hr total on-demand
(check current AWS pricing). `terraform destroy` when not actively using it.
