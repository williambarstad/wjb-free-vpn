# main.tf

# VPC and related resources
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env}-main"
  }
}

# CloudWatch log group for VPC flow logs
resource "aws_cloudwatch_log_group" "flow_logs_group" {
  name              = "${var.env}-flow-logs-group"
  retention_in_days = 14  # Set the retention as needed
}

# IAM role for VPC flow logs
resource "aws_iam_role" "flow_logs_role" {
  name = "${var.env}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CloudWatch Logs
resource "aws_iam_role_policy" "flow_logs_policy" {
  name   = "${var.env}-flow-logs-policy"
  role   = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.flow_logs_group.arn}:*"
      }
    ]
  })
}

# VPC flow logs sending to CloudWatch Logs
resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.flow_logs_group.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "REJECT"  # Options: ACCEPT, REJECT, or ALL
  vpc_id               = aws_vpc.main.id

  iam_role_arn = aws_iam_role.flow_logs_role.arn
}

# Subnets
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr_az1
  map_public_ip_on_launch = true  # Ensure public IP assignment
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "vpn_sg" {
  name        = "vpn-sg"
  description = "Allow OpenVPN traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.wjb-ip}"]  
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "vpn" {
  ami             = "ami-0123456789abcdef0"  # Replace with OpenVPN AMI or other
  instance_type   = "t3.micro"
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.vpn_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              yum install -y openvpn easy-rsa

              # Set up the CA and generate server certificates
              make-cadir /etc/openvpn/easy-rsa
              cd /etc/openvpn/easy-rsa
              ./easyrsa init-pki
              echo -ne '\n' | ./easyrsa build-ca nopass
              ./easyrsa gen-req server nopass
              echo -ne '\n' | ./easyrsa sign-req server server
              ./easyrsa gen-dh

              # Copy files to the OpenVPN directory
              cp pki/private/server.key /etc/openvpn/
              cp pki/issued/server.crt /etc/openvpn/
              cp pki/ca.crt /etc/openvpn/
              cp pki/dh.pem /etc/openvpn/

              # Create server configuration
              cat <<EOL > /etc/openvpn/server.conf
              port 1194
              proto udp
              dev tun
              ca ca.crt
              cert server.crt
              key server.key
              dh dh.pem
              server 10.8.0.0 255.255.255.0
              ifconfig-pool-persist ipp.txt
              push "redirect-gateway def1 bypass-dhcp"
              push "dhcp-option DNS 8.8.8.8"
              keepalive 10 120
              cipher AES-256-CBC
              persist-key
              persist-tun
              status openvpn-status.log
              verb 3
              EOL

              # Enable IP forwarding
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

              # Start and enable OpenVPN service
              systemctl start openvpn@server
              systemctl enable openvpn@server
              EOF

  tags = {
    Name = "OpenVPN-Server"
  }
}

# resource "null_resource" "vpn_post_config" {
#   provisioner "remote-exec" {
#     inline = [
#       "sudo wjb-vpn-conf.sh"
#     ]
#     connection {
#       type        = "ssh"
#       host        = aws_instance.vpn.public_ip
#       user        = "ec2-user"  # Replace with correct user
#       private_key = file("~/.ssh/id_rsa")  # Path to your SSH key
#     }
#   }

#   depends_on = [aws_instance.vpn]
# }

output "vpn_ip" {
  value = aws_instance.vpn.public_ip
}
