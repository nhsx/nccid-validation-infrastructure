# Use this to rebuild an AMI previosuly created,
# but with an updated amazon-cloudwatch-agent.json

variable "ami_source" {
  type = string
}
variable "ami_name" {
  type = string
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "${var.ami_name}"
  instance_type = "t3.micro"
  region        = "${var.region}"
  source_ami    = "${var.ami_source}"
  ssh_username = "ubuntu"
}

# https://www.packer.io/docs/provisioners
build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "file" {
    destination = "/opt/ami-setup/amazon-cloudwatch-agent.json"
    source      = "./amazon-cloudwatch-agent.json"
  }
  provisioner "shell" {
    inline = [
      "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/ami-setup/amazon-cloudwatch-agent.json",
      "echo '${var.ami_name} {{isotime}}' > /opt/ami-setup/build.txt"
    ]
  }
}
