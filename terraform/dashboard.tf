###############################################################
# CloudWatch Dashboard for Auto Scaling, EC2, and ALB
###############################################################

# Using existing caller identity from iam.tf (do not duplicate)
# data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_dashboard" "asg_dashboard" {
  dashboard_name = "${var.stage}-asg-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      #########################################################
      # 1️⃣ Header Text Widget
      #########################################################
      {
        "type" : "text",
        "x" : 0,
        "y" : 0,
        "width" : 24,
        "height" : 2,
        "properties" : {
          "markdown" : "# 🚀 ${var.stage} Auto Scaling Dashboard\n### Live metrics for EC2, ALB, and scaling events."
        }
      },

      #########################################################
      # 2️⃣ EC2 Instances (In Service vs Desired)
      #########################################################
      {
        "type" : "metric",
        "x" : 0,
        "y" : 2,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "metrics" : [
            [ "AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.devops_asg.name, { "stat": "Average", "label": "InService Instances" } ],
            [ ".", "GroupDesiredCapacity", ".", ".", { "stat": "Average", "label": "Desired Capacity" } ]
          ],
          "region" : var.region,
          "title" : "EC2 Instances: Desired vs In Service",
          "view" : "timeSeries",
          "stacked" : false,
          "period" : 60
        }
      },

      #########################################################
      # 3️⃣ Average CPU Utilization
      #########################################################
      {
        "type" : "metric",
        "x" : 12,
        "y" : 2,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "metrics" : [
            [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.devops_asg.name, { "stat": "Average", "label": "CPU Utilization (%)" } ]
          ],
          "region" : var.region,
          "title" : "CPU Utilization (Average)",
          "view" : "timeSeries",
          "stacked" : false,
          "period" : 60
        }
      },

      #########################################################
      # 4️⃣ ALB Request Count Graph
      #########################################################
      {
        "type" : "metric",
        "x" : 0,
        "y" : 8,
        "width" : 24,
        "height" : 6,
        "properties" : {
          "metrics" : [
            [ "AWS/ApplicationELB", "RequestCount", "TargetGroup", aws_lb_target_group.main_tg.name, "LoadBalancer", aws_lb.main_alb.name, { "stat": "Sum", "label": "Total Requests" } ]
          ],
          "region" : var.region,
          "title" : "ALB Request Count (Traffic)",
          "view" : "timeSeries",
          "stacked" : false,
          "period" : 60
        }
      },

      #########################################################
      # 5️⃣ Scaling Activity Log Insights
      #########################################################
      {
        "type" : "log",
        "x" : 0,
        "y" : 14,
        "width" : 24,
        "height" : 6,
        "properties" : {
          "query" : "SOURCE '/aws/autoscaling/${aws_autoscaling_group.devops_asg.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20",
          "region" : var.region,
          "title" : "Recent Auto Scaling Events (Up/Down)"
        }
      },

      #########################################################
      # 6️⃣ CloudWatch Alarms Widget (High & Low Traffic)
      #########################################################
      {
        "type" : "alarm",
        "x" : 0,
        "y" : 20,
        "width" : 24,
        "height" : 6,
        "properties" : {
          "title" : "🚨 Scaling Alarms (High & Low Traffic)",
          "alarms" : [
            "arn:aws:cloudwatch:${var.region}:${data.aws_caller_identity.current.account_id}:alarm:${var.stage}-high-traffic",
            "arn:aws:cloudwatch:${var.region}:${data.aws_caller_identity.current.account_id}:alarm:${var.stage}-low-traffic"
          ]
        }
      },

      #########################################################
      # 7️⃣ Summary Text Widget
      #########################################################
      {
        "type" : "text",
        "x" : 0,
        "y" : 26,
        "width" : 24,
        "height" : 3,
        "properties" : {
          "markdown" : "### ✅ Dashboard Summary\n- **Instance Count:** Tracks desired vs running EC2 instances.\n- **CPU Utilization:** Detects performance bottlenecks.\n- **Traffic Graph:** Visualizes ALB request flow.\n- **Scaling Logs:** Shows last 20 up/down events.\n- **Alarms:** Real-time triggers for scaling.\n\n_Last updated: ${timestamp()}_"
        }
      }
    ]
  })
}
