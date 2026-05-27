from __future__ import annotations

import argparse
import base64
import concurrent.futures
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


PIPELINE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = PIPELINE_DIR.parents[1]
MANIFEST_PATH = PIPELINE_DIR / "asset_manifest.json"
DEFAULT_API_URL = "http://127.0.0.1:7860/sdapi/v1/txt2img"
PREFERRED_TXT2IMG_PATH = "/sdapi/v1/txt2img"
SD_MODELS_PATH = "/sdapi/v1/sd-models"
TEST_OUTPUT_DIR = PIPELINE_DIR / "output_test"
TEST_OUTPUT_PATH = TEST_OUTPUT_DIR / "test_output.png"
DEFAULT_TIMEOUT_SECONDS = 7200
DEFAULT_TEST_STEPS = 6
WAIT_LOG_INTERVAL_SECONDS = 30


def load_manifest() -> dict:
	with MANIFEST_PATH.open("r", encoding="utf-8") as file:
		return json.load(file)


def merge_negative_prompt(manifest: dict, asset: dict) -> str:
	global_negative = manifest.get("global_negative_prompt", "")
	asset_negative = asset.get("negative_prompt", "").strip()
	return global_negative if not asset_negative else f"{global_negative}, {asset_negative}"


def build_prompt(asset: dict) -> str:
	parts = [
		asset["prompt"].strip(),
		"cartoon premium infantil mobile game",
		"soft vivid colors",
		"soft shading",
		"centered composition",
		"no text",
	]
	if asset.get("transparent", False):
		parts.append("transparent background")
	return ", ".join(parts)


def build_payload(manifest: dict, asset: dict) -> dict:
	payload = {
		"prompt": build_prompt(asset),
		"negative_prompt": merge_negative_prompt(manifest, asset),
		"steps": asset.get("steps", 24),
		"cfg_scale": asset.get("cfg_scale", 7),
		"sampler_name": asset.get("sampler", "Euler a"),
		"seed": asset.get("seed", -1),
		"width": asset["width"],
		"height": asset["height"],
		"batch_size": 1,
		"n_iter": 1,
		"save_images": False,
	}
	return remove_empty_fields(payload)


def build_test_payload(steps_test: int = DEFAULT_TEST_STEPS) -> dict:
	payload = {
		"prompt": "cute cartoon dog, transparent background",
		"negative_prompt": "text, watermark, logo, signature, blurry, low quality",
		"steps": steps_test,
		"cfg_scale": 7,
		"sampler_name": "Euler a",
		"width": 512,
		"height": 512,
		"batch_size": 1,
		"n_iter": 1,
		"save_images": False,
	}
	return payload


def remove_empty_fields(payload: dict) -> dict:
	return {
		key: value
		for key, value in payload.items()
		if value is not None and value != "" and value != []
	}


def is_base64_image_field(key: str, value) -> bool:
	key_lower = key.lower()
	image_keys = {"image", "images", "init_images", "mask", "input_image", "source_image"}
	if key_lower in image_keys:
		return True
	if isinstance(value, str) and value.startswith("data:image/"):
		return True
	return False


def sanitize_payload(value, key: str = ""):
	if is_base64_image_field(key, value):
		if isinstance(value, list):
			return [f"<base64 image hidden length {len(str(item))}>" for item in value]
		return f"<base64 image hidden length {len(str(value))}>"
	if isinstance(value, dict):
		return {item_key: sanitize_payload(item, item_key) for item_key, item in value.items()}
	if isinstance(value, list):
		return [sanitize_payload(item, key) for item in value]
	return value


def print_payload(payload: dict) -> None:
	print("Payload sent:")
	print(json.dumps(sanitize_payload(payload), indent=2, ensure_ascii=False))


