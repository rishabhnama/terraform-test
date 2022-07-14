terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.10.0"
    }
  }
}

provider "aws" {
  # Configuration options
}


#1. Create a VPC 

resource "aws_vpc" "test-vpc" {
  cidr_block = "10.0.0.0/16"
}

#2 Create 2 Subnets 1 public 1 private

#2.1 Public Subnet
#Internet gateway for incoming public requests 

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.test-vpc.id

}

# Custom route-table to get traffic to the gateway

resource "aws_route_table" "test-route-table" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0" #Forward all ipv4 traffic to gateway
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0" #Forward all ipv6 traffic o gateway
    egress_only_gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "test-route-table"
  }
}

# Public Subnet
resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "10.0.0.0/24"

}
# Link Public Subnet to the route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.test-route-table.id
}

# 2.2 Private subnet
resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_eip" "nat-eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.gw]

}

# NAT Gateway for Private subnet in Public Subnet
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.public-subnet.id
  depends_on    = [aws_internet_gateway.gw]
}

# Route table for Private subnet
resource "aws_route_table" "prt" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }
}

# Link Private Subnet to the route table
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.prt.id
}


# NSG x2
resource "aws_security_group" "nsg-public" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.test-vpc.cidr_block]
    # ipv6_cidr_blocks = [aws_vpc.test-vpc.ipv6_cidr_block]
  }
  ingress {
    description = "HTTPs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.test-vpc.cidr_block]
    # ipv6_cidr_blocks = [aws_vpc.test-vpc.ipv6_cidr_block]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.test-vpc.cidr_block]
    # ipv6_cidr_blocks = [aws_vpc.test-vpc.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "nsg-public"
  }
}

resource "aws_security_group" "nsg-private" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.test-vpc.cidr_block]
    # ipv6_cidr_blocks = [aws_vpc.test-vpc.ipv6_cidr_block]
  }
  ingress {
    description = "HTTPs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.test-vpc.cidr_block]
    # ipv6_cidr_blocks = [aws_vpc.test-vpc.ipv6_cidr_block]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.test-vpc.cidr_block]
    # ipv6_cidr_blocks = [aws_vpc.test-vpc.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "nsg-public"
  }
}


# 2 EC2 severs 1 in public and 1 in private

#Public EC2
resource "aws_instance" "public-ec2" {
  ami                         = "ami-005e54dee72cc1d00" # us-west-2
  instance_type               = "t8.micro"
  vpc_security_group_ids      = ["${aws_security_group.nsg-public.id}"]
  subnet_id                   = aws_subnet.public-subnet.id
  associate_public_ip_address = true

  tags = {
    Name = "Public EC2"
  }
}

#Private EC2
resource "aws_instance" "private-ec2" {
  ami                         = "ami-005e54dee72cc1d00" # us-west-2
  instance_type               = "t2.micro"
  vpc_security_group_ids      = ["${aws_security_group.nsg-private.id}"]
  subnet_id                   = aws_subnet.private-subnet.id
  associate_public_ip_address = false

  tags = {
    Name = "Private EC2"
  }
}








