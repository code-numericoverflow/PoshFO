[Reflection.Assembly]::Load([System.IO.File]::ReadAllBytes("$PSScriptRoot\Bin\Newtonsoft.Json.dll")) | Out-Null

function ConvertFrom-AxXml {
    param (
        [Xml]  $AxXml
    )
    [Newtonsoft.Json.JsonConvert]::SerializeXmlNode($AxXml) | ConvertFrom-Json
}

function Save-AxObject {
    param (
        [Object]   $InputObject,
        [String]   $Path
    )
    $newjson = $InputObject | ConvertTo-Json -Depth 100
    $newXml  = [Newtonsoft.Json.JsonConvert]::DeserializeXmlNode($newjson)
    $newXml.Save($Path)
    $text = Get-Content -Path $Path
    Set-Content -Path $Path -Value $text.Replace("i_type", "i:type")
}

enum YesNo {
    Yes
    No
}

function New-AxLabel {
    param (
        [String]      $Id,
        [String]      $Text,
        [String]      $Description  = ""
    )
    @{Id = $Id; Text = $Text; Description = $Description }
}

function New-AxEnumValue {
    param (
        [String]      $Name,
	    [String]      $Label
    )
    [PSCustomObject] @{Name = $Name ; Label = $Label }
}

function New-AxEnum {
    param (
        [String]           $Name,
        [Object[]]         $AxEnumValues     = @(),
        [String]           $Tags
    )
    [XML]$axXml = "<?xml version=""1.0"" encoding=""utf-8""?>
                    <AxEnum xmlns:i=""http://www.w3.org/2001/XMLSchema-instance"">
	                    <Name>$Name</Name>
	                    <Tags>$Tags</Tags>
	                    <UseEnumValue>No</UseEnumValue>
	                    <EnumValues>
		                    <AxEnumValue>
			                    <Name>NotSet</Name>
			                    <Label>NotSet</Label>
		                    </AxEnumValue>
	                    </EnumValues>
	                    <IsExtensible>true</IsExtensible>
                    </AxEnum>"
    
    $axEnum = ConvertFrom-AxXml -AxXml $axXml
    $axEnum.AxEnum.EnumValues.AxEnumValue = [System.Collections.Generic.List[Object]] $axEnum.AxEnum.EnumValues.AxEnumValue
    $axEnum.AxEnum.EnumValues.AxEnumValue.RemoveAt(0)
    $axEnum.AxEnum.EnumValues.AxEnumValue.AddRange($AxEnumValues)
    $axEnum
}

function New-AxEdt {
    param (
        [String]           $Name,
        [String]           $BaseEdt            = "AxEdtString",
        [String]           $ReferenceTable     = "",
        [String]           $RelatedField       = "",
        [int]              $StringSize         = 0,
        [String]           $Label,
        [String]           $Tags
    )
    [XML]$axXml = "<?xml version=""1.0"" encoding=""utf-8""?>
                    <AxEdt xmlns:i=""http://www.w3.org/2001/XMLSchema-instance"" xmlns=""""
	                    i:type=""$BaseEdt"">
	                    <Name>$Name</Name>
	                    <Label>$Label</Label>
	                    <ReferenceTable>$ReferenceTable</ReferenceTable>
	                    <Tags>$Tags</Tags>
	                    <ArrayElements />
	                    <Relations />
	                    <TableReferences>
		                    <AxEdtTableReference>
			                    <RelatedField>$RelatedField</RelatedField>
			                    <Table>$ReferenceTable</Table>
		                    </AxEdtTableReference>
	                    </TableReferences>
	                    <StringSize>$StringSize</StringSize>
                    </AxEdt>"
    
    $axEdt = ConvertFrom-AxXml -AxXml $axXml
    if ($ReferenceTable -eq "") {
        $axEdt.AxEdt.PSObject.Properties.Remove('ReferenceTable')
        $axEdt.AxEdt.TableReferences.PSObject.Properties.Remove('AxEdtTableReference')
    }
    if ($BaseEdt -ne "AxEdtString" -or $StringSize -eq 0) {
        $axEdt.AxEdt.PSObject.Properties.Remove('StringSize')
    }
    $axEdt
}

