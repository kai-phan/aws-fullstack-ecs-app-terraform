# Security Module

## Overview
Create security groups for Application Load Balancers and ECS tasks with proper ingress/egress rules following the principle of least privilege.

## Architecture
- ALB Security Group: Allows HTTP/HTTPS traffic from internet
- ECS Security Group: Allows traffic only from ALB security group
- Proper egress rules for outbound internet access

## Files to Create

### 1. variables.tf
**Purpose**: Define input variables for the security module
**Location**: `Infrastructure/Modules/security/variables.tf`

```hcl
variable "environment_name" {
  description = "Environment name for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### 2. main.tf
**Purpose**: Security groups and rules configuration
**Location**: `Infrastructure/Modules/security/main.tf`

```hcl
# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.environment_name}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP inbound from anywhere
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS inbound from anywhere (for future SSL implementation)
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment_name}-alb-sg"
    Type = "ALB"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.environment_name}-ecs-tasks-"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  # HTTP inbound from ALB security group
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow communication between ECS tasks (for service discovery)
  ingress {
    description = "Inter-service communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # All outbound traffic (for downloading images, accessing AWS services, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment_name}-ecs-tasks-sg"
    Type = "ECS"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for RDS (if needed in future)
resource "aws_security_group" "rds" {
  name_prefix = "${var.environment_name}-rds-"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  # MySQL/Aurora inbound from ECS tasks
  ingress {
    description     = "MySQL from ECS tasks"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  # PostgreSQL inbound from ECS tasks (alternative)
  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  # No outbound rules needed for RDS

  tags = merge(var.tags, {
    Name = "${var.environment_name}-rds-sg"
    Type = "RDS"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for VPC Endpoints (for AWS services access)
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.environment_name}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  # HTTPS inbound from VPC CIDR
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  # No outbound rules needed for VPC endpoints

  tags = merge(var.tags, {
    Name = "${var.environment_name}-vpc-endpoints-sg"
    Type = "VPCEndpoints"
  })

  lifecycle {
    create_before_destroy = true
  }
}
```

### 3. outputs.tf
**Purpose**: Export security group IDs for use by other modules
**Location**: `Infrastructure/Modules/security/outputs.tf`

```hcl
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = aws_security_group.alb.arn
}

output "ecs_security_group_arn" {
  description = "ARN of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.arn
}
```

## Implementation Steps

1. **Create the module directory**:
   ```bash
   mkdir -p Infrastructure/Modules/security
   ```

2. **Create variables.tf** with the input variables

3. **Create main.tf** with all security group resources

4. **Create outputs.tf** with the exported values

5. **Test the module** by adding it to your main.tf:
   ```hcl
   module "security" {
     source = "./Modules/security"
     
     environment_name = var.environment_name
     vpc_id          = module.networking.vpc_id
     vpc_cidr_block  = module.networking.vpc_cidr_block
     
     tags = local.common_tags
   }
   ```

6. **Validate the configuration**:
   ```bash
   cd Infrastructure
   terraform plan
   ```

## Security Best Practices

### Principle of Least Privilege
- ALB security group only allows HTTP/HTTPS from internet
- ECS security group only allows traffic from ALB
- No unnecessary ports are opened

### Defense in Depth
- Multiple layers of security (ALB → ECS → Database)
- Security groups act as virtual firewalls
- Network segmentation through private subnets

### Egress Control
- ECS tasks have outbound internet access for:
  - Pulling container images from ECR
  - Accessing AWS services (DynamoDB, S3, etc.)
  - External API calls if needed

## Security Group Rules Explained

### ALB Security Group
- **Ingress**: HTTP (80) and HTTPS (443) from anywhere (0.0.0.0/0)
- **Egress**: All traffic (required for health checks and forwarding)

### ECS Security Group
- **Ingress**: HTTP (80) only from ALB security group
- **Ingress**: Self-referencing for inter-service communication
- **Egress**: All traffic (for AWS service access and image pulls)

### RDS Security Group (Future Use)
- **Ingress**: Database ports only from ECS security group
- **Egress**: None (databases don't need outbound access)

### VPC Endpoints Security Group
- **Ingress**: HTTPS (443) from VPC CIDR
- **Egress**: None (endpoints don't need outbound access)

## Advanced Security Considerations

### Future Enhancements
1. **WAF Integration**: Add AWS WAF for application-layer protection
2. **SSL/TLS**: Implement HTTPS with ACM certificates
3. **Network ACLs**: Add subnet-level access control
4. **VPC Flow Logs**: Enable for network monitoring

### Monitoring and Alerting
- CloudWatch metrics for security group changes
- AWS Config rules for compliance monitoring
- VPC Flow Logs for traffic analysis

## Troubleshooting

### Common Issues
1. **Connection timeouts**: Check security group rules and NACLs
2. **Health check failures**: Ensure ALB can reach ECS tasks on port 80
3. **Service discovery issues**: Verify self-referencing rules

### Validation Commands
```bash
# Check security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-xxxxxxxxx"

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx

# Test connectivity (from EC2 instance)
telnet <target-ip> 80
```

## Next Step
Proceed to [IAM Module](./04-iam-module.md) to create IAM roles and policies for ECS tasks and CI/CD services.
