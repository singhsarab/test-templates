# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

# Templates update script for testfx.

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false)]
    [Alias("s")]
    [System.String] $Source = "C:\Users\sasin\Downloads",

    [Parameter(Mandatory=$false)]
    [Alias("tv")]
    [System.String] $TemplateVersion = "1.4.0"
)

$ErrorActionPreference = "Stop"

#
# Environment Variables
#
Write-Verbose "Setup environment variables."
$env:MSTEST_ROOT_DIR = (Get-Item (Split-Path $MyInvocation.MyCommand.Path)).Parent.FullName
$env:MSTEST_TEMPLATES_DIR = Join-Path $env:MSTEST_ROOT_DIR "Templates"
$env:MSTEST_WIZARDS_DIR = Join-Path $env:MSTEST_ROOT_DIR "WizardExtensions"

#
# Global variables
#
$global:TestFrameworkNugetFilePath = ""
$global:TestAdapterNugetFilePath = ""
$global:TestFrameworkVersion = ""
$global:TestAdapterVerions = ""

# Capture error state in any step globally to modify return code
$Script:ScriptFailed = $false

function Write-Log ([string] $message)
{
    $currentColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = "Green"
    if ($message)
    {
        Write-Output "... $message"
    }
    $Host.UI.RawUI.ForegroundColor = $currentColor
}

function Validate-SourcePath
{
    Write-Log "Validating the Source Path and getting nuget package information..."
    
    $TestFrameworkNugetRegex = [regex]"MSTest.TestFramework.([0-9](.+)).nupkg"
    $TestAdapterNugetRegex = [regex]"MSTest.TestAdapter.([0-9](.+)).nupkg"

    $files = (Get-ChildItem -File $Source).FullName
    foreach($file in $files){
        Write-Verbose "$file"
        $fileName = [System.IO.Path]::GetFileName($file)

        if($fileName -match $TestFrameworkNugetRegex)
        {
            $global:TestFrameworkNugetFilePath = $file
            $global:TestFrameworkVersion = $($matches[1])
            Write-Log "    Found MSTest.TestFramework with version: $TestFrameworkVersion"
        }
        elseif($fileName -match $TestAdapterNugetRegex)
        {
            $global:TestAdapterNugetFilePath = $file
            $global:TestAdapterVersion = $($matches[1])
            Write-Log "    Found MSTest.TestAdapter with version: $TestAdapterVersion"
        }
    }

    if([string]::IsNullOrEmpty($global:TestFrameworkVersion) -or [string]::IsNullOrEmpty($global:TestAdapterVersion))
    {
        Write-Error("Could not find MSTest.TestFramework*.nupkg and/or MSTest.TestAdapter*.nupkg in the specified source path: $Source")
        Set-ScriptFailed
    }

    Write-Log "Validated the Source path. All is good!"
}

function Replace-Nugets
{
    Write-Log "Replacing the nuget packages in the templates"

    $CSDesktopPackagesDir = Join-Path $env:MSTEST_TEMPLATES_DIR "CSharp\Desktop\Packages"
    $CSUWPPackagesDir = Join-Path $env:MSTEST_TEMPLATES_DIR "CSharp\UWP\Packages"
	$VBDesktopPackagesDir = Join-Path $env:MSTEST_TEMPLATES_DIR "VisualBasic\Desktop\Packages"
    $VBUWPPackagesDir = Join-Path $env:MSTEST_TEMPLATES_DIR "VisualBasic\UWP\Packages"

    $packagesDir = ($CSDesktopPackagesDir, $CSUWPPackagesDir, $VBDesktopPackagesDir, $VBUWPPackagesDir)
    foreach($dir in $packagesDir)
    {
        # Delete the old nuget packages.
        Write-Verbose "Remove-Item $dir\*"
        Remove-Item $dir\*

        # Copy over the new ones.
        Write-Verbose "$global:TestFrameworkNugetFilePath $dir -Force"
        Copy-Item $global:TestFrameworkNugetFilePath $dir -Force

        Write-Verbose "$global:TestAdapterNugetFilePath $dir -Force"
        Copy-Item $global:TestAdapterNugetFilePath $dir -Force
    }    

    Write-Log "Replaced the latest nuget packages to the templates."
}

