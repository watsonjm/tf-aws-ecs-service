variable "svc_name" {
  type        = string
  description = "ECS family (unique name) name"
}
variable "tag_prefix" {
  type        = string
  default     = null
  description = "'Name' tag prefix, used for resource naming."
}
variable "common_tags" {
  type        = map(any)
  default     = null
  description = "map of tags"
}
variable "network_mode" {
  type    = string
  default = "awsvpc"
  validation {
    condition     = can(regex("^(none|bridge|awsvpc|host)$", var.network_mode))
    error_message = "Valid values are 'none', 'bridge', 'awsvpc', and 'host'."
  }
}
variable "task_memory" {
  type    = number
  default = 512
}
variable "task_cpu" {
  type    = number
  default = 256
}
variable "container_def" {
  description = "Container definition part of task definition."
}
variable "execution_role_arn" {
  default     = null
  description = "task definition will use default role created by module unless one is passed in"
}
variable "task_role_arn" {
  type        = string
  default     = null
  description = "task definition will use default role created by module unless one is passed in"
}
variable "aws_managed_iam_policies" {
  type        = list(string)
  default     = null
  description = "Only use if you're passing in AWS managed policies for the task execution role."
}
variable "reqd_compatibilities" {
  type    = list(string)
  default = ["FARGATE"]
}
variable "cluster_name" {
  description = "Cluster you want this service to be created in."
}
variable "vpc_id" {
  type = string
}
variable "discovery_svc_name" {
  default     = null
  description = "custom discovery service name"
}
variable "create_discovery_service" {
  type    = bool
  default = false
}
variable "discovery_service_namespace" {
  type    = string
  default = null
}
variable "svc_min_percent" {
  type        = number
  default     = 0
  description = "Minium healthy percent of ECS services"
}
variable "svc_max_percent" {
  type        = number
  default     = 100
  description = "Maximum percent of tasks in RUNNING state"
}
variable "desired_count" {
  type    = number
  default = 0
}
variable "svc_launch_type" {
  type        = string
  default     = "FARGATE"
  description = "The launch type on which to run your service. Valid values are EC2 and FARGATE"
  validation {
    condition     = can(regex("^(FARGATE|EC2)$", var.svc_launch_type))
    error_message = "Valid values are EC2 or FARGATE."
  }
}
variable "platform_version" {
  type        = string
  default     = "LATEST"
  description = "https://docs.aws.amazon.com/AmazonECS/latest/developerguide/platform_versions.html"
}
variable "public_ip" {
  type    = bool
  default = false
}
variable "security_groups" {
  type    = list(string)
  default = null
}
variable "subnet_ids" {
  type = list(string)
}
variable "enable_alb" {
  type    = bool
  default = false
}
variable "forward_alb_http_to_https" {
  type    = bool
  default = true
}
variable "internal_alb" {
  type    = bool
  default = false
}
variable "route53_zone" {
  type        = string
  default     = null
  description = "this is required if forwarding 80 to 443 on the application load balancer."
}
variable "health_check_path" {
  type        = string
  default     = "/"
  description = "health check path for application load balancer"
}
variable "health_check_port" {
  type        = number
  default     = 80
  description = "health check port for application load balancer"
}
variable "health_check_http_response" {
  type        = string
  default     = "200,202"
  description = "matcher for lb target group"
}
variable "enable_autoscaling" {
  type    = bool
  default = true
}
variable "disable_scale_in" {
  type    = bool
  default = false
}
variable "scale_in_cooldown" {
  type    = number
  default = 300
}
variable "scale_out_cooldown" {
  type    = number
  default = 300
}
variable "autoscale_target_value" {
  type    = number
  default = 75
}
variable "autoscale_min_capacity" {
  type        = number
  default     = 1
  description = "The min capacity of the scalable target."
}
variable "autoscale_max_capacity" {
  type        = number
  default     = 2
  description = "The max capacity of the scalable target."
}
variable "namespace" {
  type        = string
  description = "Service discovery namespace"
  default     = ""
}
variable "ssl_cert_arn" {
  type        = string
  default     = null
  description = "Reqd for HTTPS on a load balancer"
}
variable "alb_dns_subdomain" {
  type        = string
  default     = null
  description = "Subdomain used on load balancer Route53 entry"
}
variable "task_definition_revision" {
  type        = string
  default     = "Latest"
  description = "Set to the numbered revision if you don't want to use the latest revision. This must be put in as either the word latest or a valid numbered revision."
}
# variable "enable_cw_logging" {
#   type        = bool
#   default     = true
#   description = "Enable this ECS service to send logs to CloudWatch."
# }
variable "aws_partition" {
  type        = string
  default     = "aws"
  description = "AWS partition is used for govcloud. This is not done in a data lookup because that will cause terraform plan for this module to fail."
}