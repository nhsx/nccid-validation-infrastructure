# AWS S3 encrypted bucket for CloudWatch

Create an encrypted AWS S3 bucket and IAM user for exporting AWS CloudWatch logs.

AWS CloudWatch logs can be exported to S3, but the bucket cannot use `aws:kms` encryption.
This means the `s3-encrypted` module will not work.

See
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/S3Export.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/S3ExportTasks.html

Creates an S3 bucket with:
- public access blocked
- bucket policy allowing access from AWS CloudWatch logs for a set of random supplied prefixes
- versioning enabled, with old versions deleted after one year
