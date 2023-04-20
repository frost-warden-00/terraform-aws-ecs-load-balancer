#########################################
### VPC variables
#########################################

variable "project" {
  type        = string
  default     = "pipeline"
  description = "Name of the project"
}

variable "prefix" {
  type        = string
  description = "Prefix for resources"
}

variable "cluster_name" {
  type        = string
  description = "Name of the cluster ECS"
}

variable "public_container" {
  type        = bool
  description = "Container will be public?"
}

variable "default_capacity_provider" {
  default     = "FARGATE"
  type        = string
  description = "Default Capacity Provider to use"
}

variable "region" {
  default     = "us-east-1"
  description = "Region where to deploy this infrastructure."
  type        = string
}

variable "container_cpu" {
  type        = number
  description = "CPU units for the container"
  default     = 256
}
variable "container_memory" {
  default     = 512
  type        = number
  description = "Memory for the container"
}

variable "custom_variables" {
  description = "Custom variables to set on the template file"
  type        = map(string)
  default     = {}
}

variable "ecr_repository_url" {
  type        = string
  description = "URL of ECR repository"
}

variable "file_name_task_definition" {
  type        = string
  description = "Name of the file with the task definition"
}

variable "container_name" {
  type        = string
  description = "Name of the container."
}

variable "alb_name" {
  type        = string
  description = "The name of the LB."
}

variable "alb_type" {
  type        = string
  description = "The type of load balancer to create."
  default     = "application"
  validation {
    condition     = var.alb_type == "application" || var.alb_type == "gateway" || var.alb_type == "network"
    error_message = "Load balancer type must be application, gateway or network."
  }
}

variable "alb_tg_protocol" {
  type        = string
  description = "Protocol to use for routing traffic to the targets."
}

variable "alb_tg_name" {
  type        = string
  description = "Name of the target group. If omitted, Terraform will assign a random, unique name."
}

variable "alb_tg_port" {
  type        = string
  description = "Port on which targets receive traffic, unless overridden when registering a specific target."
}

variable "namespace_name" {
  type        = string
  description = "The name of the namespace."
}

variable "namespace_service_name" {
  type        = string
  description = "The name of the service."
}

# Monitoring Variables
variable "alarm_cpu_high_evaluation_periods" {
  default     = 1
  type        = number
  description = "CPU high evaluation period"
}

variable "alarm_metric_name" {
  default     = "CPUUtilization"
  type        = string
  description = "Alarm Metric name"
}

variable "alarm_cpu_high_period" {
  default     = 60
  type        = number
  description = "CPU high period"
}

variable "alarm_cpu_high_statistic" {
  default     = "Maximum"
  type        = string
  description = "CPU high statistic"
}

variable "alarm_cpu_high_threshold" {
  default     = 60
  type        = number
  description = "CPU high threshold"
}

variable "alarm_cpu_low_evaluation_periods" {
  default     = 1
  type        = number
  description = "CPU low evaluation periods"
}

variable "alarm_cpu_low_period" {
  default     = 60
  type        = number
  description = "CPU low period"
}

variable "alarm_cpu_low_statistic" {
  default     = "Average"
  type        = string
  description = "CPU low statistic"
}

variable "alarm_cpu_low_threshold" {
  default     = 30
  type        = number
  description = "Alarm CPU low threshold"
}