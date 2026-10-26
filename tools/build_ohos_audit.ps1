[CmdletBinding()]
param(
    [string]$Target = 'bin/script_acceptance.dart',
    [ValidateSet('ohos-x64', 'ohos-arm64', 'ohos-arm64,ohos-x64')]
    [string]$Platform = 'ohos-x64',
    [string]$LogPath = 'build/offline-ide-audit/ohos-build.log',
    [string]$ReportPath = 'build/offline-ide-audit/ohos-package.json',
    [string]$FlutterSdkRoot
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Get-FileEvidence([string]$Path) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.PSIsContainer) { throw "Expected a file: $Path" }
    return [ordered]@{ path = $item.FullName; bytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
}

function Write-ReceiptJson([string]$Path, $Value) {
    $json = ($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

function Resolve-Directory([string]$Path) {
    $item = Get-Item -LiteralPath ([IO.Path]::GetFullPath($Path)) -ErrorAction Stop
    if (-not $item.PSIsContainer) { throw "Expected a directory: $Path" }
    return $item.FullName.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-OutputPath([string]$Path) {
    if (-not [IO.Path]::IsPathRooted($Path)) { $Path = Join-Path $projectRoot $Path }
    return [IO.Path]::GetFullPath($Path)
}

function Get-BuildBinding {
    $propertiesPath = Join-Path $projectRoot 'ohos/local.properties'
    $lines = @(Get-Content -LiteralPath $propertiesPath | Where-Object { $_ -match '^\s*flutter\.sdk\s*[:=]' })
    if ($lines.Count -ne 1) { throw 'Require exactly one flutter.sdk in ohos/local.properties.' }
    $property = ($lines[0] -replace '^\s*flutter\.sdk\s*[:=]\s*', '').Trim()
    $property = [regex]::Replace($property, '\\(u[0-9a-fA-F]{4}|.)', [Text.RegularExpressions.MatchEvaluator]{
        param($escape)
        $value = $escape.Groups[1].Value
        if ($value -cmatch '^u[0-9a-fA-F]{4}$') { return [string][char][Convert]::ToInt32($value.Substring(1), 16) }
        switch -CaseSensitive ($value) {
            'n' { return "`n" }; 'r' { return "`r" }; 't' { return "`t" }; 'f' { return "`f" }
            default { return $value }
        }
    })
    if (-not [IO.Path]::IsPathRooted($property)) { throw 'OHOS flutter.sdk must be absolute.' }
    $configuredSdk = Resolve-Directory $property
    $selectedSdk = $configuredSdk
    if (-not [string]::IsNullOrWhiteSpace($FlutterSdkRoot)) { $selectedSdk = Resolve-Directory $FlutterSdkRoot }
    if ($selectedSdk -ine $configuredSdk) { throw 'Requested Flutter SDK differs from OHOS flutter.sdk.' }

    $configPath = Join-Path $projectRoot '.dart_tool/package_config.json'
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $roots = @{}
    foreach ($name in @('flutter', 'qfli_studio_core')) {
        $entries = @($config.packages | Where-Object { $_.name -ceq $name })
        if ($entries.Count -ne 1 -or [string]::IsNullOrWhiteSpace($entries[0].rootUri)) {
            throw "Require exactly one $name root in package_config.json."
        }
        $uri = [Uri]::new([Uri]::new($configPath), [string]$entries[0].rootUri)
        if (-not $uri.IsFile -or $uri.IsUnc) { throw "Require a local file URI for $name." }
        $roots[$name] = Resolve-Directory $uri.LocalPath
    }
    $expectedFlutter = Resolve-Directory (Join-Path $selectedSdk 'packages/flutter')
    if ($roots['flutter'] -ine $expectedFlutter) { throw 'Flutter package root differs from the selected SDK.' }
    return [ordered]@{ sdkRoot = $selectedSdk; flutterPackageRoot = $roots['flutter']
        corePackageRoot = $roots['qfli_studio_core']
        packageConfig = (Get-FileEvidence $configPath); ohosLocalProperties = (Get-FileEvidence $propertiesPath) }
}

function Get-SourceHead([string]$Root) {
    $head = @(& git -C $Root rev-parse --verify HEAD 2>&1)
    if ($LASTEXITCODE -ne 0 -or $head.Count -ne 1 -or [string]$head[0] -notmatch '^[0-9a-fA-F]{40,64}$') {
        throw "Cannot identify source HEAD: $Root"
    }
    return ([string]$head[0]).ToLowerInvariant()
}

function Get-ShippingFiles([string]$Root, [string]$Prefix, [string[]]$Scopes) {
    # Prune before descending: build outputs/dependencies are not shipping source.
    $skipDirectories = @('build', '.git', '.dart_tool', '.hvigor', '.gradle', '.cxx',
        '.externalNativeBuild', 'oh_modules', 'node_modules', '__pycache__', '.cache',
        'caches', '.idea', '.vscode', 'signing', 'signings', 'keystore', 'keystores')
    $pending = [Collections.Generic.Stack[string]]::new()
    foreach ($scope in $Scopes) { $pending.Push((Join-Path $Root $scope)) }
    while ($pending.Count -gt 0) {
        $item = Get-Item -LiteralPath $pending.Pop() -Force -ErrorAction Stop
        $relative = $item.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
        if ($item.PSIsContainer -and $item.Name -in $skipDirectories) { continue }
        if ($relative -in @('ohos/build-profile.json5', 'ohos/local.properties',
                'ohos/entry/src/main/resources/rawfile/buildinfo.json5')) { continue }
        if ($item.Name -match '(^\.env($|\.)|^key\.properties$|(^|[._-])(signing|credentials?|secrets?)([._-]|$))' -or
            $item.Extension -in @('.p12', '.pfx', '.jks', '.keystore', '.pem', '.key', '.cer', '.p7b',
                '.mobileprovision', '.hap', '.hsp', '.har', '.apk', '.aar', '.app', '.so', '.dll',
                '.a', '.lib', '.o', '.obj', '.exe', '.pdb', '.class', '.pyc', '.tar', '.xz', '.gz', '.zip')) { continue }
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Shipping source must not traverse a link: $($item.FullName)"
        }
        if ($item.PSIsContainer) {
            foreach ($child in Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop) {
                $pending.Push($child.FullName)
            }
        }
        else {
            $file = Get-FileEvidence $item.FullName
            [pscustomobject]@{ key = "$Prefix/$relative"; path = $file.path; bytes = $file.bytes; sha256 = $file.sha256 }
        }
    }
}

function Get-SourceSnapshot([string]$FixedCoreRoot) {
    try { $binding = Get-BuildBinding }
    catch {
        if ([string]::IsNullOrWhiteSpace($FixedCoreRoot)) { throw }
        $binding = [ordered]@{ unavailableReason = $_.Exception.Message }
    }
    $coreRoot = $FixedCoreRoot
    if ([string]::IsNullOrWhiteSpace($coreRoot)) { $coreRoot = $binding.corePackageRoot }
    $heads = [ordered]@{ product = (Get-SourceHead $projectRoot); core = (Get-SourceHead $coreRoot) }
    $productScopes = @('lib', 'assets', 'native', 'bin', 'ohos', 'pubspec.yaml', 'pubspec.lock',
        'tools/build_ohos_audit.ps1', 'tools/inspect_lua_hap.py')
    if ($targetRelative -notin $productScopes -and $targetRelative -notmatch '^(lib|assets|native|bin|ohos)/') {
        $productScopes += $targetRelative
    }
    $files = @(@(Get-ShippingFiles $projectRoot 'product' $productScopes) +
        @(Get-ShippingFiles $coreRoot 'core' @('lib', 'assets', 'pubspec.yaml')) |
        Sort-Object -Property key)
    try { $endBinding = Get-BuildBinding }
    catch { $endBinding = [ordered]@{ unavailableReason = $_.Exception.Message } }
    $stable = -not [string]::IsNullOrWhiteSpace($binding.sdkRoot) -and
        ($heads.product -ceq (Get-SourceHead $projectRoot)) -and
        ($heads.core -ceq (Get-SourceHead $coreRoot)) -and
        (($binding | ConvertTo-Json -Depth 8 -Compress) -ceq ($endBinding | ConvertTo-Json -Depth 8 -Compress))
    return [ordered]@{ capturedAtUtc = [DateTime]::UtcNow.ToString('o'); heads = $heads; target = (Get-FileEvidence $targetPath)
        coreSourceRoot = $coreRoot; binding = $binding; bindingAtEnd = $endBinding; captureStable = $stable; files = $files }
}

function Assert-SnapshotUnchanged($Before, $After) {
    if (-not $Before.captureStable -or -not $After.captureStable) { throw 'Source HEAD or binding changed during snapshot capture.' }
    foreach ($field in @('heads', 'binding', 'target', 'files')) {
        if (($Before[$field] | ConvertTo-Json -Depth 16 -Compress) -cne
            ($After[$field] | ConvertTo-Json -Depth 16 -Compress)) {
            throw "Build source drift detected: $field; retain both manifests."
        }
    }
}

function Save-Command([string]$Path, [string]$Executable, [string[]]$Arguments) {
    Write-ReceiptJson $Path ([ordered]@{ executable = (Get-FileEvidence $Executable)
        arguments = $Arguments; workingDirectory = $projectRoot })
    return Get-FileEvidence $Path
}

$oldLocation = Get-Location
$hadJavaOptions = Test-Path Env:JAVA_TOOL_OPTIONS
$oldJavaOptions = $env:JAVA_TOOL_OPTIONS
$buildDirectory = Join-Path $projectRoot 'build/offline-ide-audit'
[IO.Directory]::CreateDirectory($buildDirectory) | Out-Null
$lock = $null
$receipt = $null
$before = $null
$failure = $null
$evidenceErrors = [Collections.Generic.List[string]]::new()
try {
    $lock = [IO.File]::Open((Join-Path $buildDirectory '.build.lock'),
        [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    Set-Location -LiteralPath $projectRoot
    $runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N')
    $receiptDirectory = Join-Path $buildDirectory "build-receipts/$runId"
    [IO.Directory]::CreateDirectory($receiptDirectory) | Out-Null
    $receiptPath = Join-Path $receiptDirectory 'receipt.json'
    $buildLog = Join-Path $receiptDirectory 'build.log'
    $inspectionLog = Join-Path $receiptDirectory 'inspection.log'
    $inspectionReport = Join-Path $receiptDirectory 'inspection.json'
    $callerLog = Resolve-OutputPath $LogPath
    $callerReport = Resolve-OutputPath $ReportPath
    $receipt = [ordered]@{ schemaVersion = 1; runId = $runId; startedAtUtc = [DateTime]::UtcNow.ToString('o')
        projectRoot = $projectRoot; requestedTarget = $Target; requestedPlatform = $Platform
        callerLogPath = $callerLog; callerReportPath = $callerReport; binding = $null; heads = $null
        sourceBefore = $null; sourceAfter = $null; sourceBindingGatePassed = $false
        build = [ordered]@{ command = $null; executable = $null; flutterSnapshot = $null; exitCode = $null; log = $null }
        inspection = [ordered]@{ command = $null; executable = $null; exitCode = $null; log = $null; report = $null; packageGatePassed = $false }
        artifact = $null; packageGatePassed = $false; deviceGatePassed = $false
        signatureVerification = [ordered]@{ verified = $false; status = 'pending'; reason = 'No SDK signature verification performed.' }
        succeeded = $false; primaryFailure = $null; evidenceErrors = @(); completedAtUtc = $null }
    Write-ReceiptJson $receiptPath $receipt
    if ($callerLog -ieq $callerReport) { throw 'LogPath and ReportPath must be different.' }
    $targetPath = $Target
    if (-not [IO.Path]::IsPathRooted($targetPath)) { $targetPath = Join-Path $projectRoot $targetPath }
    $targetPath = [IO.Path]::GetFullPath($targetPath)
    if (-not $targetPath.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetExtension($targetPath) -ine '.dart' -or -not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        throw 'Dart target must be an existing file within this product root.'
    }
    $targetRelative = $targetPath.Substring($projectRoot.Length + 1).Replace('\', '/')
    $before = Get-SourceSnapshot
    $beforePath = Join-Path $receiptDirectory 'source-before.json'
    Write-ReceiptJson $beforePath $before
    $receipt.sourceBefore = Get-FileEvidence $beforePath
    $receipt.binding = $before.binding
    $receipt.heads = $before.heads
    if (-not $before.captureStable) { throw 'Source HEAD or binding changed before build.' }
    # Caller copies must never overwrite shipping inputs, SDKs or retained evidence.
    $protectedPaths = @($before.binding.sdkRoot, $before.binding.corePackageRoot,
        $before.binding.packageConfig.path, $before.binding.ohosLocalProperties.path,
        $targetPath, (Join-Path $buildDirectory 'build-receipts'), (Join-Path $buildDirectory '.build.lock'))
    foreach ($scope in @('lib', 'assets', 'native', 'bin', 'ohos', 'tools', 'pubspec.yaml', 'pubspec.lock')) {
        $protectedPaths += Join-Path $projectRoot $scope
    }
    foreach ($outputPath in @($callerLog, $callerReport)) {
        foreach ($protectedPath in $protectedPaths) {
            if ($outputPath -ieq $protectedPath -or $outputPath.StartsWith($protectedPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Log/report output must not overwrite source, SDK, binding or retained evidence.'
            }
        }
        if ([IO.Path]::GetExtension($outputPath) -in @('.hap', '.p12', '.pfx', '.jks', '.keystore', '.pem', '.key', '.cer', '.p7b')) {
            throw 'Log/report output must not overwrite a package or signing file.'
        }
    }
    $dart = Join-Path $before.binding.sdkRoot 'bin/cache/dart-sdk/bin/dart.exe'
    $flutter = Join-Path $before.binding.sdkRoot 'bin/cache/flutter_tools.snapshot'
    $receipt.build.flutterSnapshot = Get-FileEvidence $flutter
    $receipt.build.executable = Get-FileEvidence $dart
    $buildArgs = @($flutter, 'build', 'hap', '--debug', '--no-pub', '--target-platform', $Platform, '-t', $Target)
    $receipt.build.command = Save-Command (Join-Path $receiptDirectory 'build-command.json') $dart $buildArgs
    Write-ReceiptJson $receiptPath $receipt
    $env:JAVA_TOOL_OPTIONS = '-Xms16m -Xmx256m -XX:+UseSerialGC'
    $started = [DateTime]::UtcNow
    & $dart @buildArgs *> $buildLog
    $receipt.build.exitCode = $LASTEXITCODE
    if ($LASTEXITCODE -ne 0) { throw "HAP build failed; inspect $buildLog" }
    $outputs = Join-Path $projectRoot 'ohos/entry/build/default/outputs/default'
    $packages = @(Get-ChildItem -LiteralPath $outputs -Filter '*.hap' |
        Where-Object { $_.LastWriteTimeUtc -ge $started.AddSeconds(-2) } |
        Sort-Object @{Expression = {$_.Name -match '-signed.hap$'}; Descending = $true},
            @{Expression = {$_.LastWriteTimeUtc}; Descending = $true}, Name)
    if ($packages.Count -eq 0) { throw 'Build produced no fresh HAP.' }
    $selected = $packages[0]
    $selectedEvidence = Get-FileEvidence $selected.FullName
    $artifact = Join-Path $buildDirectory "$([IO.Path]::GetFileNameWithoutExtension($Target))-$($selectedEvidence.sha256.Substring(0,16)).hap"
    if (Test-Path -LiteralPath $artifact) {
        if ((Get-FileEvidence $artifact).sha256 -cne $selectedEvidence.sha256) { throw 'Preserved HAP hash-name collision.' }
    }
    else { [IO.File]::Copy($selected.FullName, $artifact, $false) }
    $receipt.artifact = Get-FileEvidence $artifact
    if ($receipt.artifact.sha256 -cne $selectedEvidence.sha256) { throw 'HAP changed while being preserved.' }
    $abis = ($Platform.Split(',') | ForEach-Object {
        if ($_ -eq 'ohos-x64') { 'x86_64' } else { 'arm64-v8a' }
    }) -join ','
    $python = (Get-Command python -CommandType Application -ErrorAction Stop).Source
    $receipt.inspection.executable = Get-FileEvidence $python
    $inspectionArgs = @((Join-Path $projectRoot 'tools/inspect_lua_hap.py'), $artifact, '--abis', $abis, '--report', $inspectionReport)
    $receipt.inspection.command = Save-Command (Join-Path $receiptDirectory 'inspection-command.json') $python $inspectionArgs
    Write-ReceiptJson $receiptPath $receipt
    & $python @inspectionArgs *> $inspectionLog
    $receipt.inspection.exitCode = $LASTEXITCODE
    $report = Get-Content -LiteralPath $inspectionReport -Raw | ConvertFrom-Json
    $receipt.inspection.packageGatePassed = $report.packageGatePassed -is [bool] -and $report.packageGatePassed
    if ($receipt.inspection.exitCode -ne 0 -or -not $receipt.inspection.packageGatePassed) {
        throw "HAP inspection failed; inspect $inspectionReport"
    }
    if ($report.sha256 -cne $receipt.artifact.sha256 -or $report.deviceGatePassed -isnot [bool] -or $report.deviceGatePassed -ne $false -or
        [IO.Path]::GetFullPath([string]$report.hap) -ine $artifact) {
        throw 'Inspection report does not identify the preserved HAP with device acceptance false.'
    }
}
catch { $failure = $_ }
finally {
    # Capture evidence on failure too; no evidence error may bypass restoration.
    try {
        if ($null -ne $before) {
            $after = Get-SourceSnapshot -FixedCoreRoot $before.coreSourceRoot
            $afterPath = Join-Path $receiptDirectory 'source-after.json'
            Write-ReceiptJson $afterPath $after
            $receipt.sourceAfter = Get-FileEvidence $afterPath
            Assert-SnapshotUnchanged $before $after
            $receipt.sourceBindingGatePassed = $true
        }
    }
    catch { $evidenceErrors.Add("Source after: $($_.Exception.Message)") }
    if ($null -ne $receipt) {
        foreach ($item in @(@{ source = $buildLog; stage = 'build'; field = 'log'; mirror = $callerLog },
                @{ source = $inspectionLog; stage = 'inspection'; field = 'log'; mirror = $null },
                @{ source = $inspectionReport; stage = 'inspection'; field = 'report'; mirror = $callerReport })) {
            try {
                if (Test-Path -LiteralPath $item.source -PathType Leaf) {
                    $receipt[$item.stage][$item.field] = Get-FileEvidence $item.source
                    if ($item.mirror) {
                        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.mirror)) | Out-Null
                        if ($item.source -ine $item.mirror) { [IO.File]::Copy($item.source, $item.mirror, $true) }
                    }
                }
            }
            catch { $evidenceErrors.Add("Retain $($item.field): $($_.Exception.Message)") }
        }
        try {
            foreach ($file in @($receipt.build.command, $receipt.build.executable, $receipt.build.flutterSnapshot,
                    $receipt.inspection.command, $receipt.inspection.executable)) {
                if ($null -ne $file -and (Get-FileEvidence $file.path).sha256 -cne $file.sha256) {
                    throw "Command input or record changed: $($file.path)"
                }
            }
            if ($null -ne $receipt.artifact -and
                (Get-FileEvidence $receipt.artifact.path).sha256 -cne $receipt.artifact.sha256) {
                throw 'Preserved HAP changed after inspection.'
            }
        }
        catch { $evidenceErrors.Add("Artifact after: $($_.Exception.Message)") }
    }
    try {
        if ($hadJavaOptions) { $env:JAVA_TOOL_OPTIONS = $oldJavaOptions }
        else { Remove-Item Env:JAVA_TOOL_OPTIONS -ErrorAction SilentlyContinue }
    }
    catch { $evidenceErrors.Add("Restore Java options: $($_.Exception.Message)") }
    finally {
        try { Set-Location -LiteralPath $oldLocation }
        catch { $evidenceErrors.Add("Restore location: $($_.Exception.Message)") }
        finally {
            try { if ($null -ne $lock) { $lock.Dispose() } }
            catch { $evidenceErrors.Add("Release build lock: $($_.Exception.Message)") }
        }
    }
    if ($null -ne $receipt) {
        $receipt.completedAtUtc = [DateTime]::UtcNow.ToString('o')
        if ($null -ne $failure) { $receipt.primaryFailure = $failure.Exception.Message }
        $receipt.evidenceErrors = @($evidenceErrors.ToArray())
        $receipt.succeeded = $null -eq $failure -and $evidenceErrors.Count -eq 0 -and $receipt.sourceBindingGatePassed -and $receipt.inspection.packageGatePassed
        $receipt.packageGatePassed = $receipt.succeeded
        try { Write-ReceiptJson $receiptPath $receipt }
        catch { $evidenceErrors.Add("Write receipt: $($_.Exception.Message)") }
    }
}
if ($evidenceErrors.Count -gt 0) { Write-Warning ($evidenceErrors -join [Environment]::NewLine) }
if ($null -ne $failure) { throw $failure }
if ($evidenceErrors.Count -gt 0) { throw "Build evidence failed; inspect $receiptPath" }
Write-Output "Inspected package preserved: $artifact"
Write-Output "Build receipt: $receiptPath (signature pending; installed-device acceptance false)"
