locals {
  register_dynatrace_capability  = var.devops_agent_dynatrace == null ? false : var.devops_agent_dynatrace.existing_service_id == null
  associate_dynatrace_capability = var.devops_agent_dynatrace == null ? false : var.devops_agent_dynatrace.environment_id != null

  dynatrace_secret = local.register_dynatrace_capability ? jsondecode(data.aws_secretsmanager_secret_version.dynatrace[0].secret_string) : {}

  devops_agent_dynatrace_service_id = var.devops_agent_dynatrace == null ? null : (
    local.register_dynatrace_capability ? awscc_devopsagent_service.dynatrace[0].service_id : var.devops_agent_dynatrace.existing_service_id
  )
}

# The credentials may be stored in a different region from the Agent Space.
provider "aws" {
  alias  = "dynatrace_secrets"
  region = try(coalesce(var.devops_agent_dynatrace.secret_region, var.aws_region), var.aws_region)
}

data "aws_secretsmanager_secret_version" "dynatrace" {
  provider = aws.dynatrace_secrets
  count    = local.register_dynatrace_capability ? 1 : 0

  secret_id = var.devops_agent_dynatrace.secret_arn
}

# Account-level registration makes Dynatrace available in Add a capability > Telemetry.
resource "awscc_devopsagent_service" "dynatrace" {
  count = local.register_dynatrace_capability ? 1 : 0

  service_type = "dynatrace"
  service_details = {
    dynatrace = {
      account_urn = try(local.dynatrace_secret.DYNATRACE_ACCOUNT_URN, null)
      authorization_config = {
        o_auth_client_credentials = {
          client_name   = var.devops_agent_dynatrace.client_name
          client_id     = try(local.dynatrace_secret.DYNATRACE_CLIENT_ID, null)
          client_secret = try(local.dynatrace_secret.DYNATRACE_CLIENT_SECRET, null)
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for key in ["DYNATRACE_ACCOUNT_URN", "DYNATRACE_CLIENT_ID", "DYNATRACE_CLIENT_SECRET"] :
        try(trimspace(local.dynatrace_secret[key]) != "", false)
      ])
      error_message = "Registering Dynatrace requires DYNATRACE_ACCOUNT_URN, DYNATRACE_CLIENT_ID, and DYNATRACE_CLIENT_SECRET in secret_arn. A Dynatrace platform token cannot replace OAuth credentials."
    }
  }
}

# Supplying an environment adds telemetry to the Agent Space managed by this repo.
resource "awscc_devopsagent_association" "dynatrace" {
  count = local.associate_dynatrace_capability ? 1 : 0

  agent_space_id = awscc_devopsagent_agent_space.this.id
  service_id     = local.devops_agent_dynatrace_service_id
  configuration = {
    dynatrace = {
      env_id    = var.devops_agent_dynatrace.environment_id
      resources = sort(tolist(var.devops_agent_dynatrace.resources))
    }
  }
}
