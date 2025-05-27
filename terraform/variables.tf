variable "input_bucket_name" {
    type        = string
    description = "Bucket for input files (video, json, ass)"
}

variable "output_bucket_name" {
    type        = string
    description =  "Bucket to put the finished video"
}

variable "ecr_repo_name" {
    type        = string
    description = "Name of the burn-subs container repository - see container folder of github project"
}