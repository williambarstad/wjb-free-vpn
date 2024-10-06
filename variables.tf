variable "instance_profile" {
  description = "The name of the instance profile"
  default     = ""
}

variable "wjb-ip" {
  description = "The IP address of the user"
  default     = ""
}

variable "account_id" {
  description = "The AWS account ID"
  default     = ""
}

variable "env" {
  description = "The environment name (e.g., dev, prod)"
  default     = "dev"
}

variable "region" {
  description = "The AWS region to deploy resources"
  default     = "us-west-2"
}

variable "azone1" {
  description = "The first availability zone"
  default     = "us-west-2a"
}

variable "ami_name" {
  description = "The name of the AMI to use for the instances"
  default     = ""
}

variable "ami" {
  description = "The ID of the AMI to use for the instances"
  default     = ""
}

variable "wjb_ami_instance_profile" {
  description = "The name of the instance profile for the AMI"
  default     = ""
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

# Subnet variables
variable "public_subnet_cidr_az1" {
  description = "CIDR block for the public subnet in availability zone 1"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr_az1" {
  description = "CIDR block for the private subnet in availability zone 1"
  default     = "10.0.2.0/24"
}

variable "key_name" {
  description = "The name of the SSH key to use for the EKS nodes"
  default     = ""
}

variable "capacity_type" {
  description = "The capacity type for the EKS nodes"
  default     = "ON_DEMAND"
}

variable "instance_type" {
  description = "The instance type for the EKS nodes"
  default     = "t3.medium"
}