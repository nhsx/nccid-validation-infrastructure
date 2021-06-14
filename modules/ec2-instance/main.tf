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
# EC2 instance role
######################################################################

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html
data "aws_iam_policy_document" "instance-private-s3-policy" {
  statement {
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::aws-ssm-region/*",
      "arn:aws:s3:::aws-windows-downloads-region/*",
      "arn:aws:s3:::amazon-ssm-region/*",
      "arn:aws:s3:::amazon-ssm-packages-region/*",
      "arn:aws:s3:::region-birdwatcher-prod/*",
      "arn:aws:s3:::aws-ssm-distributor-file-region/*",
      "arn:aws:s3:::aws-ssm-document-attachments-region/*",
      "arn:aws:s3:::patch-baseline-snapshot-region/*"
    ]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "s3-access-policy" {
  name        = "${var.name}-s3-access-policy"
  path        = "/terraform/"
  description = "S3 access policy"
  policy      = data.aws_iam_policy_document.instance-private-s3-policy.json
}

resource "aws_iam_role" "role" {
  name               = "${var.name}-instance-role"
  path               = "/terraform/"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
  managed_policy_arns = concat([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    aws_iam_policy.s3-access-policy.arn
    ],
  var.instance-role-policies)
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile
resource "aws_iam_instance_profile" "profile" {
  name = "${var.name}-instance-profile"
  path = "/terraform/"
  role = aws_iam_role.role.name
}


######################################################################
# EC2 instance
######################################################################

resource "aws_instance" "instance" {
  ami                         = var.ami
  instance_type               = var.instance-type
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.profile.name
  key_name                    = var.key-name
  subnet_id                   = var.subnet-id
  # user_data
  # user_data_base64
  vpc_security_group_ids = var.security-group-ids

  root_block_device {
    encrypted = true
    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html
    volume_type = "gp2"
    volume_size = var.root-volume-size
  }

  tags = {
    Name = var.name
  }
}

resource "aws_eip" "eip" {
  count    = var.assign-elastic-ip ? 1 : 0
  instance = aws_instance.instance.id
  vpc      = true
}
