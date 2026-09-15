# AWS DevOps Agent Terraform setup

This configuration enables the **AWS DevOps Agent** in one AWS account. It
creates the Agent Space, the IAM role used by the agent, the IAM role used by
the IAM operator app, and the required monitoring-account association. Once
the apply succeeds, the agent is active for the account that supplied the AWS
credentials.

This is the AWS DevOps Agent service, not the Amazon Q Developer coding agent.

## Before you deploy

You need Terraform 1.3 or newer, AWS credentials for the monitoring account,
and permissions to create IAM roles, attach the two AWS managed policies, and
create DevOps Agent resources. The AWS DevOps Agent service is available only
in `us-east-1`, `us-west-2`, `ap-southeast-2`, `ap-northeast-1`,
`eu-central-1`, and `eu-west-1`. The configuration defaults to `eu-west-1`
(Ireland), the closest supported Region to the previous `eu-west-2` default.

The existing HCP Terraform `cloud` block is retained. Sign in to HCP Terraform
and ensure the configured organization/workspace exists, or remove that block
if you want to use local state.

## HCP Terraform AWS authentication

Remote plans use HCP Terraform's OIDC dynamic credentials. The AWS
`terraform-role` trust policy must allow the exact subject below, in addition
to any other workspace subjects your account needs:

```text
organization:smdevops96_org:project:Default Project:workspace:amazon-devops-terraform:run_phase:*
```

The current account's OIDC provider is `app.terraform.io` with audience
`aws.workload.identity`. The applied trust document is retained in
`tfc-role-trust-policy.json` as an account-specific record. The role currently
has `AdministratorAccess`, which is sufficient for this initial deployment but
should be replaced with a dedicated, least-privilege run role before using the
workspace for wider production infrastructure.

## Deploy

1. Copy the example configuration and give the Agent Space a meaningful name.

   ```powershell
   Copy-Item terraform.tfvars.example terraform.tfvars
   ```

2. Authenticate the environment that will run Terraform to the monitoring AWS
   account. With the retained HCP Terraform cloud block, configure AWS
   credentials (preferably a workload identity) in the
   `smdevops96_org/amazon-devops-terraform` workspace. If you remove the cloud
   block and run locally instead, set an approved `AWS_PROFILE` or use your
   local workload identity. Do not put AWS credentials in `terraform.tfvars`.

3. Initialize and apply.

   ```powershell
   terraform init -upgrade
   terraform validate
   terraform plan
   terraform apply
   ```

4. Confirm the result. The `agent_space_id`, `agent_space_arn`, and
   `monitoring_association_id` outputs are emitted by Terraform. With an AWS
   CLI version that includes the `devops-agent` command, you can also verify it
   directly:

   ```powershell
   aws devops-agent get-agent-space --agent-space-id (terraform output -raw agent_space_id) --region (terraform output -raw aws_region)
   ```

## IAM model

By default Terraform creates two roles, both trusted only by
`aidevops.amazonaws.com` from this account's Agent Space:

- `DevOpsAgentRole-AgentSpace-*` has AWS managed
  `AIDevOpsAgentAccessPolicy` and the narrowly scoped permission needed to
  create the Resource Explorer service-linked role.
- `DevOpsAgentRole-WebappAdmin-*` has AWS managed
  `AIDevOpsOperatorAppAccessPolicy` and enables the IAM operator app.

If your organization supplies these roles centrally, set
`existing_agentspace_role_arn` and/or `existing_operator_role_arn`. The
existing roles must meet the trust and managed-policy requirements described in
`variables.tf`.

## Scope

This baseline intentionally onboards only the account being deployed to. It
does not add cross-account monitoring, third-party telemetry or source-control
integrations, scheduled triggers, or custom-agent skills; each requires an
explicit design and, for integrations, separate credentials.

To remove the Agent Space and its association later, run `terraform destroy`.
This permanently deletes the Agent Space and its associated data.