function Edit-Templates
{
    Write-Log "Editing the project template related artifacts.."
    # The following things need to be changed:
    # 1. The vstemplate file to include the latest package contents.
    # 2. The csproj file to point to the latest nugets.
    # 3. The vsixmanifest file version bump.

    Write-Log "   Editing vstemplate artifacts..."
    $CSDesktopProjectTemplateDir = Join-Path $env:MSTEST_TEMPLATES_DIR "CSharp\Desktop\ProjectTemplates\CSharp\Test"
    $CSUWPProjectTemplateDir = Join-Path $env:MSTEST_TEMPLATES_DIR "CSharp\UWP\ProjectTemplates\CSharp\Windows UAP"
	$VBDesktopProjectTemplateDir = Join-Path $env:MSTEST_TEMPLATES_DIR "VisualBasic\Desktop\ProjectTemplates\VisualBasic\Test"
    $VBUWPProjectTemplateDir = Join-Path $env:MSTEST_TEMPLATES_DIR "VisualBasic\UWP\ProjectTemplates\VisualBasic\Windows UAP"
    
    $TestFrameworkvstemplateRegex = [regex]"package id=""MSTest.TestFramework"" version=(.+) skipAssemblyReferences=""false"""
    $TestAdaptervstemplateRegex = [regex]"package id=""MSTest.TestAdapter"" version=(.+) skipAssemblyReferences=""false"""

    $TestFrameworkvstemplateReplacement = "package id=""MSTest.TestFramework"" version=""$global:TestFrameworkVersion"" skipAssemblyReferences=""false"""
    $TestAdaptervstemplateReplacement = "package id=""MSTest.TestAdapter"" version=""$global:TestAdapterVersion"" skipAssemblyReferences=""false"""

    $projecttemplatesDirs = @($CSDesktopProjectTemplateDir, $CSUWPProjectTemplateDir, $VBDesktopProjectTemplateDir, $VBUWPProjectTemplateDir)
    foreach($templateDir in $projecttemplatesDirs)
    {
        $files = (Get-ChildItem -File $templateDir -Filter *.vstemplate).FullName

        foreach($file in $files){
            Write-Verbose "Editing $file"
            $fileContent = Get-Content $file
            $fileContent = $fileContent -replace $TestFrameworkvstemplateRegex,$TestFrameworkvstemplateReplacement
            $fileContent = $fileContent -replace $TestAdaptervstemplateRegex,$TestAdaptervstemplateReplacement
            Out-File $file -InputObject $fileContent -Encoding default
        }
    }

    Write-Log "   Editing csproj artifacts..."
    $CSDesktopTemplateVSIXDir = Join-Path $env:MSTEST_TEMPLATES_DIR "CSharp\Desktop"
    $CSUWPTemplateVSIXDir = Join-Path $env:MSTEST_TEMPLATES_DIR "CSharp\UWP"
    $VBDesktopTemplateVSIXDir = Join-Path $env:MSTEST_TEMPLATES_DIR "VisualBasic\Desktop"
    $VBUWPTemplateVSIXDir = Join-Path $env:MSTEST_TEMPLATES_DIR "VisualBasic\UWP"
    
    $TestFrameworkcsprojRegex = [regex]"Content Include=""packages\\MSTest.TestFramework.(.+).nupkg"""
    $TestAdaptercsprojRegex = [regex]"Content Include=""packages\\MSTest.TestAdapter.(.+).nupkg"""

    $TestFrameworkcsprojReplacement = "Content Include=""packages\MSTest.TestFramework.$global:TestFrameworkVersion.nupkg"""
    $TestAdaptercsprojReplacement = "Content Include=""packages\MSTest.TestAdapter.$global:TestAdapterVersion.nupkg"""

    $templatesVSIXDirs = @($CSDesktopTemplateVSIXDir, $CSUWPTemplateVSIXDir, $VBDesktopTemplateVSIXDir, $VBUWPTemplateVSIXDir)
    foreach($templateDir in $templatesVSIXDirs)
    {
        $files = (Get-ChildItem -File $templateDir -Filter *.csproj).FullName

        foreach($file in $files){
            Write-Verbose "Editing $file"
            $fileContent = Get-Content $file
            $fileContent = $fileContent -replace $TestFrameworkcsprojRegex,$TestFrameworkcsprojReplacement
            $fileContent = $fileContent -replace $TestAdaptercsprojRegex,$TestAdaptercsprojReplacement
            Out-File $file -InputObject $fileContent -Encoding UTF8
        }
    }

    Write-Log "   Editing the template version in the vsixmanifest with $TemplateVersion..."
    
    $CSDesktopManifestRegex = [regex]"Identity Id=""mstestProjectTemplate"" Version=(.+) Language"
    $CSUWPManifestRegex = [regex]"Identity Id=""mstestUniversalProjectTemplate"" Version=(.+) Language"
	$VBDesktopManifestRegex = [regex]"Identity Id=""MSTestDesktopVB.Microsoft.c6c7fff6-20cb-405d-9ad4-a60a6d0c55d9"" Version=(.+) Language"
    $VBUWPManifestRegex = [regex]"Identity Id=""MSTestUWPVB.Microsoft.3dc1d5cd-bbfb-456f-965e-5b962ad063d1"" Version=(.+) Language"

    $CSDesktopManifestReplacement = "Identity Id=""mstestProjectTemplate"" Version=""$TemplateVersion"" Language"
    $CSUWPManifestReplacement = "Identity Id=""mstestUniversalProjectTemplate"" Version=""$TemplateVersion"" Language"
    $VBDesktopManifestReplacement = "Identity Id=""MSTestDesktopVB.Microsoft.c6c7fff6-20cb-405d-9ad4-a60a6d0c55d9"" Version=""$TemplateVersion"" Language"
    $VBUWPManifestReplacement = "Identity Id=""MSTestUWPVB.Microsoft.3dc1d5cd-bbfb-456f-965e-5b962ad063d1"" Version=""$TemplateVersion"" Language"

    foreach($templateDir in $templatesVSIXDirs)
    {
        $files = (Get-ChildItem -File $templateDir -Filter *.vsixmanifest).FullName
        
        foreach($file in $files){
            Write-Verbose "Editing $file"
            $fileContent = Get-Content $file
            $fileContent = $fileContent -replace $CSDesktopManifestRegex,$CSDesktopManifestReplacement
            $fileContent = $fileContent -replace $CSUWPManifestRegex,$CSUWPManifestReplacement
			$fileContent = $fileContent -replace $VBDesktopManifestRegex,$VBDesktopManifestReplacement
            $fileContent = $fileContent -replace $VBUWPManifestRegex,$VBUWPManifestReplacement
            Out-File $file -InputObject $fileContent -Encoding default
        }
    }

    Write-Log "Successfully edited the project template related artifacts.."
}