function New-AxTableField {
    param (
        [String]           $Name,
        [String]           $Type               = "AxTableFieldString",
        [YesNo]            $AllowEdit          = [YesNo]::No,
        [String]           $ExtendedDataType   = "",
        [String]           $EnumType           = "",
        [YesNo]            $Mandatory          = [YesNo]::No
    )
    [XML]$axXml = "<AxTableField xmlns=""""
	                i_type=""$Type"">
	                <Name>$Name</Name>
	                <AllowEdit>$AllowEdit</AllowEdit>
	                <ExtendedDataType>$ExtendedDataType</ExtendedDataType>
                    <EnumType>$EnumType</EnumType>
	                <Mandatory>$Mandatory</Mandatory>
                </AxTableField>"
    
    $axTableField = ConvertFrom-AxXml -AxXml $axXml
    if ($ExtendedDataType -ne "") {
        $axTableField.AxTableField.PSObject.Properties.Remove('EnumType')
    } else {
        $axTableField.AxTableField.PSObject.Properties.Remove('ExtendedDataType')
    }
    $axTableField
}

function ConvertTo-AxTableFieldFromAxEdt {
    param (
        $AxEdt,
        [String]           $Name               = $AxEdt.AxEdt.Name,
        [YesNo]            $AllowEdit          = [YesNo]::Yes,
        [YesNo]            $Mandatory          = [YesNo]::Yes
    )
    $type = switch ($AxEdt.AxEdt.'@i:type') {
        "AxEdtString"      { "AxTableFieldString"      }
        "AxEdtInt"         { "AxTableFieldInt"         }
        "AxEdtInt64"       { "AxTableFieldInt64"       }
        "AxEdtReal"        { "AxTableFieldReal"        }
        "AxEdtTime"        { "AxTableFieldTime"        }
        "AxEdtDate"        { "AxTableFieldDate"        }
        "AxEdtUtcDateTime" { "AxTableFieldUtcDateTime" }
        "AxEdtEnum"        { "AxTableFieldEnum"        }
        default            { "AxTableFieldString"      }
    }
    $axTableField = New-AxTableField -Name $Name -Type $type -AllowEdit $AllowEdit -Mandatory $Mandatory -ExtendedDataType $AxEdt.AxEdt.Name
    $axTableField
}

function ConvertTo-AxTableFieldFromAxEnum {
    param (
        $AxEnum,
        [String]           $Name               = $AxEnum.AxEnum.Name,
        [YesNo]            $AllowEdit          = [YesNo]::Yes,
        [YesNo]            $Mandatory          = [YesNo]::Yes
    )
    $type = "AxTableFieldEnum"
    $axTableField = New-AxTableField -Name $Name -Type $type -AllowEdit $AllowEdit -Mandatory $Mandatory -EnumType $AxEnum.AxEnum.Name
    $axTableField
}

function New-AxTableFieldGroupField {
    param (
        [String]           $Name
    )
    [XML]$axXml = "<AxTableFieldGroupField>
					    <DataField>$Name</DataField>
				    </AxTableFieldGroupField>"

    $axTableFieldGroupField = ConvertFrom-AxXml -AxXml $axXml
    $axTableFieldGroupField
}

function ConvertTo-AxTableFieldGroupFieldFromAxTableField {
    param (
        $AxTableField
    )
    $axTableFieldGroupField = New-AxTableFieldGroupField -Name $AxTableField.AxTableField.Name
    $axTableFieldGroupField
}

function New-AxTableFieldGroup {
    param (
        [String]           $Name,
        [Object[]]         $AxTableFieldGroupFields    = @(),
        [String]           $Label
    )
    [XML]$axXml = "<AxTableFieldGroup>
			                    <Name>$Name</Name>
			                    <Label>$Label</Label>
			                    <Fields>
				                    <AxTableFieldGroupField>
					                    <DataField>ItemId</DataField>
				                    </AxTableFieldGroupField>
			                    </Fields>
		                    </AxTableFieldGroup>"

    $axTableFieldGroup = ConvertFrom-AxXml -AxXml $axXml
    $axTableFieldGroup.AxTableFieldGroup.Fields = [System.Collections.Generic.List[Object]] $axTableFieldGroup.AxTableFieldGroup.Fields
    $axTableFieldGroup.AxTableFieldGroup.Fields.RemoveAt(0)
    $axTableFieldGroup.AxTableFieldGroup.Fields.AddRange($AxTableFieldGroupFields)
    $axTableFieldGroup
}

function New-AxMasterTable {
    param (
        [String]           $Name,
        [Object[]]         $AxTableFields          = @(),
        [Object[]]         $AxTableFieldGroups     = @(),
        [String]           $IdField                = "",
        [String]           $DescriptionField       = "",
        [String]           $SingularLabel,
        [String]           $Label                  = $SingularLabel,
        [String]           $TitleField1            = $IdField,
        [String]           $TitleField2            = $DescriptionField,
        [String]           $Tags
    )
    if ($IdField -eq "") {
        $IdField = $AxTableFields[0].AxTableField.Name
    }
    if ($TitleField1 -eq "") {
        $TitleField1 = $IdField
    } 
    if ($DescriptionField -eq "") {
        $DescriptionField = $AxTableFields[1].AxTableField.Name
    }
    if ($TitleField2 -eq "") {
        $TitleField2 = $DescriptionField
    } 
    $variableName = $Name.ToLower()
    [XML]$axXml = "<?xml version=""1.0"" encoding=""utf-8""?>
                    <AxTable xmlns:i=""http://www.w3.org/2001/XMLSchema-instance"">
	                    <Name>$Name</Name>
	                    <SourceCode>
	                    </SourceCode>
	                    <Label>$Label</Label>
	                    <SingularLabel>$SingularLabel</SingularLabel>
	                    <SubscriberAccessLevel>
		                    <Read>Allow</Read>
	                    </SubscriberAccessLevel>
	                    <Tags>$Tags</Tags>
	                    <TitleField1>$TitleField1</TitleField1>
	                    <TitleField2>$TitleField2</TitleField2>
	                    <PrimaryIndex>$IdFieldIdx</PrimaryIndex>
	                    <DeleteActions />
	                    <FieldGroups>
		                    <AxTableFieldGroup>
			                    <Name>AutoReport</Name>
			                    <Fields>
				                    <AxTableFieldGroupField>
					                    <DataField>$IdField</DataField>
				                    </AxTableFieldGroupField>
				                    <AxTableFieldGroupField>
					                    <DataField>$TitleField2</DataField>
				                    </AxTableFieldGroupField>
			                    </Fields>
		                    </AxTableFieldGroup>
		                    <AxTableFieldGroup>
			                    <Name>AutoLookup</Name>
			                    <Fields>
				                    <AxTableFieldGroupField>
					                    <DataField>$IdField</DataField>
				                    </AxTableFieldGroupField>
				                    <AxTableFieldGroupField>
					                    <DataField>$TitleField2</DataField>
				                    </AxTableFieldGroupField>
			                    </Fields>
		                    </AxTableFieldGroup>
		                    <AxTableFieldGroup>
			                    <Name>AutoIdentification</Name>
			                    <AutoPopulate>Yes</AutoPopulate>
			                    <Fields />
		                    </AxTableFieldGroup>
		                    <AxTableFieldGroup>
			                    <Name>AutoSummary</Name>
			                    <Fields />
		                    </AxTableFieldGroup>
		                    <AxTableFieldGroup>
			                    <Name>AutoBrowse</Name>
			                    <Fields />
		                    </AxTableFieldGroup>
	                    </FieldGroups>
	                    <Fields>
		                    <AxTableField xmlns=""""
			                    i:type=""AxTableFieldString"">
			                    <Name>ForPersonId</Name>
			                    <AllowEdit>No</AllowEdit>
			                    <ExtendedDataType>ForPersonId</ExtendedDataType>
			                    <Mandatory>Yes</Mandatory>
		                    </AxTableField>
	                    </Fields>
	                    <FullTextIndexes />
	                    <Indexes>
		                    <AxTableIndex>
			                    <Name>$($IdField)Idx</Name>
			                    <AlternateKey>Yes</AlternateKey>
			                    <Fields>
				                    <AxTableIndexField>
					                    <DataField>$IdField</DataField>
				                    </AxTableIndexField>
			                    </Fields>
		                    </AxTableIndex>
	                    </Indexes>
	                    <Mappings />
	                    <Relations>
	                    </Relations>
	                    <StateMachines />
                    </AxTable>"

    $axMasterTable = ConvertFrom-AxXml -AxXml $axXml
    $axMasterTable.AxTable.Fields.AxTableField = [System.Collections.Generic.List[Object]] $axMasterTable.AxTable.Fields.AxTableField
    $axMasterTable.AxTable.Fields.AxTableField.RemoveAt(0)
    $AxTableFields | ForEach-Object {
        $axMasterTable.AxTable.Fields.AxTableField.Add($_.AxTableField)
    }
    $axMasterTable.AxTable.FieldGroups.AxTableFieldGroup = [System.Collections.Generic.List[Object]] $axMasterTable.AxTable.FieldGroups.AxTableFieldGroup
    $AxTableFieldGroups | ForEach-Object {
        $axMasterTable.AxTable.FieldGroups.AxTableFieldGroup.Add($_.AxTableFieldGroup)
    }
    $axMasterTable

#		                    <Declaration><![CDATA[
#public class $Name extends common
#{
#}
#]]></Declaration>
#		                    <Methods>
#			                    <Method>
#				                    <Name>Exist</Name>
#				                    <Source><![CDATA[
#/// <summary>
#/// Exist
#/// </summary>
#/// <tags>$Tags</tags>
#public static boolean Exist($IdField _$IdField)
#{
#    boolean found;
#
#    found = (select firstonly RecId from $Name
#        where   $Name.$IdField == _$IdField).RecId != 0;
#
#    return found;
#}
#]]></Source>
#			                    </Method>
#			                    <Method>
#				                    <Name>find</Name>
#				                    <Source><![CDATA[
#/// <summary>
#/// Find
#/// </summary>
#/// <tags>$Tags</tags>
#public static $Name find($IdField _$IdField,
#    boolean                 _forupdate          = false)
#{
#    $Name $variableName;
#
#    $variableName.selectForUpdate(_forupdate);
#
#    select firstonly $variableName
#        where   $variableName.$IdField == _$IdField;
#
#    return $variableName;
#}
#]]></Source>
#			                    </Method>
#		                    </Methods>


#		                    <AxTableRelation>
#			                    <Name>InventTableRelation</Name>
#			                    <RelatedTable>InventTable</RelatedTable>
#			                    <Constraints>
#				                    <AxTableRelationConstraint xmlns=""""
#					                    i:type=""AxTableRelationConstraintField"">
#					                    <Name>ItemId</Name>
#					                    <Field>ItemId</Field>
#					                    <RelatedField>ItemId</RelatedField>
#				                    </AxTableRelationConstraint>
#			                    </Constraints>
#		                    </AxTableRelation>

}

