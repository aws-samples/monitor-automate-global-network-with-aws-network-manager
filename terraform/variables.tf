# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# --- terraform/variables.tf ---

variable "infrastructure_region" {
  type        = string
  description = "AWS Region to build the Transit gateway network."
}

variable "email_address" {
  type        = string
  description = "Email Address - to receive SNS topic notifications."
}

variable "deploy_vpc" {
    type = bool
    description = "Indicates if the Transit gateway network should be deployed or not."

    default = false
}