# tf-aws-ecs-service
Creates all of the resources needed for an ECS service.

if you need custom role policies, attach them outside of the module like this:
```
resource "aws_iam_role_policy_attachment" "ecs_kms" {
  role = module.ecs_middleware.task_role_name
  policy_arn = aws_iam_policy.ecs_kms.arn
}

resource "aws_iam_policy" "ecs_kms" {
  name        = "${var.environment}_ecs_kms-testing"
  path        = "/"
  description = "allows KMS decrypt."

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:CreateAlias",
                "kms:CreateKey",
                "kms:DeleteAlias",
                "kms:Describe*",
                "kms:GenerateRandom",
                "kms:Get*",
                "kms:List*",
                "kms:TagResource",
                "kms:UntagResource",
                "iam:ListGroups",
                "iam:ListRoles",
                "iam:ListUsers"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
```


If you need to attach policies outside of the module, use the "aws_iam_role_policy_attachment" resource and attach to either module.<module name>.task_role_name or module.<module name>.task_execution_role_name