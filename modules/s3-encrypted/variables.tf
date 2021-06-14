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
