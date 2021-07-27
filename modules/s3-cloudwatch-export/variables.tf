variable "bucket-name" {
  type        = string
  description = "Bucket name"
}

variable "old-version-expiry-days" {
  type        = number
  default     = 366
  description = "Delete old versions after this many days"
}

variable "cloudwatch-export-prefixes" {
  type        = list(string)
  description = "List of 'random prefixes' in the bucket for separating cloudwatch export tasks, at least one is required."
}
