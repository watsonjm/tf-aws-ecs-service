output "discovery_service" {
  value = aws_service_discovery_service.this
}
output "ecs_service" {
  value = aws_ecs_service.this
}
output "ecs_task_definition" {
  value = aws_ecs_task_definition.this
}
output "lb" {
  value = var.enable_alb ? aws_lb.this : null
}
output "task_role_name" {
  value = aws_iam_role.task_role.name
}
output "task_execution_role_name" {
  value = aws_iam_role.task_execution_role.name
}
output "task_definition_in_use" {
  value = local.task_definition
}
