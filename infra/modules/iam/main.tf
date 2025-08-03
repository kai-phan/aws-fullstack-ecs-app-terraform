terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
}

#------------------- IAM Roles --------------------#
resource "aws_iam_role" "ecs_tasks_execution_role" {
  count = var.create_ecs_role == true ? 1: 0
  name = "${var.environment_name}-${var.name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    "Sid": "",
    "Effect": "Allow",
    "Priciple": {
      "Service": "ecs-tasks.amazonaws.com"
    },
    "Action": ["sts:AssumeRole"]
  })

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-ecs-task-execution-role"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "ecs_tasks_role" {
  count = var.create_ecs_role == true ? 1: 0
  name = "${var.environment_name}-${var.name}-ecs-task-role"

  assume_role_policy = jsonencode({
    "Sid": "",
    "Effect": "Allow",
    "Priciple": {
      "Service": "ecs-tasks.amazonaws.com"
    },
    "Action": ["sts:AssumeRole"]
  })

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-ecs-task-role"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "devops_role" {
  count = var.create_devops_role == true ? 1 : 0
  name = "${var.environment_name}-${var.name}-ecs-devops-role"

  assume_role_policy = jsonencode({
    "Sid": "",
    "Effect": "Allow",
    "Priciple": {
      "Service": [
        "codebuild.amazonaws.com",
        "codedeploy.amazonaws.com",
        "codepipeline.amazonaws.com"
      ]
    },
    "Action": ["sts:AssumeRole"]
  })

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-ecs-task-role"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "codedeploy_role" {
  count = var.create_devops_role == true ? 1 : 0
  name = "${var.environment_name}-${var.name}-ecs-codedeploy-role"

  assume_role_policy = jsonencode({
    "Sid": "",
    "Effect": "Allow",
    "Priciple": {
      "Service": [
        "codedeploy.amazonaws.com"
      ]
    },
    "Action": ["sts:AssumeRole"]
  })
}

#------------------ IAM Policies -------------------#
resource "aws_iam_policy" "ecs_task_role_policy" {
  count = var.create_ecs_role == true ? 1 : 0
  name = "${var.environment_name}-${var.name}-ecs-task-role-policy"
  policy = data.aws_iam_policy_document.ecs_task_role_policy_document.json
  description = "A Policy for ecs task role for ${var.name} with ${var.environment_name} environment"

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-ecs-task-role-policy"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy" "devops_policy" {
  count = var.create_devops_role == true ? 1 : 0
  name = "${var.environment_name}-${var.name}-devops-policy"
  policy = data.aws_iam_policy_document.devops_policy_document.json
  description = "A Policy for devops role for ${var.name} with ${var.environment_name} environment"

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}-devops-policy"
  })

  lifecycle {
    create_before_destroy = true
  }
}

#------------------- IAM policy attachment ---------------------#
resource "aws_iam_policy_attachment" "ecs_task_role_att" {
  count = var.create_ecs_role == true ? 1 : 0
  name       = "${var.environment_name}-${var.name}-ecs-task-role-policy-attachment"
  policy_arn = aws_iam_policy.ecs_task_role_policy[0].arn
  roles = [aws_iam_role.ecs_tasks_role[0].name]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy_attachment" "ecs_task_execution_role_att" {
  count = var.create_ecs_role == true ? 1 : 0
  name       = "${var.environment_name}-${var.name}-ecs-task-execution-role-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  roles = [aws_iam_role.ecs_tasks_execution_role[0].name]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy_attachment" "devops_policy_att" {
  count = var.create_devops_role == true ? 1 : 0
  name       = "${var.environment_name}-${var.name}-devops-policy-attachment"
  policy_arn = aws_iam_policy.devops_policy.arn
  roles = [aws_iam_role.devops_role[0].name]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy_attachment" "codedeploy_policy_att" {
  count = var.create_devops_role == true ? 1 : 0
  name       = "${var.environment_name}-${var.name}-codedeploy-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  roles = [aws_iam_role.codedeploy_role[0].name]

  lifecycle {
    create_before_destroy = true
  }
}

#----------- IAM Policies Document ----------------#
data "aws_iam_policy_document" "ecs_task_role_policy_document" {
  # This statement allows the role to pass IAM roles to other AWS services
  # The PassRole permission is required when a service needs to assign a role to another resource
  # Using "*" for resources means it can pass any role - consider restricting this to specific role ARNs for better security
  statement {
    sid    = "AllowIAMPassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowS3Actions"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = var.s3_bucket_assets
  }

  statement {
    sid    = "AllowDynamodbActions"
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:Describe*",
      "dynamodb:List*",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = var.dynamodb_table
  }
}

data "aws_iam_policy_document" "devops_policy_document" {
  statement {
    sid = "AllowS3Action"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:List*"
    ],
    resources = ["*"]
  }

  # This statement allows specific CodeBuild actions (get builds, start/stop builds, etc)
  # on the CodeBuild projects specified in var.code_build_projects
  statement {
    sid = "AllowCodebuildAction"
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:BatchGetBuildBatches",
      "codebuild:StartBuildBatch",
      "codebuild:StopBuild"
    ],
    resources = var.code_build_projects
  }

  # This statement allows listing all CodeBuild builds across all projects
  statement {
    sid = "AllowCodebuildListAction"
    effect = "Allow"
    actions = [
      "codebuild:ListBuilds"
    ],
    resources = ["*"]
  }

  statement {
    sid    = "AllowCodeDeployConfigs"
    effect = "Allow"
    actions = [
      "codedeploy:GetDeploymentConfig",
      "codedeploy:CreateDeploymentConfig",
      "codedeploy:CreateDeploymentGroup",
      "codedeploy:GetDeploymentTarget",
      "codedeploy:StopDeployment",
      "codedeploy:ListApplications",
      "codedeploy:ListDeploymentConfigs",
      "codedeploy:ListDeploymentGroups",
      "codedeploy:ListDeployments"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowECRActions"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = var.ecr_repositories
  }

  statement {
    sid    = "AllowECRAuthorization"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCECSServiceActions"
    effect = "Allow"
    actions = [
      "ecs:ListServices",
      "ecs:ListTasks",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTaskSets",
      "ecs:DeleteTaskSet",
      "ecs:DeregisterContainerInstance",
      "ecs:CreateTaskSet",
      "ecs:UpdateCapacityProvider",
      "ecs:PutClusterCapacityProviders",
      "ecs:UpdateServicePrimaryTaskSet",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "ecs:StartTask",
      "ecs:StopTask",
      "ecs:UpdateService",
      "ecs:UpdateCluster",
      "ecs:UpdateTaskSet"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowIAMPassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchActions"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}