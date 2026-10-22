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

resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-${each.key}"
  })
}

# One NAT instance per AZ keeps private-subnet egress available when a single
# NAT instance or AZ fails, while retaining the lower cost of NAT instances.
resource "aws_instance" "nat" {
  for_each                    = aws_subnet.public
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = "t4g.micro"
  subnet_id                   = each.value.id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  associate_public_ip_address = false
  source_dest_check           = false

  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-USERDATA
#!/bin/bash
set -eux
mkdir -p /etc/systemd/network/80-ec2.network.d
cat <<'EOF' > /etc/systemd/network/80-ec2.network.d/nat.conf
[Network]
IPv4Forwarding=yes
EOF
cat <<'EOF' > /etc/sysctl.d/99-nat.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
EOF
sysctl --system
systemctl restart systemd-networkd
dnf install -y iptables iptables-services
PRIMARY_IFACE=$(ip route show default | awk '{print $5}')
iptables -t nat -A POSTROUTING -o "$PRIMARY_IFACE" -j MASQUERADE
service iptables save
systemctl enable --now iptables
USERDATA

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-instance-${each.key}"
  })
}

resource "aws_eip_association" "nat" {
  for_each      = aws_instance.nat
  allocation_id = aws_eip.nat[each.key].id
  instance_id   = each.value.id
}

# Recover an impaired NAT host in place. The Elastic IP and private interface
# are retained, so the private route table does not need to change.
resource "aws_cloudwatch_metric_alarm" "nat_system_status" {
  for_each            = aws_instance.nat
  alarm_name          = "${var.project_name}-nat-system-status-${each.key}"
  alarm_description   = "Recover an impaired NAT instance"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = ["arn:aws:automate:${var.aws_region}:ec2:recover"]

  dimensions = {
    InstanceId = each.value.id
  }
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat[each.key].primary_network_interface_id
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
