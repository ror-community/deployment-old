provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
  version    = "~> 1.6"
}

data "aws_route53_zone" "public" {
  name = "ror.org"
}

data "aws_route53_zone" "internal" {
  name = "ror.org"
  private_zone = true
}

data "aws_ecs_cluster" "default" {
  cluster_name = "default"
}

data "aws_iam_role" "ecs_tasks_execution_role" {
  name = "ecs-task-execution-role"
}

data "aws_lb" "default" {
  name = "alb"
}

data "aws_lb_listener" "default" {
  load_balancer_arn = "${data.aws_lb.default.arn}"
  port = 443
}

data "template_file" "api_task" {
  template = "${file("api.json")}"

  vars {
    elastic_search     = "${var.elastic_search}"
    access_key         = "${var.access_key}"
    secret_key         = "${var.secret_key}"
    region             = "${var.region}"
    public_key         = "${var.public_key}"
    sentry_dsn         = "${var.sentry_dsn}"
    version            = "${var.ror-api_tags["sha"]}"
  }
}

data "template_file" "api-dev_task" {
  template = "${file("api-dev.json")}"

  vars {
    elastic_search     = "${var.elastic_search}"
    access_key         = "${var.access_key}"
    secret_key         = "${var.secret_key}"
    region             = "${var.region}"
    public_key         = "${var.public_key}"
    sentry_dsn         = "${var.sentry_dsn}"
    version            = "${var.ror-api-dev_tags["sha"]}"
  }
}

data "aws_s3_bucket" "search" {
  bucket = "search.ror.org"
}

data "aws_s3_bucket" "ror-org-s3" {
  bucket = "ror.org"
}
