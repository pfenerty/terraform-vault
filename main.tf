terraform {
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = var.kube_context
  }
}

resource "aws_dynamodb_table" "table" {
  name           = "${var.name_prefix}vault_data"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "Path"
  range_key      = "Key"

  attribute {
    name = "Path"
    type = "S"
  }

  attribute {
    name = "Key"
    type = "S"
  }

  tags = var.common_tags
}

resource "aws_iam_user_policy" "dynamodb" {
  name = "${var.name_prefix}vault-dynamodb"
  user = aws_iam_user.user.name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "dynamodb:DescribeLimits",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:ListTagsOfResource",
          "dynamodb:DescribeReservedCapacityOfferings",
          "dynamodb:DescribeReservedCapacity",
          "dynamodb:ListTables",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:CreateTable",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:GetRecords",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:Scan",
          "dynamodb:DescribeTable",
        ],
        "Effect" : "Allow",
        "Resource" : [aws_dynamodb_table.table.arn]
      }
    ]
  })
}

resource "aws_iam_user_policy" "kms" {
  count = var.vault_auto_unseal ? 1 : 0
  name  = "${var.name_prefix}vault-kms"
  user  = aws_iam_user.user.name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
        ],
        "Effect" : "Allow",
        "Resource" : [aws_kms_key.key[0].arn]
      }
    ]
  })
}

resource "aws_kms_key" "key" {
  count                   = var.vault_auto_unseal ? 1 : 0
  description             = "Vault unseal key"
  deletion_window_in_days = 10

  tags = var.common_tags
}

resource "aws_iam_user" "user" {
  name = "${var.name_prefix}vault"
  tags = var.common_tags
}

resource "aws_iam_access_key" "access_key" {
  user = aws_iam_user.user.name
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "vault"
  }
}

resource "kubernetes_secret" "secret" {
  metadata {
    name      = "storage-config"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  data = {
    access_key = aws_iam_access_key.access_key.id
    secret_key = aws_iam_access_key.access_key.secret
  }

}

resource "helm_release" "release" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.namespace.metadata[0].name

  values = [
    templatefile("${path.module}/templates/helm.values.tmpl", {
      injector_enable            = "true"
      server_enable              = "true"
      server_replicas            = var.vault_replicas
      ui_enable                  = var.vault_ui_enable
      dynamodb_creds_secret_name = kubernetes_secret.secret.metadata.0.name
      dynamodb_aws_region        = var.aws_region
      dynamodb_table_name        = aws_dynamodb_table.table.name
      auto_unseal                = var.vault_auto_unseal
      unseal_kms_region          = var.vault_auto_unseal ? var.aws_region : ""
      unseal_kms_key_id          = var.vault_auto_unseal ? aws_kms_key.key[0].id : ""
    })
  ]
}
