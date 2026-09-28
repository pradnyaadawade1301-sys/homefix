# Usage (from backend\Backend):  powershell -ExecutionPolicy Bypass -File .\patch_main.ps1
param([string]$Path = "..\cmd\server\main.go")

$full = (Resolve-Path $Path).Path
$src  = [System.IO.File]::ReadAllText($full)
$nl   = if ($src.Contains("`r`n")) { "`r`n" } else { "`n" }

function Fail($msg) { Write-Host "FAILED: $msg"; exit 1 }

# 1. repos
if (-not $src.Contains("disputeMsgRepo :=")) {
    $before = $src
    $src = $src -replace '(?m)^([ \t]*)(disputeRepo := repository\.NewDisputeRepository\(pool\))', ('${1}${2}' + $nl + '${1}disputeMsgRepo := repository.NewDisputeMessageRepository(pool)' + $nl + '${1}supportRepo := repository.NewSupportMessageRepository(pool)')
    if ($src -eq $before) { Fail "disputeRepo line not found" }
}

# 2. dispute service gets the message repo
if (-not $src.Contains("NewDisputeService(disputeRepo, disputeMsgRepo,")) {
    $before = $src
    $src = $src -replace 'NewDisputeService\(disputeRepo, ', 'NewDisputeService(disputeRepo, disputeMsgRepo, '
    if ($src -eq $before) { Fail "NewDisputeService call not found" }
}

# 3. support service
if (-not $src.Contains("supportService :=")) {
    $before = $src
    $src = $src -replace '(?m)^([ \t]*)(disputeService := service\.NewDisputeService\([^\r\n]*\))', ('${1}${2}' + $nl + '${1}supportService := service.NewSupportService(supportRepo)')
    if ($src -eq $before) { Fail "disputeService line not found" }
}

# 4. admin API handler gets support service
if (-not $src.Contains("walletService, supportService)")) {
    $before = $src
    $src = $src -replace 'NewAdminAPIHandler\(([^\r\n]*)walletService\)', 'NewAdminAPIHandler(${1}walletService, supportService)'
    if ($src -eq $before) { Fail "NewAdminAPIHandler call not found" }
}

# 5. Support handler in router.Handlers
if (-not $src.Contains("NewSupportHandler(")) {
    $before = $src
    $src = $src -replace '(?m)^([ \t]*)(Dispute:\s+handler\.NewDisputeHandler\(disputeService\),)', ('${1}${2}' + $nl + '${1}Support:      handler.NewSupportHandler(supportService),')
    if ($src -eq $before) { Fail "Dispute handler line not found" }
}

# 6. users columns startup migration
if (-not $src.Contains("users_google_id_key")) {
$block = @'
	// 012_email_verification / 011_user_photo / 018_google_auth - Render never
	// applies migrations/ files. Without these, login and Google sign-in fail:
	//   column "email_otp_code" does not exist (SQLSTATE 42703)
	// Safe no-op once the columns exist.
	if _, err := pool.Exec(ctx,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS email_otp_code VARCHAR(10);
		 ALTER TABLE users ADD COLUMN IF NOT EXISTS email_otp_expires_at TIMESTAMPTZ NULL;
		 ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT false;
		 ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN NOT NULL DEFAULT false;
		 ALTER TABLE users ADD COLUMN IF NOT EXISTS photo_url TEXT NULL;
		 ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255) NULL;
		 ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT NULL;
		 ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;
		 ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
		 CREATE UNIQUE INDEX IF NOT EXISTS users_google_id_key ON users (google_id) WHERE google_id IS NOT NULL;`); err != nil {
		log.Printf("startup migration: failed to ensure users auth columns exist: %v", err)
	}

'@
    $block = ($block -replace "`r?`n", $nl)
    $m = [regex]::Match($src, '(?m)^[ \t]*// 030_seed_more_categories_2')
    if (-not $m.Success) { Fail "marker '// 030_seed_more_categories_2' not found" }
    $src = $src.Insert($m.Index, $block)
}

[System.IO.File]::WriteAllText($full, $src, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Patched $full"
