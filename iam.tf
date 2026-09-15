# The service assumes these two narrowly trusted roles. Supplying either
# existing_*_role_arn variable skips the matching role and policy creation.
resource "random_id" "role_suffix" {
  byte_length = 4
}

data "aws_iam_policy_document" "agentspace_assume_role" {
  count = var.existing_agentspace_role_arn == "" ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["aidevops.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:aidevops:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agentspace/*"]
    }
  }
}

resource "aws_iam_role" "agentspace" {
  count              = var.existing_agentspace_role_arn == "" ? 1 : 0
  name               = "DevOpsAgentRole-AgentSpace-${local.role_suffix}"
  assume_role_policy = data.aws_iam_policy_document.agentspace_assume_role[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "agentspace_access" {
  count      = var.existing_agentspace_role_arn == "" ? 1 : 0
  role       = aws_iam_role.agentspace[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AIDevOpsAgentAccessPolicy"
}

# Resource Explorer needs this service-linked role for the account topology
# discovery that DevOps Agent performs.
data "aws_iam_policy_document" "agentspace_resource_explorer" {
  count = var.existing_agentspace_role_arn == "" ? 1 : 0

  statement {
    sid       = "AllowCreateResourceExplorerServiceLinkedRole"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/resource-explorer-2.amazonaws.com/AWSServiceRoleForResourceExplorer"]
  }
}

resource "aws_iam_role_policy" "agentspace_resource_explorer" {
  count  = var.existing_agentspace_role_arn == "" ? 1 : 0
  name   = "AllowCreateResourceExplorerServiceLinkedRole"
  role   = aws_iam_role.agentspace[0].id
  policy = data.aws_iam_policy_document.agentspace_resource_explorer[0].json
}

data "aws_iam_policy_document" "operator_assume_role" {
  count = var.existing_operator_role_arn == "" ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["aidevops.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:aidevops:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agentspace/*"]
    }
  }
}

resource "aws_iam_role" "operator" {
  count              = var.existing_operator_role_arn == "" ? 1 : 0
  name               = "DevOpsAgentRole-WebappAdmin-${local.role_suffix}"
  assume_role_policy = data.aws_iam_policy_document.operator_assume_role[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "operator_access" {
  count      = var.existing_operator_role_arn == "" ? 1 : 0
  role       = aws_iam_role.operator[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AIDevOpsOperatorAppAccessPolicy"
}
