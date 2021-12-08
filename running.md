# Production Model Deployment/Execution Checklist

## Preparation

1. Create base infrastructure including VM accessible from the internet (limited by security group) using Terraform
2. Copy synthetic data to `s3://${var.name}-validation-input/synthetic-validation-data/` (vendor account input bucket created by terraform in step 1)
3. Setup CloudWatch logs to forward auditd logs to ELK, check commands appear

## Model Installation

1. Install model: Either live with vendor, or without them if they’re happy to transfer model to use separately
2. Create ELK account for vendor (can also be done later). Email them in advance with login URL, and to warn them to expect an anonymous email containing credentials (sent automatically by AWS Cognito).
3. Test model on one synthetic image. If a local image is required for initial testing: `aws s3 cp s3://${var.name}-validation-input/synthetic-validation-data/xray/xxx.dcm`.
4. Adjust deployment until working
5. Run model on full synthetic dataset using the script/snakemake/tool that will be used in production
6. Refine script if necessary
7. Collect predictions and logs from synthetic dataset model
8. Check expected logs were sent to CloudWatch and ELK (remember only execution/auditd logs should be present in ELK)
9. Review output logs for sensitive identifiers, for example using [`tools/check_logs.ipynb`](./tools/check_logs.ipynb) as a base
10. Send model outputs and logs to vendor for review
11. When vendor is happy create AMI

## Validation run

1. Confirm with vendor they’re happy for model (AMI) to be launched in private network, and for validation run to proceed
2. Deploy model in private infrastructure. To access VMs use AWS Session Manager since there should be no external network access.
3. Run model on synthetic data. Check ELK logs are updated.
4. Add AWS credentials for the production validation bucket to a new aws profile: `aws --profile=data configure`
This is needed because access to the production S3 bucket is only possible using a separate set of credentials, it is not possible through the instance role
5. Tell vendor the real run is about to start.
6. Run model on real validation data. Send stdout/stderr of script to a file monitored by CloudWatch (e.g. `/home/ubuntu/run.log`)
7. Copy model outputs to vendor output S3 bucket if not already saved there as part of run script.
8. Check for errors. Re-run if required. Discuss with rest of team if number of errors is excessive.
9. Shutdown VMs but do not delete them.
10. Tell vendor model run has finished, but their model/infrastructure will be kept until initial review of results

## Check outputs of model

1. Sanity check outputs of model. Do this inside the AWS tenancy, e.g. using JupyterLab in the vendor VM, or by creating a new EC2 instances with access to the S3 output bucket with whatever analysis tools you require. This VM can be on an externally accessible network as long as input data is not accessible.
2. Remember to be careful about what information is given to analysis team to ensure no biases are introduced
3. Create a SHA256 checksums file listing all output files with the corresponding SHA256 checksum (`sha256sum ...`)
4. Copy model outputs to persistent account
5. Agree handover of outputs to analysis team

## Deletion of model

1. Communicate with vendors.
2. Delete AMIs and instances, recording evidence such as screenshots or CLI/API calls. This is the most critical stage as it involves demonstrating to a vendor that their model has been deleted, see [`tools/cleanup.ipynb`](./tools/cleanup.ipynb)
3. Archive CloudWatch logs (should include system and model logs) to persistent account, see [`tools/archive-logs.py`](./tools/archive-logs.py)
4. Delete AMIs, provide evidence to vendors
5. Delete infrastructure (`terraform delete`), keep terraform logs if possible
6. Some resources may not be deleted, e.g. S3 buckets containing data, or anything created outside Terraform. Manually delete these.
