output "critical_notifications_arn" {
  value = aws_sns_topic.this.id
}

output "aws_sns_topic_arn" {
  value = aws_sns_topic.this.arn
}
