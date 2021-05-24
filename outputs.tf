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