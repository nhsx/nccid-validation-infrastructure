variable "ami_name" {
  type    = string
  default = "nccidav-windows-2019-{{timestamp}}"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

# https://www.packer.io/docs/builders/amazon/ebs
source "amazon-ebs" "windows2019" {
  ami_name      = "${var.ami_name}"
  instance_type = "t3.medium"
  region        = "${var.region}"

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2019-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_use_ssl  = true
  winrm_insecure = true

  # This user data file sets up winrm and configures it so that the connection
  # from Packer is allowed. Without this file being set, Packer will not
  # connect to the instance.
  user_data_file = "winrm_bootstrap.txt"
}

# https://www.packer.io/docs/provisioners
build {
  sources = ["source.amazon-ebs.windows2019"]

  provisioner "file" {
    destination = "C:/Users/Administrator/install.ps1"
    source      = "install.ps1"
  }
  provisioner "file" {
    destination = "C:/Users/Administrator/amazon-cloudwatch-config.json"
    source      = "amazon-cloudwatch-config.json"
  }
  provisioner "file" {
    destination = "C:/Users/Administrator/environment-snakemake.yml"
    source      = "environment-snakemake.yml"
  }

  provisioner "powershell" {
    script = "install.ps1"
  }

  provisioner "powershell" {
    inline = [
      # Re-initialise the AWS instance on startup
      "C:/ProgramData/Amazon/EC2-Windows/Launch/Scripts/InitializeInstance.ps1 -Schedule",
      # Remove system specific information from this image
      "C:/ProgramData/Amazon/EC2-Windows/Launch/Scripts/SysprepInstance.ps1 -NoShutdown",
    ]
  }
}
