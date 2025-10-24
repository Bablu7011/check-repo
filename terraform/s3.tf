###############################################################
# 1️⃣ Bucket to store the application JAR file
###############################################################
resource "aws_s3_bucket" "jar_bucket" {
  bucket = var.jar_bucket_name
  # For demo to allow cleanup without errors
  force_destroy = true

  tags = {
    Name = "${var.stage}-jar-bucket"
  }
}

###############################################################
# 2️⃣ Bucket to store logs from the EC2 instances
###############################################################
resource "aws_s3_bucket" "ec2_logs_bucket" {
  bucket = var.ec2_logs_bucket_name
  # For demo to allow cleanup without errors
  force_destroy = true

  tags = {
    Name = "${var.stage}-ec2-logs-bucket"
  }
}

###############################################################
# 3️⃣ Bucket to store logs from the Application Load Balancer
###############################################################
resource "aws_s3_bucket" "elb_logs_bucket" {
  bucket = var.elb_logs_bucket_name
  # For demo to allow cleanup without errors
  force_destroy = true

  tags = {
    Name = "${var.stage}-elb-logs-bucket"
  }
}

###############################################################
# 4️⃣ Add a 7-day lifecycle rule to the EC2 logs bucket
###############################################################
resource "aws_s3_bucket_lifecycle_configuration" "ec2_logs_bucket_lifecycle" {
  bucket = aws_s3_bucket.ec2_logs_bucket.id

  rule {
    id     = "delete-logs-after-7-days"
    status = "Enabled"

    expiration {
      days = 7
    }
    filter {}
  }
}

###############################################################
# 5️⃣ Add a 7-day lifecycle rule to the ELB logs bucket
###############################################################
resource "aws_s3_bucket_lifecycle_configuration" "elb_logs_bucket_lifecycle" {
  bucket = aws_s3_bucket.elb_logs_bucket.id

  rule {
    id     = "delete-logs-after-7-days"
    status = "Enabled"

    expiration {
      days = 7
    }
    filter {}
  }
}

###############################################################
# 6️⃣ ELB Service Account (needed for ELB log bucket policy)
###############################################################
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "elb_logs_bucket_policy" {
  bucket = aws_s3_bucket.elb_logs_bucket.id
  policy = templatefile("${path.module}/../policy/s3_elb_logging_policy.json", {
    elb_service_account_arn = data.aws_elb_service_account.main.arn
    bucket_arn              = aws_s3_bucket.elb_logs_bucket.arn
  })
}

######################################################################
# 🆕 7️⃣ ADDITION: S3 BUCKET FOR AUTO SCALING DASHBOARD (NEW FEATURE)
######################################################################

resource "random_id" "dashboard_suffix" {
  byte_length = 4
}

# S3 bucket for hosting dashboard frontend
resource "aws_s3_bucket" "autoscaling_dashboard_bucket" {
  bucket        = "${var.stage}-autoscaling-dashboard-${random_id.dashboard_suffix.hex}"
  force_destroy = true

  tags = {
    Name = "${var.stage}-autoscaling-dashboard"
  }
}

# Allow public website hosting
resource "aws_s3_bucket_public_access_block" "dashboard_public_access" {
  bucket                  = aws_s3_bucket.autoscaling_dashboard_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Website configuration (static site)
resource "aws_s3_bucket_website_configuration" "dashboard_website" {
  bucket = aws_s3_bucket.autoscaling_dashboard_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# Public-read bucket policy
resource "aws_s3_bucket_policy" "dashboard_bucket_policy" {
  bucket     = aws_s3_bucket.autoscaling_dashboard_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.dashboard_public_access]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "PublicRead",
        Effect : "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.autoscaling_dashboard_bucket.arn}/*"
      }
    ]
  })
}

###############################################################
# Upload frontend files (with automatic API URL injection)
###############################################################

# Auto inject API Gateway URL into app.js
locals {
  updated_app_js = replace(
    file("${path.module}/../frontend/app.js"),
    "https://REPLACE_WITH_YOUR_API_GATEWAY_URL/scaling-logs",
    "${aws_apigatewayv2_api.asg_api.api_endpoint}/scaling-logs"
  )
}

# Upload index.html
resource "aws_s3_object" "dashboard_index" {
  bucket       = aws_s3_bucket.autoscaling_dashboard_bucket.id
  key          = "index.html"
  source       = "${path.module}/../frontend/index.html"
  content_type = "text/html"
}

# Upload injected app.js
resource "aws_s3_object" "dashboard_app_js" {
  bucket       = aws_s3_bucket.autoscaling_dashboard_bucket.id
  key          = "app.js"
  content      = local.updated_app_js
  content_type = "application/javascript"
}

# Upload style.css
resource "aws_s3_object" "dashboard_style_css" {
  bucket       = aws_s3_bucket.autoscaling_dashboard_bucket.id
  key          = "style.css"
  source       = "${path.module}/../frontend/style.css"
  content_type = "text/css"
}

