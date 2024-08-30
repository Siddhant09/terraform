
provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

# 1. Create a vpc
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "test vpc"
  }
}

# 2. Create internet gateway
resource "aws_internet_gateway" "my-gw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "test gw"
  }
}

# 3. Create custom route table
resource "aws_route_table" "my-route-table" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_internet_gateway.my-gw.id
  }

  tags = {
    Name = "test route table"
  }
}

# 4. Create a subnet
resource "aws_subnet" "my-subnet" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "test subnet"
  }
}

# 5. Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.my-subnet.id
  route_table_id = aws_route_table.my-route-table.id
}

# 6. Create security groups to allow port 22, 80, 443
resource "aws_security_group" "allow-web" {
  name        = "allow-web-traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in setp 4
resource "aws_network_interface" "web-server" {
  subnet_id       = aws_subnet.my-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]
}

# 8. Assign an elastic ip to the network interface create in step 7
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.multi-ip.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = aws_internet_gateway.my-gw
}

# 9. Create ubuntu server and install/enable apache2
resource "aws_instance" "my-instance" {
  ami               = "ami-07cc1bbe145f35b58"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "newkey"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server.id
  }

  tags = {
    Name = "test instance"
  }

  user_data = <<-EOF
        <powershell>
            Install-WindowsFeature -name Web-Server -IncludeManagementTools
            New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'RunOnce' -Value 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Install-WindowsFeature Web-Server -IncludeManagementTools"'
            Start-Service W3SVC
            Set-Service -Name W3SVC -StartupType Automatic
        </powershell>
    EOF
}

output "public-ip" {
  value = aws_instance.my-instance.public_ip
}
