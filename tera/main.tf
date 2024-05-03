terraform {
  required_version = ">= 0.13.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.51.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 3.51.0" 
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 1.3.0"
    }
  }
}

/* Data Project Bucket Creation  */
module "gcs_buckets_data" {
  count                 = var.require_data ? 1 : 0
  source                = "git::https://gitlab.agile.nat.bt.com/APP20470/reference-repository-read/consumer-data-ingestion-modules.git//gcs?ref=v1.4"
  project_id            = var.project_id
  stage                 = var.stage
  bucket_name_list      = var.bucket_list
  ingestion_bucket_list = var.ingestion_buckets
  labels = {
    domain          = "network",
    domain_category = "network_performance",
    origin_system   = "greenplum",
    consumption_cfu = "technology"
  }
  lifecycle_rules = [{
    # Delete any object that is 2 years old.
    condition = {
      age = "730" # 2 years old. Age is based on days
    }
    action = {
      type = "Delete"
    }
    }
    ,
    {
      # Archive any object that is 30 days old
      condition = {
        age = "30" # 30 days old. Age is based on days
      }
      action = {
        type          = "SetStorageClass"
        storage_class = "ARCHIVE"
      }
    }
  ]
}

/* This module grants roles to a Composer SA from an ingestion project into data project */
module "ingest_to_data_composer_sa_data" {
  count             = var.require_data ? 1 : 0
  source            = "git::https://gitlab.agile.nat.bt.com/CDHS/data-ingest/data-ingest-modules.git//composer_sa_access?ref=v2.2.9"
  project_id        = var.project_id        #data project
  ingest_project_id = var.ingest_project_id #proc project
  stage             = var.stage
  composer_sa_roles = var.composer_sa_roles 
}

/*Adding Permisssion in respective data Project for dataflow service Account*/
module "ingest_to_data_dataflow_sa_data" {
  source            = "git::https://gitlab.agile.nat.bt.com/CDHS/data-ingest/data-ingest-modules.git//dataflow_sa_access?ref=v2.2.9"
  for_each          = toset(var.ingest_dataflow_jobs)
  project_id        = var.project_id
  ingest_project_id = var.ingest_project_id
  stage             = var.stage
  job_name          = each.value
  dataflow_sa_roles = var.dataflow_sa_roles
}

/* This module grants readonly access on Big Query(Tables) to DataProduct project from CCN project*/
module "dataproject_service_accounts_permission" { 
  count             = var.require_data ? 1 : 0
  source           = "./modules/bq_sa_access_dataproduct"
  project_id        = var.project_id
  }

locals {
  bq-config-path = "./project_configuration/${var.project_id}/bq.yaml"
  bq-config-path-np = "./project_configuration/${var.project_id}/bq_no_partition.yaml"
  bq-config      = fileexists(local.bq-config-path) ? yamldecode(file(local.bq-config-path)) : { datasets : {} }
  bq-config-np      = fileexists(local.bq-config-path-np) ? yamldecode(file(local.bq-config-path-np)) : { datasets : {} }
  # data-catalog-path   = "./project_configuration/${var.project_id}/datacatalog.yaml"
  # data-catalog-config = fileexists(local.data-catalog-path) ? yamldecode(file(local.data-catalog-path)) : { entries : {}, entryGroups : {} }
}

