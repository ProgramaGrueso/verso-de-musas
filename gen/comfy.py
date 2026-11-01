"""Envía trabajos a ComfyUI local (Krea2 + LoRA, MiniMax Music 3) y descarga los resultados."""
import json, sys, time, urllib.request, urllib.parse, pathlib, random

HOST = "http://127.0.0.1:8188"
OUT = pathlib.Path(__file__).parent / "raw"
OUT.mkdir(exist_ok=True)

def post(wf):
    r = urllib.request.urlopen(urllib.request.Request(HOST + "/prompt", json.dumps({"prompt": wf}).encode(), {"Content-Type": "application/json"}))
    return json.load(r)["prompt_id"]

def wait(pid, name):
    while True:
        h = json.load(urllib.request.urlopen(f"{HOST}/history/{pid}"))
        if pid in h:
            st = h[pid].get("status", {})
            if st.get("status_str") == "error":
                print("ERROR", name, json.dumps(st)[:800]); return []
            files = []
            for o in h[pid]["outputs"].values():
                for f in o.get("images", []) + o.get("audio", []):
                    q = urllib.parse.urlencode({"filename": f["filename"], "subfolder": f["subfolder"], "type": f["type"]})
                    ext = pathlib.Path(f["filename"]).suffix
                    dst = OUT / f"{name}{ext}"
                    dst.write_bytes(urllib.request.urlopen(f"{HOST}/view?{q}").read())
                    files.append(dst)
            print("OK", name, [str(f) for f in files], flush=True); return files
        time.sleep(3)

def image_wf(prompt, lora, w, h, seed, strength=0.9):
    return {
        "761": {"class_type": "UNETLoader", "inputs": {"unet_name": "moodyKrea2MixUncensoredV8FREEV8_v70_fp8.safetensors", "weight_dtype": "default"}},
        "755": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
        "757": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "698": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "627": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["755", 0]}},
        "763": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["627", 0]}},
        "854": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["761", 0], "lora_name": lora, "strength_model": strength}},
        "599": {"class_type": "KSamplerAdvanced", "inputs": {"model": ["854", 0], "positive": ["627", 0], "negative": ["763", 0], "latent_image": ["698", 0], "add_noise": "enable", "noise_seed": seed, "steps": 7, "cfg": 1.0, "sampler_name": "er_sde", "scheduler": "simple", "start_at_step": 0, "end_at_step": 7, "return_with_leftover_noise": "enable"}},
        "647": {"class_type": "LatentUpscaleBy", "inputs": {"samples": ["599", 0], "upscale_method": "bislerp", "scale_by": 2.0}},
        "638": {"class_type": "KSamplerAdvanced", "inputs": {"model": ["854", 0], "positive": ["627", 0], "negative": ["627", 0], "latent_image": ["647", 0], "add_noise": "enable", "noise_seed": seed, "steps": 9, "cfg": 1.0, "sampler_name": "dpmpp_2m_sde", "scheduler": "sgm_uniform", "start_at_step": 4, "end_at_step": 999, "return_with_leftover_noise": "disable"}},
        "610": {"class_type": "VAEDecode", "inputs": {"samples": ["638", 0], "vae": ["757", 0]}},
        "732": {"class_type": "SaveImage", "inputs": {"filename_prefix": "VersoDeMusas/img", "images": ["610", 0]}},
    }
