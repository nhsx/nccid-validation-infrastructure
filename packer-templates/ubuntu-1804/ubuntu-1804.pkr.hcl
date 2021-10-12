variable "ami_name" {
  type = string
  default = "nccidav-ubuntu-1804-auditd-{{timestamp}}"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

# https://www.packer.io/docs/builders/amazon/ebs
source "amazon-ebs" "ubuntu1804" {
  ami_name      = "${var.ami_name}"
  instance_type = "t3.micro"
  region        = "${var.region}"
  source_ami_filter {
    filters = {
      name = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server*"
      root-device-type = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    # Canonical
    owners = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

# https://www.packer.io/docs/provisioners
build {
  sources = ["source.amazon-ebs.ubuntu1804"]

  provisioner "shell" {
    inline = [
      "sudo mkdir /opt/ami-setup",
      "sudo chown ubuntu /opt/ami-setup"
    ]
  }
  provisioner "file" {
    destination = "/opt/ami-setup/amazon-cloudwatch-agent.json"
    source      = "../ubuntu-common/amazon-cloudwatch-agent.json"
  }
  provisioner "file" {
    destination = "/opt/ami-setup/setup.sh"
    source      = "../ubuntu-common/setup.sh"
  }
  provisioner "file" {
    destination = "/opt/ami-setup/user-setup.sh"
    source      = "../ubuntu-common/user-setup.sh"
  }
  provisioner "file" {
    destination = "/opt/ami-setup/Mambaforge-4.10.3-6-Linux-x86_64.sh.sha256"
    source      = "../ubuntu-common/Mambaforge-4.10.3-6-Linux-x86_64.sh.sha256"
  }
  provisioner "shell" {
    inline = [
      # https://github.com/hashicorp/packer/issues/2639
      # https://serverfault.com/a/969598
      "/usr/bin/cloud-init status --wait",
      "sudo /opt/ami-setup/setup.sh",
      "/opt/ami-setup/user-setup.sh",
      "echo '${var.ami_name} {{isotime}}' > /opt/ami-setup/build.txt"
    ]
  }
}
