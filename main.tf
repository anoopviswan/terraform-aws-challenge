resource "aws_s3_bucket" "with_exif" {
  bucket = "with-exif-july2021"
  acl    = "private"
  force_destroy = true

  tags = {
    Name        = "Exif bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket" "without_exif" {
  bucket = "without-exif-july2021"
  acl    = "private"
  force_destroy = true

  tags = {
    Name        = "Without Exif bucket"
    Environment = "Dev"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name = "lambda_role_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.with_exif.arn}",
          "${aws_s3_bucket.with_exif.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.without_exif.arn}",
          "${aws_s3_bucket.without_exif.arn}/*"
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect = "Allow"
        Resource = "*"
      },
    ]
  })
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir = "./python"
  output_path = "./strip_exif.py.zip"
}

resource "aws_lambda_function" "strip_exif" {
  filename      = "./strip_exif.py.zip"
  function_name = "strip_exif"
  role          = aws_iam_role.lambda_role.arn
  handler       = "strip_exif.lambda_handler"
  runtime = "python3.8"

  environment {
    variables = {
      DEST_BUCKET = "${aws_s3_bucket.without_exif.arn}"
    }
  }
}

resource "aws_lambda_permission" "allow_source_bucket" {
  statement_id = "AllowExecutionFromS3Bucket"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.strip_exif.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.with_exif.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.with_exif.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.strip_exif.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }
}

resource "aws_iam_user" "user1" {
  name = "s3user1"
  path = "/"
}

resource "aws_iam_user_policy" "s3_read_policy" {
  name = "s3_read_policy"
  user = aws_iam_user.user1.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.with_exif.arn}",
        "${aws_s3_bucket.with_exif.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_user" "user2" {
  name = "s3user2"
  path = "/"
}

resource "aws_iam_user_policy" "s3_write_policy" {
  name = "s3_write_policy"
  user = aws_iam_user.user2.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.without_exif.arn}",
        "${aws_s3_bucket.without_exif.arn}/*"
      ]
    }
  ]
}
EOF
}