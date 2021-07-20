variable "bucket-name" {
  type        = string
  description = "Bucket name"
}

variable "bucket-readonly-principals" {
  type = list(object({
    identifiers = list(string)
    type        = string
  }))
  default     = []
  description = "List of AWS Principals with bucket readonly access"
}

variable "bucket-admin-principals" {
  type = list(object({
    identifiers = list(string)
    type        = string
  }))
  default     = []
  description = "List of AWS Principals with bucket admin access"
}

variable "old_version_expiry_days" {
  type        = number
  default     = 366
  description = "Delete old versions after this many days"
}
