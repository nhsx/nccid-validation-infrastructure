# AWS Terraform initial setup

Terraform can store its state file in a remote shared location, in this case an AWS S3 bucket.
Run this terraform once to create the bucket (use a local state file).
All future terraform invocations will use this S3 bucket for managing state.

1. Change into this directory
1. Initialise modules `terraform init`
1. Activate the AWS account and region that the TFState will be stored in, for example by exporting the `AWS_PROFILE` environment variable.
   This account may be different from the account used for deploying the rest of the infrastructure.
1. Run `terraform apply -var-file=../private/backend-setup.tfvars`
