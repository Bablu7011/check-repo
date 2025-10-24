# --------------------------
# Instance "Blueprint" (Launch Template)
# --------------------------
resource "aws_launch_template" "devops_lt" {
  name = "${var.stage}-launch-template"

  # Settings from our old aws_instance resource
  image_id      = "ami-0f5ee92e2d63afc18" # Ubuntu 22.04 LTS (ap-south-1)
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # This ensures every new instance runs our setup script
  user_data = base64encode(templatefile("${path.module}/../scripts/user_data.sh.tpl", {
    JAR_BUCKET      = aws_s3_bucket.jar_bucket.id
    EC2_LOGS_BUCKET = aws_s3_bucket.ec2_logs_bucket.id
  }))

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.stage}-lt-instance"
  }
}

# --------------------------
# Auto Scaling Group (ASG)
# --------------------------
resource "aws_autoscaling_group" "devops_asg" {
  name = "${var.stage}-asg"

  # Connects to the "blueprint" we just made
  launch_template {
    id      = aws_launch_template.devops_lt.id
    version = "$Latest"
  }

  # Run in both our public subnets for high availability
  vpc_zone_identifier = [
    aws_subnet.devops_subnet.id,
    aws_subnet.devops_subnet_2.id
  ]

  # These are the rules from your assignment!
  min_size         = 2
  max_size         = 4
  desired_capacity = 2 # Start with the minimum

  # This line automatically adds new instances to the load balancer
  target_group_arns = [aws_lb_target_group.main_tg.arn]

  # This tells the ASG to use the LB's health check
  # It gives the instance time to start the python server
  health_check_type         = "ELB"
  health_check_grace_period = 300 # 5 minutes

  lifecycle {
    create_before_destroy = true
  }

  # --- THIS IS THE CORRECTED PART ---
  # This tag will be added to every instance the ASG creates
  tag {
    key                 = "Name"
    value               = "${var.stage}-asg-instance"
    propagate_at_launch = true
  }
}


###############################################################
# CloudWatch Alarms for Auto Scaling
###############################################################

# High Traffic Alarm (Scale Up)
resource "aws_cloudwatch_metric_alarm" "high_request_alarm" {
  alarm_name          = "${var.stage}-high-traffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1          # Number of evaluation periods
  period              = 60         # 1 minute
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "High traffic detected - RequestCountPerTarget > 100 for 1 minute"

  dimensions = {
    TargetGroup = aws_lb_target_group.main_tg.name
    LoadBalancer = aws_lb.main_alb.name
  }

  treat_missing_data = "notBreaching"
}

# Low Traffic Alarm (Scale Down)
resource "aws_cloudwatch_metric_alarm" "low_request_alarm" {
  alarm_name          = "${var.stage}-low-traffic"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1          # Number of evaluation periods
  period              = 300        # 5 minutes
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  statistic           = "Sum"
  threshold           = 90
  alarm_description   = "Low traffic detected - RequestCountPerTarget < 90 for 5 minutes"

  dimensions = {
    TargetGroup = aws_lb_target_group.main_tg.name
    LoadBalancer = aws_lb.main_alb.name
  }

  treat_missing_data = "notBreaching"
}
