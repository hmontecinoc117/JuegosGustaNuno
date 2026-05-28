import argparse
import base64
import json
from pathlib import Path
from datetime import datetime
import requests
import sys


SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[1]
DEFAULT_CONFIG_PATH = Path("config/asset_generation/sd_generation_config.json")
DEFAULT_TEMPLATES_PATH = Path("config/asset_generation/sd_prompt_templates.json")
REQUIRED_JOB_FIELDS = [
    "id",
    "enabled",
    "asset_type",
    "template",
    "output_path",
    "file_name",
    "title",
    "description",
    "positive_detail",
    "negative_extra",
    "tags"
]


def parse_args():
    parser = argparse.ArgumentParser(description="Generate visual assets with Automatic1111 Stable Diffusion API.")
    parser.add_argument("--config", default=str(DEFAULT_CONFIG_PATH), help="Path to sd_generation_config.json.")
    parser.add_argument("--templates", default=str(DEFAULT_TEMPLATES_PATH), help="Path to sd_prompt_templates.json.")
    parser.add_argument("--jobs", required=True, help="Path to jobs JSON file.")
    parser.add_argument("--only", default="", help="Run only one job id.")
    parser.add_argument("--type", default="", help="Run only one asset_type.")
    parser.add_argument("--dry-run", action="store_true", help="Print payloads without calling the API.")
    return parser.parse_args()


def resolve_project_path(path_value):
    path = Path(path_value)
    if path.is_absolute():
        return path
    return PROJECT_ROOT / path


def load_json(path_value, label):
    path = resolve_project_path(path_value)
    if not path.exists():
        raise FileNotFoundError(f"{label} file does not exist: {path}")
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def join_url(base_url, endpoint):
    return base_url.rstrip("/") + "/" + endpoint.lstrip("/")


def check_api(config):
    base_url = config["api_base_url"]
    models_url = join_url(base_url, "/sdapi/v1/sd-models")
    print(f"Checking Stable Diffusion API: {models_url}")
    try:
        response = requests.get(models_url, timeout=10)
        response.raise_for_status()
    except requests.RequestException as error:
        raise RuntimeError(f"Stable Diffusion API is not reachable. Start WebUI with webui-user.bat --api. Detail: {error}")
    print("API OK")


def require_job_fields(job):
    missing = []
    for field in REQUIRED_JOB_FIELDS:
        if field not in job:
            missing.append(field)
    if missing:
        raise ValueError(f"Job {job.get('id', '<missing id>')} missing required fields: {', '.join(missing)}")


def get_value(job, config, job_key, config_key):
    value = job.get(job_key, None)
    if value is not None:
        return value
    return config[config_key]


def combine_prompt(base_text, detail_text):
    parts = []
    if base_text:
        parts.append(str(base_text).strip())
    if detail_text:
        parts.append(str(detail_text).strip())
    return ", ".join(part for part in parts if part)


def build_payload(job, template, config):
    width = get_value(job, config, "width", "default_width")
    height = get_value(job, config, "height", "default_height")
    steps = get_value(job, config, "steps", "default_steps")
    cfg_scale = get_value(job, config, "cfg_scale", "default_cfg_scale")
    sampler_name = get_value(job, config, "sampler_name", "default_sampler_name")
    seed = get_value(job, config, "seed", "default_seed")
    batch_size = get_value(job, config, "batch_size", "default_batch_size")
    n_iter = get_value(job, config, "n_iter", "default_n_iter")
    return {
        "prompt": combine_prompt(template.get("base_positive", ""), job.get("positive_detail", "")),
        "negative_prompt": combine_prompt(template.get("base_negative", ""), job.get("negative_extra", "")),
        "width": width,
        "height": height,
        "steps": steps,
        "cfg_scale": cfg_scale,
        "sampler_name": sampler_name,
        "seed": seed,
        "batch_size": batch_size,
        "n_iter": n_iter,
        "restore_faces": bool(config.get("restore_faces", False)),
        "tiling": bool(config.get("tiling", False)),
        "do_not_save_samples": bool(config.get("do_not_save_samples", False)),
        "do_not_save_grid": bool(config.get("do_not_save_grid", True))
    }


