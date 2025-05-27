output "task_definition_arn" {
  value = aws_ecs_task_definition.render_task.arn
}

output "cluster_arn" {
  value = aws_ecs_cluster.render_cluster.arn
}

output "render_task_role" {
    value = aws_iam_role.render_task_role.arn
}

output "ecs_execution_role" {
    value = aws_iam_role.ecs_execution_role.arn
}