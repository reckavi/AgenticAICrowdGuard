# CrowdGuard Headcount — run this version

This is an upgraded copy of your supplied CrowdGuard project. Your original archive is untouched.

## Run on your Windows laptop

1. Extract the ZIP completely. Open the **CrowdGuard_Headcount** folder.
2. Double-click **START_CROWDGUARD.bat**.
3. The first run creates `venv`, installs packages and downloads/verifies the pretrained head model (approximately 12.3 MB). Keep internet connected during setup. Python 3.12 is recommended.
4. Open **http://127.0.0.1:8000**. Evaluation: **http://127.0.0.1:8000/evaluation**.
5. Keep the terminal open. Both frontend and backend run from this one server. No separate frontend terminal is required.

If Python is missing, install Python 3.12 and enable “Add Python to PATH”, then run the BAT again. If port 8000 is occupied, stop the old CrowdGuard terminal with Ctrl+C first.

PowerShell alternative, from this folder:

```powershell
py -3.12 -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.txt
.\venv\Scripts\python.exe scripts\download_model.py
Copy-Item .env.example .env
.\venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Only copy `.env.example` on the first run; preserve your edited `.env` afterwards. Environment variables set in PowerShell take precedence over `.env`.

## What changed

- HOG full-body detection has been replaced by a **pretrained YOLOv8 head-only detector**. OpenCV runs the ONNX network on CPU. Overlapping image tiles help preserve small-head detail; one global non-maximum-suppression step removes overlapping duplicate detections.
- Count = accepted visible-head bounding boxes in the current frame. This is **not unique-person tracking** and does not count people completely hidden from the camera.
- Head boxes, frame count, model/source and processing time appear in the existing control-room UI.
- Uploaded videos are sampled at video timestamps. Each sampled frame and annotation has its own filename; old evaluation evidence is never overwritten by a later frame.
- While an officer decision is pending, live analysis continues. The review dialog still shows the original frozen evidence/recommendation. Its workflow ID prevents approving a stale dialog for a different action.
- Graph architecture remains **Analysis Agent → officer gate → Dispatch Agent → Monitoring Agent**. Perception, risk and flow-control remain one Analysis Agent. The human gate remains FastAPI state, not a graph node.
- Monitoring registers a wait for a new frame. It no longer reruns the same image and treats it as proof that an intervention worked.
- Approved messages enter a persistent SQLite ntfy outbox. Network/server failures retry with backoff. Duplicate graph execution uses the same workflow notification record.
- Evaluation now uses verified head evidence, rejects contradictory counts, separates model/settings profiles, excludes simulations from detection metrics, preserves unsaved form drafts and shows permanent evidence history on the right.
- Added exact-count accuracy, explicitly different from the risk classification accuracy previously removed. Risk F1 and risk classification cards remain removed.

## Analyse the real video

Choose **Connect data source → Video**, select the zone, select your MP4, then **Start analysis**. The feed displays its status and sampled-frame count. For an image use Image. For a webcam use Camera / RTSP and source `0`.

A video upload is processed in the background; allow the first reading to finish. Refreshing the dashboard does not restart the video. The dashboard updates every four seconds. Processing speed depends on the laptop and the resolution; this is sampled monitoring, not a claim of 30 FPS inference.

**Configure the camera area:** edit `venue_config.json`: `area_sqm` must be the real ground area visible in that camera/zone. Density = visible head count / this area. Do not reduce the area simply to force HIGH risk. The supplied venue values are inherited demonstration settings. Occlusion can make observed density an underestimate of actual crowd density.

## Automatic evaluation — how to use it

1. Upload a real image/video, then open Evaluation Metrics.
2. Select the zone and recorded observation. Its original image and stored prediction are loaded automatically.
3. In **Label head boxes**, drag a tight rectangle around every visible head. Use zoom; right-click a label to remove it. Draw boxes from the image, independently of model output. Model boxes can be shown in amber for inspection.
4. Click **Save evidence & calculate**. The backend matches predictions against labels at IoU ≥ 0.50, one-to-one in confidence order. Actual count, TP, FP, FN, MAE, precision, recall and exact-count accuracy calculate automatically.
5. Saved values appear in the right-hand history. Selecting that observation again restores its labels. Re-saving replaces its evidence rather than adding another copy.

Alternatively use **Enter verified counts** after manually checking the image and model boxes. Enter actual count and verified TP; FP = predicted count − TP and FN = actual count − TP fill automatically. Count equality alone does not establish TP.

Live polling updates metrics/history only; it does not clear the active form. Unsaved labels/counts are kept locally in that browser. SQLite contains saved evidence, not unsaved drafts. Export evidence JSON for your report/backup.

For a fully automatic run on an already annotated test dataset, use the included script:

```powershell
.\venv\Scripts\python.exe scripts\evaluate_dataset.py --images "C:\HeadDataset\images\test" --labels "C:\HeadDataset\labels\test"
```

Use YOLO labels: one line per visible head, `0 center_x center_y width height`, normalized to [0,1]. Include an empty text file for a verified empty image. Paths under images/test and labels/test must match. The script runs the model, imports the labels, calculates metrics and populates this same dashboard. It never creates approval requests or sends notifications. Use new held-out images; rerunning a dataset creates new observations, so do not count repeated runs as independent test samples.

Without independent labels, detection metrics correctly show **Awaiting evidence**. An unlabelled video cannot truthfully supply its own precision/recall.

## ntfy setup and what “success” means

On first run the starter copies `.env.example` to `.env`. It uses your previously confirmed topic:

```text
NTFY_SERVER=https://ntfy.sh
NTFY_TOPIC=crowdguard-sushmitha-2026-x7k9
```

Subscribe to that **exact topic** on the phone. Save `.env` and restart the backend after changing it. For a protected topic set `NTFY_TOKEN` as well.

Choose **Review recommendation**, type your officer notes (for example, “OK proceed”), then **Approve & dispatch**. Your notes, action, zone and frozen count are included in the notification. Check **Evaluation → Approved alerts**:

- **queued:** stored, waiting for the publisher.
- **retrying:** transient failure; another attempt is scheduled.
- **accepted:** ntfy returned a message ID confirming publication.
- **failed:** permanent error or retries exhausted; the reason is visible. Fix configuration/connectivity and click Retry failed alert.

Publish success = accepted alerts / queued approved alerts. It can reach 100% only when all those alerts were accepted. It is **not phone-delivery confirmation**. The application cannot guarantee the phone displays every accepted message. Phone internet, notification permission, topic subscription and battery settings matter. A timeout retry can duplicate a message because the remote server may have accepted the first request before its response was lost.

Queued alerts persist across backend restarts. Run one backend instance (the supplied command uses one worker).

## Model training and claims for your report

The included model is already trained by the upstream authors on SCUT-HEAD Parts A/B. **This delivery integrates that pretrained model; it does not claim new training on your stampede video.** Your uploaded project/video did not contain verified head annotations or independent train/validation/test splits. No benchmark score has been fabricated or copied into the dashboard from another dataset.

For your own supervised training, see `docs/TRAINING.md`. This is optional and separate from running the project. Checkpoint source and attribution are in `models/MODEL_CARD.md`.

Small, blurred, dark, distant or heavily occluded heads can still be missed. The change improves the detection approach but does not establish a particular accuracy on your video. Review saved annotated frames and label representative held-out samples to measure it.

## Data and project boundaries

- `data/crowdguard.db`: new events, saved labels, outbox. Back up this file and the corresponding `uploads` folder together while the app is stopped.
- This upgrade starts with a clean database so historical HOG/manual measurements do not masquerade as new head-model performance. Your original archive retains your old database/videos.
- LangGraph active checkpoints remain in memory, as in your original project. Pending approvals and live streams do not resume after restart; reconnect/reanalyse and obtain a new officer decision. SQLite history and queued notifications do persist.
- No Agentic RAG was added. Risk scoring and flow recommendations are rule based; optional LLM reasoning remains separate. These recommendations do not control physical gates or deploy personnel automatically.
- The original density regression artifact is not used: its old HOG features are incompatible with head boxes. The active density method is explicitly count divided by configured area.

## Checks performed

See `docs/VALIDATION.md` for the executed tests and their limits. The tests use mocked notification responses, so they do not claim actual delivery to your phone.
