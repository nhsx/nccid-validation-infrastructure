output "bucket-arn" {
  value = aws_s3_bucket.bucket.arn
}

output "key-arn" {
  value = aws_kms_key.bucket-key.arn
}

output "bucket-readonly-role" {
  value = aws_iam_role.bucket-readonly-role[*].arn
}

output "bucket-admin-role" {
  value = aws_iam_role.bucket-admin-role[*].arn
}
