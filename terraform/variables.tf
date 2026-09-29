variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used for naming all resources"
  type        = string
  default     = "chaosops"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (control-plane + workers)"
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "AZ for the subnet"
  type        = string
  default     = "ap-south-1a"
}

variable "instance_type_master" {
  description = "Instance type for the Kubernetes control-plane node"
  type        = string
  default     = "t3.medium" # kubeadm needs >=2 vCPU / 2GB RAM min; t3.medium is comfortable
}

variable "instance_type_worker" {
  description = "Instance type for Kubernetes worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form, e.g. 1.2.3.4/32 — used to restrict SSH/API access"
  type        = string
  # No default on purpose: force the operator to set this explicitly (terraform.tfvars)
}

variable "key_name" {
  description = "Name to give the generated AWS key pair"
  type        = string
  default     = "chaosops-key"
}

variable "app_node_port" {
  description = "NodePort the Flask app Service is exposed on inside the cluster"
  type        = number
  default     = 30080
}

variable "grafana_node_port" {
  description = "NodePort Grafana is exposed on (via kube-prometheus-stack)"
  type        = number
  default     = 30030
}

variable "prometheus_node_port" {
  description = "NodePort Prometheus is exposed on"
  type        = number
  default     = 30090
}
