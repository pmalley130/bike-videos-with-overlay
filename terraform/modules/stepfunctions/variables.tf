variable "cluster_name" {
    type = string
}

variable "task_definition" {
    type = string
}

variable "subnet_id" {
    type = string
}

variable ecs_sg_id {
    type = string
}

variable "render_task_role" {
    type = string
}

variable "ecs_execution_role" {
    type = string
}