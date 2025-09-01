resource "aws_s3_bucket" "lambda_artefacts" {
  bucket = "${local.account_id}-lambda-artefacts"
}

resource "aws_s3_object" "lambda_artefact" {
  bucket       = aws_s3_bucket.lambda_artefacts.id
  key          = "builds/${random_uuid.build_id.result}.zip"
  source       = data.archive_file.codebase.output_path
  content_type = "application/zip"
}
