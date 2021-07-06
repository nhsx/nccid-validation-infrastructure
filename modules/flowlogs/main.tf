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

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log

resource "aws_cloudwatch_log_group" "flowlogs" {
  name = var.name
}

data "aws_iam_policy_document" "flowlogs-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudwatch-flowlogs-policy" {
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
  }
}
resource "aws_iam_role" "flowlogs" {
  name = "${var.name}-vpc-role"

  assume_role_policy = data.aws_iam_policy_document.flowlogs-assume-role-policy.json

  inline_policy {
    name   = "${var.name}-cloudwatch-flowlogs-policy"
    policy = data.aws_iam_policy_document.cloudwatch-flowlogs-policy.json
  }
}

resource "aws_flow_log" "flowlogs" {
  # Using for_each is too complicated
  # https://discuss.hashicorp.com/t/the-for-each-value-depends-on-resource-attributes-that-cannot-be-determined-until-apply/25016
  count = length(var.vpc-ids)

  iam_role_arn    = aws_iam_role.flowlogs.arn
  log_destination = aws_cloudwatch_log_group.flowlogs.arn
  traffic_type    = "ALL"
  vpc_id          = var.vpc-ids[count.index]
}