def print_generation_config(asset: dict, api_url: str, payload: dict) -> None:
	print("Generation config:")
	print(f"  file_name: {asset['file_name']}")
	print(f"  category: {asset['category']}")
	print(f"  endpoint: {api_url}")
	print(f"  size: {payload.get('width')}x{payload.get('height')}")
	print(f"  steps: {payload.get('steps')}")
	print(f"  cfg_scale: {payload.get('cfg_scale')}")
	print(f"  sampler_name: {payload.get('sampler_name')}")
	print(f"  seed: {payload.get('seed', -1)}")
	print(f"  batch_size: {payload.get('batch_size')}")
	print(f"  n_iter: {payload.get('n_iter')}")
	print("Final prompt:")
	print(payload.get("prompt", ""))
	print("Final negative prompt:")
	print(payload.get("negative_prompt", ""))


def decode_image(image_value: str) -> bytes:
	if "," in image_value:
		image_value = image_value.split(",", 1)[1]
	return base64.b64decode(image_value)


def get_base_url(url: str) -> str:
	parsed = urllib.parse.urlparse(url)
	if not parsed.scheme or not parsed.netloc:
		raise ValueError(f"Invalid API URL: {url}")
	return f"{parsed.scheme}://{parsed.netloc}"


def join_url(base_url: str, path: str) -> str:
	return urllib.parse.urljoin(base_url.rstrip("/") + "/", path.lstrip("/"))


def open_url(resource, timeout: int, no_timeout: bool = False):
	if no_timeout:
		return urllib.request.urlopen(resource)
	if timeout <= 0:
		return urllib.request.urlopen(resource, timeout=None)
	return urllib.request.urlopen(resource, timeout=timeout)


def load_openapi(base_url: str, timeout: int, no_timeout: bool = False) -> dict:
	openapi_url = join_url(base_url, "/openapi.json")
	with open_url(openapi_url, timeout, no_timeout) as response:
		return json.loads(response.read().decode("utf-8"))


def load_sd_models(base_url: str, timeout: int, no_timeout: bool = False) -> list:
	models_url = join_url(base_url, SD_MODELS_PATH)
	with open_url(models_url, timeout, no_timeout) as response:
		result = json.loads(response.read().decode("utf-8"))
	if not isinstance(result, list):
		raise RuntimeError("sd-models did not return a list.")
	return result


def find_txt2img_endpoints(openapi_data: dict) -> list[str]:
	paths = openapi_data.get("paths", {})
	return sorted(path for path in paths.keys() if "txt2img" in path.lower())


def has_openapi_field(value, field_name: str) -> bool:
	if isinstance(value, dict):
		for key, item in value.items():
			if key == field_name:
				return True
			if has_openapi_field(item, field_name):
				return True
	if isinstance(value, list):
		return any(has_openapi_field(item, field_name) for item in value)
	return False


def select_txt2img_endpoint(base_url: str, endpoints: list[str]) -> str | None:
	for endpoint in endpoints:
		if endpoint.rstrip("/") == PREFERRED_TXT2IMG_PATH:
			return join_url(base_url, endpoint)
	if endpoints:
		return join_url(base_url, endpoints[0])
	return None


def check_api(api_url: str, timeout: int, no_timeout: bool = False, verbose: bool = True) -> tuple[bool, str | None]:
	base_url = get_base_url(api_url)
	sd_models_reachable = False
	openapi_responds = False
	txt2img_endpoints: list[str] = []
	selected_endpoint: str | None = None
	sd_models_error = ""
	openapi_error = ""

	try:
		load_sd_models(base_url, timeout, no_timeout)
		sd_models_reachable = True
		selected_endpoint = join_url(base_url, PREFERRED_TXT2IMG_PATH)
	except Exception as error:
		sd_models_error = str(error)

	try:
		openapi_data = load_openapi(base_url, timeout, no_timeout)
		openapi_responds = True
		txt2img_endpoints = find_txt2img_endpoints(openapi_data)
		if not selected_endpoint:
			selected_endpoint = select_txt2img_endpoint(base_url, txt2img_endpoints)
	except Exception as error:
		openapi_error = str(error)

	if verbose:
		print(f"Base URL: {base_url}")
		print(f"sd-models reachable: {sd_models_reachable}")
		print(f"openapi.json responds: {openapi_responds}")
		print("txt2img endpoints found:")
		if txt2img_endpoints:
			for endpoint in txt2img_endpoints:
				print(f"- {endpoint}")
		else:
			print("- none")
		selected_display = PREFERRED_TXT2IMG_PATH if sd_models_reachable else selected_endpoint
		print(f"Selected endpoint: {selected_display if selected_display else 'none'}")
		if sd_models_error:
			print(f"sd-models error: {sd_models_error}")
		if openapi_error:
			print(f"openapi.json error: {openapi_error}")

	return (sd_models_reachable or openapi_responds) and selected_endpoint is not None, selected_endpoint


