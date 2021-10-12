# AWS provider setup
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
      # version = "3.42.0"
    }
  }
}

######################################################################
# VPC
######################################################################

data "aws_region" "current" {}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.subnet-cidr
  tags = {
    Name = "${var.name}-subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  count  = var.public-vpc ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name}-gw"
  }
}

resource "aws_route" "gw-route" {
  count                  = var.public-vpc ? 1 : 0
  route_table_id         = aws_vpc.vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw[0].id
}


######################################################################
# Security group and endpoints
######################################################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "sg" {
  name        = "${var.name}-sg"
  description = "Allow inbound ${var.external-in-port} and all outbound"
  vpc_id      = aws_vpc.vpc.id

  ingress = [
    {
      description      = "Incoming tcp ${var.external-in-port}"
      protocol         = "tcp"
      from_port        = var.external-in-port
      to_port          = var.external-in-port
      cidr_blocks      = var.external-in-cidrs
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = true
    },
    {
      description      = "All internal"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      cidr_blocks      = [var.vpc-cidr]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = true
    }
  ]

  egress {
    description      = "All outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cloudwatch-logs-and-interface-VPC.html
data "aws_iam_policy_document" "cloudwatch-logs-policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
    effect    = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

locals {
  aws-interface-endpoint-policies = {
    "ssm"         = null
    "ec2messages" = null
    "logs"        = data.aws_iam_policy_document.cloudwatch-logs-policy.json
    # "ec2" = null
    "ssmmessages" = null
    "kms"         = null
  }
}

# https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html#sysman-setting-up-vpc-create
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cloudwatch-logs-and-interface-VPC.html
resource "aws_vpc_endpoint" "aws" {
  for_each            = var.public-vpc ? {} : local.aws-interface-endpoint-policies
  vpc_id              = aws_vpc.vpc.id
  subnet_ids          = [aws_subnet.subnet.id]
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.sg.id]
  private_dns_enabled = true
  policy              = each.value
}

# s3 needs to be a gateway not an interface
resource "aws_vpc_endpoint" "aws-s3" {
  count             = var.public-vpc ? 0 : 1
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
}

# associate route table with VPC endpoint
resource "aws_vpc_endpoint_route_table_association" "aws-s3" {
  count           = var.public-vpc ? 0 : 1
  route_table_id  = aws_vpc.vpc.main_route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.aws-s3[0].id
}
