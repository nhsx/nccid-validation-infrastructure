#!/bin/bash
set -eu

SETUPDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
cd "$SETUPDIR"

export DEBIAN_FRONTEND=noninteractive

# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/download-cloudwatch-agent-commandline.html
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
# or region specific
# wget https://s3.eu-west-2.amazonaws.com/amazoncloudwatch-agent-eu-west-2/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

dpkg -i -E ./amazon-cloudwatch-agent.deb

apt-get update -q
apt-get install -y -q \
    auditd \
    dcmtk \
    docker-compose \
    docker.io \
    fuse \
    unzip
# apt-get upgrade -y -q

usermod -aG docker ubuntu

cat << EOF > /etc/audit/rules.d/commands.rules
-a exit,always -S execve
EOF

systemctl restart auditd

# AWS CLI v2
# https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

# Configure cloudwatch agent
# Edit amazon-cloudwatch-agent.json to monitor additional log files
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file-wizard.html
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:amazon-cloudwatch-agent.json

# S3 filesystem mount
curl -sfLO https://github.com/kahing/goofys/releases/download/v0.24.0/goofys
chmod a+x goofys
mv goofys /usr/local/bin/
