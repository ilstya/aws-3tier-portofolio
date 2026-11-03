data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "app" {
  name = "${var.name}-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app-profile"
  role = aws_iam_role.app.name
}

resource "aws_launch_template" "app" {
  name_prefix            = "${var.name}-app-"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.app_sg_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  metadata_options {
    http_tokens = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-app" }
  }

  user_data = base64encode(<<EOT
#!/bin/bash
dnf install -y python3-pip
pip3 install flask pymysql boto3
cat > /opt/app.py <<'PYEOF'
${var.app_code}
PYEOF
cat > /etc/systemd/system/app.service <<'SVC'
[Unit]
Description=Flask app
After=network-online.target
[Service]
ExecStart=/usr/bin/python3 /opt/app.py
Restart=always
Environment=DB_HOST=${var.db_host}
Environment=DB_SECRET_ARN=${var.db_secret_arn}
Environment=AWS_DEFAULT_REGION=ap-southeast-1
[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload
systemctl enable --now app
EOT
  )
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "app" {
  name     = "${var.name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.name}-asg"
  min_size                  = var.min_size
  desired_capacity          = var.desired_size
  max_size                  = var.max_size
  vpc_zone_identifier       = var.app_subnet_ids
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }
}
