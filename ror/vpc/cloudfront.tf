resource "aws_cloudfront_distribution" "site" {
  origin {
    domain_name = "${data.aws_s3_bucket.ror-org-s3.website_endpoint}"
    origin_id = "${data.aws_s3_bucket.ror-org-s3.bucket_domain_name}"

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.ror_org.cloudfront_access_identity_path}"
    }
  }
  // origin {
  //   domain_name = "${data.aws_s3_bucket.search.bucket_domain_name}"
  //   origin_id   = "search.ror.org"

  //   // s3_origin_config {
  //   //   origin_access_identity = "${aws_cloudfront_origin_access_identity.search_ror_org.cloudfront_access_identity_path}"
  //   // }
  // }

  tags {
    site        = "ror"
    environment = "production"
  }

  aliases             = ["ror.org", "search.ror.org"]
  default_root_object = "index.html"
  enabled             = "true"

  # You can override this per object, but for our purposes, this is fine for everything
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${data.aws_s3_bucket.search.bucket_domain_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    # This says to redirect http to https
    viewer_protocol_policy = "redirect-to-https"
    compress               = "true"
    min_ttl                = 0

    # default cache time in seconds.  This is 1 day, meaning CloudFront will only
    # look at your S3 bucket for changes once per day.
    default_ttl            = 86400
    max_ttl                = 2592000

    // lambda_function_association {
    //   event_type   = "origin-request"
    //   lambda_arn   = "${aws_lambda_function.index-page.qualified_arn}"
    //   include_body = false
    // }
  }

  logging_config {
    include_cookies = false
    bucket          = "${data.aws_s3_bucket.logs.bucket_domain_name}"

    prefix = "cf/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "${data.aws_acm_certificate.cloudfront.arn}"
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  // depends_on = [
  //   "data.aws_lambda_function.index-page"
  // ]
}

resource "aws_cloudfront_origin_access_identity" "ror_org" {}
resource "aws_cloudfront_origin_access_identity" "search_ror_org" {}

resource "aws_route53_record" "apex" {
  zone_id = "${aws_route53_zone.public.zone_id}"
  name = "ror.org"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.site.domain_name}"
    zone_id = "${aws_cloudfront_distribution.site.hosted_zone_id}" 
    evaluate_target_health = true
  }
}
