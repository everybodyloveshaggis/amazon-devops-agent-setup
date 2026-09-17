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

variable "devops_agent_dynatrace" {
  description = "Optional Dynatrace capability provider. Supply secret_arn to register or existing_service_id to reuse a registration. Set environment_id to add telemetry to this Agent Space."
  type = object({
    secret_arn          = optional(string)
    secret_region       = optional(string)
    client_name         = optional(string, "aws-devops-agent")
    existing_service_id = optional(string)
    environment_id      = optional(string)
    resources           = optional(set(string), [])
  })
  default = null

  validation {
    condition = var.devops_agent_dynatrace == null ? true : (
      var.devops_agent_dynatrace.existing_service_id == null ?
      can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", var.devops_agent_dynatrace.secret_arn)) :
      try(trimspace(var.devops_agent_dynatrace.existing_service_id) != "", false)
    )
    error_message = "Supply a Secrets Manager secret_arn for a new registration, or a nonempty existing_service_id to reuse one."
  }

  validation {
    condition = var.devops_agent_dynatrace == null ? true : (
      try(trimspace(var.devops_agent_dynatrace.client_name) != "", false) &&
      (var.devops_agent_dynatrace.secret_region == null ? true : can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.devops_agent_dynatrace.secret_region))) &&
      (var.devops_agent_dynatrace.environment_id == null ? length(var.devops_agent_dynatrace.resources) == 0 : can(regex("^[a-zA-Z0-9-]+$", var.devops_agent_dynatrace.environment_id))) &&
      alltrue([for resource in var.devops_agent_dynatrace.resources : try(trimspace(resource) != "", false)])
    )
    error_message = "Use a nonempty client_name, a valid secret_region if supplied, and a short environment_id (not a URL) when adding telemetry. Entity IDs must be nonempty and require an environment_id."
  }
}
