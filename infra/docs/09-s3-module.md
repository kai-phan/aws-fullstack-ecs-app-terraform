# S3 Module

## Overview
Create S3 buckets for CodePipeline artifacts storage and application static assets with appropriate security policies and configurations.

## Architecture
- Artifacts Bucket: For CodePipeline build artifacts and deployment packages
- Assets Bucket: For application static assets (images, documents, etc.)
- Proper bucket policies and CORS configuration
- Versioning and lifecycle management

## Files to Create

### 1. variables.tf
**Purpose**: Define input variables for the S3 module
**Location**: `Infrastructure/Modules/s3/variables.tf`

```hcl
variable "environment_name" {
  description = "Environment name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "artifacts_bucket_versioning" {
  description = "Enable versioning for artifacts bucket"
  type        = bool
  default     = true
}

variable "assets_bucket_versioning" {
  description = "Enable versioning for assets bucket"
  type        = bool
  default     = false
}

variable "enable_public_read_assets" {
  description = "Enable public read access for assets bucket"
  type        = bool
  default     = true
}
```

### 2. main.tf
**Purpose**: S3 buckets and policies configuration
**Location**: `Infrastructure/Modules/s3/main.tf`

```hcl
# Random suffix for bucket names to ensure uniqueness
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data source for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Bucket for CodePipeline Artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.environment_name}-codepipeline-artifacts-${random_string.bucket_suffix.result}"

  tags = merge(var.tags, {
    Name    = "${var.environment_name}-codepipeline-artifacts"
    Purpose = "CodePipeline Artifacts"
    Type    = "S3"
  })
}

# Artifacts Bucket Versioning
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = var.artifacts_bucket_versioning ? "Enabled" : "Disabled"
  }
}

# Artifacts Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Artifacts Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Artifacts Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "artifacts_lifecycle"
    status = "Enabled"

    # Delete old versions after 30 days
    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# S3 Bucket for Application Assets
resource "aws_s3_bucket" "assets" {
  bucket = "${var.environment_name}-assets-${random_string.bucket_suffix.result}"

  tags = merge(var.tags, {
    Name    = "${var.environment_name}-assets"
    Purpose = "Application Assets"
    Type    = "S3"
  })
}

# Assets Bucket Versioning
resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = var.assets_bucket_versioning ? "Enabled" : "Disabled"
  }
}

# Assets Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Assets Bucket Public Access Block (conditional)
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = !var.enable_public_read_assets
  block_public_policy     = !var.enable_public_read_assets
  ignore_public_acls      = !var.enable_public_read_assets
  restrict_public_buckets = !var.enable_public_read_assets
}

# Assets Bucket Policy for Public Read (conditional)
resource "aws_s3_bucket_policy" "assets_public_read" {
  count  = var.enable_public_read_assets ? 1 : 0
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.assets.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.assets]
}

# Assets Bucket CORS Configuration
resource "aws_s3_bucket_cors_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  cors_rule {
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

# Assets Bucket Website Configuration (optional)
resource "aws_s3_bucket_website_configuration" "assets" {
  count  = var.enable_public_read_assets ? 1 : 0
  bucket = aws_s3_bucket.assets.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Bucket Notification for Assets (optional - for future use)
resource "aws_s3_bucket_notification" "assets" {
  bucket = aws_s3_bucket.assets.id

  # Example: Lambda function trigger on object creation
  # lambda_function {
  #   lambda_function_arn = aws_lambda_function.processor.arn
  #   events              = ["s3:ObjectCreated:*"]
  #   filter_prefix       = "uploads/"
  #   filter_suffix       = ".jpg"
  # }
}
```

### 3. outputs.tf
**Purpose**: Export S3 bucket information for use by other modules
**Location**: `Infrastructure/Modules/s3/outputs.tf`

