# ECR Module

## Overview
Create Amazon Elastic Container Registry (ECR) repositories for storing Docker images of the frontend and backend applications with appropriate lifecycle policies.

## Architecture
- Client ECR Repository: For Vue.js frontend container images
- Server ECR Repository: For Node.js backend container images
- Lifecycle policies to manage image retention and costs
- Repository policies for secure access

## Files to Create

### 1. variables.tf
**Purpose**: Define input variables for the ECR module
**Location**: `Infrastructure/Modules/ecr/variables.tf`

```hcl
variable "environment_name" {
  description = "Environment name for resource naming"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository"
  type        = string
  default     = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}
```

### 2. main.tf
**Purpose**: ECR repositories and policies configuration
**Location**: `Infrastructure/Modules/ecr/main.tf`

```hcl
# ECR Repository for Client Application
resource "aws_ecr_repository" "client" {
  name                 = "${var.environment_name}-client"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(var.tags, {
    Name        = "${var.environment_name}-client-ecr"
    Application = "client"
    Type        = "ECR"
  })
}

# ECR Repository for Server Application
resource "aws_ecr_repository" "server" {
  name                 = "${var.environment_name}-server"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(var.tags, {
    Name        = "${var.environment_name}-server-ecr"
    Application = "server"
    Type        = "ECR"
  })
}

# Lifecycle Policy for Client Repository
resource "aws_ecr_lifecycle_policy" "client" {
  repository = aws_ecr_repository.client.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod", "production"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging", "stage"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last 3 development images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "development"]
          countType     = "imageCountMoreThan"
          countNumber   = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Lifecycle Policy for Server Repository
resource "aws_ecr_lifecycle_policy" "server" {
  repository = aws_ecr_repository.server.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod", "production"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging", "stage"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last 3 development images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "development"]
          countType     = "imageCountMoreThan"
          countNumber   = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Repository Policy for Client (optional - for cross-account access)
resource "aws_ecr_repository_policy" "client" {
  repository = aws_ecr_repository.client.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Repository Policy for Server (optional - for cross-account access)
resource "aws_ecr_repository_policy" "server" {
  repository = aws_ecr_repository.server.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
```

### 3. outputs.tf
**Purpose**: Export ECR repository information for use by other modules
**Location**: `Infrastructure/Modules/ecr/outputs.tf`

```hcl
# Client Repository Outputs
output "client_repository_arn" {
  description = "ARN of the client ECR repository"
  value       = aws_ecr_repository.client.arn
}

output "client_repository_url" {
  description = "URL of the client ECR repository"
  value       = aws_ecr_repository.client.repository_url
}

output "client_repository_name" {
  description = "Name of the client ECR repository"
  value       = aws_ecr_repository.client.name
}

output "client_registry_id" {
  description = "Registry ID of the client ECR repository"
  value       = aws_ecr_repository.client.registry_id
}

# Server Repository Outputs
output "server_repository_arn" {
  description = "ARN of the server ECR repository"
  value       = aws_ecr_repository.server.arn
}

output "server_repository_url" {
  description = "URL of the server ECR repository"
  value       = aws_ecr_repository.server.repository_url
}

output "server_repository_name" {
  description = "Name of the server ECR repository"
  value       = aws_ecr_repository.server.name
}

output "server_registry_id" {
  description = "Registry ID of the server ECR repository"
  value       = aws_ecr_repository.server.registry_id
}

# Combined Outputs
output "repository_urls" {
  description = "Map of repository URLs"
  value = {
    client = aws_ecr_repository.client.repository_url
    server = aws_ecr_repository.server.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository ARNs"
  value = {
    client = aws_ecr_repository.client.arn
    server = aws_ecr_repository.server.arn
  }
}
```

## Implementation Steps

1. **Create the module directory**:
   ```bash
   mkdir -p Infrastructure/Modules/ecr
   ```

2. **Create variables.tf** with the input variables

3. **Create main.tf** with ECR repositories and policies

4. **Create outputs.tf** with the exported values

5. **Test the module** by adding it to your main.tf:
   ```hcl
   module "ecr" {
     source = "./Modules/ecr"
     
     environment_name = var.environment_name
     
     tags = local.common_tags
   }
   ```

6. **Validate the configuration**:
   ```bash
   cd Infrastructure
   terraform plan
   ```

## ECR Features Explained

### Image Scanning
- **Scan on Push**: Automatically scans images for vulnerabilities
- **Enhanced Scanning**: Can be enabled for continuous monitoring
- **Integration**: Works with AWS Security Hub and Inspector

### Lifecycle Policies
- **Cost Optimization**: Automatically removes old/unused images
- **Retention Rules**: Different rules for different environments
- **Tag-based**: Rules based on image tags (prod, staging, dev)
- **Time-based**: Rules based on image age

### Repository Policies
- **Access Control**: Define who can push/pull images
- **Cross-account**: Allow access from other AWS accounts
- **Conditional**: Use conditions for fine-grained control

## Best Practices

### Tagging Strategy
```bash
# Production images
docker tag myapp:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:prod-v1.0.0
docker tag myapp:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:production-latest

# Staging images
docker tag myapp:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:staging-v1.0.0-rc1

# Development images
docker tag myapp:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:dev-feature-branch
```

### Security
- Enable image scanning for vulnerability detection
- Use immutable tags for production images
- Implement least-privilege access policies
- Regular security reviews of stored images

### Cost Management
- Implement lifecycle policies to remove old images
- Monitor repository sizes and costs
- Use appropriate retention periods for different environments

## Docker Commands for ECR

### Authentication
```bash
# Get login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### Build and Push
```bash
# Build image
docker build -t myapp .

# Tag image
docker tag myapp:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/environment-client:latest

# Push image
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/environment-client:latest
```

### Pull Image
```bash
# Pull image
docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/environment-client:latest
```

## Troubleshooting

### Common Issues
1. **Authentication failures**: Check AWS credentials and ECR permissions
2. **Push denied**: Verify repository policies and IAM permissions
3. **Image not found**: Check repository name and image tags
4. **Lifecycle policy not working**: Verify policy syntax and rule priorities

### Validation Commands
```bash
# List repositories
aws ecr describe-repositories

# List images in repository
aws ecr list-images --repository-name environment-client

# Get repository policy
aws ecr get-repository-policy --repository-name environment-client

# Get lifecycle policy
aws ecr get-lifecycle-policy --repository-name environment-client
```

## Integration with CI/CD

The ECR repositories will be used by:
- **CodeBuild**: To push built images
- **ECS**: To pull images for deployment
- **CodeDeploy**: For Blue/Green deployments

## Next Step
Proceed to [S3 Module](./09-s3-module.md) to create S3 buckets for artifacts and static assets, or continue with [ECS Module](./06-ecs-module.md) for container orchestration.
