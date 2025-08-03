terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-vpc"
  })
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-igw"
  })
}

# Public subnets
resource "aws_subnet" "public" {
  count = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone = "${var.aws_region}${var.availability_zones[count.index]}"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-public-subnet"
  })
}

# Private subnets client
resource "aws_subnet" "private_client" {
  count = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 1 + length(var.availability_zones))
  availability_zone = "${var.aws_region}${var.availability_zones[count.index]}"

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-private-client-subnet"
  })
}

# Private subnets server
resource "aws_subnet" "private_server" {
  count = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 1 + length(var.availability_zones) * 2)
  availability_zone = "${var.aws_region}${var.availability_zones[count.index]}"

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-private-server-subnet"
  })
}

# Elastic IP
resource "aws_eip" "eip" {
  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-eip"
  })
}

# NAT gateway
resource "aws_nat_gateway" "nat" {
  subnet_id = aws_subnet.public[0].id
  allocation_id = aws_eip.eip.id

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-nat"
  })
}


# Public route table
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-public-route-table"
  })
}

# Private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-private-route-table"
  })
}

# Route table association
resource "aws_route_table_association" "public_rt_assoc" {
  count = length(var.availability_zones)
  route_table_id = aws_default_route_table.default.id
  subnet_id = aws_subnet.public[count.index].id
}

resource "aws_route_table_association" "private_client_rt_assoc" {
  count = length(var.availability_zones)
  route_table_id = aws_route_table.private_rt.id
  subnet_id = aws_subnet.private_client[count.index].id
}

resource "aws_route_table_association" "private_server_rt_assoc" {
  count = length(var.availability_zones)
  route_table_id = aws_route_table.private_rt.id
  subnet_id = aws_subnet.private_server[count.index].id
}