/*This Module will create big query main tables in Data project, configurations will be created in data project configuration*/
 module "bigquery_rw_dataset_greenplum" {
   for_each = local.bq-config.datasets_rw
   source   = "git::https://gitlab.agile.nat.bt.com/CDHS/data-ingest/data-ingest-modules.git//big_query?ref=v2.2.5"

   dataset_id   = each.value.datasetId
   dataset_name = each.value.datasetName
   description  = each.value.datasetDescription
   project_id   = var.project_id
   stage        = var.stage
   tables = [
     for schema in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/*.json") :
     {
       table_id = trimspace(lower(trimsuffix(basename(schema), ".json"))),
       schema   = "${path.root}/${schema}",
       time_partitioning = {
         type                     = "DAY",
         field                    = "DATETIMESTAMP",
         require_partition_filter = false,
         expiration_ms            = null,
       },
       expiration_time = null
       clustering      = [],
       labels = {
         domain          = "${var.label_domain}",
         domain_category = "${each.value.domaincat}",
         origin_system   = "${var.label_origin_cfu}",
         consumption_cfu = "${var.label_consumption_cfu}" 
       }
     }
   ]
  } 

/*This Module will create big query table without partitioning*/
 module "bigquery_rw_dataset_greenplum_no_partition" {
   for_each = local.bq-config-np.datasets_rw
   source   = "git::https://gitlab.agile.nat.bt.com/CDHS/data-ingest/data-ingest-modules.git//big_query?ref=v2.2.5"

   dataset_id   = each.value.datasetId
   dataset_name = each.value.datasetName
   description  = each.value.datasetDescription
   project_id   = var.project_id
   stage        = var.stage
   tables = [
     for schema in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/*.json") :
     {
       table_id = trimspace(lower(trimsuffix(basename(schema), ".json"))),
       schema   = "${path.root}/${schema}",
       expiration_time = null
       time_partitioning = null
       clustering      = [],
       labels = {
         domain          = "${var.label_domain}",
         domain_category = "${each.value.domaincat}",
         origin_system   = "${var.label_origin_cfu}",
         consumption_cfu = "${var.label_consumption_cfu}" 
       }
     }
   ]
  }

#This module is to create only Dataset and no tables 
module "bigquery_rw_dataset_sma_dataset_only" {
   for_each = local.bq-config.datasets_temp
   source   = "git::https://gitlab.agile.nat.bt.com/CDHS/data-ingest/data-ingest-modules.git//big_query?ref=v2.2.5"

   dataset_id   = each.value.datasetId
   dataset_name = each.value.datasetName
   description  = each.value.datasetDescription
   project_id   = var.project_id
   stage        = var.stage
   dataset_labels = {
         domain          = "${var.label_domain}",
         domain_category = "${each.value.domaincat}",
         origin_system   = "${var.label_origin_cfu}",
         consumption_cfu = "${var.label_consumption_cfu}" 
       }
  }

# /*This Module is for Show and Tell Demo and will create Test dataset and table*/
#  module "bigquery_rw_dataset_demo" {
#    for_each = local.bq-config.datasets_demo
#    source   = "git::https://gitlab.agile.nat.bt.com/CDHS/data-ingest/data-ingest-modules.git//big_query?ref=v2.2.5"

#    dataset_id   = each.value.datasetId
#    dataset_name = each.value.datasetName
#    description  = each.value.datasetDescription
#    project_id   = var.project_id
#    stage        = var.stage
#    tables = [
#      for schema in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/*.json") :
#      {
#        table_id = trimspace(lower(trimsuffix(basename(schema), ".json"))),
#        schema   = "${path.root}/${schema}",
#        time_partitioning = {
#          type                     = "DAY",
#          field                    = "DATETIMESTAMP",
#          require_partition_filter = false,
#          expiration_ms            = null,
#        },
#        expiration_time = null
#        clustering      = [],
#        labels = {
#          domain          = "${var.label_domain}",
#          domain_category = "${each.value.domaincat}",
#          origin_system   = "${var.label_origin_cfu}",
#          consumption_cfu = "${var.label_consumption_cfu}" 
#        }
#      }
#    ]
#   }  

/* Data Project Bucket Creation with different Lifecycle rules*/
# module "gcs_buckets_data_1" {
#   count                 = var.require_data ? 1 : 0
#   source                = "git::https://gitlab.agile.nat.bt.com/APP20470/reference-repository-read/consumer-data-ingestion-modules.git//gcs?ref=v1.4"
#   project_id            = var.project_id
#   stage                 = var.stage
#   bucket_name_list      = var.bucket_list2
#   ingestion_bucket_list = var.ingestion_buckets
#   labels = {
#     domain          = "network",
#     domain_category = "network_performance",
#     origin_system   = "greenplum",
#     consumption_cfu = "technology"
#   }
#   lifecycle_rules = [
#     # {
#     # # Delete any object that is 5 years old
#     # condition = {
#     #   age = "1825" # 5 years old. Age is based on days
#     # }
#     # action = {
#     #   type = "Delete"
#     # }
#     # }
#     # ,
#     {
#       # Archive any object that is 90 days old
#       condition = {
#         age = "90" # 90 days old. Age is based on days
#       }
#       action = {
#         type          = "SetStorageClass"
#         storage_class = "ARCHIVE"
#       }
#     }
#   ]
# }

# locals {
#   bq-config-path = "./project_configuration/${var.project_id}/bq.yaml"
#   bq-config      = fileexists(local.bq-config-path) ? yamldecode(file(local.bq-config-path)) : { datasets : {} }
#   # data-catalog-path   = "./project_configuration/${var.project_id}/datacatalog.yaml"
#   # data-catalog-config = fileexists(local.data-catalog-path) ? yamldecode(file(local.data-catalog-path)) : { entries : {}, entryGroups : {} }
# }

# /* This module grants roles to a Composer SA from an ingestion project into data project*/
# module "ingest_to_data_composer_sa_data" {
#   count             = var.require_data ? 1 : 0
#   source            = "git::https://gitlab.agile.nat.bt.com/CDHS/data-ingest/data-ingest-modules.git//composer_sa_access?ref=v2.2.9"
#   project_id        = var.project_id        #data project
#   ingest_project_id = var.ingest_project_id #proc project
#   stage             = var.stage
#   composer_sa_roles = var.composer_sa_roles
# }

# /*This Module will create Views in Data project, configurations will be created in data project configuration*/
# module "bigquery_ro_dataset" {
#   for_each = local.bq-config.datasets_ro
#   source   = "git::https://gitlab.agile.nat.bt.com/CDHS/data-ingest/data-ingest-modules.git//big_query?ref=v2.2.5"

#   dataset_id   = each.value.datasetId
#   dataset_name = each.value.datasetName
#   description  = each.value.datasetDescription
#   project_id   = var.project_id
#   stage        = var.stage
#   views = [
#     for schema in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/**/*.sql") :
#     {
#       view_id  = trimspace(lower(trimsuffix(basename(schema), ".sql"))),
#       sql_file = "${path.root}/${schema}",
#       labels = {
#         domain          = "common_business_entities",
#         domain_category = "users_and_roles",
#         origin_system   = "dnp",
#         consumption_cfu = "bt_consumer"
#       }
#     }

#   ]
#   depends_on = [module.bigquery_rw_dataset]
# }

# /*This Module will create big query stage tables in Data project for latest, configurations will be created in data project configuration*/
# module "bigquery_stg_dataset" {
#   for_each = local.bq-config.datasets_stg
#   source   = "git::https://gitlab.agile.nat.bt.com/CDHS/data-ingest/data-ingest-modules.git//big_query?ref=v2.2.5"

#   dataset_id   = each.value.datasetId
#   dataset_name = each.value.datasetName
#   description  = each.value.datasetDescription
#   project_id   = var.project_id
#   stage        = var.stage
#   tables = [
#     for schema in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/stage_tables/**/*.json") :
#     {
#       table_id          = trimspace(lower(trimsuffix(basename(schema), ".json"))),
#       schema            = "${path.root}/${schema}",
#       time_partitioning = null,
#       expiration_time   = null
#       clustering        = [],
#       labels = {
#         domain          = "common_business_entities",
#         domain_category = "users_and_roles",
#         origin_system   = "dnp",
#         consumption_cfu = "bt_consumer"
#       },
#     }
#   ]
#   depends_on = [module.bigquery_rw_dataset]
# }

# /*This Module will create big query procs in Data project , configurations will be created in data project configuration*/
# module "bigquery_proc_load" {
#   for_each     = local.bq-config.datasets_stg
#   source       = "./modules/big_query_sp"
#   dataset_id   = each.value.datasetId
#   dataset_name = each.value.datasetName
#   description  = each.value.datasetDescription
#   project_id   = var.project_id
#   stage        = var.stage
#   routines = [
#     for proc in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/proc_load_src/*.sql") :
#     {
#       routine_id = trimspace(lower(trimsuffix(basename(proc), ".sql"))),
#       proc_sql   = "${path.root}/${proc}",

#     }

#   ]
#   depends_on = [module.bigquery_stg_dataset]
# }

# /*This Module will create big query procs in Data project , configurations will be created in data project configuration*/
# module "bigquery_proc_arc_del" {
#   for_each     = local.bq-config.datasets_stg
#   source       = "./modules/big_query_sp1"
#   dataset_id   = each.value.datasetId
#   dataset_name = each.value.datasetName
#   description  = each.value.datasetDescription
#   project_id   = var.project_id
#   stage        = var.stage
#   routines = [
#     for proc in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/proc_arc_del_src/*.sql") :
#     {
#       routine_id = trimspace(lower(trimsuffix(basename(proc), ".sql"))),
#       proc_sql   = "${path.root}/${proc}",

#     }

#   ]
#   depends_on = [module.bigquery_stg_dataset]
# }

# /*This Module will create big query procs in Data project , configurations will be created in data project configuration*/
# module "bigquery_proc_audit" {
#   for_each     = local.bq-config.datasets_stg
#   source       = "./modules/big_query_sp2"
#   dataset_id   = each.value.datasetId
#   dataset_name = each.value.datasetName
#   description  = each.value.datasetDescription
#   project_id   = var.project_id
#   stage        = var.stage
#   routines = [
#     for proc in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/proc_audit_src/*.sql") :
#     {
#       routine_id = trimspace(lower(trimsuffix(basename(proc), ".sql"))),
#       proc_sql   = "${path.root}/${proc}",

#     }

#   ]
#   depends_on = [module.bigquery_stg_dataset]
# }


# /*This Module will create big query audit tables in Data project for latest, configurations will be created in data project configuration*/
# module "bigquery_tab_audit" {
#   for_each = local.bq-config.datasets_rw
#   source   = "./modules/big_query_without_dataset"

#   dataset_id   = each.value.datasetId
#   dataset_name = each.value.datasetName
#   description  = each.value.datasetDescription
#   project_id   = var.project_id
#   stage        = var.stage
#   tables = [
#     for schema in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/audit_tables/**/*.json") :
#     {
#       table_id          = trimspace(lower(trimsuffix(basename(schema), ".json"))),
#       schema            = "${path.root}/${schema}",
#       time_partitioning = null,
#       expiration_time   = null
#       clustering        = [],
#       labels = {
#         domain          = "common_business_entities",
#         domain_category = "users_and_roles",
#         origin_system   = "dnp",
#         consumption_cfu = "bt_consumer"
#       },
#     }
#   ]
#   depends_on = [module.bigquery_rw_dataset]
# }



# /*This Module will create big query history tables in Data project for latest, configurations will be created in data project configuration*/
# module "bigquery_tab_history" {
#   for_each = local.bq-config.datasets_rw
#   source   = "./modules/big_query_without_dataset"

#   dataset_id   = each.value.datasetId
#   dataset_name = each.value.datasetName
#   description  = each.value.datasetDescription
#   project_id   = var.project_id
#   stage        = var.stage
#   tables = [
#     for schema in fileset(path.root, "/project_configuration/${var.project_id}/bigquery-schemas/${each.value.datasetId}/history_tables/**/*.json") :
#     {
#       table_id = trimspace(lower(trimsuffix(basename(schema), ".json"))),
#       schema   = "${path.root}/${schema}",
#       time_partitioning = {
#         type                     = "DAY",
#         field                    = "HIST_INSERT_DT",
#         require_partition_filter = false,
#         expiration_ms            = null,
#       },
#       expiration_time = null
#       clustering      = [],
#       labels = {
#         domain          = "common_business_entities",
#         domain_category = "users_and_roles",
#         origin_system   = "dnp",
#         consumption_cfu = "bt_consumer"
#       },
#     }
#   ]
#   depends_on = [module.bigquery_rw_dataset]
# }


# /*This Module will create Catalog Entry Group ,Configurations are added in data project config*/

# module "data_catalog_entry_group" {
#   for_each   = var.entry_groups
#   source     = "git::https://gitlab.agile.nat.bt.com/CDHS/core-templates.git//modules/data-analytics/data-catalog/entry-group?ref=v1.1.0"
#   project_id = var.project_id
#   region     = var.region
#   entry_group_def = [{
#     id           = each.value.id
#     display_name = each.value.displayName
#     description  = each.value.description
#   }]
# }


# /*This Module will create Catalog Entries ,Configurations are added in data project config*/
# module "data-catalog-entries" {
#   for_each = var.entries
#   source   = "git::https://gitlab.agile.nat.bt.com/CDHS/core-templates.git//modules/data-analytics/data-catalog/entry?ref=v1.1.0"
#   entry_def = [[{
#     id              = each.value.id
#     display_name    = each.value.displayName
#     description     = each.value.displayName
#     schema          = each.value.schema != null ? file("./project_configuration/${var.project_id}/${each.value.schema}") : null
#     linked_resource = null
#     type            = each.value.type
#     origin_system   = each.value.sourceSystem
#     file_patterns   = each.value.filePatterns
#   }]]
#   parent_entry_group_id = "projects/${var.project_id}/locations/europe-west2/entryGroups/${var.entry_group_name}"

#   depends_on = [module.data_catalog_entry_group]
# }



# /*This Module will create Catalog Entries ,Configurations are added in data project config*/
# module "data-catalog-entries_raw" {
#   for_each = var.entries_raw
#   source   = "git::https://gitlab.agile.nat.bt.com/CDHS/core-templates.git//modules/data-analytics/data-catalog/entry?ref=v1.1.0"
#   entry_def = [[{
#     id              = each.value.id
#     display_name    = each.value.displayName
#     description     = each.value.displayName
#     schema          = each.value.schema != null ? file("./project_configuration/${var.project_id}/${each.value.schema}") : null
#     linked_resource = null
#     type            = each.value.type
#     origin_system   = each.value.sourceSystem
#     file_patterns   = each.value.filePatterns
#   }]]
#   parent_entry_group_id = "projects/${var.project_id}/locations/europe-west2/entryGroups/${var.entry_group_name}"

#   depends_on = [module.data_catalog_entry_group]
# }



# /*This Module will create Tag Entries ,Configurations are added in data project config*/
# module "data_catalog_tag_entries" {
#   for_each = var.entries
#   #source     = "git::https://gitlab.agile.nat.bt.com/APP20470/reference-repository-read/consumer-data-ingestion-modules.git//tags?ref=v1.4"
#   source     = "./modules/tags"
#   entry_name = each.value.id
#   template   = ""
#   project_id = var.project_id
#   stage      = var.cat_stage
#   #Below values Needs to be configured in Project Configuration
#   security_passport_num        = var.security_passport_num
#   PIA_number                   = var.PIA_number
#   design_pattern_ID            = var.design_pattern_ID
#   app_ID                       = var.app_ID
#   transfer_protocol            = var.transfer_protocol
#   retention                    = var.retention
#   ingestion_type               = var.ingestion_type
#   source_ip                    = var.source_ip
#   port                         = var.port
#   data_ownership               = var.data_ownership
#   cfu                          = var.cfu
#   frequency                    = var.frequency
#   domain                       = var.domain
#   as_is_view_group             = var.as_is_view_group
#   data_steward_name            = var.data_steward_name
#   source_system_name           = var.source_system_name
#   entry_group_name             = var.entry_group_name
#   consent                      = var.consent
#   third_party_restriction      = var.third_party_restriction
#   contains_personal_data       = var.contains_personal_data
#   purchased_from_3rd_party     = var.purchased_from_3rd_party
#   data_classification          = var.data_classification
#   privacy_signoff_by           = var.privacy_signoff_by
#   purpose_of_use_pia           = var.purpose_of_use_pia
#   restrictions                 = var.restrictions
#   privacy_policy               = var.privacy_policy
#   acf_tag                      = var.acf_tag
#   cloud_core_node_element_name = each.value.cloud_core_node_element_name
#   cloud_core_node_element_type = each.value.cloud_core_node_element_type
#   cloud_core_node_name         = each.value.cloud_core_node_name
#   depends_on                   = [module.data-catalog-entries_raw]
# }
# module "data_catalog_tag_entries_raw" {
#   for_each = var.entries_raw
#   #source     = "git::https://gitlab.agile.nat.bt.com/APP20470/reference-repository-read/consumer-data-ingestion-modules.git//tags?ref=v1.4"
#   source     = "./modules/tags"
#   entry_name = each.value.id
#   template   = ""
#   project_id = var.project_id
#   stage      = var.cat_stage
#   #Below values Needs to be configured in Project Configuration
#   security_passport_num        = var.security_passport_num
#   PIA_number                   = var.PIA_number
#   design_pattern_ID            = var.design_pattern_ID
#   app_ID                       = var.app_ID
#   transfer_protocol            = var.transfer_protocol
#   retention                    = var.retention
#   ingestion_type               = var.ingestion_type
#   source_ip                    = var.source_ip
#   port                         = var.port
#   data_ownership               = var.data_ownership
#   cfu                          = var.cfu
#   frequency                    = var.frequency
#   domain                       = var.domain
#   as_is_view_group             = var.as_is_view_group
#   data_steward_name            = var.data_steward_name
#   source_system_name           = var.source_system_name
#   entry_group_name             = var.entry_group_name
#   consent                      = var.consent
#   third_party_restriction      = var.third_party_restriction
#   contains_personal_data       = var.contains_personal_data
#   purchased_from_3rd_party     = var.purchased_from_3rd_party
#   data_classification          = var.data_classification
#   privacy_signoff_by           = var.privacy_signoff_by
#   purpose_of_use_pia           = var.purpose_of_use_pia
#   restrictions                 = var.restrictions
#   privacy_policy               = var.privacy_policy
#   acf_tag                      = var.acf_tag
#   cloud_core_node_element_name = each.value.cloud_core_node_element_name
#   cloud_core_node_element_type = each.value.cloud_core_node_element_type
#   cloud_core_node_name         = each.value.cloud_core_node_name
#   # depends_on = [ module.data_catalog_tag_template]
#   depends_on = [module.data-catalog-entries_raw]
# }

# /*This Module will create Tag Entries for bq tables and views */
# module "bigquery_table_tags" {
#   for_each = var.entries
#   #source   =  "git::https://gitlab.agile.nat.bt.com/APP20470/reference-repository-read/consumer-data-ingestion-modules.git//bq_tags?ref=v1.4"
#   source                       = "./modules/bq_tags"
#   project_id                   = var.project_id
#   template                     = "projects/cdh-data-catalog-project/locations/europe-west2/tagTemplates/cloud_core_node"
#   bigquery_id                  = "projects/${var.project_id}/datasets/${each.value.datasetName}/tables/${each.value.tableName}"
#   cloud_core_node_element_name = "BigQuery Table"
#   cloud_core_node_element_type = "Cloud Core Node"
#   cloud_core_node_name         = each.value.cloud_core_node_name
#   depends_on                   = [module.data-catalog-entries_raw]
# }

# module "bigquery_view_tags" {
#   for_each = var.entries
#   #source   =  "git::https://gitlab.agile.nat.bt.com/APP20470/reference-repository-read/consumer-data-ingestion-modules.git//bq_tags?ref=v1.4"
#   source = "./modules/bq_tags"
#   project_id = var.project_id
#   template = "projects/cdh-data-catalog-project/locations/europe-west2/tagTemplates/cloud_core_node"
#   bigquery_id = "projects/${var.project_id}/datasets/${each.value.vwDatasetName}/tables/vw_${each.value.tableName}"
#   cloud_core_node_element_name = "${each.value.cloud_core_node_name} Default View"
#   cloud_core_node_element_type = "Cloud Core Node Controlled View"
#   cloud_core_node_name = each.value.cloud_core_node_name
#   depends_on = [
#     module.data-catalog-entries_raw]
# }
