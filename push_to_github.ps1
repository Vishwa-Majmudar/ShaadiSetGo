Param(
    [string]$Remote = "https://github.com/Vishwa-Majmudar/ShaadiSetGo.git",
    [string]$Branch = "main",
    [switch]$Force
)

Write-Host "Preparing to push project to remote: $Remote (branch: $Branch)"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not available in PATH. Install Git before running this script."
    exit 1
}

if (-not (Test-Path .git)) {
    git init
    Write-Host "Initialized new git repository."
}

git remote remove origin -ErrorAction SilentlyContinue
git remote add origin $Remote

git add -A
try {
    git commit -m "Add ShaadiSetGo project files" -q
} catch {
    Write-Host "No changes to commit or commit failed; continuing to push."
}

if ($Force) {
    git push -u origin $Branch --force
} else {
    git push -u origin $Branch
}

Write-Host "Done. Verify the repository at $Remote"
