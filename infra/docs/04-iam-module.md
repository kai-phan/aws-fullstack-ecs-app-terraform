# IAM Module

## Overview
Create IAM roles and policies for ECS tasks, CodeBuild, CodeDeploy, and CodePipeline services with appropriate permissions following the principle of least privilege.

## Architecture
- ECS Task Execution Role: For ECS to pull images and write logs
- ECS Task Role: For application to access AWS services (DynamoDB, S3)
- CodeBuild Service Role: For building and pushing container images
- CodeDeploy Service Role: For ECS Blue/Green deployments
- CodePipeline Service Role: For orchestrating CI/CD pipeline

## Files to Create

### 1. variables.tf
**Purpose**: Define input variables for the IAM module
**Location**: `Infrastructure/Modules/iam/variables.tf`

```hcl
variable "environment_name" {
  description = "Environment name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### 2. ecs-roles.tf
**Purpose**: IAM roles for ECS tasks
**Location**: `Infrastructure/Modules/iam/ecs-roles.tf`

```hcl
# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.environment_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment_name}-ecs-task-execution-role"
    Type = "ECS"
  })
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for ECR access
resource "aws_iam_role_policy" "ecs_task_execution_ecr_policy" {
  name = "${var.environment_name}-ecs-task-execution-ecr-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Task Role (for application permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.environment_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment_name}-ecs-task-role"
    Type = "ECS"
  })
}

# Policy for DynamoDB access
resource "aws_iam_role_policy" "ecs_task_dynamodb_policy" {
  name = "${var.environment_name}-ecs-task-dynamodb-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${var.account_id}:table/${var.environment_name}-products",
          "arn:aws:dynamodb:${var.aws_region}:${var.account_id}:table/${var.environment_name}-products/index/*"
        ]
      }
    ]
  })
}

# Policy for S3 access (for assets bucket)
resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "${var.environment_name}-ecs-task-s3-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.environment_name}-assets-bucket/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.environment_name}-assets-bucket"
        ]
      }
    ]
  })
}
```

### 3. codebuild-role.tf
**Purpose**: IAM role for CodeBuild service
**Location**: `Infrastructure/Modules/iam/codebuild-role.tf`

```hcl
# CodeBuild Service Role
resource "aws_iam_role" "codebuild_service_role" {
  name = "${var.environment_name}-codebuild-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment_name}-codebuild-service-role"
    Type = "CodeBuild"
  })
}

# CodeBuild Service Policy
resource "aws_iam_role_policy" "codebuild_service_policy" {
  name = "${var.environment_name}-codebuild-service-policy"
  role = aws_iam_role.codebuild_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/codebuild/${var.environment_name}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.environment_name}-codepipeline-artifacts/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### 4. codedeploy-role.tf
**Purpose**: IAM role for CodeDeploy service
**Location**: `Infrastructure/Modules/iam/codedeploy-role.tf`

```hcl
# CodeDeploy Service Role
resource "aws_iam_role" "codedeploy_service_role" {
  name = "${var.environment_name}-codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment_name}-codedeploy-service-role"
    Type = "CodeDeploy"
  })
}

# Attach AWS managed policy for ECS deployments
resource "aws_iam_role_policy_attachment" "codedeploy_service_role_policy" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# Additional policy for ECS and ALB access
resource "aws_iam_role_policy" "codedeploy_additional_policy" {
  name = "${var.environment_name}-codedeploy-additional-policy"
  role = aws_iam_role.codedeploy_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:CreateTaskSet",
          "ecs:UpdateServicePrimaryTaskSet",
          "ecs:DeleteTaskSet",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:ModifyRule",
          "lambda:InvokeFunction",
          "cloudwatch:DescribeAlarms",
          "sns:Publish",
          "s3:GetObject"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### 5. codepipeline-role.tf
**Purpose**: IAM role for CodePipeline service
**Location**: `Infrastructure/Modules/iam/codepipeline-role.tf`

```hcl
# CodePipeline Service Role
resource "aws_iam_role" "codepipeline_service_role" {
  name = "${var.environment_name}-codepipeline-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment_name}-codepipeline-service-role"
    Type = "CodePipeline"
  })
}

