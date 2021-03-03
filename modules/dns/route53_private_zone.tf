resource "aws_route53_zone" "private_zone" {
  name = "ti.dev.justice.gov.uk"

  vpc {
    vpc_id = var.vpc_id
  }

  tags = var.tags
}

resource "aws_route53_record" "dev-txt" {
  zone_id = aws_route53_zone.private_zone.id
  name    = "test.ti.dev.justice.gov.uk"
  type    = "TXT"
  ttl     = "300"
  records = ["Successful"]
}