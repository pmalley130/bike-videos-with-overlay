output "task_definition_arn" {
  value = aws_ecs_task_definition.render_task.arn
}

output "cluster_arn" {
  value = aws_ecs_cluster.render_cluster.arn
}