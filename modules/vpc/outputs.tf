output "subnet-id" {
  value = aws_subnet.subnet.id
}

output "vpc-id" {
  value = aws_vpc.vpc.id
}

output "vpc-security-group-id" {
  value = aws_security_group.sg.id
}
