# Networking Module

## Overview
Create the networking infrastructure including VPC, subnets, internet gateway, NAT gateways, and route tables following AWS best practices for high availability.

## Architecture
- 1 VPC with configurable CIDR block
- 2 Public subnets (for ALBs) across different AZs
- 2 Private subnets (for ECS tasks) across different AZs
- 1 Internet Gateway for public internet access
- 2 NAT Gateways (one per AZ) for private subnet internet access
- Route tables with appropriate routing rules

## Files to Create

### 1. variables.tf
**Purpose**: Define input variables for the networking module
**Location**: `Infrastructure/Modules/networking/variables.tf`

```hcl
variable "environment_name" {
  description = "Environment name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zone suffixes"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### 2. main.tf
**Purpose**: Main networking resources configuration
**Location**: `Infrastructure/Modules/networking/main.tf`

```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.environment_name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.environment_name}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = "${var.aws_region}${var.availability_zones[count.index]}"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.environment_name}-public-subnet-${var.availability_zones[count.index]}"
    Type = "Public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = "${var.aws_region}${var.availability_zones[count.index]}"

  tags = merge(var.tags, {
    Name = "${var.environment_name}-private-subnet-${var.availability_zones[count.index]}"
    Type = "Private"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = length(var.availability_zones)
  
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.environment_name}-nat-eip-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.environment_name}-nat-gateway-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.environment_name}-public-rt"
    Type = "Public"
  })
}

# Private Route Tables (one per AZ)
resource "aws_route_table" "private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.environment_name}-private-rt-${var.availability_zones[count.index]}"
    Type = "Private"
  })
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

### 3. outputs.tf
**Purpose**: Export networking resources for use by other modules
**Location**: `Infrastructure/Modules/networking/outputs.tf`

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = [for az in var.availability_zones : "${var.aws_region}${az}"]
}
```

## Implementation Steps

1. **Create the module directory**:
   ```bash
   mkdir -p Infrastructure/Modules/networking
   ```

2. **Create variables.tf** with the input variables

3. **Create main.tf** with all networking resources

4. **Create outputs.tf** with the exported values

5. **Test the module** by adding it to your main.tf:
   ```hcl
   module "networking" {
     source = "./Modules/networking"
     
     environment_name    = var.environment_name
     aws_region         = var.aws_region
     availability_zones = var.availability_zones
     vpc_cidr          = var.vpc_cidr
     
     tags = local.common_tags
   }
   ```

6. **Validate the configuration**:
   ```bash
   cd Infrastructure
   terraform init
   terraform plan
   ```

## Key Features

### High Availability
- Resources are distributed across multiple availability zones
- Each AZ has its own NAT Gateway for redundancy

### Security
- Private subnets for ECS tasks (no direct internet access)
- Public subnets only for load balancers
- Proper routing through NAT Gateways for outbound internet access

### Scalability
- CIDR blocks are calculated dynamically using `cidrsubnet()`
- Easy to add more subnets or change CIDR ranges

### Cost Optimization
- NAT Gateways are placed in each AZ (consider cost vs availability trade-offs)
- Elastic IPs are properly managed

## Network Design Details

### CIDR Allocation
- VPC: 10.0.0.0/16 (default, configurable)
- Public subnets: 10.0.1.0/24, 10.0.2.0/24
- Private subnets: 10.0.10.0/24, 10.0.11.0/24

### Routing
- Public subnets route to Internet Gateway for internet access
- Private subnets route to NAT Gateway in same AZ for outbound internet
- All subnets can communicate within VPC

## Troubleshooting

### Common Issues
1. **CIDR conflicts**: Ensure CIDR blocks don't overlap
2. **AZ availability**: Some regions may not have all requested AZs
3. **NAT Gateway costs**: Consider using single NAT Gateway for cost savings in dev environments

### Validation Commands
```bash
# Check VPC creation
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=your-env-vpc"

# Check subnet creation
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxxxxxx"

# Check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxxxxxxxx"
```

## Next Step
Proceed to [Security Module](../../docs/03-security-module.md) to create security groups and network access controls.
