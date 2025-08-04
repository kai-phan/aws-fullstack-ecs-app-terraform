resource "aws_ecr_repository" "ecr_repository" {
  name = "${var.environment_name}-${var.name}"
  image_tag_mutability = "MUTABLE"

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.name}"
  })
}