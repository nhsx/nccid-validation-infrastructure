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

# https://anthony-f-tannous.medium.com/provisioning-aws-kms-encrypted-buckets-with-cross-account-access-62c0eb771873
# https://blog.container-solutions.com/how-to-create-cross-account-user-roles-for-aws-with-terraform

######################################################################
# Encrypted S3 bucket
######################################################################

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "bucket-key-policy" {

  dynamic "statement" {
    # Ignore if no readonly principals
    for_each = length(var.bucket-readonly-principals) > 0 ? [1] : []
    content {
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      resources = ["*"]
      effect    = "Allow"

      dynamic "principals" {
        for_each = var.bucket-readonly-principals
        content {
          identifiers = principals.value["identifiers"]
          type        = principals.value["type"]
        }
      }
    }
  }

  statement {
    actions   = ["kms:*"]
    resources = ["*"]
    effect    = "Allow"

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.id}:root"]
      type        = "AWS"
    }

    dynamic "principals" {
      for_each = var.bucket-admin-principals
      content {
        identifiers = principals.value["identifiers"]
        type        = principals.value["type"]
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key
resource "aws_kms_key" "bucket-key" {
  description = "KMS key for bucket"
  # Default: delete key material 30 days after key is deleted
  # deletion_window_in_days = 30
  policy = data.aws_iam_policy_document.bucket-key-policy.json
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
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

  lifecycle_rule {
    id                                     = "Delete old versions of objects"
    enabled                                = true
    abort_incomplete_multipart_upload_days = var.old_version_expiry_days
    expiration {
      expired_object_delete_marker = true
    }
    noncurrent_version_expiration {
      days = var.old_version_expiry_days
    }
  }

  #   logging = {
  #     target_bucket =
  #     target_prefix =
  #   }
}


# Cross-account access without switching roles
data "aws_iam_policy_document" "bucket-policy" {

  dynamic "statement" {
    # Ignore if no readonly principals
    for_each = length(var.bucket-readonly-principals) > 0 ? [1] : []
    content {
      actions = [
        "s3:ListBucket",
        "s3:GetObject",
        # "s3:PutObject"
      ]
      resources = [
        aws_s3_bucket.bucket.arn,
        "${aws_s3_bucket.bucket.arn}/*"
      ]
      effect = "Allow"

      dynamic "principals" {
        for_each = var.bucket-readonly-principals
        content {
          identifiers = principals.value["identifiers"]
          type        = principals.value["type"]
        }
      }
    }
  }

  statement {
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*"
    ]
    effect = "Allow"

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.id}:root"]
      type        = "AWS"
    }

    dynamic "principals" {
      for_each = var.bucket-admin-principals
      content {
        identifiers = principals.value["identifiers"]
        type        = principals.value["type"]
      }
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

# https://learn.hashicorp.com/tutorials/terraform/aws-iam-policy
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
# There are two ways to set policies:
# - attachments allow other policies to be added separately
# - inline policies assume exclusive control (manual changes will be reverted)
#   - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_policy_attachment
#   - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
#   - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment


######################################################################
# Role that allows cross-account read-only bucket access
######################################################################

data "aws_iam_policy_document" "bucket-readonly-xacct-policy" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      # "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*"
    ]
    effect = "Allow"
  }
  statement {
    actions = [
      # "kms:Encrypt",
      "kms:Decrypt",
      # "kms:ReEncrypt*",
      # "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.bucket-key.arn]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "bucket-readonly-xacctrole-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    dynamic "principals" {
      for_each = var.bucket-readonly-principals
      content {
        identifiers = principals.value["identifiers"]
        type        = principals.value["type"]
      }
    }
  }
}

resource "aws_iam_role" "bucket-readonly-role" {
  # If there are no principals don't create the role
  count = length(var.bucket-readonly-principals) > 0 ? 1 : 0

  name               = "${var.bucket-name}-readonly-role"
  path               = "/terraform/"
  assume_role_policy = data.aws_iam_policy_document.bucket-readonly-xacctrole-policy.json
  inline_policy {
    name   = "${var.bucket-name}-readonly-xacctrole-policy"
    policy = data.aws_iam_policy_document.bucket-readonly-xacct-policy.json
  }
}

######################################################################
# Role that allows cross-account admin bucket access
######################################################################

data "aws_iam_policy_document" "bucket-admin-xacct-policy" {
  # statement {
  #   actions   = ["s3:ListAllMyBuckets"]
  #   resources = ["arn:aws:s3:::*"]
  #   effect    = "Allow"
  # }
  # statement {
  #   actions   = ["s3:ListBucket"]
  #   resources = [aws_s3_bucket.bucket.arn]
  #   effect    = "Allow"
  # }
  statement {
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*"
    ]
    effect = "Allow"
  }
  statement {
    actions   = ["kms:*"]
    resources = [aws_kms_key.bucket-key.arn]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "bucket-admin-xacctrole-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    dynamic "principals" {
      for_each = var.bucket-admin-principals
      content {
        identifiers = principals.value["identifiers"]
        type        = principals.value["type"]
      }
    }
  }
}

resource "aws_iam_role" "bucket-admin-role" {
  # If there are no principals don't create the role
  count = length(var.bucket-admin-principals) > 0 ? 1 : 0

  name               = "${var.bucket-name}-admin-role"
  path               = "/terraform/"
  assume_role_policy = data.aws_iam_policy_document.bucket-admin-xacctrole-policy.json
  inline_policy {
    name   = "${var.bucket-name}-admin-xacctrole-policy"
    policy = data.aws_iam_policy_document.bucket-admin-xacct-policy.json
  }
}