def decode_image(image_value):
    if "," in image_value:
        image_value = image_value.split(",", 1)[1]
    return base64.b64decode(image_value)


def output_image_path(job, index):
    output_dir = resolve_project_path(job["output_path"])
    file_path = output_dir / job["file_name"]
    if index == 0:
        return file_path
    return output_dir / f"{file_path.stem}_{index + 1:02d}{file_path.suffix}"


def metadata_path(config, job, index):
    metadata_dir = resolve_project_path(config["output_metadata_dir"])
    suffix = "" if index == 0 else f"_{index + 1:02d}"
    return metadata_dir / f"{job['id']}{suffix}.json"


def save_metadata(config, job, payload, response_data, image_path, index):
    info = response_data.get("info", "")
    metadata = {
        "generated_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        "job_id": job["id"],
        "title": job["title"],
        "asset_type": job["asset_type"],
        "template": job["template"],
        "output_image": str(image_path.relative_to(PROJECT_ROOT)).replace("\\", "/"),
        "final_positive_prompt": payload["prompt"],
        "final_negative_prompt": payload["negative_prompt"],
        "payload": payload,
        "api_response_info": info
    }
    path = metadata_path(config, job, index)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file:
        json.dump(metadata, file, indent=2, ensure_ascii=False)
    return path


def print_payload(job, payload):
    print(f"DRY RUN job: {job['id']}")
    print(json.dumps(payload, indent=2, ensure_ascii=False))


def request_txt2img(config, payload):
    url = join_url(config["api_base_url"], config["txt2img_endpoint"])
    response = requests.post(url, json=payload, timeout=None)
    response.raise_for_status()
    return response.json()


def generate_job(config, templates, job, dry_run):
    require_job_fields(job)
    template_id = job["template"]
    if template_id not in templates:
        raise ValueError(f"Job {job['id']} references missing template: {template_id}")
    template = templates[template_id]
    payload = build_payload(job, template, config)

    if dry_run:
        print_payload(job, payload)
        return

    print(f"Generating job: {job['id']} -> {job['output_path']}/{job['file_name']}")
    response_data = request_txt2img(config, payload)
    images = response_data.get("images", [])
    if not images:
        raise RuntimeError(f"Job {job['id']} returned no images.")

    for index, image_value in enumerate(images):
        image_path = output_image_path(job, index)
        image_path.parent.mkdir(parents=True, exist_ok=True)
        image_path.write_bytes(decode_image(image_value))
        meta_path = save_metadata(config, job, payload, response_data, image_path, index)
        print(f"Generated image: {image_path}")
        print(f"Generated metadata: {meta_path}")


def select_jobs(jobs_data, only_id, asset_type):
    jobs = jobs_data.get("jobs", [])
    selected = []
    for job in jobs:
        if not job.get("enabled", False):
            continue
        if only_id and job.get("id") != only_id:
            continue
        if asset_type and job.get("asset_type") != asset_type:
            continue
        selected.append(job)
    return jobs, selected


def main():
    args = parse_args()
    try:
        config = load_json(args.config, "config")
        templates = load_json(args.templates, "templates")
        jobs_data = load_json(args.jobs, "jobs")
        all_jobs, selected = select_jobs(jobs_data, args.only, args.type)

        print(f"Total jobs: {len(all_jobs)}")
        print(f"Enabled selected jobs: {len(selected)}")
        if args.only and not selected:
            raise ValueError(f"No enabled job found with id: {args.only}")
        if args.type and not selected:
            raise ValueError(f"No enabled jobs found for asset_type: {args.type}")

        if not args.dry_run:
            check_api(config)

        for job in selected:
            generate_job(config, templates, job, args.dry_run)

        print("Done.")
        return 0
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
