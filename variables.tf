### TERRAFORM VARIABLES

# PROVIDER
# AWS Region
variable "region" {
  description = "AWS region"
  default     = "us-west-1"
}

variable "akid" {
  description = "AWS Key"
  default     = ""
}

variable "secret" {
  description = "AWS Secret"
  default     = ""
}


# SUBNETS
# Public Subnet CIDRs
variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# Private Subnet CIDRs
variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
 default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# Availability Zones
variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

#Simple AD Domain
variable "domain" {
  description = "Windows Domain"
  default     = ""
}

variable "domain_password" {
  description = "Windows Domain Password"
  default     = ""
}

variable "ad_size" {
  description = "Active Directory Size"
  default     = "Small"
}