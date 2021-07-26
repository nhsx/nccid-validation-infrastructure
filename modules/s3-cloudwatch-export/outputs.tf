output "bucket-arn" {
  value = aws_s3_bucket.bucket.arn
}

output "bucket-export-locations" {
  value = formatlist("s3://${var.bucket-name}/%s", var.cloudwatch-export-prefixes)
}