def read_txt2img_response(request: urllib.request.Request, timeout: int, no_timeout: bool) -> dict:
	with open_url(request, timeout, no_timeout) as response:
		return json.loads(response.read().decode("utf-8"))


def wait_for_txt2img_response(request: urllib.request.Request, timeout: int, no_timeout: bool) -> dict:
	with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
		future = executor.submit(read_txt2img_response, request, timeout, no_timeout)
		while True:
			try:
				return future.result(timeout=WAIT_LOG_INTERVAL_SECONDS)
			except concurrent.futures.TimeoutError:
				print("Waiting for Automatic1111 generation...", flush=True)


def request_image(api_url: str, payload: dict, timeout: int, no_timeout: bool = False) -> bytes:
	data = json.dumps(payload).encode("utf-8")
	request = urllib.request.Request(
		api_url,
		data=data,
		headers={"Content-Type": "application/json"},
		method="POST",
	)
	try:
		result = wait_for_txt2img_response(request, timeout, no_timeout)
	except urllib.error.HTTPError as error:
		body = error.read().decode("utf-8", errors="replace")
		print(f"HTTP ERROR {error.code}: {error.reason}")
		print("Response body:")
		print(body)
		print_payload(payload)
		raise

	images = result.get("images", [])
	if not images:
		raise RuntimeError("Automatic1111 returned no images.")
	return decode_image(images[0])


def selected_assets(manifest: dict, category: str | None, all_assets: bool, file_name: str | None) -> list[dict]:
	assets = manifest.get("assets", [])
	if all_assets:
		selected = assets
	elif category:
		selected = [asset for asset in assets if asset.get("category") == category]
	else:
		selected = []

	if file_name:
		selected = [asset for asset in selected if asset.get("file_name") == file_name]

	return selected


def generate_asset(
	api_url: str,
	manifest: dict,
	asset: dict,
	dry_run: bool,
	overwrite: bool,
	timeout: int,
	no_timeout: bool,
) -> bool:
	output_path = PROJECT_ROOT / asset["output_folder"] / asset["file_name"]
	payload = build_payload(manifest, asset)

	if output_path.exists() and not overwrite:
		print(f"SKIP exists: {output_path}")
		return True

	if dry_run:
		print(f"DRY RUN: {asset['category']} -> {output_path}")
		print_payload(payload)
		return True

	output_path.parent.mkdir(parents=True, exist_ok=True)
	print(f"GENERATE: {asset['category']} -> {output_path}")
	print_generation_config(asset, api_url, payload)
	image_bytes = request_image(api_url, payload, timeout, no_timeout)
	output_path.write_bytes(image_bytes)
	return True


