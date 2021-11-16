#####################
# Locals & Data
#####################
locals {
  execution_role        = var.execution_role_arn == null ? aws_iam_role.this.arn : var.execution_role_arn
  task_role             = var.task_role_arn == null ? aws_iam_role.this.arn : var.task_role_arn
  discovery_svc_name    = var.discovery_svc_name == null ? var.svc_name : var.discovery_svc_name
  ecs_svc_sg            = var.security_groups == null ? [data.aws_security_group.default.id] : var.security_groups
  ecs_min_roles         = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  acm_wildcard_cert_arn = var.enable_alb && var.forward_alb_http_to_https ? var.ssl_cert_arn : null
  latest_revision       = "${aws_ecs_task_definition.this.family}:${max(aws_ecs_task_definition.this.revision, data.aws_ecs_task_definition.latest.revision)}"
  specific_revision     = "${aws_ecs_task_definition.this.family}:${var.task_definition_revision}"
  task_definition       = upper(var.task_definition_revision) == "LATEST" ? local.latest_revision : local.specific_revision
}
data "aws_security_group" "default" {
  vpc_id = var.vpc_id
  name   = "default"
}
data "aws_ecs_cluster" "cluster" {
  cluster_name = var.cluster_name
}
data "aws_iam_role" "awsmanaged" {
  name = "AWSServiceRoleForApplicationAutoScaling_ECSService"
}
data "aws_route53_zone" "zone" {
  count = var.enable_alb ? 1 : 0
  name  = var.route53_zone
}
data "aws_ecs_task_definition" "latest" {
  task_definition = aws_ecs_task_definition.this.family
}
#####################
# Task Definition
#####################
resource "aws_ecs_task_definition" "this" {
  family                   = var.svc_name
  network_mode             = var.network_mode
  requires_compatibilities = var.reqd_compatibilities
  execution_role_arn       = local.execution_role
  task_role_arn            = local.task_role
  memory                   = var.task_memory
  cpu                      = var.task_cpu
  container_definitions    = var.container_def

  tags = merge(var.common_tags, { Name = "${var.svc_name}-task-def" })
}

#####################
# ESC Service
#####################
resource "aws_ecs_service" "this" {
  depends_on = [
    aws_iam_role_policy_attachment.this
  ]
  name                               = var.svc_name
  cluster                            = data.aws_ecs_cluster.cluster.id
  task_definition                    = local.task_definition
  deployment_maximum_percent         = var.svc_max_percent
  deployment_minimum_healthy_percent = var.svc_min_percent
  desired_count                      = var.desired_count
  enable_ecs_managed_tags            = true
  health_check_grace_period_seconds  = 0
  launch_type                        = var.svc_launch_type
  platform_version                   = var.platform_version
  propagate_tags                     = "TASK_DEFINITION"
  scheduling_strategy                = "REPLICA"

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    assign_public_ip = var.public_ip
    security_groups  = local.ecs_svc_sg
    subnets          = var.subnet_ids
  }

  dynamic "service_registries" {
    for_each = var.create_discovery_service ? ["registry"] : []
    content {
      registry_arn = aws_service_discovery_service.this[0].arn
    }
  }

  dynamic "load_balancer" {
    for_each = var.enable_alb ? ["alb"] : []
    content {
      container_name   = var.svc_name
      container_port   = 80
      target_group_arn = aws_lb_target_group.this[0].arn
    }
  }

  # lifecycle {
  #   ignore_changes = [task_definition]
  # }

  tags = merge(var.common_tags, { Name = "${var.svc_name}-service" })
}


#####################
# Discovery Service
#####################
resource "aws_service_discovery_service" "this" {
  count = var.create_discovery_service ? 1 : 0
  name  = local.discovery_svc_name

  dns_config {
    namespace_id   = var.discovery_service_namespace
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 60
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = merge(var.common_tags, { Name = "${var.svc_name}-service-discovery" })
}

#####################
# IAM
#####################
resource "aws_iam_role" "this" {
  name_prefix = "${var.tag_prefix}-ecs-role-"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = merge(var.common_tags, { Name = "${var.tag_prefix}-ecs-role" })
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each   = var.aws_managed_iam_policies == null ? toset(local.ecs_min_roles) : toset(concat(local.ecs_min_roles, var.aws_managed_iam_policies))
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_policy" "ecs_cw" {
  count       = var.enable_cw_logging ? 1 : 0
  name_prefix = "${var.tag_prefix}-ecs-cw-logs"
  path        = "/"
  description = "allows ECS logging to CloudWatch."

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cw_logging" {
  count      = var.enable_cw_logging ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.ecs_cw.0.arn
}

#####################
# AUTOSCALING
#####################
resource "aws_appautoscaling_target" "this" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.autoscale_max_capacity
  min_capacity       = var.autoscale_min_capacity
  resource_id        = "service/${data.aws_ecs_cluster.cluster.cluster_name}/${aws_ecs_service.this.name}"
  role_arn           = data.aws_iam_role.awsmanaged.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "this" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.svc_name}-autoscaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    disable_scale_in   = var.disable_scale_in
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
    target_value       = var.autoscale_target_value

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

#####################
# LOAD BALANCER
#####################
resource "aws_lb" "this" {
  count                      = var.enable_alb ? 1 : 0
  name                       = "${var.svc_name}-ecs-alb"
  subnets                    = var.subnet_ids
  security_groups            = local.ecs_svc_sg
  internal                   = var.internal_alb
  ip_address_type            = "ipv4"
  load_balancer_type         = "application"
  enable_deletion_protection = false

  tags = merge(var.common_tags, { Name = "${var.svc_name}-ecs-alb" })
}

resource "aws_lb_listener" "http_forward" {
  count             = var.enable_alb && var.forward_alb_http_to_https ? 1 : 0
  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      host        = "#{host}"
      path        = "/#{path}"
      port        = "443"
      protocol    = "HTTPS"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "http" {
  count             = var.enable_alb && !var.forward_alb_http_to_https ? 1 : 0
  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.this[0].arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "this_https" {
  count             = var.enable_alb && var.forward_alb_http_to_https ? 1 : 0
  load_balancer_arn = aws_lb.this[0].arn
  certificate_arn   = local.acm_wildcard_cert_arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"

  default_action {
    target_group_arn = aws_lb_target_group.this[0].arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "this" {
  count       = var.enable_alb ? 1 : 0
  depends_on  = [aws_lb.this]
  name        = "${var.tag_prefix}-ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = var.health_check_path
    port                = var.health_check_port
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = var.health_check_http_response
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, { Name = "${var.svc_name}-ecs-tg" })
}

#####################
# DNS               #
#####################
resource "aws_route53_record" "this" {
  count   = var.enable_alb ? 1 : 0
  zone_id = data.aws_route53_zone.zone[0].id
  name    = "${var.alb_dns_subdomain}.${data.aws_route53_zone.zone[0].name}"
  type    = "A"
  alias {
    name                   = "dualstack.${aws_lb.this[0].dns_name}"
    zone_id                = aws_lb.this[0].zone_id
    evaluate_target_health = true
  }
}