function New-AxPackageDescriptor {
    [XML]$axXml = "<PackageDescriptor xmlns=""http://schemas.datacontract.org/2004/07/Microsoft.Dynamics.Framework.Tools.ProjectSystem.ExportImport"" xmlns:i=""http://www.w3.org/2001/XMLSchema-instance"">
                  <ContentResourceDictionary xmlns:a=""http://schemas.microsoft.com/2003/10/Serialization/Arrays""/>
                  <PackageVersion xmlns:a=""http://schemas.datacontract.org/2004/07/System"">
                    <a:_Build>-1</a:_Build>
                    <a:_Major>1</a:_Major>
                    <a:_Minor>1</a:_Minor>
                    <a:_Revision>-1</a:_Revision>
                  </PackageVersion>
                </PackageDescriptor>"

    $axPackageDescriptor = ConvertFrom-AxXml -AxXml $axXml
    $axPackageDescriptor
}

function New-AxModelInfo {
    param (
        [String]     $Name            = "FleetManagement",
        [String]     $ModelModule     = "FleetManagement",
        [String]     $DisplayName     = "Fleet Management",
        [String]     $Description     = "Sample application to demonstrate capability of the Dynamics 365 for Operations framework." 
    )
    [XML]$axXml = "<AxModelInfo xmlns:i=""http://www.w3.org/2001/XMLSchema-instance"">
                      <AppliedUpdates i:nil=""true"" xmlns:a=""http://schemas.microsoft.com/2003/10/Serialization/Arrays""/>
                      <Customization>DoNotAllow</Customization>
                      <Description>$Description</Description>
                      <DisplayName>$DisplayName</DisplayName>
                      <Id>256</Id>
                      <Layer>8</Layer>
                      <Locked>false</Locked>
                      <ModelModule>$ModelModule</ModelModule>
                      <ModelReferences i:nil=""true"" xmlns:a=""http://schemas.microsoft.com/2003/10/Serialization/Arrays""/>
                      <ModuleReferences xmlns:a=""http://schemas.microsoft.com/2003/10/Serialization/Arrays"">
                        <a:string>ApplicationPlatform</a:string>
                        <a:string>ApplicationFoundation</a:string>
                        <a:string>Directory</a:string>
                        <a:string>Dimensions</a:string>
                        <a:string>SourceDocumentation</a:string>
                      </ModuleReferences>
                      <Name>$Name</Name>
                      <Publisher>Microsoft Corporation</Publisher>
                      <SolutionId>00000000-0000-0000-0000-000000000000</SolutionId>
                      <VersionBuild>9206</VersionBuild>
                      <VersionMajor>10</VersionMajor>
                      <VersionMinor>0</VersionMinor>
                      <VersionRevision>22379</VersionRevision>
                    </AxModelInfo>"

    $axModelInfo = ConvertFrom-AxXml -AxXml $axXml
    $axModelInfo
}

