data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "crowdstrike_key" {
  description  = "crowdstrike kms key for reencrypting ebs volumes"
  multi_region = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
        Sid = "Enable IAM user perms"
        Effect = "Allow"
        Principal = {
            AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = ["kms*"]
        Resource = "*"
    },
  ]})
}

resource "aws_kms_alias" "crowdstrike_key_alias" {
  name          = "alias/crowdstrike-snapshot"
  target_key_id = aws_kms_key.crowdstrike_key.key_id
}

resource "aws_iam_role" "cross_account_role" {
  name = "crowdstrike-snapshot-scanning"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = lookup(var.principals, var.CrowdstrikeAccountID)
        }
        Condition = {
            test = "StringEquals"
            variable = "sts:ExternalID" 
            values = var.ExternalID
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_policy" "cross_account_policy" {
  name        = "crwd-snapshot-scanning"
  path        = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "SnapshotEC2"
        Action = [
            "ec2:CopySnapshot",
            "ec2:CreateTags",
            "ec2:ModifySnapshotAttribute",
            "ec2:DeleteVolume",
            "ec2:DeleteSnapshot",
            "ec2:DescribeVolume*",
            "ec2:CreateSnapshot",
            "ec2:CreateSnapshots",
            "ec2:DescribeSnapshot*",
            "ec2:DescribeInstance*",
            "ec2:CreateVolume",
            "ec2:DeleteSnapshot*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid = "DecryptEncryptedEBS"
        Action = [
            "kms:CreateGrant",
            "kms:ReEncrypt*",
            "kms:GenerateDataKeyWithoutPlaintext",
            "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid = "LaunchBatchJobs"
        Action = [
            "batch:Describe*",
            "batch:List*",
            "batch:SubmitJob",
            "batch:TagResource",
            "batch:CancelJob"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid = "IntrospectIAMPerms"
        Action = [
            "iam:GetRolePolicy",
            "iam:GetPolicy",
            "iam:GetPolicyVersion",
            "iam:ListRolePolicies",
            "iam:ListAttachedRolePolicies"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "cross_account_policy_attach" {
  name       = "test-attachment"
  roles      = [aws_iam_role.cross_account_role.name]
  policy_arn = aws_iam_policy.cross_account_policy.arn
}

resource "aws_iam_role" "spot_fleet_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "spotfleet.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  managed_policy_arns = [ "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole" ]
}

resource "aws_iam_role" "compute_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  inline_policy {
    name = "sessionManager"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Principal = {
            Service = "ec2.amazonaws.com"
            }
            Action = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
            Resource = "*"
        },
        {
            Effect = "Allow"
            Action = ["s3:GetEncryptionConfiguration"]
            Resource = "*"
        },
        ]
    })
  }
  managed_policy_arns = [ "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role", "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore" ]
}

resource "aws_iam_instance_profile" "compute_profile" {
  role = aws_iam_role.compute_role.name
}

resource "aws_iam_role" "job_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  inline_policy {
    name = "ec2"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Principal = {
            Service = "ec2.amazonaws.com"
            }
            Action = [
              "ec2:CreateTags",
              "ec2:CopySnapshot",
              "ec2:ModifySnapshotAttribute",
              "ec2:DetachVolume",
              "ec2:AttachVolume",
              "ec2:DeleteVolume",
              "ec2:DeleteSnapshot",
              "ec2:Describe*",
              "ec2:CreateSnapshot",
              "ec2:DescribeSnapshots",
              "ec2:CreateVolume"
            ]
            Resource = "*"
        },
        ]
    })
  }
  inline_policy {
    name = "kms"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Action = [
              "kms:CreateGrant",
              "kms:ReEncrypt*",
              "kms:GenerateDataKeyWithoutPlaintext",
              "kms:DescribeKey"
            ]
            Resource = "arn:${data.aws_partition.current.partition}:kms:*:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.crowdstrike_key.key_id}"
        },
        ]
    })
  }
}

