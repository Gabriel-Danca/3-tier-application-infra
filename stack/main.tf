resource "aws_vpc" "gdanca_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name  = "gdanca-vpc-terraform"
    Owner = "gdanca"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.gdanca_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name  = "gdanca-subnet1"
    Owner = "gdanca"
  }
}



resource "aws_internet_gateway" "gdanca_igw" {
  vpc_id = aws_vpc.gdanca_vpc.id

  tags = {
    Name  = "gdanca_igw"
    Owner = "gdanca"
  }
}



resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.gdanca_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gdanca_igw.id
  }

  #   route {
  #     ipv6_cidr_block        = "::/0"
  #     egress_only_gateway_id = aws_egress_only_internet_gateway.example.id
  #   }

  tags = {
    Name  = "gdanca_public_route_table"
    Owner = "gdanca"
  }
}

resource "aws_route_table_association" "subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_security_group" "gdanca_k8s_sg" {
  name   = "gdanca_k8s_sg"
  vpc_id = aws_vpc.gdanca_vpc.id

  tags = {
    Name  = "gdanca_k8s_sg"
    Owner = "gdanca"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.gdanca_k8s_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_k8s_api" {
  security_group_id = aws_security_group.gdanca_k8s_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "allow_nodeports" {
  security_group_id = aws_security_group.gdanca_k8s_sg.id
  cidr_ipv4         = "${chomp(data.http.myip.response_body)}/32"
  from_port         = 30000
  ip_protocol       = "tcp"
  to_port           = 32767
}

resource "aws_vpc_security_group_ingress_rule" "allow_internal_traffic" {
  security_group_id            = aws_security_group.gdanca_k8s_sg.id
  referenced_security_group_id = aws_security_group.gdanca_k8s_sg.id
  from_port                    = -1
  ip_protocol                  = "-1"
  to_port                      = -1
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.gdanca_k8s_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = -1
  ip_protocol       = "-1"
  to_port           = -1
}

resource "aws_instance" "gdanca_control_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet1.id
  vpc_security_group_ids      = [aws_security_group.gdanca_k8s_sg.id]
  associate_public_ip_address = true
  key_name                    = "gdanca-3tier"

  # user_data = file("script.sh")

  tags = {
    Name  = "gdanca_control_node"
    Owner = "gdanca"
  }
}

resource "aws_instance" "gdanca_worker_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet1.id
  vpc_security_group_ids      = [aws_security_group.gdanca_k8s_sg.id]
  associate_public_ip_address = true
  key_name                    = "gdanca-3tier"

  #   user_data = file("script.sh")

  tags = {
    Name  = "gdanca_worker_node"
    Owner = "gdanca"
  }
}

resource "local_file" "ansible_inventory" {
  content = <<-EOF
  [control_plane]
  ${aws_instance.gdanca_control_node.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=./gdanca-key.pem

  [workers]
  ${aws_instance.gdanca_worker_node.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=./gdanca-key.pem

  [k8s_cluster:children]
  control_plane
  workers
  EOF

  filename        = "${path.module}/../../../ansible/inventory.ini"
  file_permission = "0644"
}

