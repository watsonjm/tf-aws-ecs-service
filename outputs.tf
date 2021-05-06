output "discovery_service" {
  value = aws_service_discovery_service.this
}
#"${module.ecs_middleware.discovery_service[0].name}.${aws_service_discovery_private_dns_namespace.ecs.name}"