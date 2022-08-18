# Terraform Vault
Terraform project to deploy Vault on K8s using AWS resources as a backend.

* AWS

    1. DynamoDB - used as backend storage for Vault

    2. KMS Key - used for auto unseal if enabled

    3. IAM

        1. DynamoDB Policy following [official docs](https://www.vaultproject.io/docs/configuration/storage/dynamodb#required-aws-permissions)

        2. KMS Policy for auto unseal key

        3. User for Vault application (assigned the two above policies)

        4. Access Key for user to be used as credentials

* Kubernetes

    1. Namespace

    2. AWS Credentials Secret - secret containing aws access and secret key created

    3. Vault Deployment using Helm