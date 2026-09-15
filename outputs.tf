output "agent_space_id" {
  description = "ID of the active AWS DevOps Agent space."
  value       = awscc_devopsagent_agent_space.this.id
}

output "agent_space_arn" {
  description = "ARN of the active AWS DevOps Agent space."
  value       = awscc_devopsagent_agent_space.this.arn
}

output "agent_space_name" {
  description = "Name of the AWS DevOps Agent space."
  value       = awscc_devopsagent_agent_space.this.name
}

output "monitoring_account_id" {
  description = "AWS account associated with this Agent Space for monitoring."
  value       = data.aws_caller_identity.current.account_id
}

output "monitoring_association_id" {
  description = "Association ID for the monitoring account."
  value       = awscc_devopsagent_association.monitoring_account.id
}

output "agentspace_role_arn" {
  description = "IAM role assumed by the DevOps Agent service."
  value       = local.agentspace_role_arn
}

output "operator_role_arn" {
  description = "IAM role used by the enabled IAM operator application."
  value       = local.operator_role_arn
}

output "aws_region" {
  description = "AWS Region containing the Agent Space."
  value       = data.aws_region.current.name
}
