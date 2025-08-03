# Core Terraform Configuration

## Overview
Set up the foundational Terraform files that define providers, variables, main configuration, and outputs for the entire infrastructure.

## Files to Create

### 1. versions.tf
**Purpose**: Define Terraform version requirements and provider configurations
**Location**: `Infrastructure/versions.tf`

```hcl
terraform {
  required_version = ">= 0.13"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
```

### 2. variables.tf
**Purpose**: Define all input variables for the infrastructure
**Location**: `Infrastructure/variables.tf`

```hcl
variable "aws_profile" {
  description = "AWS profile name from ~/.aws/credentials"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "environment_name" {
  description = "Environment name used for resource naming and tagging"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for CodePipeline"
  type        = string
  sensitive   = true
}

variable "repository_name" {
  description = "GitHub repository name"
  type        = string
}

variable "repository_owner" {
  description = "GitHub repository owner/organization"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zone suffixes (e.g., ['a', 'b'])"
  type        = list(string)
  default     = ["a", "b"]
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_cpu" {
  description = "CPU units for ECS containers"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Memory (MB) for ECS containers"
  type        = number
  default     = 1024
}
```

### 3. main.tf
**Purpose**: Main configuration file that orchestrates all modules
**Location**: `Infrastructure/main.tf`

```hcl
# Configure AWS Provider
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for common tags and naming
locals {
  common_tags = {
    Environment = var.environment_name
    Project     = "ecs-fullstack-demo"
    ManagedBy   = "terraform"
  }
  
  name_prefix = var.environment_name
}

# Networking Module
module "networking" {
  source = "./Modules/networking"
  
  environment_name    = var.environment_name
  aws_region         = var.aws_region
  availability_zones = var.availability_zones
  vpc_cidr          = var.vpc_cidr
  
  tags = local.common_tags
}

# Security Module
module "security" {
  source = "./Modules/security"
  
  environment_name = var.environment_name
  vpc_id          = module.networking.vpc_id
  vpc_cidr_block  = module.networking.vpc_cidr_block
  
  tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "./Modules/iam"
  
  environment_name = var.environment_name
  aws_region      = var.aws_region
  account_id      = data.aws_caller_identity.current.account_id
  
  tags = local.common_tags
}

# ECR Module
module "ecr" {
  source = "./Modules/ecr"
  
  environment_name = var.environment_name
  
  tags = local.common_tags
}

# S3 Module
module "s3" {
  source = "./Modules/s3"
  
  environment_name = var.environment_name
  aws_region      = var.aws_region
  
  tags = local.common_tags
}

# DynamoDB Module
module "dynamodb" {
  source = "./Modules/dynamodb"
  
  environment_name = var.environment_name
  
  tags = local.common_tags
}

# ALB Module
module "alb" {
  source = "./Modules/alb"
  
  environment_name     = var.environment_name
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  
  tags = local.common_tags
}

# ECS Module
module "ecs" {
  source = "./Modules/ecs"
  
  environment_name           = var.environment_name
  aws_region                = var.aws_region
  vpc_id                    = module.networking.vpc_id
  private_subnet_ids        = module.networking.private_subnet_ids
  ecs_security_group_id     = module.security.ecs_security_group_id
  
  # ECR repositories
  client_repository_url     = module.ecr.client_repository_url
  server_repository_url     = module.ecr.server_repository_url
  
  # IAM roles
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn          = module.iam.ecs_task_role_arn
  
  # ALB target groups
  client_target_group_arn    = module.alb.client_target_group_arn
  server_target_group_arn    = module.alb.server_target_group_arn
  
  # DynamoDB table
  dynamodb_table_name       = module.dynamodb.table_name
  
  # Container configuration
  container_cpu             = var.container_cpu
  container_memory          = var.container_memory
  
  tags = local.common_tags
}

# CodeBuild Module
module "codebuild" {
  source = "./Modules/codebuild"
  
  environment_name              = var.environment_name
  aws_region                   = var.aws_region
  codebuild_service_role_arn   = module.iam.codebuild_service_role_arn
  artifacts_bucket_name        = module.s3.artifacts_bucket_name
  client_repository_url        = module.ecr.client_repository_url
  server_repository_url        = module.ecr.server_repository_url
  
  tags = local.common_tags
}

# CodeDeploy Module
module "codedeploy" {
  source = "./Modules/codedeploy"
  
  environment_name               = var.environment_name
  codedeploy_service_role_arn   = module.iam.codedeploy_service_role_arn
  ecs_cluster_name              = module.ecs.cluster_name
  ecs_service_names             = module.ecs.service_names
  client_target_group_name      = module.alb.client_target_group_name
  server_target_group_name      = module.alb.server_target_group_name
  client_listener_arn           = module.alb.client_listener_arn
  server_listener_arn           = module.alb.server_listener_arn
  
  tags = local.common_tags
}

# SNS Module
module "sns" {
  source = "./Modules/sns"
  
  environment_name = var.environment_name
  
  tags = local.common_tags
}

# CodePipeline Module
module "codepipeline" {
  source = "./Modules/codepipeline"
  
  environment_name                = var.environment_name
  aws_region                     = var.aws_region
  codepipeline_service_role_arn  = module.iam.codepipeline_service_role_arn
  artifacts_bucket_name          = module.s3.artifacts_bucket_name
  github_token                   = var.github_token
  repository_owner               = var.repository_owner
  repository_name                = var.repository_name
  
  # CodeBuild projects
  client_build_project_name      = module.codebuild.client_build_project_name
  server_build_project_name      = module.codebuild.server_build_project_name
  
  # CodeDeploy applications
  client_codedeploy_app_name     = module.codedeploy.client_application_name
  server_codedeploy_app_name     = module.codedeploy.server_application_name
  client_deployment_group_name   = module.codedeploy.client_deployment_group_name
  server_deployment_group_name   = module.codedeploy.server_deployment_group_name
  
  # SNS topic
  sns_topic_arn                  = module.sns.topic_arn
  
  tags = local.common_tags
}
```

