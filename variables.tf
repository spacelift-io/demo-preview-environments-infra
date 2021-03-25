variable "aws_region" {
  default = "eu-west-1"
}

variable "certificate_arn" {
}

variable "code_version" {
}

variable "domain_name" {
}

variable "environment" {
}

locals {
  suffix   = "_${var.environment}"
  endpoint = "${var.environment}.${var.domain_name}"
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