resource "aws_iam_role" "cloudformation_service_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudformation.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  inline_policy {
    name = "createVpcsAndBatch"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Sid = "getPublicParams"
            Effect = "Allow"
            Action = [
              "ssm:GetParameter*"
            ]
            Resource = "arn:${data.aws_partition.current.partition}:ssm:*::parameter/aws*"
        },
        {
            Sid = "createDeleteVpcs"
            Effect = "Allow"
            Action = [
                "ec2:AllocateAddress",
                "ec2:AssociateRouteTable",
                "ec2:AttachInternetGateway",
                "ec2:CreateTags",
                "ec2:CreateVpc",
                "ec2:CreateInternetGateway",
                "ec2:CreateNatGateway",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSubnet",
                "ec2:CreateRouteTable",
                "ec2:CreateRoute",
                "ec2:Describe*",
                "ec2:DisassociateRouteTable",
                "ec2:DeleteInternetGateway",
                "ec2:DeleteNatGateway",
                "ec2:DeleteRouteTable",
                "ec2:DeleteRoute",
                "ec2:DeleteSubnet",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteTags",
                "ec2:DeleteVpc",
                "ec2:DetachInternetGateway",
                "ec2:DetachNetworkInterface",
                "ec2:List*",
                "ec2:ModifyVpcAttribute",
                "ec2:ReleaseAddress"
            ]
            Resource = "*"
        },
        {
            Sid = "createDeleteBatch"
            Effect = "Allow"
            Action = [
                "batch:CreateJobQueue",
                "batch:CreateComputeEnvironment",
                "batch:DeleteJobQueue",
                "batch:DeleteComputeEnvironment",
                "batch:DeregisterJobDefinition",
                "batch:Describe*",
                "batch:List*",
                "batch:RegisterJobDefinition",
                "batch:TagResource",
                "batch:UntagResource",
                "batch:UpdateComputeEnvironment",
                "batch:UpdateJobQueue",
                "iam:CreateServiceLinkedRole",
                "iam:PassRole",
                "logs:*"
            ]
            Resource = "*"
        },
        ]
    })
  }
}

resource "aws_iam_role" "registration_lambda_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  inline_policy {
    name = "customResourceRequirements"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Sid = "logs"
            Effect = "Allow"
            Action = ["logs:*"]
            Resource = "*"
        },
        ]
    })
  }
}

resource "aws_lambda_function" "registration_lambda" {
  filename      = "account_registration.zip"
  function_name = "crowdstrike-snapshot-registration-lambda"
  role          = aws_iam_role.registration_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 20
  description   = "calls the crowdstrike API to inform of stack completion"
  architectures = ["x86_64"]
  environment {
    variables = {
      CLIENT_ID = var.CrowdstrikeClientID
      CLIENT_SECRET = var.CrowdstrikeClientSecret
      BASE_URL = var.CrowdstrikeAPIUrl
    }
  }
}

resource "aws_lambda_invocation" "invoke_registration_lambda" {
  count = var.VPC ? 0 : 1
  depends_on = [ aws_lambda_invocation.invoke_custom_resource_lambda ]
  function_name = aws_lambda_function.registration_lambda.function_name

  input = jsonencode({
    Regions = var.Regions
    AccountID = data.aws_caller_identity.current.account_id
    RoleArn = aws_iam_role.cross_account_role.arn
    ExternalID = var.ExternalID
    KmsAlias = aws_kms_alias.crowdstrike_key_alias.name
  })
}

resource "aws_lambda_invocation" "invoke_registration_lambda_vpc" {
  count = var.VPC ? 1 : 0
  depends_on = [ aws_lambda_invocation.invoke_custom_resource_lambda_vpc ]
  function_name = aws_lambda_function.registration_lambda.function_name

  input = jsonencode({
    Regions = var.Regions
    AccountID = data.aws_caller_identity.current.account_id
    RoleArn = aws_iam_role.cross_account_role.arn
    ExternalID = var.ExternalID
    KmsAlias = aws_kms_alias.crowdstrike_key_alias.name
  })
}

