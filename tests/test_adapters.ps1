$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$aagentScript = Join-Path $projectRoot "aagent.ps1"
$fakeProvider = Join-Path $projectRoot "tests/helpers/fake-provider.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)

. $aagentScript

function Assert-AdapterEqual($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Assert-AdapterContains([string] $Value, [string] $Expected, [string] $Message) {
    if (-not $Value.Contains($Expected)) {
        throw $Message
    }
}

function Assert-AdapterFileLine([string] $Path, [string] $Expected, [string] $Message) {
    if ($Expected -notin [IO.File]::ReadAllLines($Path, $utf8)) {
        throw $Message
    }
}

function ConvertTo-AdapterHex([AllowEmptyString()][string] $Value) {
    return [Convert]::ToHexString($utf8.GetBytes($Value)).ToLowerInvariant()
}

function Assert-AdapterRecord(
    [string] $Path,
    [AllowEmptyString()]
    [string] $ExpectedStdin,
    [AllowEmptyCollection()]
    [AllowEmptyString()]
    [string[]] $ExpectedArguments
) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Provider record is missing: $Path"
    }
    Assert-AdapterFileLine $Path "argc=$($ExpectedArguments.Count)" "Provider argument count differs."
    for ($index = 0; $index -lt $ExpectedArguments.Count; $index++) {
        Assert-AdapterFileLine `
            $Path `
            "arg.$index.hex=$(ConvertTo-AdapterHex $ExpectedArguments[$index])" `
            "Provider argument $index differs."
    }
    Assert-AdapterFileLine $Path "stdin.hex=$(ConvertTo-AdapterHex $ExpectedStdin)" "Provider stdin differs."
}

function Invoke-AdapterCli([string] $Tag, [string[]] $Arguments, [AllowEmptyString()][string] $Stdin = "") {
    $pwsh = (Get-Process -Id $PID).Path
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add("-NoProfile")
    $startInfo.ArgumentList.Add("-File")
    $startInfo.ArgumentList.Add($aagentScript)
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Could not start adapter test process: $Tag"
    }
    $process.StandardInput.Write($Stdin)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $status = $process.ExitCode
    $process.Dispose()

    return [pscustomobject] @{
        Stdout = $stdout
        Stderr = $stderr
        Status = $status
    }
}

function Get-AdapterModel([string] $Provider) {
    switch ($Provider) {
        "claude" { return "claude-model" }
        "codex" { return "codex-model" }
        "opencode" { return "provider/model" }
        "copilot" { return "copilot-model" }
        "gemini" { return "gemini-model" }
        "amp" { return "" }
    }
}

function Get-AdapterDisplayName([string] $Provider) {
    switch ($Provider) {
        "claude" { return "Claude Code" }
        "codex" { return "Codex CLI" }
        "opencode" { return "OpenCode" }
        "copilot" { return "GitHub Copilot CLI" }
        "amp" { return "Amp" }
        "gemini" { return "Gemini CLI" }
    }
}

function Get-PromptArguments([string] $Provider, [string] $Prompt, [string] $Model) {
    switch ($Provider) {
        "claude" { return @("--print", $Prompt, "--model", $Model, "--native-flag", "-leading-value") }
        "codex" { return @("exec", "--model", $Model, "--native-flag", "-leading-value", $Prompt) }
        "opencode" { return @("run", "--model", $Model, "--native-flag", "-leading-value", $Prompt) }
        "copilot" { return @("--prompt", $Prompt, "--silent", "--no-ask-user", "--model", $Model, "--native-flag", "-leading-value") }
        "amp" { return @("--execute", $Prompt, "--native-flag", "-leading-value") }
        "gemini" { return @("--model", $Model, "--native-flag", "-leading-value", "--prompt", $Prompt) }
    }
}

function Get-StdinCase([string] $Provider, [string] $Stdin) {
    switch ($Provider) {
        "claude" { return [pscustomobject] @{ Arguments = @("--print"); Stdin = $Stdin } }
        "codex" { return [pscustomobject] @{ Arguments = @("exec", "-"); Stdin = $Stdin } }
        "opencode" { return [pscustomobject] @{ Arguments = @("run", $Stdin); Stdin = "" } }
        "copilot" { return [pscustomobject] @{ Arguments = @("--prompt", $Stdin, "--silent", "--no-ask-user"); Stdin = "" } }
        "amp" { return [pscustomobject] @{ Arguments = @("--execute"); Stdin = $Stdin } }
        "gemini" { return [pscustomobject] @{ Arguments = @(); Stdin = $Stdin } }
    }
}

function Get-BothCase([string] $Provider, [string] $Prompt, [string] $Stdin) {
    switch ($Provider) {
        "claude" { return [pscustomobject] @{ Arguments = @("--print", $Prompt); Stdin = $Stdin } }
        "codex" { return [pscustomobject] @{ Arguments = @("exec", $Prompt); Stdin = $Stdin } }
        "opencode" {
            return [pscustomobject] @{
                Arguments = @("run", "$Prompt`n`n--- stdin context ---`n$Stdin")
                Stdin = ""
            }
        }
        "copilot" {
            return [pscustomobject] @{
                Arguments = @("--prompt", "$Prompt`n`n--- stdin context ---`n$Stdin", "--silent", "--no-ask-user")
                Stdin = ""
            }
        }
        "amp" { return [pscustomobject] @{ Arguments = @("--execute", $Prompt); Stdin = $Stdin } }
        "gemini" { return [pscustomobject] @{ Arguments = @("--prompt", $Prompt); Stdin = $Stdin } }
    }
}

