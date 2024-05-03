from prompt_toolkit import prompt
import json
import os


def setup_folder_structure() -> str:
    project_id: str = prompt("Project ID: ")
    project_path = f"project_configuration/{project_id}"
    try:
        os.mkdir(project_path)
        return project_id
    except FileExistsError:
        print("Project of that name already exists...")
        return setup_folder_structure()

def _write_tfvars(project_type: str, project_id: str, stage: str="") -> None:
    file_path: str = f"project_configuration/{project_id}/variables.tfvars"

    tfvars_config: dict = {
        "empty": "",
        "storage": 'services_list = ["cloudresourcemanager", "storage", "iam"]',
        "composer": f'stage = {stage}\nrequire_vpc = true\nrequire_composer = true',
        "cloud_function": f'stage = {stage}\nrequire_vpc = true',
        "streaming": f'stage = {stage}\nrequire_vpc = true',
        "compute_standard": f'stage = {stage}\nrequire_vpc = true'
    }
    with open(file_path, "w") as tfvars_file:
        tfvars_file.write(tfvars_config[project_type])

def setup_tfvars_config(project_id: str, project_type: str) -> None:
    if "1" in project_type or "compute" in project_type.lower():
        _compute_tfvars(project_id)
    elif "2" in project_type or "storage" in project_type.lower():
        _write_tfvars("storage", project_id)
    elif "3" in project_type or "monitor" in project_type.lower():
        _write_tfvars("empty", project_id)
    elif "4" in project_type or "other" in project_type.lower():
        _write_tfvars("empty", project_id)
    else:
        setup_tfvars_config()

def _compute_tfvars(project_id: str) -> None:
    stage_input = prompt("Project Stage:\n1. dev\n2. test\n3. prod\n")
    if "2" in stage_input or "test" in stage_input.lower():
        stage = '"test"'
    elif "3" in stage_input or "prod" in stage_input.lower():
        stage = '"prod"'
    else:
        stage = '"dev"'

    compute_trigger_input = prompt("Compute Trigger:\n1. Batch Composer\n2. Cloud Function\n3. Streaming\n4. Other\n")
    if "1" in compute_trigger_input or "composer" in compute_trigger_input.lower():
        _write_tfvars("composer", project_id, stage)
    elif "2" in compute_trigger_input or "cloud function" in compute_trigger_input.lower():
        _write_tfvars("cloud_function", project_id, stage)
    elif "3" in compute_trigger_input or "streaming" in compute_trigger_input.lower():
        _write_tfvars("streaming", project_id, stage)
    else:
        _write_tfvars("compute_standard", project_id, stage)

    _setup_dataflow_jobs(project_id)
    
def _setup_dataflow_jobs(project_id: str) -> None:
    dataflow_job_config = {}
    i = 1
    while True:
        user_input_job_name = prompt("Dataflow job name: (press enter to skip)") 
        if len(user_input_job_name) != 0:
            user_input_cidr = prompt("Cidr Range: (press enter to default)")
            cidr = f"10.0.{i+2}.0/26" if len(user_input_cidr) == 0 else user_input_cidr
            i += 1

            dataflow_job_config[user_input_job_name] = {"cidr_range": cidr}
        else:
            break
    _update_json_config(project_id, "dataflow_job_config", dataflow_job_config)

def _update_json_config(project_id: str, key, value) -> None:
    json_config_path: str = f"project_configuration/{project_id}/variables.tfvars.json"
    if os.path.exists(json_config_path):
        with open(json_config_path) as json_config_file:
            config = json.load(json_config_file)
    else:
        config = {}
    config[key] = value
    with open(json_config_path, "w") as json_config_file:
        json.dump(config, json_config_file)

if __name__ == "__main__":
    project_id:str = ""
    n = 0

    print("Welcome to interactive BT Cloud Data Hub project builder.")
    while True:

        if n == 0:
            project_id = setup_folder_structure()
            n += 1
        elif n == 1:
            user_input = prompt("Purpose of the project:\n1. Compute\n2. Storage\n3. Monitoring\n4. Other\n")
            setup_tfvars_config(project_id, project_type=user_input)
            n += 1
        elif n == 2:
            user_input = prompt("Does this project require GCS bucket:\n1. Yes\n2. No\n")
            if "1" in user_input or "yes" in user_input.lower() or "y" in user_input.lower():
                user_input = prompt("Bucket List (',' separator): ")
                user_input = user_input.split(',')
                clean_input = list(map(str.strip, user_input))
                clean_input = list(filter(None, clean_input))
                _update_json_config(project_id, key="bucket_list", value=clean_input)
            else:
                _update_json_config(project_id, key="bucket_list", value="{}")
            n += 1
        else:
            break
        
    print(
        "\nProject builder complete. Next steps are:\n" \
        f"--> Review config files in path: `project_configuration/{project_id}`\n" \
        f"--> Run a terraform plan by using the commands:\n   --> make project='{project_id}' plan\n" \
        "--> Read through additional functionality in the module READMEs"
    )



    