function New-AxProjectContent {
    param (
        [String]    $AxType,
        [String]    $Name
    )
    "<Content Include=""$AxType\$Name"">
        <SubType>Content</SubType>
        <Name>$Name</Name>
        <Link>$Name</Link>
    </Content>"
}

function New-AxProject {
    param (
        [String]     $Name       = "AxProject",
        [String]     $Model      = "FleetManagement",
        [String]     $guid       = [Guid]::NewGuid(),
        [Object[]]   $AxEnums    = @(),
        [Object[]]   $AxEdts     = @(),
        [Object[]]   $AxTables   = @()
    )
    $projectContents = ""
    $axEnumContents   = $AxEnums   | ForEach-Object { 
        $content = New-AxProjectContent -AxType "AxEnum"   -Name $_.AxEnum.Name
        $projectContents += $content
    }
    $axEdtContents    = $AxEdts    | ForEach-Object {
        $content = New-AxProjectContent -AxType "AxEdt"    -Name $_.AxEdt.Name
        $projectContents += $content
    }
    $axTableContents  = $AxTables  | ForEach-Object {
        $content = New-AxProjectContent -AxType "AxTable"  -Name $_.AxTable.Name
        $projectContents += $content
    }

    [XML]$axXml = "<?xml version=""1.0"" encoding=""utf-8""?>
                    <Project ToolsVersion=""14.0"" DefaultTargets=""Build"" xmlns=""http://schemas.microsoft.com/developer/msbuild/2003"">
                      <PropertyGroup>
                        <Configuration Condition="" '`$(Configuration)' == '' "">Debug</Configuration>
                        <Platform Condition="" '`$(Platform)' == '' "">AnyCPU</Platform>
                        <BuildTasksDirectory Condition="" '`$(BuildTasksDirectory)' == ''"">`$(MSBuildProgramFiles32)\MSBuild\Microsoft\Dynamics\AX</BuildTasksDirectory>
                        <Model>$Model</Model>
                        <TargetFrameworkVersion>v4.6</TargetFrameworkVersion>
                        <OutputPath>bin</OutputPath>
                        <SchemaVersion>2.0</SchemaVersion>
                        <GenerateCrossReferences>True</GenerateCrossReferences>
                        <ProjectGuid>{$guid}</ProjectGuid>
                        <Name>$Name</Name>
                        <RootNamespace>$Name</RootNamespace>
                      </PropertyGroup>
                      <PropertyGroup Condition=""'`$(Configuration)|`$(Platform)' == 'Debug|AnyCPU'"">
                        <Configuration>Debug</Configuration>
                        <DBSyncInBuild>False</DBSyncInBuild>
                        <GenerateFormAdaptors>False</GenerateFormAdaptors>
                        <Company>
                        </Company>
                        <Partition>initial</Partition>
                        <PlatformTarget>AnyCPU</PlatformTarget>
                        <DataEntityExpandParentChildRelations>False</DataEntityExpandParentChildRelations>
                        <DataEntityUseLabelTextAsFieldName>False</DataEntityUseLabelTextAsFieldName>
                      </PropertyGroup>
                      <PropertyGroup Condition="" '`$(Configuration)' == 'Debug' "">
                        <DebugSymbols>true</DebugSymbols>
                        <EnableUnmanagedDebugging>false</EnableUnmanagedDebugging>
                      </PropertyGroup>
                      <ItemGroup>
                      $projectContents
                      </ItemGroup>
                      <Import Project=""`$(MSBuildBinPath)\Microsoft.Common.targets"" />
                      <Import Project=""`$(BuildTasksDirectory)\Microsoft.Dynamics.Framework.Tools.BuildTasks.targets"" />
                    </Project>"

                      #<ItemGroup>
                      #  <Folder Include=""Contents\"" />
                      #</ItemGroup>

    $axProject = ConvertFrom-AxXml -AxXml $axXml
    $axProject
}