resource "aws_iam_role" "custom_resource_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  inline_policy {
    name = "customResourceRequirements"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Sid = "createDeleteSubstacks"
            Effect = "Allow"
            Action = [
                "cloudformation:CreateStack",
                "cloudformation:CreateChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:DeleteStack",
                "cloudformation:Describe*",
                "cloudformation:List*"
            ]
            Resource = "*"
        },
        {
            Sid = "passrole"
            Effect = "Allow"
            Action = [
                "iam:PassRole"
            ]
            Resource = aws_iam_role.cloudformation_service_role.arn
        },
        {
            Sid = "writeLogs"
            Effect = "Allow"
            Action = [
                "logs:*"
            ]
            Resource = "*"
        },
        {
            Sid = "createDeleteKMS"
            Effect = "Allow"
            Action = [
                "kms:CancelKeyDeletion",
                "kms:CreateAlias",
                "kms:CreateKey",
                "kms:DescribeKey",
                "kms:DeleteAlias",
                "kms:EnableKey",
                "kms:ReplicateKey",
                "kms:ScheduleKeyDeletion",
                "kms:TagResource"
            ]
            Resource = "*"
        },
        {
            Sid = "manageState"
            Effect = "Allow"
            Action = [
                "ssm:PutParameter",
                "ssm:GetParameter",
                "ssm:DeleteParameter"
            ]
            Resource = "*"
        },
        ]
    })
  }
}

resource "aws_lambda_function" "custom_resource_lambda" {
  s3_bucket     = "cs-horizon-ioa-lambda-${data.aws_region.current.name}"
  s3_key        = "aws/snapshot/${var.LambdaVersion}/crowdstrike-snapshot-registration.zip"
  package_type  = "Zip"
  function_name = "crowdstrike-snapshot-lambda"
  role          = aws_iam_role.custom_resource_role.arn
  handler       = "main"
  runtime       = "go1.x"
  timeout       = 900
  description   = "creates vpcs, aws batch resources, and kms replica keys across multiple regions for snapshot scanning"
  architectures = ["x86_64"]
}

resource "aws_lambda_invocation" "invoke_custom_resource_lambda_vpc" {
  count = var.VPC ? 1 : 0
  function_name = aws_lambda_function.registration_lambda.function_name

  input = jsonencode({
    Version = var.LambdaVersion
    VPCRegions = var.VPCRegions
    SubnetRegions = var.SubnetRegions
    CrowdstrikeClientID = var.CrowdstrikeClientID
    CrowdstrikeClientSecret = var.CrowdstrikeClientSecret
    CloudformationRole = aws_iam_role.cloudformation_service_role.name
    MultiRegionKeyArn = aws_kms_key.crowdstrike_key.arn
    MultiRegionKeyAlias = aws_kms_alias.crowdstrike_key_alias.name
    BatchInstanceProfile = aws_iam_instance_profile.compute_profile.name
    BatchSpotFleetRole = aws_iam_role.spot_fleet_role.name
    BatchJobRole = aws_iam_role.job_role.name
    ScannerContainer = var.ScannerContainer
    Regions = var.Regions
  })
}

resource "aws_lambda_invocation" "invoke_custom_resource_lambda" {
  count = var.VPC ? 0 : 1
  function_name = aws_lambda_function.registration_lambda.function_name

  input = jsonencode({
    Version = var.LambdaVersion
    CrowdstrikeClientID = var.CrowdstrikeClientID
    CrowdstrikeClientSecret = var.CrowdstrikeClientSecret
    CloudformationRole = aws_iam_role.cloudformation_service_role.name
    MultiRegionKeyArn = aws_kms_key.crowdstrike_key.arn
    MultiRegionKeyAlias = aws_kms_alias.crowdstrike_key_alias.name
    BatchInstanceProfile = aws_iam_instance_profile.compute_profile.name
    BatchSpotFleetRole = aws_iam_role.spot_fleet_role.name
    BatchJobRole = aws_iam_role.job_role.name
    ScannerContainer = var.ScannerContainer
    Regions = var.Regions
  })
}