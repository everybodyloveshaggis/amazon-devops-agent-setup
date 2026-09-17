mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { name = "eu-west-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

mock_provider "aws" {
  alias = "dynatrace_secrets"
  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "{\"DYNATRACE_ACCOUNT_URN\":\"urn:dtaccount:test-account\",\"DYNATRACE_CLIENT_ID\":\"test-client\",\"DYNATRACE_CLIENT_SECRET\":\"test-client-secret\"}"
    }
  }
}

mock_provider "awscc" {
  mock_resource "awscc_devopsagent_agent_space" {
    defaults = { id = "12345678-1234-1234-1234-123456789012" }
  }
  mock_resource "awscc_devopsagent_service" {
    defaults = { service_id = "registered-dynatrace" }
  }
  mock_resource "awscc_devopsagent_association" {
    defaults = { association_id = "test-association" }
  }
}

mock_provider "random" {}
mock_provider "time" {}

variables {
  aws_region                   = "eu-west-1"
  existing_agentspace_role_arn = "arn:aws:iam::123456789012:role/AgentSpace"
  existing_operator_role_arn   = "arn:aws:iam::123456789012:role/Operator"
  devops_agent_dynatrace       = null
}

run "disabled_by_default" {
  command = apply

  assert {
    condition = (
      length(awscc_devopsagent_service.dynatrace) == 0 &&
      length(awscc_devopsagent_association.dynatrace) == 0 &&
      length(data.aws_secretsmanager_secret_version.dynatrace) == 0 &&
      output.devops_agent_dynatrace_service_id == null &&
      output.devops_agent_dynatrace_association_id == null &&
      awscc_devopsagent_association.monitoring_account.agent_space_id == output.agent_space_id
    )
    error_message = "Default onboarding must preserve the AWS monitoring association without reading Dynatrace credentials or registering telemetry."
  }
}

run "registration_only" {
  command = apply

  variables {
    devops_agent_dynatrace = {
      secret_arn    = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:dynatrace-test"
      secret_region = "eu-west-2"
      client_name   = "scottstrialdtaccount"
    }
  }

  assert {
    condition = (
      awscc_devopsagent_service.dynatrace[0].service_type == "dynatrace" &&
      awscc_devopsagent_service.dynatrace[0].service_details.dynatrace.account_urn == "urn:dtaccount:test-account" &&
      awscc_devopsagent_service.dynatrace[0].service_details.dynatrace.authorization_config.o_auth_client_credentials.client_name == "scottstrialdtaccount" &&
      awscc_devopsagent_service.dynatrace[0].service_details.dynatrace.authorization_config.o_auth_client_credentials.client_id == "test-client" &&
      awscc_devopsagent_service.dynatrace[0].service_details.dynatrace.authorization_config.o_auth_client_credentials.client_secret == "test-client-secret" &&
      output.devops_agent_dynatrace_service_id == "registered-dynatrace" &&
      length(awscc_devopsagent_association.dynatrace) == 0
    )
    error_message = "Registration must use the OAuth secret and allow the capability to be added manually later."
  }
}

run "register_and_add_telemetry" {
  command = apply

  variables {
    devops_agent_dynatrace = {
      secret_arn     = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:dynatrace-test"
      environment_id = "abc12345"
      resources      = ["SERVICE-1234567890ABCDEF", "APPLICATION-1234567890ABCDEF", "SERVICE-1234567890ABCDEF"]
    }
  }

  assert {
    condition = (
      awscc_devopsagent_association.dynatrace[0].service_id == output.devops_agent_dynatrace_service_id &&
      awscc_devopsagent_association.dynatrace[0].agent_space_id == output.agent_space_id &&
      awscc_devopsagent_association.dynatrace[0].agent_space_id == awscc_devopsagent_association.monitoring_account.agent_space_id &&
      awscc_devopsagent_association.dynatrace[0].configuration.dynatrace.env_id == "abc12345" &&
      awscc_devopsagent_association.dynatrace[0].configuration.dynatrace.resources == tolist(["APPLICATION-1234567890ABCDEF", "SERVICE-1234567890ABCDEF"]) &&
      output.devops_agent_dynatrace_association_id == "test-association"
    )
    error_message = "Telemetry must use this repo's Agent Space, the registered service, and the requested environment with deduplicated entity IDs."
  }
}

run "reuse_manual_registration_without_secret" {
  command = plan

  variables {
    devops_agent_dynatrace = {
      existing_service_id = "manually-registered-dynatrace"
      environment_id      = "abc12345"
    }
  }

  assert {
    condition = (
      length(awscc_devopsagent_service.dynatrace) == 0 &&
      length(data.aws_secretsmanager_secret_version.dynatrace) == 0 &&
      awscc_devopsagent_association.dynatrace[0].service_id == "manually-registered-dynatrace" &&
      length(awscc_devopsagent_association.dynatrace[0].configuration.dynatrace.resources) == 0
    )
    error_message = "Reusing a manual registration must not read credentials or create a duplicate provider; entity scoping is optional."
  }
}

run "reject_environment_url" {
  command = plan
  variables {
    devops_agent_dynatrace = {
      existing_service_id = "manually-registered-dynatrace"
      environment_id      = "https://abc12345.apps.dynatrace.com"
    }
  }
  expect_failures = [var.devops_agent_dynatrace]
}

run "reject_missing_secret_arn" {
  command = plan
  variables {
    devops_agent_dynatrace = {}
  }
  expect_failures = [var.devops_agent_dynatrace]
}

run "reject_missing_oauth_credentials" {
  command = plan
  variables {
    devops_agent_dynatrace = {
      secret_arn = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:dynatrace-test"
    }
  }
  override_data {
    target = data.aws_secretsmanager_secret_version.dynatrace[0]
    values = { secret_string = "{\"DYNATRACE_PLATFORM_TOKEN\":\"test-platform-token\"}" }
  }
  expect_failures = [awscc_devopsagent_service.dynatrace]
}
