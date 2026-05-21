data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Project = var.project_name
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = { for idx, az in local.azs : az => idx }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                     = "${var.project_name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in local.azs : az => idx }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 10)

  tags = merge(local.tags, {
    Name                              = "${var.project_name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "nat" {
  name        = "${var.project_name}-nat"
  description = "NAT instance traffic"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Private subnet egress through NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat"
  })
}

resource "aws_instance" "nat" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = "t4g.nano"
  subnet_id                   = values(aws_subnet.public)[0].id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  associate_public_ip_address = true
  source_dest_check           = false

  user_data = <<-USERDATA
    #!/bin/bash
    set -eux
    sysctl -w net.ipv4.ip_forward=1
    echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-nat.conf
    dnf install -y iptables-services
    iptables -t nat -A POSTROUTING -o $(ip route show default | awk '{print $5}') -j MASQUERADE
    service iptables save
    systemctl enable --now iptables
  USERDATA

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-instance"
  })
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat.primary_network_interface_id
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-private-${each.key}-rt"
  })
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
