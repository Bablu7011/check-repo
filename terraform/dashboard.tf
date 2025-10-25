resource "aws_cloudwatch_dashboard" "scaling_activity_dashboard" {
  dashboard_name = "${var.stage}-scaling-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # --------------------------------------------------------
      # 1. EC2 Instance Scaling Activity Chart
      # --------------------------------------------------------
      {
        "type" : "metric",
        "x" : 0,
        "y" : 0,
        "width" : 24,
        "height" : 8,
        "properties" : {
          "metrics" : [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", aws_autoscaling_group.devops_asg.name, { "label" : "Desired Capacity", "color" : "#1f77b4" }],
            [".", "GroupInServiceInstances", ".", ".", { "label" : "In Service Instances", "color" : "#2ca02c" }]
          ],
          "view" : "timeSeries",
          "stacked" : false,
          "region" : "ap-south-1",
          "title" : "EC2 Scaling Activity (Desired vs In-Service Instances)",
          "period" : 300,
          "yAxis" : {
            "left" : { "label" : "Number of Instances", "min" : 0 }
          }
        }
      },

      # --------------------------------------------------------
      # 2. Scaling Summary (Markdown text)
      # --------------------------------------------------------
      {
        "type" : "text",
        "x" : 0,
        "y" : 8,
        "width" : 24,
        "height" : 3,
        "properties" : {
          "markdown" : "### 🟢 Auto Scaling Summary\n\n- **Tracks EC2 instance scale-up and scale-down events** for the Auto Scaling Group `${aws_autoscaling_group.devops_asg.name}`.\n- View the chart above to see when the ASG increased or decreased capacity.\n- Select **1h, 3h, or 1d** at the top to see scaling history over time.\n\n_Updated automatically via Terraform._"
        }
      }
    ]
  })
}