### 4. outputs.tf
**Purpose**: Define outputs that will be displayed after terraform apply
**Location**: `Infrastructure/outputs.tf`

```hcl
# Application URLs
output "application_url" {
  description = "URL of the client application"
  value       = "http://${module.alb.client_dns_name}"
}

output "api_url" {
  description = "URL of the server API"
  value       = "http://${module.alb.server_dns_name}"
}

output "swagger_endpoint" {
  description = "Swagger documentation endpoint"
  value       = "http://${module.alb.server_dns_name}/api/docs"
}

# Infrastructure Details
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecr_repositories" {
  description = "ECR repository URLs"
  value = {
    client = module.ecr.client_repository_url
    server = module.ecr.server_repository_url
  }
}

# S3 Buckets
output "artifacts_bucket" {
  description = "S3 bucket for CodePipeline artifacts"
  value       = module.s3.artifacts_bucket_name
}

output "assets_bucket" {
  description = "S3 bucket for application assets"
  value       = module.s3.assets_bucket_name
}

# DynamoDB
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = module.dynamodb.table_name
}

# CodePipeline
output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.codepipeline.pipeline_name
}

# Load Balancer DNS Names
output "client_alb_dns" {
  description = "DNS name of the client ALB"
  value       = module.alb.client_dns_name
}

output "server_alb_dns" {
  description = "DNS name of the server ALB"
  value       = module.alb.server_dns_name
}
```

## Implementation Steps

1. **Create the directory structure** (if not already done):
   ```bash
   mkdir -p Infrastructure/Modules Infrastructure/Templates Infrastructure/docs
   ```

2. **Create versions.tf** with the provider configuration

3. **Create variables.tf** with all required input variables

4. **Create main.tf** with the module orchestration (you'll add modules as you create them)

5. **Create outputs.tf** with the desired output values

## Notes
- The main.tf file references modules that don't exist yet - you'll uncomment/add module blocks as you create each module
- Start with a minimal main.tf that only includes the provider configuration, then add modules one by one
- Test each addition with `terraform plan` to ensure syntax is correct
- The variables defined here will be used across all modules

## Next Step
Proceed to [Networking Module](../Modules/networking/02-networking-module.md) to create the VPC and networking infrastructure.
