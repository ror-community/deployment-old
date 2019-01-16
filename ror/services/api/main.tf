resource "aws_ecs_service" "api" {
  name = "api"
  cluster = "${data.aws_ecs_cluster.default.id}"
  launch_type = "FARGATE"
  task_definition = "${aws_ecs_task_definition.api.arn}"
  desired_count = 2

  network_configuration {
    security_groups = ["${var.private_security_group_id}"]
    subnets         = ["${var.private_subnet_ids}"]
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.api.arn}"
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.api.id}"
    container_name   = "api"
    container_port   = "80"
  }

  depends_on = [
    "data.aws_lb_listener.default"
  ]
}

resource "aws_lb_target_group" "api" {
  name     = "api"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
  target_type = "ip"

  health_check {
    path = "/heartbeat"
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name = "/ecs/api"
}

resource "aws_ecs_task_definition" "api" {
  family = "api"
  execution_role_arn = "${data.aws_iam_role.ecs_tasks_execution_role.arn}",
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "512"
  memory = "1024"

  container_definitions =  "${data.template_file.api_task.rendered}"
}

resource "aws_lb_listener_rule" "redirect_ror_id" {
  listener_arn = "${data.aws_lb_listener.default.arn}"

  action {
    type = "redirect"

    redirect {
      host        = "${data.aws_s3_bucket.search.website_endpoint}"
      port        = "443"
      protocol    = "HTTPS"
      path        = "/organizations/#{path}"
      status_code = "HTTP_302"
    }
  }

  condition {
    field  = "path-pattern"
    values = ["/0*"]
  }

  condition {
    field  = "host-header"
    values = ["ror.org"]
  }
}

resource "aws_lb_listener_rule" "redirect_ror_site" {
  listener_arn = "${data.aws_lb_listener.default.arn}"

  action {
    type = "redirect"

    redirect {
      host        = "${data.aws_s3_bucket.ror-org-s3.website_endpoint}"
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_302"
    }
  }

  condition {
    field  = "host-header"
    values = ["ror.org"]
  }
}

resource "aws_route53_record" "api" {
    zone_id = "${data.aws_route53_zone.public.zone_id}"
    name = "api.ror.org"
    type = "CNAME"
    ttl = "${var.ttl}"
    records = ["${data.aws_lb.default.dns_name}"]
}

resource "aws_route53_record" "split-api" {
  zone_id = "${data.aws_route53_zone.internal.zone_id}"
  name = "api.ror.org"
  type = "CNAME"
  ttl = "${var.ttl}"
  records = ["${data.aws_lb.default.dns_name}"]
}

resource "aws_route53_record" "apex" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  name = "ror.org"
  type = "A"

  alias {
    name = "${data.aws_lb.default.dns_name}"
    zone_id = "${data.aws_lb.default.zone_id}"
    evaluate_target_health = true
  }
}

# Service Discovery Namepace
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "local"
  vpc = "${var.vpc_id}"
}

resource "aws_service_discovery_service" "api" {
  name = "api"

  health_check_custom_config {
    failure_threshold = 3
  }

  dns_config {
    namespace_id = "${aws_service_discovery_private_dns_namespace.internal.id}"
    
    dns_records {
      ttl = 300
      type = "A"
    }
  }
}