function Edit-Wizards
{
    Write-Log "Editing wizard experience related artifacts.."

    $intelliTestWizardFile = Join-Path $env:MSTEST_WIZARDS_DIR "MSTestV2IntelliTestExtension\MSTestv2TestFramework.cs"
    
    Write-Verbose "Editing $intelliTestWizardFile"

    $TestFrameworkIWizRegex = [regex]"ShortAssemblyName.FromName\(""MSTest.TestFramework""\), (.+), AssemblyReferenceType.NugetReference"
    $TestAdapterIWizRegex = [regex]"ShortAssemblyName.FromName\(""MSTest.TestAdapter""\), (.+), AssemblyReferenceType.NugetReference"

    $TestFrameworkIWizReplacement = "ShortAssemblyName.FromName(""MSTest.TestFramework""), ""$global:TestFrameworkVersion"", AssemblyReferenceType.NugetReference"
    $TestAdapterIWizReplacement = "ShortAssemblyName.FromName(""MSTest.TestAdapter""), ""$global:TestAdapterVersion"", AssemblyReferenceType.NugetReference"

    $fileContent = Get-Content $intelliTestWizardFile
    $fileContent = $fileContent -replace $TestFrameworkIWizRegex,$TestFrameworkIWizReplacement
    $fileContent = $fileContent -replace $TestAdapterIWizRegex,$TestAdapterIWizReplacement
    Out-File $intelliTestWizardFile -InputObject $fileContent -Encoding utf8
    
    $cutWizardFile = Join-Path $env:MSTEST_WIZARDS_DIR "MSTestv2UnitTestExtension\MSTestv2SolutionManager.cs"

    Write-Verbose "Editing $cutWizardFile"
    
    $TestFrameworkCWizRegex = [regex]"this.EnsureNuGetReference\(unitTestProject, ""MSTest.TestFramework"", (.+)\)"
    $TestAdapterCWizRegex = [regex]"this.EnsureNuGetReference\(unitTestProject, ""MSTest.TestAdapter"", (.+)\)"

    $TestFrameworkCWizReplacement = "this.EnsureNuGetReference(unitTestProject, ""MSTest.TestFramework"", ""$global:TestFrameworkVersion"")"
    $TestAdapterCWizReplacement = "this.EnsureNuGetReference(unitTestProject, ""MSTest.TestAdapter"", ""$global:TestAdapterVersion"")"

    $fileContent = Get-Content $cutWizardFile
    $fileContent = $fileContent -replace $TestFrameworkCWizRegex,$TestFrameworkCWizReplacement
    $fileContent = $fileContent -replace $TestAdapterCWizRegex,$TestAdapterCWizReplacement
    Out-File $cutWizardFile -InputObject $fileContent -Encoding utf8

    Write-Log "   Editing the Wizard vsix version in the vsixmanifest with $TemplateVersion..."
    
    $IntelliTestManifestRegex = [regex]"Identity Id=""MSTestV2IntelliTestExtensionPackage.Microsoft.935a8bb8-364d-46ce-a02f-fbb74f2d9188"" Version=(.+) Language"
    $CUTManifestRegex = [regex]"Identity Id=""MSTestV2UnitTestExtensionPackage.Microsoft.632139eb-968c-47ce-8667-f0898f00833f"" Version=(.+) Language"

    $IntelliTestManifestReplacement = "Identity Id=""MSTestV2IntelliTestExtensionPackage.Microsoft.935a8bb8-364d-46ce-a02f-fbb74f2d9188"" Version=""$TemplateVersion"" Language"
    $CUTManifestReplacement = "Identity Id=""MSTestV2UnitTestExtensionPackage.Microsoft.632139eb-968c-47ce-8667-f0898f00833f"" Version=""$TemplateVersion"" Language"

    $intellitestWizardDir = Join-Path $env:MSTEST_WIZARDS_DIR "MSTestv2IntelliTestExtensionPackage"
    $cutWizardDir = Join-Path $env:MSTEST_WIZARDS_DIR "MSTestv2UnitTestExtensionPackage"

    $wizardVSIXDirs = @($intellitestWizardDir, $cutWizardDir)

    foreach($templateDir in $wizardVSIXDirs)
    {
        $files = (Get-ChildItem -File $templateDir -Filter *.vsixmanifest).FullName
        
        foreach($file in $files){
            Write-Verbose "Editing $file"
            $fileContent = Get-Content $file
            $fileContent = $fileContent -replace $IntelliTestManifestRegex,$IntelliTestManifestReplacement
            $fileContent = $fileContent -replace $CUTManifestRegex,$CUTManifestReplacement
            Out-File $file -InputObject $fileContent -Encoding default
        }
    }

    Write-Log "Successfully edited the wizard experience related artifacts.."
}


function Set-ScriptFailed
{
    $Script:ScriptFailed = $true
}

Write-Log " "
Write-Log "Nice, we have new nuget packages! Updating all code stake-holders. Hold on."
Write-Log "**************************************************************************"

Validate-SourcePath
Replace-Nugets
Edit-Templates
Edit-Wizards

Write-Log " "
Write-Log "**************************************************************************"
Write-Log "*** All good. Please go ahead and push the changes in. ***"
Write-Log "**************************************************************************"

if ($Script:ScriptFailed) { Exit 1 } else { Exit 0 }