# AWS S3 encrypted bucket

Creates an S3 bucket with:
- public access blocked
- cross account roles for readonly and admin access (assume role)
- bucket policy allowing cross account readonly and admin access (assume role not necessary)
- versioning enabled, with old versions deleted after one year

The bucket policy allows authorised principals to access `s3://<bucket-name>/`.
