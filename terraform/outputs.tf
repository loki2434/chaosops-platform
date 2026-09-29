output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ips" {
  value = aws_instance.worker[*].public_ip
}

output "ssh_private_key_path" {
  value = local_file.private_key.filename
}

output "kubectl_context_hint" {
  value = "After the Ansible run: scp -i ${var.key_name}.pem ubuntu@${aws_instance.master.public_ip}:~/.kube/config ./kubeconfig && export KUBECONFIG=./kubeconfig"
}

# Renders ../ansible/inventory/hosts.ini directly from the real instance IPs,
# so you never hand-copy IPs between Terraform and Ansible.
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.ini"
  content  = <<-EOT
    [master]
    ${aws_instance.master.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/${var.key_name}.pem

    [workers]
    %{ for worker in aws_instance.worker ~}
    ${worker.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/${var.key_name}.pem
    %{ endfor ~}

    [all:vars]
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
    ansible_python_interpreter=/usr/bin/python3
  EOT
}
