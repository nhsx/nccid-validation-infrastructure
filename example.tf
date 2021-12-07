variable "name" {
  type        = string
  default     = "nccidav-vendor"
  description = "Name to be used for generating resource names"
}

variable "ec2-key-name" {
  type = string
  # SSM web access is enabled so this key doesn't need to be shared
  # Import this into AWS EC2 before running Terraform
  default     = "key-name"
  description = "EC2 key name"
}

variable "aws-region" {
  type        = string
  default     = "eu-west-2"
  description = "AWS region (default London)"
}

variable "base-os-ami" {
  type = string
  # AMI built from packer-templates/ubuntu-2004/ubuntu-2004.pkr.hcl
  default     = "ami-?????????????????"
  description = "Base OS AMI ID"
}

variable "model-ami" {
  type = string
  # AMI with model installed
  default     = "ami-?????????????????"
  description = "Model AMI ID"
}

variable "external-in-cidrs" {
  type        = list(string)
  default     = ["127.0.0.1/32"]
  description = "CIDRs that can access public VM"
}

variable "ec2-instance-type" {
  type        = string
  default     = "t3.xlarge"
  description = "EC2 instance type"
}

variable "ec2-public-count" {
  type        = number
  default     = 1
  description = "Number of EC2 model instances on public VPC"
}

variable "ec2-private-count" {
  type        = number
  default     = 1
  description = "Number of EC2 model instances on private VPC"
}

variable "kibana-readonly" {
  type        = bool
  default     = true
  description = "Should Kibana access default to read-only?"
}

variable "create-s3-input-bucket" {
  type        = bool
  default     = true
  description = "Create an S3 input bucket for temporary use?"
}

variable "s3-input-syntheticdata-prefix" {
  type        = string
  default     = "synthetic-validation-data"
  description = "Give the public instance access to test data in the input bucket"
}

variable "external-s3-output-access" {
  type        = string
  default     = "arn:aws:iam::000000000000:root"
  description = "Allow read-only access for this account"
}

variable "cloudwatch-export-prefix" {
  type        = string
  default     = "cwl-export/random-string"
  description = "Random prefix to use for exporting cloudwatch logs to S3"
}

variable "default-tags" {
  type = map(any)
  default = {
    Project          = "NCCID AI Validation"
    Environment      = "prod"
    Owner            = "NCCID.validation@example.org"
    "NCCIDAV:vendor" = "vendor"
    "NCCIDAV:status" = "prod"
  }
  description = "Default tags applied to all AWS resources"
}

# AWS provider setup
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.45.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws-region
  default_tags {
    tags = var.default-tags
  }
}

data "aws_caller_identity" "current" {}

module "elasticsearch" {
  source = "./modules/elasticsearch"

  name            = var.name
  kibana-readonly = var.kibana-readonly
}

# Get IP of caller to limit SSH inbound IPs
# data "http" "myip" {
#   url = "https://checkip.amazonaws.com/"
# }

module "vpc-public" {
  source            = "./modules/vpc"
  name              = "${var.name}-public"
  vpc-cidr          = "172.20.0.0/16"
  subnet-cidr       = "172.20.1.0/24"
  external-in-cidrs = var.external-in-cidrs
  external-in-port  = 22
  public-vpc        = true
}

module "vpc-private" {
  count       = 1
  source      = "./modules/vpc"
  name        = "${var.name}-private"
  vpc-cidr    = "172.21.0.0/16"
  subnet-cidr = "172.21.1.0/24"
  public-vpc  = false
}

module "s3-input" {
  count       = 1
  source      = "./modules/s3-encrypted"
  bucket-name = "${var.name}-validation-input"
  bucket-readonly-principals = [{
    identifiers = ["ec2.amazonaws.com"]
    type        = "Service"
  }]
  old-version-expiry-days = 30
}

module "s3-output" {
  source      = "./modules/s3-encrypted"
  bucket-name = "${var.name}-validation-output"
  bucket-admin-principals = [{
    identifiers = ["ec2.amazonaws.com"]
    type        = "Service"
  }]
  bucket-readonly-principals = [{
    identifiers = [var.external-s3-output-access]
    type        = "AWS"
  }]
  old-version-expiry-days = 30
}

module "s3-cloudwatch-logs" {
  source                     = "./modules/s3-cloudwatch-export"
  bucket-name                = "${var.name}-validation-cloudwatch-logs"
  old-version-expiry-days    = 30
  cloudwatch-export-prefixes = [var.cloudwatch-export-prefix]
}