```hcl
# Artifacts Bucket Outputs
output "artifacts_bucket_id" {
  description = "ID of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_name" {
  description = "Name of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "artifacts_bucket_domain_name" {
  description = "Domain name of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.bucket_domain_name
}

output "artifacts_bucket_regional_domain_name" {
  description = "Regional domain name of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.bucket_regional_domain_name
}

# Assets Bucket Outputs
output "assets_bucket_id" {
  description = "ID of the assets S3 bucket"
  value       = aws_s3_bucket.assets.id
}

output "assets_bucket_name" {
  description = "Name of the assets S3 bucket"
  value       = aws_s3_bucket.assets.bucket
}

output "assets_bucket_arn" {
  description = "ARN of the assets S3 bucket"
  value       = aws_s3_bucket.assets.arn
}

output "assets_bucket_domain_name" {
  description = "Domain name of the assets S3 bucket"
  value       = aws_s3_bucket.assets.bucket_domain_name
}

output "assets_bucket_regional_domain_name" {
  description = "Regional domain name of the assets S3 bucket"
  value       = aws_s3_bucket.assets.bucket_regional_domain_name
}

output "assets_bucket_website_endpoint" {
  description = "Website endpoint of the assets S3 bucket"
  value       = var.enable_public_read_assets ? aws_s3_bucket_website_configuration.assets[0].website_endpoint : null
}

output "assets_bucket_website_domain" {
  description = "Website domain of the assets S3 bucket"
  value       = var.enable_public_read_assets ? aws_s3_bucket_website_configuration.assets[0].website_domain : null
}

# Combined Outputs
output "bucket_names" {
  description = "Map of bucket names"
  value = {
    artifacts = aws_s3_bucket.artifacts.bucket
    assets    = aws_s3_bucket.assets.bucket
  }
}

output "bucket_arns" {
  description = "Map of bucket ARNs"
  value = {
    artifacts = aws_s3_bucket.artifacts.arn
    assets    = aws_s3_bucket.assets.arn
  }
}
```

## Implementation Steps

1. **Create the module directory**:
   ```bash
   mkdir -p Infrastructure/Modules/s3
   ```

2. **Create variables.tf** with the input variables

3. **Create main.tf** with S3 buckets and configurations

4. **Create outputs.tf** with the exported values

5. **Test the module** by adding it to your main.tf:
   ```hcl
   module "s3" {
     source = "./Modules/s3"
     
     environment_name = var.environment_name
     aws_region      = var.aws_region
     
     tags = local.common_tags
   }
   ```

6. **Validate the configuration**:
   ```bash
   cd Infrastructure
   terraform plan
   ```

## S3 Features Explained

### Artifacts Bucket
- **Purpose**: Store CodePipeline artifacts, build outputs, deployment packages
- **Security**: Private bucket with encryption enabled
- **Lifecycle**: Automatic transition to cheaper storage classes
- **Versioning**: Enabled to track artifact versions

### Assets Bucket
- **Purpose**: Store application static assets (images, documents, etc.)
- **Security**: Configurable public read access
- **CORS**: Configured for web application access
- **Website**: Optional static website hosting

### Security Features
- **Encryption**: Server-side encryption with AES256
- **Public Access Block**: Prevents accidental public exposure
- **Bucket Policies**: Fine-grained access control
- **Versioning**: Track object changes

### Cost Optimization
- **Lifecycle Policies**: Automatic transition to cheaper storage
- **Incomplete Upload Cleanup**: Remove failed multipart uploads
- **Version Management**: Automatic cleanup of old versions

## Best Practices

### Security
```hcl
# Always encrypt buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access by default
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### Naming
- Use environment prefixes for organization
- Add random suffixes for global uniqueness
- Use descriptive names indicating purpose

### Access Patterns
- Use IAM roles instead of access keys
- Implement least-privilege access
- Use bucket policies for cross-account access

## Usage Examples

### Upload Assets
```bash
# Upload a file to assets bucket
aws s3 cp image.jpg s3://environment-assets-12345678/images/

# Sync a directory
aws s3 sync ./assets/ s3://environment-assets-12345678/
```

### Access from Application
```javascript
// Node.js example
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

// Get object URL
const url = s3.getSignedUrl('getObject', {
  Bucket: 'environment-assets-12345678',
  Key: 'images/logo.png',
  Expires: 3600
});
```

### CORS Configuration
The CORS configuration allows web applications to:
- GET and HEAD requests from any origin
- PUT and POST requests for file uploads
- Access to ETag headers for caching

## Integration Points

### CodePipeline
- Artifacts bucket stores build outputs
- Source artifacts from GitHub
- Deploy artifacts to ECS

### Application
- Assets bucket serves static content
- Images, stylesheets, documents
- CDN integration possible

### Monitoring
- CloudTrail for API calls
- CloudWatch metrics for usage
- S3 access logs for detailed analysis

## Troubleshooting

### Common Issues
1. **Bucket name conflicts**: Use random suffixes
2. **Access denied**: Check bucket policies and IAM permissions
3. **CORS errors**: Verify CORS configuration
4. **Public access blocked**: Check public access block settings

### Validation Commands
```bash
# List buckets
aws s3 ls

# Check bucket policy
aws s3api get-bucket-policy --bucket bucket-name

# Check public access block
aws s3api get-public-access-block --bucket bucket-name

# Check CORS configuration
aws s3api get-bucket-cors --bucket bucket-name
```

## Next Step
Proceed to [DynamoDB Module](./08-dynamodb-module.md) to create the database for your application data.
