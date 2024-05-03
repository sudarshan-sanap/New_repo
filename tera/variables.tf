variable "ingest_project_id" {
  type    = string
  default = "default-ingest-project-id"
}

variable "ingest_dataflow_jobs" {
  type    = list(string)
  default = []
}
variable "proc_dataflow_jobs" {
  type    = list(string)
  default = []
}
variable "project_id" {
  type        = string
  description = "(Required) The project id in which to create the resource under"
}

variable "data_ingest_sa" {
  type        = list(string)
  default     = []
  description = "(Optional) Service Accountwhich will be ingesting data to Raw Bucket"
}
variable "stage" {
  type        = string
  description = "(Optional) The (logical development) stage used to concat against the resource name"
  default     = ""
}

variable "region" {
  type        = string
  description = "(Optional) The region to create the resource in"
  default     = "europe-west2"
}

variable "zone" {
  type        = string
  description = "(Optional) The zone to create the resource in"
  default     = "europe-west2-a"
}

variable "subnet_log_config" {
  description = "(Optional) VPC Subnetwork log configuration. Applied to all subnets in project"

  type = object({
    aggregation_interval = string
    flow_sampling        = number
    metadata             = string
  })

  default = {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
variable "composer_pypi_packages" {
  type        = string
  description = "(Optional)  Map of configuration for Composer"
  default     = ""
}


variable "dataflow_job_config" {
  default     = {}
  description = "(Optional) Map of configuration for dataflow job(s)"
}
variable "entry_groups" {
  default     = {}
  description = "(Optional) Map of configuration for Entry Groups"
}
variable "entries" {
  default     = {}
  description = "(Optional) Map of configuration for Entries"
}
variable entries_raw {
  default     = {}
  description = "(Optional) Map of configuration for Entries"
}

variable "entry_group_name" {
  type        = string
  description = "(Optional) Name Of parent Entry Group"
  default     = ""
}
variable "file_type" {
  type        = string
  description = "(Optional) Name Of File Type"
  default     = "FILESET"
}
variable "dataset_name" {
  default     = {}
  description = "(Optional) Map of configuration for dataset "
}
variable "dataset_name_ro" {
  default     = {}
  description = "(Optional) Map of configuration for Read Only  dataset "
}
variable "bucket_list" {
  type        = list(string)
  description = "(Optional) List of all buckets required on the project"
  default     = []
}
variable "bucket_list2" {
  type        = list(string)
  description = "(Optional) List of all buckets required on the project"
  default     = []
}
variable "data_steward" {
  type        = list(string)
  description = "(Optional) List of users who needs permission to upload data"
  default     = []
}
variable "ingestion_buckets" {
  type        = list(string)
  description = "(Optional) List of all ingestion buckets required on the project"
  default     = []
}

variable "cloud_function_config" {
  description = "(Optional) The fields to define our function config"
  default     = {}
}
variable "alert-policy-config" {
  description = "(Optional) The fields to define alert policies key value pair"
  default     = {}
}
variable "composer_image_version" {
  type        = string
  description = "(Optional) The image to use for the composer instance"
  default     = "composer-1.11.0-airflow-1.10.9"
}

variable "notification_disp_name" {
  type        = string
  description = "(Optional) Map of custom PyPi packages to install"
  default     = ""
}

variable "asg_email_address" {
  type        = string
  description = "(Optional) Map of custom PyPi packages to install"
  default     = ""
}
variable "alert_condition" {
  type        = string
  description = "(Optional) value for alert condition"
  default     = ""
}
variable "alert_policy_Service_name" {
  type        = string
  description = "(Optional) value for alert Alert Plicy Service Name"
  default     = ""
}
variable "require_monitoring" {
  type    = bool
  default = false
}
variable "require_data" {
  type    = bool
  default = false
}
variable "require_proc" {
  type    = bool
  default = false
}
# variable ingest_project_id {
#   type    = string
#   default = "default-ingest-project-id"
# }
variable "expiration" {
  type    = string
  default = ""
}
variable "tables" {
  description = "A list of objects which include table_id, schema, clustering, time_partitioning, expiration_time and labels."
  default     = []
  type = list(object({
    table_id   = string,
    schema     = string,
    clustering = list(string),
    time_partitioning = object({
      expiration_ms            = string,
      field                    = string,
      type                     = string,
      require_partition_filter = bool,
    }),
    expiration_time = string,
    labels          = map(string),
  }))
}

variable "views" {
  type = list(object({
    view_id  = string,
    sql_file = string,
    labels   = map(string),
  }))
  default     = []
  description = "(Optional) A list of objects which include table_id, which is view id, and view query"
}

variable "routines" {
  type = list(object({
    routine_id  = string,
    proc_sql = string,
      }))
  default     = []
  description = "(Optional) A list of objects which include proc query"
}


variable "looging_bucket" {
  type        = list(string)
  description = "(Optional) list of all buckets required on the project"
  default     = []
}
variable "services_list" {
  description = "(Optional) APIs to enable"
  type        = list(string)
  default = [
    "cloudresourcemanager",
    "dataflow",
    "compute",
    "iam",
    "servicenetworking",
    "monitoring",
    "storage",
    "dns",
    "composer",
    "vpcaccess",
    "datacatalog"
  ]
}
variable "dataflow_sa_roles" {
  type = list(string)
  default = [
    "roles/bigquery.admin",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/iam.serviceAccountUser",
    "roles/dataflow.worker",
    "roles/dataflow.admin",
    "roles/storage.objectAdmin",
    "roles/storage.admin",
    "roles/storage.objectCreator",
    "roles/storage.objectViewer",
    "roles/bigquery.user",
    "roles/cloudfunctions.admin",
    "roles/dataflow.serviceAgent",
    "roles/cloudfunctions.serviceAgent"

  ]
  description = "(Optional) The roles to apply to the Dataflow Service account in the data project"
}


variable "composer_sa_roles" {
  type = list(string)
  default = [
    "roles/bigquery.admin",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/iam.serviceAccountUser",
    "roles/dataflow.worker",
    "roles/dataflow.admin",
    "roles/storage.objectAdmin",
    "roles/storage.admin",
    "roles/storage.objectCreator",
    "roles/storage.objectViewer",
    "roles/bigquery.user",
    "roles/dataflow.serviceAgent"
  ]
}

variable "entry_group_def" {
  type = list(object(
    {
      id           = string
      display_name = string
      description  = string
    }
  ))
  default     = null
  description = "(Optional) A list of entry groups"
}


variable "entry_def" {
  type = list(list(object(
    {
      id              = string
      display_name    = string
      description     = string
      schema          = string
      linked_resource = string
      type            = string
      origin_system   = string
      file_patterns   = list(any)
    }
  )))
  default = null
}
variable "tag_template_id" {
  type        = string
  default     = ""
  description = "(Optional) Tag Template Id"
}
variable "tag_template_name" {
  type        = string
  default     = ""
  description = "(Optional) Tag Template Name"
}
variable "dag_names" {
  type        = list(string)
  description = "(Optional) list of all composer dagnames for alert policy"
  default     = []
}
variable "cf_names" {
  type        = list(string)
  description = "(Optional) list of cloud function names fr alert policy"
  default     = []
}
variable "df_names" {
  type        = list(string)
  description = "(Optional) list of dataflow Job names for alert policy"
  default     = []
}
variable "frequency" {
  type        = string
  description = "(Optional) Frequency of Data like Daily,Hourly,Monthly"
  default     = ""
}

variable "domain" {
  type        = string
  description = "(Optional) Domain Name"
  default     = ""
}
variable "as_is_view_group" {
  type        = string
  description = "(Optional) data Viewer group name"
  default     = ""
}
variable "data_steward_name" {
  type        = string
  description = "(Optional) Data Steward Name"
  default     = ""
}

variable "source_system_name" {
  type        = string
  description = "(Optional) Source System Names"
  default     = ""
}
variable "data_ownership" {
  type        = string
  description = "(Optional) Data Owner Name"
  default     = ""
}
variable "cfu" {
  type        = string
  description = "(Optional) CFU Name"
  default     = ""
}
variable "retention" {
  type        = string
  description = "(Optional) Data Retention in Days"
  default     = "730 Days"
}
variable "transfer_protocol" {
  type        = string
  description = "(Optional) Transfer Protocol Like SFTP"
  default     = "SFTP"
}
variable "app_ID" {
  type        = string
  description = "(Optional) Application ID"
  default     = ""
}
variable "design_pattern_ID" {
  type        = string
  description = "(Optional) Design Pattern Id"
  default     = ""
}
variable "PIA_number" {
  type        = string
  description = "(Optional) PIA Number"
  default     = ""
}
variable "security_passport_num" {
  type        = string
  description = "(Optional) Security Passport Number"
  default     = ""
}
variable "ingestion_type" {
  type        = string
  description = "(Optional) Ingestion Type Like Batch or Streaming"
  default     = "Batch"
}
variable source_ip {
  type        = string
  description = "(Optional) Source Ip Address"
  default     = "0.0.0.0"
}
variable port {
  type        = string
  description = "(Optional) Source Ip Address"
  default     = "22"
}

variable consent {
  type        = string
  description = "(Optional) Consent"
  default     = "None"
}
variable third_party_restriction {
  type        = string
  description = "(Optional) Third Party Restriction"
  default     = "None"
}
variable contains_personal_data {
  type        = bool
  description = "(Optional) contains_personal_data"
  default     = false
}
variable purchased_from_3rd_party {
  type        = bool
  description = "(Optional) purchased_from_3rd_party"
  default     = false
}

variable data_classification {
  type        = string
  description = "(Optional) data_classification"
  default     = "Confidential"
}
variable privacy_signoff_by {
  type        = string
  description = "(Optional) privacy_signoff_by"
  default     = ""
}
variable purpose_of_use_pia {
  type        = string
  description = "(Optional) purpose_of_use_pia"
  default     = ""
}
variable restrictions {
  type        = string
  description = "(Optional) restrictions"
  default     = ""
}
variable privacy_policy {
  type        = string
  description = "(Optional) privacy_policy"
  default     = ""
}
variable acf_tag {
  type        = string
  description = "(Optional) acf_tag"
  default     = ""
}
variable cat_stage {
  type        = string
  description = "(Optional) Catalog Stage"
  default     = ""
}
variable label_origin_cfu{
  type        = string
  description = "(Optional) label value for origin cfu"
  default     = "technology"
}
variable label_consumption_cfu{
  type        = string
  description = "(Optional) label value for consumption cfu"
  default     = "technology"
}
variable label_domain {
  type        = string
  description = "(Optional) Label value for domain"
  default     = "network"
}
variable label_domain_cat {
  type        = string
  description = "(Optional) label value for domain category"
  default     = "network_performance"
}