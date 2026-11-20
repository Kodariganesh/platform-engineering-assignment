provider "aws" {
  region = var.aws_region
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  source_dir = "/var/lib/platform-app-source"
  bootstrap_files = {
    "app/server.py"                   = "0644"
    "requirements.txt"                = "0644"
    "scripts/deploy.sh"               = "0755"
    "scripts/health-check.sh"         = "0755"
    "systemd/platform-app.service"    = "0644"
    "systemd/platform-health.service" = "0644"
    "systemd/platform-health.timer"   = "0644"
  }

  user_data = "#cloud-config\n${yamlencode({
    write_files = [
      for relative_path, mode in local.bootstrap_files : {
        path        = "${local.source_dir}/${relative_path}"
        owner       = "root:root"
        permissions = mode
        encoding    = "b64"
        content     = filebase64("${path.module}/../${relative_path}")
      }
    ]
    runcmd = [["/bin/bash", "${local.source_dir}/scripts/deploy.sh"]]
  })}"
}

resource "aws_security_group" "app" {
  name_prefix = "platform-app-"
  description = "Public application access and optional restricted SSH"
  vpc_id      = data.aws_subnet.selected.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  description       = "Public HTTP access to FastAPI"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count             = var.ssh_access == null ? 0 : 1
  security_group_id = aws_security_group.app.id
  description       = "SSH from a single public IPv4 address"
  cidr_ipv4         = var.ssh_access.cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound access for OS and Python package downloads"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "app" {
  ami                         = nonsensitive(data.aws_ssm_parameter.ubuntu.value)
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.selected.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.ssh_access == null ? null : var.ssh_access.key_name

  user_data                   = local.user_data
  user_data_replace_on_change = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    precondition {
      condition     = length(local.user_data) <= 16384
      error_message = "The cloud-init configuration exceeds the EC2 user data size limit."
    }
  }

  tags = {
    Name = "platform-app"
  }

  depends_on = [aws_vpc_security_group_egress_rule.internet]
}
