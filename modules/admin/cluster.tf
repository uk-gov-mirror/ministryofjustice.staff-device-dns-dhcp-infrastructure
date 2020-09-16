resource "aws_ecs_cluster" "admin_cluster" {
  name = "${var.prefix}-cluster"

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "admin_log_group" {
  name = "${var.prefix}-log-group"

  retention_in_days = 7

  tags = var.tags
}

resource "aws_ecr_repository" "admin_ecr" {
  name = "${var.short_prefix}-admin"

  tags = var.tags
}

resource "aws_ecr_repository_policy" "admin_docker_dhcp_repository_policy" {
  repository = aws_ecr_repository.admin_ecr.name

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "1",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages",
                "ecr:DeleteRepository",
                "ecr:BatchDeleteImage",
                "ecr:SetRepositoryPolicy",
                "ecr:DeleteRepositoryPolicy"
            ]
        }
    ]
}
EOF
}

resource "aws_ecs_task_definition" "admin_task" {
  family                   = "${var.prefix}-task"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.ecs_admin_instance_role.arn
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"

  container_definitions = <<EOF
[
    {
      "portMappings": [
        {
          "hostPort": 3000,
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "name": "admin",
      "environment": [
        {
          "name": "DB_USER",
          "value": "${var.admin_db_username}"
        },{
          "name": "DB_PASS",
          "value": "${var.admin_db_password}"
        },{
          "name": "DB_NAME",
          "value": "${aws_db_instance.admin_db.name}"
        },{
          "name": "DB_HOST",
          "value": "${aws_route53_record.admin_db.name}"
        },{
          "name": "RACK_ENV",
          "value": "production"
        },{
          "name": "SECRET_KEY_BASE",
          "value": "${var.secret_key_base}"
        },{
          "name": "RAILS_LOG_TO_STDOUT",
          "value": "1"
        },{
          "name": "RAILS_SERVE_STATIC_FILES",
          "value": "1"
        },{
          "name": "SENTRY_DSN",
          "value": "${var.sentry_dsn}"
        },{
          "name": "S3_KEA_CONFIG_OBJECT_KEY",
          "value": "config.json"
        },{
          "name": "KEA_CONFIG_BUCKET",
          "value": "${var.kea_config_bucket_name}"
        },
        {
          "name": "COGNITO_CLIENT_ID",
          "value": "${var.cognito_user_pool_client_id}"
        },
        {
          "name": "COGNITO_CLIENT_SECRET",
          "value": "${var.cognito_user_pool_client_secret}"
        },
        {
          "name": "COGNITO_USER_POOL_SITE",
          "value": "https://${var.cognito_user_pool_domain}.auth.${var.region}.amazoncognito.com"
        },
        {
          "name": "COGNITO_USER_POOL_ID",
          "value": "${var.cognito_user_pool_id}"
        },
        {
          "name": "DHCP_CLUSTER_NAME",
          "value": "${var.dhcp_cluster_name}"
        },
        {
          "name": "DHCP_SERVICE_NAME",
          "value": "${var.dhcp_service_name}"
        },{
          "name": "S3_BIND_CONFIG_OBJECT_KEY",
          "value": "named.conf"
        },{
          "name": "BIND_CONFIG_BUCKET",
          "value": "${var.bind_config_bucket_name}"
        }
      ],
      "image": "${aws_ecr_repository.admin_ecr.repository_url}",
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.admin_log_group.name}",
          "awslogs-region": "${var.region}",
          "awslogs-stream-prefix": "${var.prefix}-docker-logs"
        }
      },
      "expanded": true
    }
]
EOF
}

resource "aws_ecs_service" "admin-service" {
  depends_on      = [aws_alb_listener.alb_listener]
  name            = var.prefix
  cluster         = aws_ecs_cluster.admin_cluster.id
  task_definition = aws_ecs_task_definition.admin_task.arn
  desired_count   = 3
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_alb_target_group.admin_tg.arn
    container_name   = "admin"
    container_port   = "3000"
  }

  network_configuration {
    subnets = var.subnet_ids

    security_groups = [
      aws_security_group.admin_ecs_out.id
    ]

    assign_public_ip = true
  }
}

resource "aws_alb_target_group" "admin_tg" {
  depends_on           = [aws_lb.admin_alb]
  name                 = "${var.short_prefix}-tg"
  port                 = "3000"
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 10

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/healthcheck"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
