output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_client_subnet_cidrs" {
  description = "CIDR blocks of the private client subnets"
  value       = aws_subnet.private_client[*].cidr_block
}

output "private_server_subnet_cidrs" {
  description = "CIDR blocks of the private server subnets"
  value       = aws_subnet.private_server[*].cidr_block
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateway"
  value       = aws_nat_gateway.nat.id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = [for az in var.availability_zones : "${var.aws_region}${az}"]
}