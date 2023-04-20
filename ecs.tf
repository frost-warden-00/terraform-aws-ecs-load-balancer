###############################################################################
####              Load Balancer                                    ###
###############################################################################
module "ecs-load-balancer" {
  source           = "git::git@github.com:frost-warden-00/terraform-aws-load-balancer.git?ref=v1"
  lb_name          = var.alb_name
  lb_internal      = false
  lb_type          = var.alb_type
  subnets          = data.aws_subnets.this_public.ids
  vpc_name         = var.vpc_name
  target_group_arn = aws_lb_target_group.this.arn
}

resource "aws_lb_target_group" "this" {
  name        = var.alb_tg_name
  port        = var.alb_tg_port     #80
  protocol    = var.alb_tg_protocol #"HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.targetVpc.id

  health_check {
    matcher = "200,302"
  }
}

###############################################################################
####              ECS Task Definition                                    ###
###############################################################################

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/example_task_definitions.html
resource "aws_ecs_task_definition" "task_definition" {
  # Required for FARGATE/FARGATE_SPOT
  family                   = "${var.container_name}-td"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory

  container_definitions = data.template_file.task_definition.rendered
}

resource "aws_cloudwatch_log_group" "container_log_group" {
  name = "/ecs/${var.container_name}-log"

  tags = merge(tomap({ "Name" = "${var.container_name}-log" }))
}

###############################################################################
####              ECS Service                                     ###
###############################################################################
data "aws_service_discovery_dns_namespace" "dns" {
  name = var.namespace_name
  type = "DNS_PRIVATE"
}

resource "aws_service_discovery_service" "this" {
  name = var.namespace_service_name

  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.dns.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}


resource "aws_ecs_service" "service" {
  name    = var.container_name
  cluster = var.cluster_name
  # Comment only on first apply, could create a flag called "first_apply"(boolean), and if it's true then use the resource, if false then use the data source
  # task_definition = var.first_apply = true ? aws_ecs_task_definition.task_definition.id : data.aws_ecs_task_definition.latest.id
  # Issue for why to use this dirty Hack
  # https://github.com/hashicorp/terraform-provider-aws/issues/632
  task_definition = data.aws_ecs_task_definition.latest.id
  # Use only on first apply
  #task_definition = aws_ecs_task_definition.task_definition.id
  desired_count = 1

  service_registries {
    registry_arn = aws_service_discovery_service.this.arn
  }

  network_configuration {
    subnets          = data.aws_subnets.this.ids
    assign_public_ip = var.public_container
    security_groups  = [aws_security_group.container-security-group.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.container_name
    container_port   = "80"
  }

  capacity_provider_strategy {
    capacity_provider = var.default_capacity_provider
    weight            = 1
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "up" {
  name               = "${var.container_name}-scale-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "down" {
  name               = "${var.container_name}-scale_down"
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "${var.container_name}-CPU-Utilization-High"
  namespace           = "AWS/ECS"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_cpu_high_evaluation_periods
  metric_name         = var.alarm_metric_name
  period              = var.alarm_cpu_high_period
  statistic           = var.alarm_cpu_high_statistic
  threshold           = var.alarm_cpu_high_threshold

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = aws_ecs_service.service.name
  }

  alarm_actions = [
  aws_appautoscaling_policy.up.arn]
}

resource "aws_cloudwatch_metric_alarm" "service_cpu_low" {
  alarm_name          = "${var.container_name}-CPU-Utilization-Low"
  namespace           = "AWS/ECS"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_cpu_low_evaluation_periods
  metric_name         = var.alarm_metric_name
  period              = var.alarm_cpu_low_period
  statistic           = var.alarm_cpu_low_statistic
  threshold           = var.alarm_cpu_low_threshold

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = aws_ecs_service.service.name
  }

  alarm_actions = [
  aws_appautoscaling_policy.down.arn]
}