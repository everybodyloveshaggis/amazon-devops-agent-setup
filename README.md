# AWS DevOps Agent Terraform setup

This configuration enables the **AWS DevOps Agent** in one AWS account. It
creates the Agent Space, the IAM role used by the agent, the IAM role used by
the IAM operator app, and the required monitoring-account association. Once
the apply succeeds, the agent is active for the account that supplied the AWS
credentials.

Optionally, it also registers Dynatrace as a capability provider and adds a
Dynatrace environment to the managed Agent Space's telemetry capabilities.

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

## Dynatrace telemetry capability

The optional `devops_agent_dynatrace` configuration implements the registration
and association steps in [AWS's Dynatrace connection guide](https://docs.aws.amazon.com/devopsagent/latest/userguide/connecting-telemetry-sources-connecting-dynatrace.html).
Leave it unset to deploy the existing AWS onboarding without Dynatrace.

For a new registration, store the following JSON in AWS Secrets Manager:

```json
{
  "DYNATRACE_ACCOUNT_URN": "urn:dtaccount:<your-account-uuid>",
  "DYNATRACE_CLIENT_ID": "<oauth-client-id>",
  "DYNATRACE_CLIENT_SECRET": "<oauth-client-secret>"
}
```

Create the OAuth client with the permissions specified in the linked guide.
These credentials are separate from the platform token used for AWS monitoring
inside Dynatrace. The Terraform run role needs `secretsmanager:GetSecretValue`
on this secret and `kms:Decrypt` if the secret uses a customer-managed KMS key,
as well as Cloud Control and DevOps Agent registration/association permissions.
Secret values are redacted from plans but stored in Terraform state; restrict
access to the workspace's state.

Add this to `terraform.tfvars`, or set the `devops_agent_dynatrace` workspace
variable in HCP Terraform with HCL enabled (use only the object as its value):

```hcl
devops_agent_dynatrace = {
  secret_arn     = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:dynatrace-xxxxxx"
  secret_region  = "eu-west-2"
  client_name    = "scottstrialdtaccount"
  environment_id = "abc12345"
  resources      = [] # Optional entity IDs, e.g. SERVICE-0123456789ABCDEF
}
```

The registration and telemetry association use `aws_region`, alongside the
Agent Space already managed by this repository. No separate Agent Space ID is
needed. `secret_region` defaults to `aws_region`; override it if the secret is
stored elsewhere. `environment_id` is the short Dynatrace environment ID, not
its URL. Entity IDs are optional and help topology discovery.

Omit `environment_id` and `resources` to register the provider only. It can then
be selected under **Agent Space > Capabilities > Telemetry > Add** in the AWS
console. Supplying `environment_id` adds the capability automatically.

### Reuse your manually registered provider

Find your registration's `serviceId` using
`aws devops-agent list-services --filter-service-type dynatrace --region <aws-region>`.
Use that ID instead of supplying credentials:

```hcl
devops_agent_dynatrace = {
  existing_service_id = "<registered-dynatrace-service-id>"
  environment_id      = "abc12345"
}
```

Terraform will reuse this registration without reading a secret or managing
the registration's lifecycle. It must exist in this AWS account and region.
If the environment is already added to this Agent Space, import the association
before applying to avoid a duplicate. Find its `associationId` using
`aws devops-agent list-associations --agent-space-id <agent-space-id> --region <aws-region>`,
matching the Dynatrace service and environment. Configure the object above,
then import:

```sh
terraform import 'awscc_devopsagent_association.dynatrace[0]' '<agent-space-id>|<association-id>'
```

For a remote HCP Terraform run with Terraform 1.5+, you can instead add a
temporary import block:

```hcl
import {
  to = awscc_devopsagent_association.dynatrace[0]
  id = "<agent-space-id>|<association-id>"
}
```

Run `terraform init`, review `terraform plan`, and apply. Outputs expose
`devops_agent_dynatrace_service_id` and, when associated,
`devops_agent_dynatrace_association_id`. Confirm the registration under
**Capability Providers** and a valid association under the Agent Space's
**Telemetry** section; a successful apply alone does not verify Dynatrace
accepted the credentials. For automatic incident triggering and updates,
complete the separate Dynatrace SRE Agents app setup described in the connection
guide using the console's webhook details.

## Local checks

```sh
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform test
```

Tests require Terraform 1.7 or later. They use mocked providers and cover
disabled mode, registration, attachment to this repository's Agent Space,
reuse of a manual registration, and invalid credentials/configuration. They
do not provision infrastructure; live connectivity requires an apply.

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

This configuration onboards the account being deployed to and optionally adds
Dynatrace telemetry. It does not add cross-account monitoring, other third-party
integrations, scheduled triggers, or custom-agent skills.

To remove the Agent Space and its association later, run `terraform destroy`.
This permanently deletes the Agent Space and its associated data.
