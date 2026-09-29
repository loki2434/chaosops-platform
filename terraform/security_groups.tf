# One security group shared by master + workers, modeled on kubeadm's
# documented port requirements. Node-to-node traffic is allowed via
# self-reference so Calico/Flannel overlay + kube-proxy work without
# needing per-port node rules.

resource "aws_security_group" "k8s_nodes" {
  name        = "${var.project_name}-k8s-nodes-sg"
  description = "Security group for kubeadm control-plane and worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-k8s-nodes-sg"
  }
}

# --- SSH: restricted to operator IP only ---
resource "aws_security_group_rule" "ssh_in" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_cidr]
  security_group_id = aws_security_group.k8s_nodes.id
  description       = "SSH from operator IP"
}

# --- Kubernetes API server: restricted to operator IP (kubectl from laptop) ---
resource "aws_security_group_rule" "k8s_api_in" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_cidr]
  security_group_id = aws_security_group.k8s_nodes.id
  description       = "kube-apiserver from operator IP"
}

# --- All node-to-node traffic (etcd, kubelet, NodePort range, CNI overlay) ---
resource "aws_security_group_rule" "nodes_self_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.k8s_nodes.id
  description       = "Allow all traffic between cluster nodes"
}

# --- NodePort range open to operator IP so the app/Grafana/Prometheus are reachable ---
resource "aws_security_group_rule" "nodeport_range_in" {
  type              = "ingress"
  from_port         = 30000
  to_port            = 32767
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_cidr]
  security_group_id = aws_security_group.k8s_nodes.id
  description       = "NodePort range (app, Grafana, Prometheus) from operator IP"
}

# --- Egress: allow everything (package installs, container pulls, etc.) ---
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_nodes.id
  description       = "Allow all outbound"
}
