# --------------------------
# CloudWatch Dashboard
# --------------------------
resource "aws_cloudwatch_dashboard" "devops_dashboard" {
  dashboard_name = "${var.stage}-Dashboard"

  # This is the JSON body that defines the widgets
  dashboard_body = jsonencode({
    "widgets" : [
      # WIDGET 1: Auto Scaling Group - Instance Count
      {
        "type" : "metric",
        "x" : 0, # Position on the dashboard (X=0, Y=0)
        "y" : 0,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "metrics" : [
            [
              "AWS/AutoScaling",
              "GroupInServiceInstances",
              "AutoScalingGroupName",
              aws_autoscaling_group.devops_asg.name
            ]
          ],
          "period" : 60, # Changed to 1-minute intervals for faster updates
          "stat" : "Average",
          "region" : var.region,
          "title" : "Number of Running Instances (ASG)"
        }
      },
      # WIDGET 2: ALB - Request Count Per Target (NEW)
      {
        "type" : "metric",
        "x" : 0, # Position on the dashboard (X=0, Y=6)
        "y" : 6,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "metrics" : [
            [
              "AWS/ApplicationELB",
              "RequestCountPerTarget",
              "LoadBalancer",
              aws_lb.main_alb.arn_suffix,
              "TargetGroup",
              aws_lb_target_group.main_tg.arn_suffix
            ]
          ],
          "period" : 60, # 1-minute intervals
          "stat" : "Sum",
          "region" : var.region,
          "title" : "Total Requests Per Target (ALB)"
        }
      }
    ]
  })
}