data "aws_iam_policy_document" "s3-input-access-policy-doc" {
  # Actual permissions are the intersection of this and the bucket policy
  count = var.create-s3-input-bucket ? 1 : 0

  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "${module.s3-input[0].bucket-arn}/*",
      module.s3-input[0].bucket-arn,
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [module.s3-input[0].key-arn]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "s3-output-access-policy-doc" {
  # Actual permissions are the intersection of this and the bucket policy

  statement {
    actions = [
      "s3:ListBucket",
      "s3:*Object",
      "s3:*MultipartUpload*"
    ]
    resources = [
      "${module.s3-output.bucket-arn}/*",
      module.s3-output.bucket-arn
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = [module.s3-output.key-arn]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "s3-input-syntheticdata-access-policy-doc" {
  # Actual permissions are the intersection of this and the bucket policy
  statement {
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${module.s3-input[0].bucket-arn}/${var.s3-input-syntheticdata-prefix}/*"
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "${module.s3-input[0].bucket-arn}",
    ]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "${var.s3-input-syntheticdata-prefix}/*",
      ]
    }
    effect = "Allow"
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [module.s3-input[0].key-arn]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "s3-input-access-policy" {
  count       = var.create-s3-input-bucket ? 1 : 0
  name        = "${var.name}-s3-input-access-instance-policy"
  path        = "/terraform/"
  description = "S3 input access instance policy"
  policy      = data.aws_iam_policy_document.s3-input-access-policy-doc[0].json
}

resource "aws_iam_policy" "s3-output-access-policy" {
  name        = "${var.name}-s3-output-access-instance-policy"
  path        = "/terraform/"
  description = "S3 output access instance policy"
  policy      = data.aws_iam_policy_document.s3-output-access-policy-doc.json
}

resource "aws_iam_policy" "s3-input-syntheticdata-access-policy" {
  name        = "${var.name}-s3-input-syntheticdata-access-instance-policy"
  path        = "/terraform/"
  description = "S3 input synthetic-data access instance policy"
  policy      = data.aws_iam_policy_document.s3-input-syntheticdata-access-policy-doc.json
}

module "ec2-instance-public" {
  count                  = var.ec2-public-count
  source                 = "./modules/ec2-instance"
  instance-type          = var.ec2-instance-type
  name                   = "${var.name}-public-${count.index}"
  ami                    = var.base-os-ami
  key-name               = var.ec2-key-name
  subnet-id              = module.vpc-public.subnet-id
  security-group-ids     = [module.vpc-public.vpc-security-group-id]
  instance-role-policies = [aws_iam_policy.s3-input-syntheticdata-access-policy.arn]
  assign-elastic-ip      = true
}

module "ec2-instance-private" {
  count                  = var.ec2-private-count
  source                 = "./modules/ec2-instance"
  instance-type          = var.ec2-instance-type
  name                   = "${var.name}-private-${count.index}"
  ami                    = var.model-ami
  key-name               = var.ec2-key-name
  subnet-id              = module.vpc-private.0.subnet-id
  security-group-ids     = [module.vpc-private.0.vpc-security-group-id]
  instance-role-policies = concat(aws_iam_policy.s3-input-access-policy[*].arn, [aws_iam_policy.s3-output-access-policy.arn])
  assign-elastic-ip      = false
  root-volume-size       = 100
}

module "flowlogs" {
  source  = "./modules/flowlogs"
  name    = "${var.name}-flowlogs"
  vpc-ids = concat([module.vpc-public.vpc-id], module.vpc-private.*.vpc-id)
}

output "elasticsearch-endpoint" {
  value = "https://${module.elasticsearch.elasticsearch-endpoint}"
}

output "kibana-endpoint" {
  value = "https://${module.elasticsearch.kibana-endpoint}"
}

output "ec2-public" {
  value = {
    id          = flatten(module.ec2-instance-public[*].instance[*].id),
    private-dns = flatten(module.ec2-instance-public[*].instance[*].private_dns),
    public-dns  = flatten(module.ec2-instance-public[*].instance[*].public_dns),
    elastic-dns = flatten(module.ec2-instance-public[*].elastic-ip[*].public_dns)
  }
}

output "cloudwatch-export-s3-locations" {
  value = module.s3-cloudwatch-logs.bucket-export-locations
}