$enum                  = New-AxEnum -Name "pepito" -AxEnumValues @((New-AxEnumValue -Name "pp" -Label "kk" ), (New-AxEnumValue -Name "pp2" -Label "kk2" ))
$idEdt                 = New-AxEdt -Name "pepId" -Label "@FOR01" -BaseEdt AxEdtString -ReferenceTable Customers -RelatedField FirstName
$descriptionEdt        = New-AxEdt -Name "pepDescription" -Label "@FOR02" -BaseEdt AxEdtString
$idTableField          = ConvertTo-AxTableFieldFromAxEdt -AxEdt $idEdt
$descriptionTableField = ConvertTo-AxTableFieldFromAxEdt -AxEdt $descriptionEdt
$pepitoTableField      = ConvertTo-AxTableFieldFromAxEnum -AxEnum $enum
$tableGroupField       = ConvertTo-AxTableFieldGroupFieldFromAxTableField -AxTableField $descriptionTableField
$tableFieldGroup       = New-AxTableFieldGroup      -Name MyTableGroup  -Label "@FOR03" -AxTableFieldGroupFields @($tableGroupField)
$masterTable           = New-AxMasterTable          -Name MyMasterTable -Label "@FOR04" -AxTableFields @($idTableField, $descriptionTableField, $pepitoTableField) -AxTableFieldGroups @($tableFieldGroup)
$modelInfo             = New-AxModelInfo
$project               = New-AxProject              -Name MyProject     -AxEnums $enum -AxEdts @($idEdt, $descriptionEdt) -AxTables $masterTable
$descriptor            = New-AxPackageDescriptor

