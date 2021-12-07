# AWS Terraform examples

## Usage:
Based on https://learn.hashicorp.com/tutorials/terraform/aws-build

## Initial setup of TFState backend (S3 bucket)
See [./backend-setup](./backend-setup)

## Building AMIs
If you want to build a custom Ubuntu or Windows AMI with the AWS CloudWatch agent and other utilities:
1. Check the AWS tenancy has a default public VPC, if it doesn't [create it in the AWS console](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html#create-default-vpc)
1. `cd packer-templates/<image>`
1. `packer build <image>.pkr.hcl`

## Deploying infrastructure
1. Install Terraform (last tested with version `1.0.2`)
1. Rename and edit `example.tf`
1. Initialise modules `terraform init`
1. Upload or create an EC2 keypair (e.g. `aws ec2 import-key-pair --key-name <key-name> --public-key-material fileb://~/.ssh/id_rsa.pub`)
1. Run `terraform apply -var-file=path/to/input.tfvars`
   Set the `AWS_PROFILE` environment variable or other authentication environment variables if needed for the deployed infrastructure (note this AWS account may be different from the backend A3 TFState account)
1. Complete the manual post-deployment steps

## Manual post-deployment steps
- Setup Elasticsearch authentication
   1. Follow the manual instructions in [`modules/elasticsearch/README.md`](modules/elasticsearch/README.md).
   1. Go to the AWS Cognito service
   1. Under `User Pools` open the user pool, go to `General settings` → `Users and groups`
   1. Add some users (only an email is necessary)
- Setup log shipping from CloudWatch to ElasticSearch
   1. Go to the AWS CloudWatch service
   1. Open `Logs` → `Log groups`
   1. Select the `audit.log` group, and optionally others
   1. Select `Actions` → `Subscription filters` → `Create Elasticsearch subscription filter`
   1. Under `Choose destination` → `Amazon ES cluster` select the `${var.name}`
   1. Under `Lambda IAM Execution Role` select `${var.name}-es-admin-lambda-role`
   1. Under `Configure log format and filters` → `Subscription filter name` enter a name, e.g. `auditd`
   1. Scroll to the bottom and click `Start streaming`.
   1. Wait for the banner at the top to show it's ready
- Setup ElasticSearch indexes
   1. Go to the Kibana URL output when you ran terraform
   1. Login with the Cognito account you created
   1. Go to `Kibana` → `Add your data` → `Create index pattern`
   1. Index pattern name: enter `cwl-*`
   1. `Time field`: select `@timestamp`
   1. `Create index pattern`

## Developing code
1. Format files `terraform fmt -recursive`
1. Validate `terraform validate`

## Access to EC2 instances
All instances can be accessed using SSM in both public and private VPCs.
The Public instance can be accessed using SSH if your IP is allowed.

## Basic checks:
Setup
1. Copy a file into the created S3 bucket `s3://${var.bucket-name}` using any method, e.g. `aws s3 cp hello.txt s3://${var.bucket-name}/a/hello.txt`

Public EC2 instance:
1. Log in from outside using SSH
1. Check public internet access works: `curl www.bbc.co.uk`
1. Check S3 access to the configured bucket works:
   - `aws s3 ls s3://${var.bucket-name}`
   - `aws s3 cp s3://${var.bucket-name}/a/hello.txt -` (outputs to stdout)
1. Check connection is possible using SSM

Private EC2 instance:
1. Log in using SSM
1. Switch user, e.g. `sudo su - ubuntu`
1. Check public internet access ir blocked: `curl www.bbc.co.uk`
1. Check S3 access to the configured bucket works:
   - `aws s3 ls s3://${var.bucket-name}`
   - `aws s3 cp s3://${var.bucket-name}/a/hello.txt -` (outputs to stdout)

ElasticSearch
1. Log into Kibana
1. Under discover data check there are logs corresponding to the command you ran on the instances.
