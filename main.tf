# Information about the account that runs this Terraform configuration. This is
# the monitoring account that the new Agent Space will monitor.
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

locals {
  role_suffix = var.role_name_suffix != "" ? var.role_name_suffix : random_id.role_suffix.hex

  agentspace_role_arn = var.existing_agentspace_role_arn != "" ? var.existing_agentspace_role_arn : aws_iam_role.agentspace[0].arn
  operator_role_arn   = var.existing_operator_role_arn != "" ? var.existing_operator_role_arn : aws_iam_role.operator[0].arn
}
