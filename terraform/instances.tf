resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = var.instance_type_master
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.k8s_nodes.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-k8s-master"
    Role = "master"
  }
}

resource "aws_instance" "worker" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = var.instance_type_worker
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.k8s_nodes.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-k8s-worker-${count.index + 1}"
    Role = "worker"
  }
}
