###############################################################
# 1. Create a unique S3 bucket for our dashboard website
###############################################################
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket" "dashboard_bucket" {
  bucket = "${var.stage}-asg-dashboard-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.stage}-dashboard-bucket"
  }
}

###############################################################
# 2. Allow the bucket to have a public policy
###############################################################
resource "aws_s3_bucket_public_access_block" "dashboard_public_access" {
  bucket = aws_s3_bucket.dashboard_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

###############################################################
# 3. Configure the bucket as a static website
###############################################################
resource "aws_s3_bucket_website_configuration" "dashboard_website" {
  bucket = aws_s3_bucket.dashboard_bucket.id

  index_document {
    suffix = "index.html"
  }
}

###############################################################
# 4. Add a public read-only policy for S3 objects
###############################################################
resource "aws_s3_bucket_policy" "dashboard_policy" {
  bucket     = aws_s3_bucket.dashboard_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.dashboard_public_access]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.dashboard_bucket.arn}/*"
      }
    ]
  })
}

###############################################################
# 5. Create Cognito Identity Pool (for guest users)
###############################################################
resource "aws_cognito_identity_pool" "dashboard_pool" {
  identity_pool_name               = "${var.stage}-dashboard-pool"
  allow_unauthenticated_identities = true
}

###############################################################
# 6. Create IAM Role for unauthenticated users
###############################################################
resource "aws_iam_role" "dashboard_cognito_role" {
  name = "${var.stage}-dashboard-cognito-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.dashboard_pool.id
          },
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })
}

###############################################################
# 7. Attach policy from the /policy folder (read-only ASG + CW)
###############################################################
resource "aws_iam_role_policy" "dashboard_cognito_policy" {
  name = "${var.stage}-dashboard-cognito-policy"
  role = aws_iam_role.dashboard_cognito_role.id

  # Reads JSON directly from your policy folder
  policy = file("${path.module}/../policy/dashboard_read_logs_policy.json")
}

###############################################################
# 8. Attach this IAM Role to the Cognito Identity Pool
###############################################################
resource "aws_cognito_identity_pool_roles_attachment" "dashboard_attachment" {
  identity_pool_id = aws_cognito_identity_pool.dashboard_pool.id
  roles = {
    "unauthenticated" = aws_iam_role.dashboard_cognito_role.arn
  }

  depends_on = [
    aws_iam_role_policy.dashboard_cognito_policy
  ]
}

###############################################################
# 9. Upload the HTML file (with placeholder replacement)
###############################################################
resource "aws_s3_object" "dashboard_html" {
  bucket       = aws_s3_bucket.dashboard_bucket.id
  key          = "index.html"
  content_type = "text/html"

  # Replace placeholders with Terraform variables
  content = replace(
    replace(
      replace(
        file("${path.module}/index.html"),
        "__COGNITO_POOL_ID__", aws_cognito_identity_pool.dashboard_pool.id
      ),
      "__AWS_REGION__", var.region
    ),
    "__ASG_NAME__", aws_autoscaling_group.devops_asg.name
  )

  # Re-upload file on changes
    etag = md5("${file("${path.module}/index.html")}-${timestamp()}")


  depends_on = [
    aws_s3_bucket_policy.dashboard_policy
  ]
}


