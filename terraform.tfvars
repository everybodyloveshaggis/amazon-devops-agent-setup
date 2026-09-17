# AWS DevOps Agent is only offered in certain AWS regions. The default value below sets the
# Region to London. See variables.tf for the complete supported list.
aws_region              = "eu-west-2"
agent_space_name        = "devops-agent"
agent_space_description = "AWS DevOps Agent monitoring space managed by Terraform."

# Provide these only when your organization already manages the two service
# roles. Leave them commented to have this configuration create the roles.
# existing_agentspace_role_arn = "arn:aws:iam::123456789012:role/YourAgentSpaceRole"
# existing_operator_role_arn   = "arn:aws:iam::123456789012:role/YourOperatorAppRole"

tags = {
  Environment = "production"
  ManagedBy   = "Terraform"
  Service     = "AWS-DevOps-Agent"
}

devops_agent_dynatrace = {
  secret_arn     = "arn:aws:secretsmanager:eu-west-2:899045892145:secret:aws-devops-agent-EqKw85"
  secret_region  = "eu-west-2"
  client_name    = "scottstrialdtaccount"
  environment_id = "jew15896"
  resources      = [] # Optional entity IDs, e.g. SERVICE-0123456789ABCDEF
}