# Initial setup of S3 bucket to store tfstate file
variable "bucket-name" {
  type        = string
  description = "Bucket name for Terraform state file"
}

variable "default-tags" {
  type        = map(any)
  default     = {}
  description = "Default tags applied to all AWS resources"
}

variable "aws-region" {
  type        = string
  default     = "eu-west-2"
  description = "AWS region (default London)"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
      # version = "3.42.0"
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

resource "aws_kms_key" "bucket-key" {
  description = "KMS key for bucket"
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket-name

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.bucket-key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "public-block" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
