###############################################################
# CloudWatch Dashboard for Auto Scaling Activity
###############################################################

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_dashboard" "asg_dashboard" {
  dashboard_name = "${var.stage}-asg-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Title / Summary
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 4
        properties = {
          markdown = "🚀 **${var.stage} Auto Scaling Dashboard**\n\n**Region:** ap-south-1\n**Account:** ${data.aws_caller_identity.current.account_id}\n\n**Metrics Displayed:**\n- EC2 Instances (Desired, InService)\n- CPU Utilization\n- ALB Requests per Target\n- Scaling Behavior\n\n_Last Updated: ${timestamp()}_"
        }
      },

      # Desired vs InService Instances
      {
        type   = "metric"
        x      = 0
        y      = 5
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", aws_autoscaling_group.devops_asg.name],
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.devops_asg.name]
          ]
          period = 60
          stat   = "Average"
          region = "ap-south-1"
          title  = "🧩 Auto Scaling - Desired vs InService Instances"
        }
      },



      # CPU Utilization
      {
        type   = "metric"
        x      = 0
        y      = 11
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.devops_asg.name]
          ]
          period = 60
          stat   = "Average"
          region = "ap-south-1"
          title  = "⚙️ EC2 CPU Utilization (per ASG)"
        }
      },

      # Scaling Behavior (Capacity History)
      {
        type   = "metric"
        x      = 12
        y      = 11
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", aws_autoscaling_group.devops_asg.name],
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.devops_asg.name]
          ]
          period = 60
          stat   = "Average"
          region = "ap-south-1"
          title  = "🔔 Scaling Events (Capacity Changes)"
        }
      }
    ]
  })
}

