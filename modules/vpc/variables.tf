variable "name" {
  type        = string
  description = "VPC name"
}

variable "vpc-cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR"
}

variable "subnet-cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "VPC CIDR"
}

variable "external-in-cidrs" {
  type        = list(string)
  default     = ["127.0.0.1/32"]
  description = "Allow inbound traffic from these CIDRs to `external-in-port`"
}

variable "external-in-port" {
  type        = number
  default     = 22
  description = "Allow inbound traffic from `external-in-cidrs` to this port"
}

variable "public-vpc" {
  type        = bool
  default     = false
  description = "Enable public internet access via a gateway. Do not change this from true → false after deployment (false → true is OK)."
}
