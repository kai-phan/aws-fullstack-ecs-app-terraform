# DynamoDB Module

## Overview
Create a DynamoDB table for storing application data (products) with proper configuration for performance, security, and cost optimization.

## Architecture
- Products table with id as primary key
- On-demand billing mode for variable workloads
- Point-in-time recovery enabled
- Server-side encryption enabled
- Global secondary indexes if needed

## Table Schema
```
Table: products
- id (Number) - Primary Key (HASH)
- title (String) - Product title
- path (String) - S3 URL for product image
- description (String) - Product description (optional)
- price (Number) - Product price (optional)
- category (String) - Product category (optional)
- created_at (String) - ISO timestamp
- updated_at (String) - ISO timestamp
```

## Files to Create

### 1. variables.tf
**Purpose**: Define input variables for the DynamoDB module
**Location**: `Infrastructure/Modules/dynamodb/variables.tf`

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

variable "billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "Billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "read_capacity" {
  description = "Read capacity units (only used if billing_mode is PROVISIONED)"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units (only used if billing_mode is PROVISIONED)"
  type        = number
  default     = 5
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "table_class" {
  description = "DynamoDB table class"
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.table_class)
    error_message = "Table class must be either STANDARD or STANDARD_INFREQUENT_ACCESS."
  }
}
```

### 2. main.tf
**Purpose**: DynamoDB table and configuration
**Location**: `Infrastructure/Modules/dynamodb/main.tf`

```hcl
# DynamoDB Table for Products
resource "aws_dynamodb_table" "products" {
  name           = "${var.environment_name}-products"
  billing_mode   = var.billing_mode
  table_class    = var.table_class
  hash_key       = "id"
  
  # Conditional capacity settings for PROVISIONED mode
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Primary key attribute
  attribute {
    name = "id"
    type = "N"
  }

  # Global Secondary Index for category-based queries (optional)
  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "CategoryIndex"
    hash_key        = "category"
    range_key       = "created_at"
    projection_type = "ALL"
    
    # Conditional capacity for GSI in PROVISIONED mode
    read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
    write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  }

  # Time To Live attribute (optional)
  ttl {
    attribute_name = "ttl"
    enabled        = false
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  # Deletion protection
  deletion_protection_enabled = var.enable_deletion_protection

  tags = merge(var.tags, {
    Name = "${var.environment_name}-products-table"
    Type = "DynamoDB"
  })
}

# DynamoDB Table for User Sessions (optional)
resource "aws_dynamodb_table" "sessions" {
  name           = "${var.environment_name}-sessions"
  billing_mode   = "PAY_PER_REQUEST"
  table_class    = "STANDARD"
  hash_key       = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  # TTL for automatic session cleanup
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.environment_name}-sessions-table"
    Type = "DynamoDB"
  })
}

