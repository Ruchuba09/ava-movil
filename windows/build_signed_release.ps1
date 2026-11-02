param(
    [string]$Thumbprint = $env:AVA_CODESIGN_THUMBPRINT
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Thumbprint)) {
    throw "Set AVA_CODESIGN_THUMBPRINT to the thumbprint of an installed Authenticode certificate."
}

$Thumbprint = $Thumbprint -replace "\s", ""
$certificate = Get-Item -LiteralPath "Cert:\CurrentUser\My\$Thumbprint"
if (-not $certificate.HasPrivateKey) {
    throw "The selected certificate does not have an accessible private key."
}
if ($certificate.NotBefore -gt (Get-Date) -or $certificate.NotAfter -le (Get-Date)) {
    throw "The selected code-signing certificate is not currently valid."
}

$codeSigningOid = "1.3.6.1.5.5.7.3.3"
$hasCodeSigningUsage = $certificate.EnhancedKeyUsageList |
    Where-Object { $_.ObjectId.Value -eq $codeSigningOid }
if (-not $hasCodeSigningUsage) {
    throw "The selected certificate is not valid for code signing."
}

$chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
if (-not $chain.Build($certificate)) {
    throw "The selected certificate does not build to a trusted certificate chain."
}

$signTool = Get-Command "signtool.exe" -ErrorAction SilentlyContinue
if (-not $signTool) {
    throw "signtool.exe was not found. Install the Windows SDK and add SignTool to PATH."
}
if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
    throw "Flutter was not found in PATH."
}

$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $repositoryRoot
try {
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows release build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$executableCandidates = @(
    (Join-Path $repositoryRoot "build\windows\x64\runner\Release\movil_base.exe"),
    (Join-Path $repositoryRoot "build\windows\runner\Release\movil_base.exe")
)
$executablePath = $executableCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $executablePath) {
    throw "The Windows release executable was not found in the expected Flutter build directories."
}

& $signTool.Source sign /sha1 $Thumbprint /s My /fd SHA256 /tr "http://timestamp.digicert.com" /td SHA256 $executablePath
if ($LASTEXITCODE -ne 0) {
    throw "Authenticode signing failed with exit code $LASTEXITCODE."
}

& $signTool.Source verify /pa /v $executablePath
if ($LASTEXITCODE -ne 0) {
    throw "Authenticode signature verification failed with exit code $LASTEXITCODE."
}

Write-Host "Signed and verified: $executablePath"
