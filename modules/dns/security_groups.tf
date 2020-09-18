locals {
  timestamp_string = formatdate("YYYYMMDDhhmmss", timestamp())
}

resource "aws_security_group" "dns_server" {
  name        = "${var.prefix}-dns-server-${local.timestamp_string}"
  description = "Allow the ECS agent to talk to the ECS endpoints"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}