# CodePipeline Service Policy
resource "aws_iam_role_policy" "codepipeline_service_policy" {
  name = "${var.environment_name}-codepipeline-service-policy"
  role = aws_iam_role.codepipeline_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.environment_name}-codepipeline-artifacts",
          "arn:aws:s3:::${var.environment_name}-codepipeline-artifacts/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = [
          "arn:aws:codebuild:${var.aws_region}:${var.account_id}:project/${var.environment_name}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${var.account_id}:role/${var.environment_name}-ecs-task-execution-role",
          "arn:aws:iam::${var.account_id}:role/${var.environment_name}-ecs-task-role"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          "arn:aws:sns:${var.aws_region}:${var.account_id}:${var.environment_name}-notifications"
        ]
      }
    ]
  })
}
```

### 6. outputs.tf
**Purpose**: Export IAM role ARNs for use by other modules
**Location**: `Infrastructure/Modules/iam/outputs.tf`

```hcl
# ECS Role Outputs
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.name
}

output "ecs_task_role_name" {
  description = "Name of the ECS task role"
  value       = aws_iam_role.ecs_task_role.name
}

# CodeBuild Role Outputs
output "codebuild_service_role_arn" {
  description = "ARN of the CodeBuild service role"
  value       = aws_iam_role.codebuild_service_role.arn
}

output "codebuild_service_role_name" {
  description = "Name of the CodeBuild service role"
  value       = aws_iam_role.codebuild_service_role.name
}

# CodeDeploy Role Outputs
output "codedeploy_service_role_arn" {
  description = "ARN of the CodeDeploy service role"
  value       = aws_iam_role.codedeploy_service_role.arn
}

output "codedeploy_service_role_name" {
  description = "Name of the CodeDeploy service role"
  value       = aws_iam_role.codedeploy_service_role.name
}

# CodePipeline Role Outputs
output "codepipeline_service_role_arn" {
  description = "ARN of the CodePipeline service role"
  value       = aws_iam_role.codepipeline_service_role.arn
}

output "codepipeline_service_role_name" {
  description = "Name of the CodePipeline service role"
  value       = aws_iam_role.codepipeline_service_role.name
}
```

## Implementation Steps

1. **Create the module directory**:
   ```bash
   mkdir -p Infrastructure/Modules/iam
   ```

2. **Create variables.tf** with the input variables

3. **Create the role files** in the following order:
   - `ecs-roles.tf` (ECS task execution and task roles)
   - `codebuild-role.tf` (CodeBuild service role)
   - `codedeploy-role.tf` (CodeDeploy service role)
   - `codepipeline-role.tf` (CodePipeline service role)

4. **Create outputs.tf** with the exported values

5. **Test the module** by adding it to your main.tf:
   ```hcl
   module "iam" {
     source = "./Modules/iam"
     
     environment_name = var.environment_name
     aws_region      = var.aws_region
     account_id      = data.aws_caller_identity.current.account_id
     
     tags = local.common_tags
   }
   ```

6. **Validate the configuration**:
   ```bash
   cd Infrastructure
   terraform plan
   ```

## IAM Best Practices

### Principle of Least Privilege
- Each role has only the minimum permissions required
- Resource-specific ARNs where possible
- No wildcard permissions unless necessary

### Role Separation
- Separate roles for different services and functions
- ECS execution vs. task roles have different purposes
- CI/CD roles are isolated from application roles

### Security Considerations
- Roles use service-specific assume role policies
- Cross-service access is explicitly defined
- Sensitive actions require specific permissions

## Role Purposes Explained

### ECS Task Execution Role
- **Purpose**: Used by ECS to start containers
- **Permissions**: Pull images from ECR, write to CloudWatch Logs
- **Used by**: ECS service when starting tasks

### ECS Task Role
- **Purpose**: Used by application code running in containers
- **Permissions**: Access DynamoDB, S3, other AWS services
- **Used by**: Application code at runtime

### CodeBuild Service Role
- **Purpose**: Used by CodeBuild to build and push images
- **Permissions**: Access ECR, S3 artifacts, CloudWatch Logs
- **Used by**: CodeBuild projects during build process

### CodeDeploy Service Role
- **Purpose**: Used by CodeDeploy for ECS Blue/Green deployments
- **Permissions**: Manage ECS services, ALB target groups
- **Used by**: CodeDeploy during deployment process

### CodePipeline Service Role
- **Purpose**: Used by CodePipeline to orchestrate CI/CD
- **Permissions**: Trigger builds, deployments, access S3
- **Used by**: CodePipeline during pipeline execution

## Troubleshooting

### Common Issues
1. **Access denied errors**: Check role permissions and resource ARNs
2. **AssumeRole failures**: Verify trust relationships
3. **Cross-service access**: Ensure PassRole permissions are correct

### Validation Commands
```bash
# Check role creation
aws iam get-role --role-name your-role-name

# Check attached policies
aws iam list-attached-role-policies --role-name your-role-name

# Check inline policies
aws iam list-role-policies --role-name your-role-name
```

## Next Step
Proceed to [ECR Module](./05-ecr-module.md) to create container repositories for your applications.
