#!/usr/bin/env python

from argparse import ArgumentParser
import boto3
from datetime import datetime


parser = ArgumentParser(description="Export cloudwatch logs to S3")
parser.add_argument("vendor", help="vendor name")
parser.add_argument("--group", "-g", help="Log group name. If omitted a list of log groups will be displayed, but nothing will be exported")
parser.add_argument("--bucket", help="Destination bucket (see s3-cloudwatch-logs.bucket-name in example.tf)")
parser.add_argument("--prefix", help="Bucket prefix (see cloudwatch-export-prefix in example.tf)")

args = parser.parse_args()

logs = boto3.client("logs")

date = datetime.now().isoformat()[:10]

if args.bucket:
    destination = args.bucket
else:
    destination = f"nccidav-{args.vendor}-validation-cloudwatch-logs"

prefix = f"{args.prefix}/{args.group}-{date}"

if args.group:
    print(args.group, date, args.vendor)
    task = logs.create_export_task(
        taskName=f"export-{args.group}-{date}",
        logGroupName=args.group,
        fromTime=0,
        to=2147483647000,
        destination=destination,
        destinationPrefix=prefix,
    )
    print(task)
else:
    groups = logs.describe_log_groups()["logGroups"]
    for group in groups:
        print(group["logGroupName"])