Remove-Item "C:\WINDOWS\TEMP\TestFO" -Recurse -Force

MkDir "C:\WINDOWS\TEMP\TestFO\ProjectItem\AxEnum"  -ErrorAction SilentlyContinue | Out-Null
MkDir "C:\WINDOWS\TEMP\TestFO\ProjectItem\AxEdt"   -ErrorAction SilentlyContinue | Out-Null
MkDir "C:\WINDOWS\TEMP\TestFO\ProjectItem\AxTable" -ErrorAction SilentlyContinue | Out-Null
MkDir "C:\WINDOWS\TEMP\TestFO\Model"               -ErrorAction SilentlyContinue | Out-Null
MkDir "C:\WINDOWS\TEMP\TestFO\Project"             -ErrorAction SilentlyContinue | Out-Null

Save-AxObject -InputObject $enum             -Path "C:\WINDOWS\TEMP\TestFO\ProjectItem\AxEnum\pepito.xml"
Save-AxObject -InputObject $idEdt            -Path "C:\WINDOWS\TEMP\TestFO\ProjectItem\AxEdt\pepId.xml"
Save-AxObject -InputObject $descriptionEdt   -Path "C:\WINDOWS\TEMP\TestFO\ProjectItem\AxEdt\pepDescription.xml"
Save-AxObject -InputObject $masterTable      -Path "C:\WINDOWS\TEMP\TestFO\ProjectItem\AxTable\MyMasterTable.xml"
Save-AxObject -InputObject $modelInfo        -Path "C:\WINDOWS\TEMP\TestFO\Model\FleetManagement.xml"
Save-AxObject -InputObject $project          -Path "C:\WINDOWS\TEMP\TestFO\Project\MyProject.rnrproj"
Save-AxObject -InputObject $descriptor       -Path "C:\WINDOWS\TEMP\TestFO\BA6BECB9-70B9-4E31-BD29-1A3725A0BA4F.xml"

Compress-Archive -Path "C:\WINDOWS\TEMP\TestFO\*" -DestinationPath "C:\WINDOWS\TEMP\TestFO.zip" -Force
Remove-Item "C:\WINDOWS\TEMP\TestFO.axpp" -Force
Rename-Item "C:\WINDOWS\TEMP\TestFO.zip" "C:\WINDOWS\TEMP\TestFO.axpp" -Force
