variable "aws_region" {
  description = "AWS Region in which to deploy the DevOps Agent space."
  type        = string
  default     = "eu-west-2"

  validation {
    condition = contains([
      "eu-west-2",
      "eu-west-1",
    ], var.aws_region)
    error_message = "AWS DevOps Agent must be in eu-west-2 or eu-west-1 for me."
  }
}

variable "agent_space_name" {
  description = "Name for the AWS DevOps Agent space."
  type        = string
  default     = "devops-agent"

  validation {
    condition     = length(trimspace(var.agent_space_name)) > 0
    error_message = "agent_space_name must not be empty."
  }
}

variable "agent_space_description" {
  description = "Description shown for the AWS DevOps Agent space."
  type        = string
  default     = "AWS DevOps Agent monitoring space managed by Terraform."
}

variable "role_name_suffix" {
  description = "Optional suffix for the IAM role names. A stable random suffix is used when omitted."
  type        = string
  default     = ""
}

variable "existing_agentspace_role_arn" {
  description = "Optional existing Agent Space role ARN. It must trust aidevops.amazonaws.com and have AIDevOpsAgentAccessPolicy attached."
  type        = string
  default     = ""
}

variable "existing_operator_role_arn" {
  description = "Optional existing operator-app role ARN. It must trust aidevops.amazonaws.com, allow sts:TagSession, and have AIDevOpsOperatorAppAccessPolicy attached."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to IAM roles created by this configuration."
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Service   = "AWS-DevOps-Agent"
  }
}
