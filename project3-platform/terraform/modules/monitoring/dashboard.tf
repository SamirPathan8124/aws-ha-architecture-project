resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "p3-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "App errors"
          region  = "ap-south-1"
          stat    = "Sum"
          period  = 300
          metrics = [["P3", "AppErrors"]]
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Recent app logs"
          region = "ap-south-1"
          query  = "SOURCE '/aws/containerinsights/p3-eks/application' | fields @timestamp, @message | sort @timestamp desc | limit 20"
        }
      }
    ]
  })
}
