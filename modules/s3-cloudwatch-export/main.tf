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

data "aws_region" "current" {}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket-name
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id                                     = "Delete old versions of objects"
    enabled                                = true
    abort_incomplete_multipart_upload_days = var.old-version-expiry-days
    expiration {
      expired_object_delete_marker = true
    }
    noncurrent_version_expiration {
      days = var.old-version-expiry-days
    }
  }

  #   logging = {
  #     target_bucket =
  #     target_prefix =
  #   }
}


# Allow access for AWS CloudWatch logs
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/S3ExportTasksConsole.html
data "aws_iam_policy_document" "bucket-policy" {

  statement {
    actions = [
      "s3:GetBucketAcl"
    ]
    resources = [
      aws_s3_bucket.bucket.arn
    ]
    effect = "Allow"
    principals {
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
      type        = "Service"
    }
  }

  statement {
    actions = [
      "s3:PutObject"
    ]
    resources = formatlist("${aws_s3_bucket.bucket.arn}/%s/*", var.cloudwatch-export-prefixes)
    effect    = "Allow"
    principals {
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket-policy.json
}

resource "aws_s3_bucket_public_access_block" "public-block" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
