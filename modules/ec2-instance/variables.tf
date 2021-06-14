variable "name" {
  type        = string
  description = "Name to be used for generating resource names"
}

variable "key-name" {
  type        = string
  description = "SSH key name"
}

variable "subnet-id" {
  type        = string
  description = "Subnet ID"
}

variable "security-group-ids" {
  type        = list(string)
  description = "List of security group IDs"
}

variable "assign-elastic-ip" {
  type        = bool
  default     = false
  description = "Assign an elastic IP to this instance (requires public VPC)"
}

variable "ami" {
  type        = string
  description = "AMI base image"
}

variable "instance-type" {
  type        = string
  default     = "t3.micro"
  description = "Instance type"
}

variable "root-volume-size" {
  type        = number
  default     = 100
  description = "Root volume size (GB)"
}

variable "instance-role-policies" {
  type        = list(string)
  default     = []
  description = "ARNs of additional IAM policies to add to the instance"
}

# variable "input-bucket-name" {
#   type        = string
#   description = "Input bucket name"
# }

# variable "output-bucket-name" {
#   type        = string
#   description = "Output bucket name"
# }