def run_test_txt2img(api_url: str, timeout: int, no_timeout: bool, steps_test: int) -> bool:
	api_ok, selected_endpoint = check_api(api_url, timeout, no_timeout, verbose=False)
	if not api_ok or selected_endpoint is None:
		print("ERROR: Automatic1111 API check failed.")
		check_api(api_url, timeout, no_timeout, verbose=True)
		return False

	payload = build_test_payload(steps_test)
	print(f"TEST txt2img endpoint: {selected_endpoint}")
	print_payload(payload)
	image_bytes = request_image(selected_endpoint, payload, timeout, no_timeout)
	TEST_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	TEST_OUTPUT_PATH.write_bytes(image_bytes)
	print(f"Saved test image: {TEST_OUTPUT_PATH}")
	return True


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Generate Godot PNG assets with Automatic1111.")
	group = parser.add_mutually_exclusive_group(required=True)
	group.add_argument("--category", help="Generate one manifest category.")
	group.add_argument("--all", action="store_true", help="Generate all assets.")
	group.add_argument("--check-api", action="store_true", help="Check Automatic1111 OpenAPI and txt2img endpoint.")
	group.add_argument("--test-txt2img", action="store_true", help="Send a minimal txt2img request and save test_output.png.")
	parser.add_argument("--dry-run", action="store_true", help="Print actions without calling the API.")
	parser.add_argument("--overwrite", action="store_true", help="Overwrite existing PNG files.")
	parser.add_argument("--api-url", default=None, help="Automatic1111 base URL or txt2img endpoint.")
	parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS, help="HTTP request timeout in seconds. Use 0 to wait without timeout.")
	parser.add_argument("--no-timeout", action="store_true", help="Wait for Automatic1111 without a request timeout.")
	parser.add_argument("--steps-test", type=int, default=DEFAULT_TEST_STEPS, help="Steps for --test-txt2img.")
	parser.add_argument("--file", default=None, help="Generate only one file name from the selected category or all assets.")
	return parser.parse_args()


def main() -> int:
	args = parse_args()
	manifest = load_manifest()
	api_url = args.api_url or manifest.get("api_url", DEFAULT_API_URL)
	timeout = int(args.timeout)
	no_timeout = bool(args.no_timeout or timeout <= 0)
	steps_test = max(1, int(args.steps_test))

	if no_timeout:
		print("Request timeout: infinite")
	else:
		print(f"Request timeout: {timeout} seconds")

	if args.check_api:
		ok, _selected_endpoint = check_api(api_url, timeout, no_timeout, verbose=True)
		return 0 if ok else 2

	if args.test_txt2img:
		try:
			return 0 if run_test_txt2img(api_url, timeout, no_timeout, steps_test) else 2
		except urllib.error.HTTPError as error:
			print(f"ERROR: Automatic1111 returned HTTP {error.code} during txt2img test.")
			return 2
		except urllib.error.URLError as error:
			print(f"ERROR: Automatic1111 API is not reachable from {api_url}")
			print(f"DETAIL: {error}")
			return 2
		except Exception as error:
			print(f"ERROR: txt2img test failed: {error}")
			return 3

	assets = selected_assets(manifest, args.category, args.all, args.file)

	if not assets:
		print("No assets selected. Check category name or --file value.")
		return 1

	if not args.dry_run:
		api_ok, selected_endpoint = check_api(api_url, timeout, no_timeout, verbose=False)
		if not api_ok or selected_endpoint is None:
			print("ERROR: Automatic1111 API check failed.")
			check_api(api_url, timeout, no_timeout, verbose=True)
			return 2
		api_url = selected_endpoint

	success_count = 0
	for asset in assets:
		try:
			if generate_asset(api_url, manifest, asset, args.dry_run, args.overwrite, timeout, no_timeout):
				success_count += 1
		except urllib.error.HTTPError as error:
			print(f"ERROR: Automatic1111 returned HTTP {error.code} while generating {asset.get('file_name')}.")
			return 2
		except urllib.error.URLError as error:
			print(f"ERROR: Automatic1111 API is not reachable at {api_url}")
			print(f"DETAIL: {error}")
			return 2
		except Exception as error:
			print(f"ERROR generating {asset.get('file_name')}: {error}")
			return 3

	print(f"Done. Processed {success_count} asset(s).")
	return 0


if __name__ == "__main__":
	sys.exit(main())
