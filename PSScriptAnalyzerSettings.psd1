@{
    # PSScriptAnalyzer settings for the llm-settings repo.
    # Picked up automatically by `Invoke-ScriptAnalyzer -Settings <this file>`
    # in CI, and by editors (VS Code PowerShell extension) that auto-discover
    # this file at the workspace root.

    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Write-Host is the right API for an interactive installer that prints
        # coloured progress to a user who just typed `.\install.ps1`. The rule
        # was created when Write-Host was a black hole; PowerShell 5.0 (2016)
        # rewired it to the Information stream, so output is now redirectable
        # (`6>file.log`) and capturable (`6>&1`). The "use Write-Information"
        # alternative requires opting in with $InformationPreference and loses
        # colour support — strictly worse for our use case.
        'PSAvoidUsingWriteHost',

        # `iwr | iex` is the upstream-documented install path for elan
        # (https://elan.lean-lang.org/elan-init.ps1). Downloading to a temp
        # file and dot-sourcing has identical security properties with more
        # code, and would diverge from the official Lean docs.
        'PSAvoidUsingInvokeExpression',

        # `New-Link` is a private bootstrap helper used in exactly one place
        # (install.ps1). Adding [CmdletBinding(SupportsShouldProcess)] is
        # ceremony for a function with no external consumer and no -WhatIf
        # use case (a partial install would leave the machine in a worse
        # state than just running it).
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
