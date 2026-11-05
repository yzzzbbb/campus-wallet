# Push the local git tree of campus-wallet to GitHub via the Git Data API.
# Use when github.com is unreachable but api.github.com is reachable.
# Usage:
#   $env:GH_PAT = 'ghp_xxx'
#   powershell -ExecutionPolicy Bypass -File tools\push_via_api.ps1
param(
  [string]$Token = $env:GH_PAT,
  [string]$Owner = 'yzzzbbb',
  [string]$Repo = 'campus-wallet',
  [string]$Branch = 'main',
  [string]$RepoRoot = 'D:\campus_wallet',
  [string]$CommitMessage = 'feat: campus-wallet v0.1 MVP - Flutter app with full source'
)

$ErrorActionPreference = 'Stop'
if (-not $Token) { throw 'No token. Set $env:GH_PAT or pass -Token.' }

$api = "https://api.github.com/repos/$Owner/$Repo"
$authHeader = 'Authorization: Bearer ' + $Token

function Invoke-GhApi {
  param([string]$Method, [string]$Url, [string]$Body = $null)
  $args = @('-s', '-X', $Method, '-H', $authHeader, '-H', 'Accept: application/vnd.github+json', '-H', 'X-GitHub-Api-Version: 2022-11-28')
  if ($Body) {
    $args += @('-H', 'Content-Type: application/json', '-d', $Body)
  }
  $args += $Url
  $out = & curl.exe @args
  if ($LASTEXITCODE -ne 0) { throw "curl failed for $Url" }
  $parsed = $out | ConvertFrom-Json
  if ($parsed.message) { throw "API error: $($parsed.message)" }
  return $parsed
}

Write-Host '1) Get current head ref...'
$ref = Invoke-GhApi 'GET' "$api/git/refs/heads/$Branch"
$headSha = $ref.object.sha

Write-Host '2) Get head commit...'
$headCommit = Invoke-GhApi 'GET' "$api/git/commits/$headSha"
$baseTree = $headCommit.tree.sha
$parents = @($headSha)

# Files to delete from remote (MCP test leftovers)
$deletePaths = @('BOOTSTRAP.md', 'mcp-bin.dat', 'docs/mcp-test.txt')

Write-Host '3) Get tracked file list from local git...'
$files = & git -C $RepoRoot ls-files
if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed' }

$treeEntries = @()
foreach ($rel in $files) {
  if ($deletePaths -contains $rel) { continue }
  $abs = Join-Path $RepoRoot ($rel -replace '/', '\')
  if (-not (Test-Path $abs)) { throw "missing file: $abs" }
  $bytes = [System.IO.File]::ReadAllBytes($abs)
  $b64 = [System.Convert]::ToBase64String($bytes)
  $body = @{ content = $b64; encoding = 'base64' } | ConvertTo-Json -Compress
  $blob = Invoke-GhApi 'POST' "$api/git/blobs" $body
  $treeEntries += @{ path = $rel; mode = '100644'; type = 'blob'; sha = $blob.sha }
  Write-Host ("   blob " + $blob.sha.Substring(0, 8) + "  " + $rel)
}
foreach ($p in $deletePaths) {
  $treeEntries += @{ path = $p; mode = '100644'; type = 'blob'; sha = $null }
  Write-Host "   delete $p"
}

Write-Host '4) Create tree...'
$treeBody = @{ base_tree = $baseTree; tree = $treeEntries } | ConvertTo-Json -Depth 10 -Compress
$tree = Invoke-GhApi 'POST' "$api/git/trees" $treeBody

Write-Host '5) Create commit...'
$commitBody = @{ message = $CommitMessage; tree = $tree.sha; parents = $parents } | ConvertTo-Json -Compress
$commit = Invoke-GhApi 'POST' "$api/git/commits" $commitBody

Write-Host '6) Update branch ref...'
$refBody = @{ sha = $commit.sha; force = $false } | ConvertTo-Json -Compress
$updated = Invoke-GhApi 'PATCH' "$api/git/refs/heads/$Branch" $refBody

Write-Host ('DONE. New head: ' + $updated.object.sha)