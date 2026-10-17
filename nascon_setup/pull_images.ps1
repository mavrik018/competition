# NaSCon '26 — pre-pull the required Docker image bundle (booklet §2).
# Run at home: powershell -ExecutionPolicy Bypass -File nascon_setup\pull_images.ps1
# Re-running is safe: already-present images are skipped quickly.

$images = @(
  'postgres:16-alpine',
  'redis:7-alpine',
  'minio/minio:RELEASE.2024-09-22T00-33-43Z',
  'rabbitmq:3.13-management-alpine',
  'nats:2.10-alpine',
  'bluenviron/mediamtx:1.9.1',
  'livekit/livekit-server:v1.7.2',
  'binwiederhier/ntfy:v2.11.0',
  'prom/prometheus:v2.54.1',
  'grafana/grafana:11.2.0',
  'grafana/k6:0.54.0',
  'selenium/hub:4.24.0',
  'selenium/node-chrome:4.24.0',
  'selenium/node-firefox:4.24.0',
  # Intel/AMD Windows and Linux laptops (Apple Silicon: seleniarm/node-chromium:4.24.0)
  'selenium/node-edge:4.24.0',
  # Backend runtimes (the booklet asks for one; both are small)
  'python:3.12-slim',
  'node:20-alpine'
)

$failed = @()
foreach ($image in $images) {
  Write-Host "=== $image"
  docker pull $image
  if ($LASTEXITCODE -ne 0) { $failed += $image }
}

Write-Host ''
if ($failed.Count -eq 0) {
  Write-Host "All $($images.Count) images pulled."
} else {
  Write-Host "FAILED ($($failed.Count)): $($failed -join ', ')"
  exit 1
}