# CloudWatch Alarms for DynamoDB (optional)
resource "aws_cloudwatch_metric_alarm" "products_read_throttle" {
  alarm_name          = "${var.environment_name}-dynamodb-products-read-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadThrottledEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors DynamoDB read throttling"
  alarm_actions       = []

  dimensions = {
    TableName = aws_dynamodb_table.products.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "products_write_throttle" {
  alarm_name          = "${var.environment_name}-dynamodb-products-write-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteThrottledEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors DynamoDB write throttling"
  alarm_actions       = []

  dimensions = {
    TableName = aws_dynamodb_table.products.name
  }

  tags = var.tags
}
```

### 3. outputs.tf
**Purpose**: Export DynamoDB table information for use by other modules
**Location**: `Infrastructure/Modules/dynamodb/outputs.tf`

```hcl
# Products Table Outputs
output "products_table_name" {
  description = "Name of the products DynamoDB table"
  value       = aws_dynamodb_table.products.name
}

output "products_table_arn" {
  description = "ARN of the products DynamoDB table"
  value       = aws_dynamodb_table.products.arn
}

output "products_table_id" {
  description = "ID of the products DynamoDB table"
  value       = aws_dynamodb_table.products.id
}

output "products_table_stream_arn" {
  description = "ARN of the products DynamoDB table stream"
  value       = aws_dynamodb_table.products.stream_arn
}

# Sessions Table Outputs
output "sessions_table_name" {
  description = "Name of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.name
}

output "sessions_table_arn" {
  description = "ARN of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.arn
}

# Combined Outputs
output "table_name" {
  description = "Primary table name (products)"
  value       = aws_dynamodb_table.products.name
}

output "table_arn" {
  description = "Primary table ARN (products)"
  value       = aws_dynamodb_table.products.arn
}

output "table_names" {
  description = "Map of all table names"
  value = {
    products = aws_dynamodb_table.products.name
    sessions = aws_dynamodb_table.sessions.name
  }
}

output "table_arns" {
  description = "Map of all table ARNs"
  value = {
    products = aws_dynamodb_table.products.arn
    sessions = aws_dynamodb_table.sessions.arn
  }
}

# Global Secondary Index Outputs
output "products_gsi_names" {
  description = "Names of Global Secondary Indexes"
  value       = ["CategoryIndex"]
}
```

## Implementation Steps

1. **Create the module directory**:
   ```bash
   mkdir -p Infrastructure/Modules/dynamodb
   ```

2. **Create variables.tf** with the input variables

3. **Create main.tf** with DynamoDB table configuration

4. **Create outputs.tf** with the exported values

5. **Test the module** by adding it to your main.tf:
   ```hcl
   module "dynamodb" {
     source = "./Modules/dynamodb"
     
     environment_name = var.environment_name
     
     tags = local.common_tags
   }
   ```

6. **Validate the configuration**:
   ```bash
   cd Infrastructure
   terraform plan
   ```

## DynamoDB Features Explained

### Billing Modes
- **PAY_PER_REQUEST**: Automatic scaling, pay for actual usage
- **PROVISIONED**: Fixed capacity, predictable costs

### Global Secondary Indexes (GSI)
- **CategoryIndex**: Query products by category and creation date
- **Projection**: ALL attributes included in index
- **Use case**: Filter products by category

### Security Features
- **Server-side encryption**: Data encrypted at rest
- **IAM integration**: Fine-grained access control
- **VPC endpoints**: Private network access

### Performance Features
- **Point-in-time recovery**: Backup and restore capability
- **TTL**: Automatic item expiration
- **Streams**: Capture data changes

## Sample Data Structure

### Products Table Items
```json
{
  "id": {"N": "1"},
  "title": {"S": "Sample Product"},
  "path": {"S": "https://bucket.s3.region.amazonaws.com/image.jpg"},
  "description": {"S": "Product description"},
  "price": {"N": "29.99"},
  "category": {"S": "electronics"},
  "created_at": {"S": "2024-01-01T00:00:00Z"},
  "updated_at": {"S": "2024-01-01T00:00:00Z"}
}
```

### Sessions Table Items
```json
{
  "session_id": {"S": "sess_123456789"},
  "user_id": {"S": "user_123"},
  "data": {"S": "{\"cart\": [], \"preferences\": {}}"},
  "created_at": {"S": "2024-01-01T00:00:00Z"},
  "expires_at": {"N": "1704153600"}
}
```

## Best Practices

### Design Patterns
```javascript
// Single Table Design (advanced)
const productItem = {
  PK: `PRODUCT#${productId}`,
  SK: `METADATA`,
  GSI1PK: `CATEGORY#${category}`,
  GSI1SK: `CREATED#${timestamp}`,
  title: "Product Title",
  // ... other attributes
};
```

### Query Patterns
```javascript
// Query by primary key
const params = {
  TableName: 'products',
  Key: { id: { N: '1' } }
};

// Query by GSI
const gsiParams = {
  TableName: 'products',
  IndexName: 'CategoryIndex',
  KeyConditionExpression: 'category = :cat',
  ExpressionAttributeValues: {
    ':cat': { S: 'electronics' }
  }
};
```

### Error Handling
```javascript
// Handle throttling
const dynamodb = new AWS.DynamoDB.DocumentClient({
  maxRetries: 3,
  retryDelayOptions: {
    customBackoff: function(retryCount) {
      return Math.pow(2, retryCount) * 100;
    }
  }
});
```

## Performance Optimization

### Read Patterns
- Use Query instead of Scan when possible
- Implement pagination with LastEvaluatedKey
- Use projection expressions to limit returned data
- Consider eventually consistent reads for better performance

### Write Patterns
- Use batch operations for multiple items
- Implement conditional writes to prevent conflicts
- Use transactions for ACID requirements
- Consider write sharding for hot partitions

### Cost Optimization
- Use PAY_PER_REQUEST for variable workloads
- Monitor and adjust provisioned capacity
- Use Standard-IA table class for infrequent access
- Implement TTL for automatic cleanup

## Monitoring and Alerting

### Key Metrics
- ReadCapacityUnits/WriteCapacityUnits
- ConsumedReadCapacityUnits/ConsumedWriteCapacityUnits
- ThrottledRequests
- SystemErrors/UserErrors

### CloudWatch Alarms
```hcl
resource "aws_cloudwatch_metric_alarm" "high_consumed_reads" {
  alarm_name          = "dynamodb-high-consumed-reads"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConsumedReadCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "80"
  
  dimensions = {
    TableName = aws_dynamodb_table.products.name
  }
}
```

## Troubleshooting

### Common Issues
1. **Throttling**: Increase capacity or use exponential backoff
2. **Hot partitions**: Distribute access patterns evenly
3. **Large items**: Use S3 for large attributes
4. **Query performance**: Optimize key design and indexes

### Validation Commands
```bash
# Describe table
aws dynamodb describe-table --table-name environment-products

# List tables
aws dynamodb list-tables

# Get item
aws dynamodb get-item --table-name environment-products --key '{"id":{"N":"1"}}'

# Query table
aws dynamodb query --table-name environment-products --key-condition-expression "id = :id" --expression-attribute-values '{":id":{"N":"1"}}'
```

## Integration with Application

### Node.js SDK Example
```javascript
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

// Get all products
const getAllProducts = async () => {
  const params = {
    TableName: process.env.DYNAMODB_TABLE
  };
  
  try {
    const result = await dynamodb.scan(params).promise();
    return result.Items;
  } catch (error) {
    console.error('Error fetching products:', error);
    throw error;
  }
};
```

## Next Step
Proceed to [ECS Module](./06-ecs-module.md) to create the container orchestration infrastructure, or continue with [ALB Module](./07-alb-module.md) for load balancing.
