# AWS validates the role trust policies while it creates an Agent Space. Wait
# briefly after creating either role so IAM propagation does not cause a
# transient create failure.
resource "time_sleep" "wait_for_iam" {
  count = var.existing_agentspace_role_arn == "" || var.existing_operator_role_arn == "" ? 1 : 0

  create_duration = "30s"

  depends_on = [
    aws_iam_role.agentspace,
    aws_iam_role_policy_attachment.agentspace_access,
    aws_iam_role_policy.agentspace_resource_explorer,
    aws_iam_role.operator,
    aws_iam_role_policy_attachment.operator_access,
  ]
}

# Enabling the IAM operator app lets authorized IAM users work with the agent
# through the AWS DevOps Agent web application.
resource "awscc_devopsagent_agent_space" "this" {
  name        = var.agent_space_name
  description = var.agent_space_description

  operator_app = {
    iam = {
      operator_app_role_arn = local.operator_role_arn
    }
  }

  depends_on = [time_sleep.wait_for_iam]
}

# A monitor association is the last required onboarding resource. It links the
# current account to the space and turns on AWS topology discovery for it.
resource "awscc_devopsagent_association" "monitoring_account" {
  agent_space_id = awscc_devopsagent_agent_space.this.id
  service_id     = "aws"

  configuration = {
    aws = {
      account_id         = data.aws_caller_identity.current.account_id
      account_type       = "monitor"
      assumable_role_arn = local.agentspace_role_arn
      resources          = []
    }
  }
}