$testDir = Join-Path ([IO.Path]::GetTempPath()) ("aagent-adapters-" + [guid]::NewGuid().ToString("N"))
$overrideNames = @(
    "AAGENT_CLAUDE_BIN", "AAGENT_CODEX_BIN", "AAGENT_OPENCODE_BIN", "AAGENT_COPILOT_BIN",
    "AAGENT_AMP_BIN", "AAGENT_GEMINI_BIN"
)
$environmentNames = @(
    "HOME", "XDG_CONFIG_HOME", "APPDATA", "PATH",
    "AAGENT_FAKE_RECORD_DIR", "AAGENT_FAKE_PROVIDER", "AAGENT_FAKE_INVOCATION_KIND",
    "AAGENT_FAKE_RUN_STDOUT", "AAGENT_FAKE_RUN_STDERR", "AAGENT_FAKE_RUN_STATUS",
    "AAGENT_FAKE_PROBE_STDOUT", "AAGENT_FAKE_PROBE_STDERR", "AAGENT_FAKE_PROBE_STATUS",
    "AAGENT_FAKE_PROBE_DELAY", "AAGENT_FAKE_PROBE_BYTES",
    "AAGENT_FAKE_CLAUDE_STDOUT", "AAGENT_FAKE_CLAUDE_STDERR", "AAGENT_FAKE_CLAUDE_STATUS",
    "AAGENT_FAKE_CODEX_APP_SERVER_STDOUT", "AAGENT_FAKE_CODEX_APP_SERVER_STDERR",
    "AAGENT_FAKE_CODEX_APP_SERVER_STATUS", "AAGENT_FAKE_CODEX_LOGIN_STDOUT",
    "AAGENT_FAKE_CODEX_LOGIN_STDERR", "AAGENT_FAKE_CODEX_LOGIN_STATUS",
    "AAGENT_PROVIDER", "AAGENT_AUTH_POLICY", "AAGENT_PRIORITY", "AAGENT_ALLOW_LOCAL",
    "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
    "CODEX_API_KEY", "OPENAI_API_KEY", "COPILOT_PROVIDER_BASE_URL", "COPILOT_PROVIDER_TYPE",
    "COPILOT_PROVIDER_API_KEY", "COPILOT_PROVIDER_BEARER_TOKEN", "COPILOT_PROVIDER_HEADERS",
    "COPILOT_MODEL", "COPILOT_PROVIDER_MODEL_ID", "COPILOT_PROVIDER_WIRE_MODEL",
    "COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"
) + $overrideNames
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    $homeDir = Join-Path $testDir "home"
    $configDir = Join-Path $testDir "config"
    $appDataDir = Join-Path $testDir "appdata"
    $fakeBin = Join-Path $testDir "bin"
    $workDir = Join-Path $testDir "working directory 🌍"
    foreach ($directory in @($homeDir, $configDir, $appDataDir, $fakeBin, $workDir)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $expectedWorkDir = $workDir
    if (-not $IsWindows) {
        Push-Location $workDir
        try {
            $expectedWorkDir = (& /bin/pwd -P).Trim()
        } finally {
            Pop-Location
        }
    }

    $env:HOME = $homeDir
    $env:XDG_CONFIG_HOME = $configDir
    $env:APPDATA = $appDataDir
    $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$($originalEnvironment['PATH'])"
    foreach ($name in $environmentNames) {
        if ($name -notin @("HOME", "XDG_CONFIG_HOME", "APPDATA", "PATH")) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        }
    }

    $providers = @("claude", "codex", "opencode", "copilot", "amp", "gemini")
    foreach ($provider in $providers) {
        Copy-Item -LiteralPath $fakeProvider -Destination (Join-Path $fakeBin "$provider.ps1")
    }
    $prompt = "fix the `"quoted`" issue 🌍`nand keep formatting"
    $stdinPayload = "stdin only`nsecond line`n`n"
    $bothPrompt = "review this change`ncarefully"
    $bothStdin = "diff --git a/file b/file`n+new line`n"

    foreach ($provider in $providers) {
        $recordDir = Join-Path $testDir "records-$provider"
        [IO.Directory]::CreateDirectory($recordDir) | Out-Null
        $env:AAGENT_FAKE_RECORD_DIR = $recordDir
        $env:AAGENT_FAKE_PROVIDER = $provider
        $env:AAGENT_FAKE_RUN_STDOUT = "provider-stdout-$provider"
        $env:AAGENT_FAKE_RUN_STDERR = "provider-stderr-$provider"
        $env:AAGENT_FAKE_RUN_STATUS = "0"
        $env:AAGENT_FAKE_CLAUDE_STDOUT = '{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","apiProvider":"claude.ai"}'
        $env:AAGENT_FAKE_CODEX_APP_SERVER_STDOUT = '{"id":1,"result":{"account":{"type":"apiKey"},"requiresOpenaiAuth":true}}'

        $model = Get-AdapterModel $provider
        $displayName = Get-AdapterDisplayName $provider
        $promptArguments = [Collections.Generic.List[string]]::new()
        foreach ($argument in @("-P", $provider, "-C", $workDir)) {
            $promptArguments.Add($argument)
        }
        if (-not [string]::IsNullOrEmpty($model)) {
            $promptArguments.Add("-m")
            $promptArguments.Add($model)
        }
        foreach ($argument in @($prompt, "--", "--native-flag", "-leading-value")) {
            $promptArguments.Add($argument)
        }

        $result = Invoke-AdapterCli "$provider-prompt" ([string[]] $promptArguments)
        Assert-AdapterEqual $result.Status 0 "$provider prompt launch failed. stderr: $($result.Stderr)"
        Assert-AdapterEqual $result.Stdout "provider-stdout-$provider" "$provider stdout differs."
        Assert-AdapterEqual `
            $result.Stderr `
            "aagent: selected $displayName via explicit --provider$([Environment]::NewLine)provider-stderr-$provider" `
            "$provider wrapper/provider stderr differs."
        Assert-AdapterRecord `
            (Join-Path $recordDir "$provider.run.1.record") `
            "" `
            ([string[]] (Get-PromptArguments $provider $prompt $model))
        Assert-AdapterFileLine `
            (Join-Path $recordDir "$provider.run.1.record") `
            "cwd.hex=$(ConvertTo-AdapterHex $expectedWorkDir)" `
            "$provider cwd differs."

        $env:AAGENT_FAKE_RUN_STDOUT = ""
        $env:AAGENT_FAKE_RUN_STDERR = ""
        $stdinCase = Get-StdinCase $provider $stdinPayload
        $result = Invoke-AdapterCli "$provider-stdin" @("-P", $provider, "-C", $workDir) $stdinPayload
        Assert-AdapterEqual $result.Status 0 "$provider stdin-only launch failed."
        Assert-AdapterRecord `
            (Join-Path $recordDir "$provider.run.2.record") `
            $stdinCase.Stdin `
            ([string[]] $stdinCase.Arguments)

        $bothCase = Get-BothCase $provider $bothPrompt $bothStdin
        $result = Invoke-AdapterCli "$provider-both" @("-P", $provider, "-C", $workDir, $bothPrompt) $bothStdin
        Assert-AdapterEqual $result.Status 0 "$provider prompt-plus-stdin launch failed."
        Assert-AdapterRecord `
            (Join-Path $recordDir "$provider.run.3.record") `
            $bothCase.Stdin `
            ([string[]] $bothCase.Arguments)

        $env:AAGENT_FAKE_RUN_STDOUT = "quiet-stdout-$provider"
        $env:AAGENT_FAKE_RUN_STDERR = "quiet-stderr-$provider"
        $env:AAGENT_FAKE_RUN_STATUS = "95"
        $result = Invoke-AdapterCli "$provider-quiet" @("-P", $provider, "--quiet", "status test")
        Assert-AdapterEqual $result.Status 95 "$provider non-zero status was remapped."
        Assert-AdapterEqual $result.Stdout "quiet-stdout-$provider" "$provider quiet stdout differs."
        Assert-AdapterEqual $result.Stderr "quiet-stderr-$provider" "$provider quiet suppressed stderr."
        Assert-AdapterEqual ([IO.File]::ReadAllText((Join-Path $recordDir "run.count"), $utf8).Trim()) "4" "$provider launched more than once per request."

        $dryArguments = [Collections.Generic.List[string]]::new()
        foreach ($argument in @("-P", $provider, "--dry-run")) {
            $dryArguments.Add($argument)
        }
        if (-not [string]::IsNullOrEmpty($model)) {
            $dryArguments.Add("-m")
            $dryArguments.Add($model)
        }
        foreach ($argument in @("dry-run-secret-prompt", "--", "--secret-native", "native-secret-value")) {
            $dryArguments.Add($argument)
        }
        $result = Invoke-AdapterCli "$provider-dry" ([string[]] $dryArguments)
        Assert-AdapterEqual $result.Status 0 "$provider dry-run failed."
        Assert-AdapterContains $result.Stdout "provider: $provider" "$provider dry-run ID is missing."
        Assert-AdapterContains $result.Stdout "<prompt>" "$provider dry-run prompt placeholder is missing."
        if ($result.Stdout.Contains("dry-run-secret-prompt")) { throw "$provider dry-run leaked the prompt." }
        if ($result.Stdout.Contains("native-secret-value")) { throw "$provider dry-run leaked a native argument." }
        if (-not [string]::IsNullOrEmpty($model)) {
            if ($result.Stdout.Contains($model)) { throw "$provider dry-run leaked the model value." }
        }
        Assert-AdapterEqual $result.Stderr "" "$provider dry-run wrote a notice."
        Assert-AdapterEqual ([IO.File]::ReadAllText((Join-Path $recordDir "run.count"), $utf8).Trim()) "4" "$provider dry-run launched a provider."

        if ($provider -eq "amp") {
            $result = Invoke-AdapterCli "$provider-model" @("-P", $provider, "-m", "unsupported-model", "model test")
            Assert-AdapterEqual $result.Status 64 "Amp accepted an unsupported model."
            Assert-AdapterContains $result.Stderr "does not support --model" "Amp model error is missing."
            Assert-AdapterEqual ([IO.File]::ReadAllText((Join-Path $recordDir "run.count"), $utf8).Trim()) "4" "Amp model error launched a provider."
        }

        $result = Invoke-AdapterCli "$provider-empty" @("-P", $provider)
        Assert-AdapterEqual $result.Status 64 "$provider empty input was accepted."
        Assert-AdapterContains $result.Stderr "a non-empty prompt or piped stdin is required" "$provider empty input error differs."
        Assert-AdapterEqual ([IO.File]::ReadAllText((Join-Path $recordDir "run.count"), $utf8).Trim()) "4" "$provider empty input launched a provider."

        $adapter = Get-AagentAdapter $provider
        if ([string]::IsNullOrEmpty($adapter.Safety)) {
            throw "$provider safety note is missing."
        }
    }
} finally {
    foreach ($name in $environmentNames) {
        if ($null -eq $originalEnvironment[$name]) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], "Process")
        }
    }
    if (Test-Path -LiteralPath $testDir) {
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}

Write-Host "Adapter PowerShell tests passed."
