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
    Set-Content -Path $Path -Value $text.Replace("i_type", "i:type").Replace("i_nil", "i:nil")
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
        [ValidateSet("AxEdtString","AxEdtInt","AxEdtInt64", "AxEdtReal", "AxEdtTime", "AxEdtDate", "AxEdtUtcDateTime", "AxEdtEnum", "AxEdtBoolean")]
        [String]           $Type               = "AxEdtString",
        [String]           $Extends            = "",
        [String]           $ReferenceTable     = "",
        [String]           $RelatedField       = "",
        [int]              $StringSize         = 0,
        [String]           $Label,
        [String]           $Tags
    )
    [XML]$axXml = "<?xml version=""1.0"" encoding=""utf-8""?>
                    <AxEdt xmlns:i=""http://www.w3.org/2001/XMLSchema-instance"" xmlns=""""
	                    i_type=""$Type"">
	                    <Name>$Name</Name>
	                    <Label>$Label</Label>
                    	<Extends>$Extends</Extends>
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
    if ($Type -ne "AxEdtString" -or $StringSize -eq 0) {
        $axEdt.AxEdt.PSObject.Properties.Remove('StringSize')
    }
    if ($Extends -eq "") {
        $axEdt.AxEdt.PSObject.Properties.Remove('Extends')
    }
    $axEdt
}

function New-AxTableField {
    param (
        [String]           $Name,
        [ValidateSet("AxTableFieldString","AxTableFieldInt","AxTableFieldInt64", "AxTableFieldReal", "AxTableFieldTime", "AxTableFieldDate", "AxTableFieldUtcDateTime", "AxTableFieldEnum", "AxTableFieldBoolean")]
        [String]           $Type               = "AxTableFieldString",
        [String]           $AllowEdit          = [YesNo]::No,
        [String]           $ExtendedDataType   = "",
        [String]           $EnumType           = "",
        [String]           $Mandatory          = [YesNo]::No
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
        [String]           $AllowEdit          = [YesNo]::Yes,
        [String]           $Mandatory          = [YesNo]::Yes
    )
    $type = ($AxEdt.AxEdt.'@i_type').Replace("AxEdt", "AxTableField")
    $axTableField = New-AxTableField -Name $Name -Type $type -AllowEdit $AllowEdit -Mandatory $Mandatory -ExtendedDataType $AxEdt.AxEdt.Name
    $axTableField
}

function ConvertTo-AxTableFieldFromAxEnum {
    param (
        $AxEnum,
        [String]           $Name               = $AxEnum.AxEnum.Name,
        [String]           $AllowEdit          = [YesNo]::Yes,
        [String]           $Mandatory          = [YesNo]::Yes
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
    $axTableFieldGroup.AxTableFieldGroup.Fields.AxTableFieldGroupField = [System.Collections.Generic.List[Object]] $axTableFieldGroup.AxTableFieldGroup.Fields.AxTableFieldGroupField
    $axTableFieldGroup.AxTableFieldGroup.Fields.AxTableFieldGroupField.RemoveAt(0)
    $AxTableFieldGroupFields | ForEach-Object {
        $axTableFieldGroup.AxTableFieldGroup.Fields.AxTableFieldGroupField.Add($_.AxTableFieldGroupField)
    }
    $axTableFieldGroup
}

function New-AxTableFieldRelation {
    param (
        [String]        $RelatedTable,
        [String]        $RelatedField,
        [String]        $ConstrainName     = $RelatedField,
        [String]        $Field             = $RelatedField
    )
    [XML]$axXml = "<AxTableRelation>
			                    <Name>$($RelatedTable)Relation</Name>
			                    <RelatedTable>$RelatedTable</RelatedTable>
			                    <Constraints>
				                    <AxTableRelationConstraint xmlns=""""
					                    i_type=""AxTableRelationConstraintField"">
					                    <Name>$ConstrainName</Name>
					                    <Field>$Field</Field>
					                    <RelatedField>$RelatedField</RelatedField>
				                    </AxTableRelationConstraint>
			                    </Constraints>
		                    </AxTableRelation>"

    $axTableRelation = ConvertFrom-AxXml -AxXml $axXml
    $axTableRelation
}

function New-AxTableIndexField {
    param (
        [String]     $DataFieldName
    )
    [XML]$axXml = "<AxTableIndexField>
					    <DataField>$DataFieldName</DataField>
				    </AxTableIndexField>"

    $axTableIndexField = ConvertFrom-AxXml -AxXml $axXml
    $axTableIndexField
}

function ConvertTo-AxTableIndexFieldFromFromAxTableField {
    param (
        $AxTableField
    )
    $axTableField = New-AxTableIndexField -DataFieldName $AxTableField.AxTableField.Name
    $axTableField
}

function New-AxTableIndex {
    param (
        [String]        $Name,
        [String]        $AlternateKey             ,
        [Object]        $AxTableIndexFields       = @()
    )
	[XML]$axXml = "<AxTableIndex>
			            <Name>$Name</Name>
			            <AlternateKey>$AlternateKey</AlternateKey>
			            <Fields>
				            <AxTableIndexField>
					            <DataField>DataFieldSample</DataField>
				            </AxTableIndexField>
			            </Fields>
		            </AxTableIndex>"

    $axTableIndex = ConvertFrom-AxXml -AxXml $axXml
    $axTableIndex.AxTableIndex.Fields.AxTableIndexField = [System.Collections.Generic.List[Object]] $axTableIndex.AxTableIndex.Fields.AxTableIndexField
    $axTableIndex.AxTableIndex.Fields.AxTableIndexField.RemoveAt(0)
    $AxTableIndexFields | ForEach-Object {
        $axTableIndex.AxTableIndex.Fields.AxTableIndexField.Add($_.AxTableIndexField)
    }
    $axTableIndex
}

function New-AxMethod {
    param (
        [String]   $Name,
        [String]   $Source
    )
    [XML]$axXml = "<Method>
				                    <Name>$Name</Name>
				                    <Source><![CDATA[
$Source
]]></Source>
			                    </Method>"
    $axMethod = ConvertFrom-AxXml -AxXml $axXml
    $axMethod
}

function New-AxExistMethod {
    param (
        [String]    $IdField        = "",
        [String]    $VariableName   = "",
        [String]    $Tags           = ""
    )
    New-AxMethod -Name Exist -Source "
/// <summary>
/// Exist
/// </summary>
/// <tags>$Tags</tags>
public static boolean Exist($IdField _$IdField)
{
    boolean found;

    found = (select firstonly RecId from $variableName
        where   $variableName.$IdField == _$IdField).RecId != 0;

    return found;
}
"
}

function New-AxFindMethod {
    param (
        [String]    $IdField        = "",
        [String]    $Name           = "",
        [String]    $VariableName   = $Name.ToLower(),
        [String]    $Tags           = ""
    )
    New-AxMethod -Name Find -Source "
/// <summary>
/// Find
/// </summary>
/// <tags>$Tags</tags>
public static $Name find($IdField _$IdField,
    boolean                 _forupdate          = false)
{
    $Name $variableName;

    $variableName.selectForUpdate(_forupdate);

    select firstonly $variableName
        where   $variableName.$IdField == _$IdField;

    return $variableName;
}
"
}

function New-AxTable {
    param (
        [String]           $Name,
        [String]           $SingularLabel,
        [String]           $Label                  = $SingularLabel,
        [Object[]]         $AxTableFields          = @(),
        [Object[]]         $AxTableFieldGroups     = @(),
        [Object[]]         $AxTableIndexes         = @(),
        [Object[]]         $AxTableRelations       = @(),
        [String]           $TitleField1            = $AxTableFields[0].AxTableField.Name,
        [String]           $TitleField2            = $AxTableFields[1].AxTableField.Name,
        [String]           $PrimaryIndexName       = $AxTableIndexes[0].AxTableIndex.Name,
        [String]           $Tags
    )
    [XML]$axXml = "<?xml version=""1.0"" encoding=""utf-8""?>
                    <AxTable xmlns:i=""http://www.w3.org/2001/XMLSchema-instance"">
	                    <Name>$Name</Name>
	                    <SourceCode>
		                    <Declaration><![CDATA[
public class $Name extends common
{
}
]]></Declaration>
		                    <Methods>
			                    <Method>
				                    <Name>Exist</Name>
				                    <Source><![CDATA[
/// <summary>
/// Exist
/// </summary>
/// <tags>$Tags</tags>
public static boolean Exist($IdField _$IdField)
{
    boolean found;

    found = (select firstonly RecId from $variableName
        where   $variableName.$IdField == _$IdField).RecId != 0;

    return found;
}
]]></Source>
			                    </Method>
		                    </Methods>
	                    </SourceCode>
	                    <Label>$Label</Label>
	                    <SingularLabel>$SingularLabel</SingularLabel>
	                    <SubscriberAccessLevel>
		                    <Read>Allow</Read>
	                    </SubscriberAccessLevel>
	                    <Tags>$Tags</Tags>
	                    <TitleField1>$TitleField1</TitleField1>
	                    <TitleField2>$TitleField2</TitleField2>
	                    <PrimaryIndex>$PrimaryIndexName</PrimaryIndex>
	                    <DeleteActions />
	                    <FieldGroups>
		                    <AxTableFieldGroup>
			                    <Name>AutoReport</Name>
			                    <Fields>
				                    <AxTableFieldGroupField>
					                    <DataField>$TitleField1</DataField>
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
					                    <DataField>$TitleField1</DataField>
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
			                    i_type=""AxTableFieldString"">
			                    <Name>TableFieldNameSample</Name>
			                    <AllowEdit>No</AllowEdit>
			                    <ExtendedDataType>ExtendedDataTypeSample</ExtendedDataType>
			                    <Mandatory>Yes</Mandatory>
		                    </AxTableField>
	                    </Fields>
	                    <FullTextIndexes />
	                    <Indexes>
		                    <AxTableIndex>
			                    <Name>IndexNameSample</Name>
			                    <AlternateKey>Yes</AlternateKey>
			                    <Fields>
				                    <AxTableIndexField>
					                    <DataField>TableIndexFieldSample</DataField>
				                    </AxTableIndexField>
			                    </Fields>
		                    </AxTableIndex>
	                    </Indexes>
	                    <Mappings />
	                    <Relations>
		                    <AxTableRelation>
			                    <Name>InventTableRelation</Name>
			                    <RelatedTable>InventTable</RelatedTable>
			                    <Constraints>
				                    <AxTableRelationConstraint xmlns=""""
					                    i_type=""AxTableRelationConstraintField"">
					                    <Name>ItemId</Name>
					                    <Field>ItemId</Field>
					                    <RelatedField>ItemId</RelatedField>
				                    </AxTableRelationConstraint>
			                    </Constraints>
		                    </AxTableRelation>
	                    </Relations>
	                    <StateMachines />
                    </AxTable>"

    $axTable = ConvertFrom-AxXml -AxXml $axXml
    $axTable.AxTable.SourceCode.Methods.Method = [System.Collections.Generic.List[Object]] $axTable.AxTable.SourceCode.Methods.Method
    $axTable.AxTable.SourceCode.Methods.Method.RemoveAt(0)
    if ($PrimaryIndexName -ne "") {
        $existMethod = New-AxExistMethod -IdField $TitleField1 -VariableName $Name -Tags $Tags
        $axTable.AxTable.SourceCode.Methods.Method.Add($existMethod.Method)
        $findMethod = New-AxFindMethod -IdField $TitleField1 -Name $Name -Tags $Tags
        $axTable.AxTable.SourceCode.Methods.Method.Add($findMethod.Method)
    }
    $axTable.AxTable.Fields.AxTableField = [System.Collections.Generic.List[Object]] $axTable.AxTable.Fields.AxTableField
    $axTable.AxTable.Fields.AxTableField.RemoveAt(0)
    $AxTableFields | ForEach-Object {
        $axTable.AxTable.Fields.AxTableField.Add($_.AxTableField)
    }
    $axTable.AxTable.FieldGroups.AxTableFieldGroup = [System.Collections.Generic.List[Object]] $axTable.AxTable.FieldGroups.AxTableFieldGroup
    $AxTableFieldGroups | ForEach-Object {
        $axTable.AxTable.FieldGroups.AxTableFieldGroup.Add($_.AxTableFieldGroup)
    }
    $axTable.AxTable.Indexes.AxTableIndex = [System.Collections.Generic.List[Object]] $axTable.AxTable.Indexes.AxTableIndex
    $axTable.AxTable.Indexes.AxTableIndex.RemoveAt(0)
    $AxTableIndexes | ForEach-Object {
        $axTable.AxTable.Indexes.AxTableIndex.Add($_.AxTableIndex)
    }
    $axTable.AxTable.Relations.AxTableRelation = [System.Collections.Generic.List[Object]] $axTable.AxTable.Relations.AxTableRelation
    $axTable.AxTable.Relations.AxTableRelation.RemoveAt(0)
    $AxTableRelations | ForEach-Object {
        $axTable.AxTable.Relations.AxTableRelation.Add($_.AxTableRelation)
    }
    $axTable
}

function New-AxFormDataSourceField {
    param (
        [String]     $FieldName
    )
    [XML]$axXml = "<AxFormDataSourceField>
					    <DataField>$FieldName</DataField>
				    </AxFormDataSourceField>"

    $axFormDataSourceField = ConvertFrom-AxXml -AxXml $axXml
    $axFormDataSourceField
}

function New-AxFormControl {
    param (
        [String]    $Name,
        [String]    $Type               = "String",
        [String]    $DataField          = "",
        [String]    $DataMethod         = "",
        [String]    $DataSource,
        [String]    $FormControlType    = "AxFormStringControl"   # https://docs.microsoft.com/en-us/dynamicsax-2012/developer/form-control-classes
    )
    [XML]$axXml = "<AxFormControl xmlns=""""
						i_type=""$FormControlType"">
						<Name>$Name</Name>
						<Type>$Type</Type>
						<FormControlExtension
							i_nil=""true"" />
						<DataMethod>$DatMethod</DataMethod>
						<DataField>$DataField</DataField>
						<DataSource>$DataSource</DataSource>
					</AxFormControl>"

    $axFormControl = ConvertFrom-AxXml -AxXml $axXml
    if ($DataField -ne "") {
        $axFormControl.AxFormControl.PSObject.Properties.Remove('DataMethod')
    } else {
        $axFormControl.AxFormControl.PSObject.Properties.Remove('DataField')
    }
    $axFormControl
}

function ConvertTo-AxFormControlFromAxTableField {
    param (
        $AxTableField,
        [String]  $DataSourceName
    )
    $type = ($AxTableField.AxTableField.'@i_type').Replace("AxTableField", "")
    $formControlType = "AxForm" + $type + "Control"
    $axFormControl = New-AxFormControl -Type $type -Name ($AxTableField.AxTableField.Name + "Control") -DataField $AxTableField.AxTableField.Name -DataSource $DataSourceName -FormControlType $formControlType
    $axFormControl
}

function New-AxSimpleListForm {
    param (
        [Object]      $AxTable,
        [String]      $TableName                = $AxTable.AxTable.Name,
        [Object[]]    $AxFormDataSourceFields   = @(),
        [Object[]]    $AxFormControls           = @(),
        [String]      $Name                     = $TableName,
        [String]      $DSName                   = $TableName,
        [String]      $Caption                  = $AxTable.AxTable.Label,
        [String]      $QuickFilterField         = $AxTable.AxTable.Fields.AxTableField[0].Name,
        [String]      $ConfigurationKey
    )
    [XML]$axXml = "<?xml version=""1.0"" encoding=""utf-8""?>
                    <AxForm xmlns:i=""http://www.w3.org/2001/XMLSchema-instance"" xmlns=""Microsoft.Dynamics.AX.Metadata.V6"">
	                    <Name>$Name</Name>
	                    <SourceCode>
		                    <Methods xmlns="""">
			                    <Method>
				                    <Name>classDeclaration</Name>
				                    <Source><![CDATA[
[Form]
public class $Name extends FormRun
{
}

]]></Source>
			                    </Method>
		                    </Methods>
		                    <DataSources xmlns="""" />
		                    <DataControls xmlns="""" />
		                    <Members xmlns="""" />
	                    </SourceCode>
	                    <DataSources>
		                    <AxFormDataSource xmlns="""">
			                    <Name>$DSName</Name>
			                    <Table>$TableName</Table>
			                    <Fields>
				                    <AxFormDataSourceField>
					                    <DataField>AssortmentGroupId</DataField>
				                    </AxFormDataSourceField>
			                    </Fields>
			                    <ReferencedDataSources />
			                    <DataSourceLinks />
			                    <DerivedDataSources />
		                    </AxFormDataSource>
	                    </DataSources>
	                    <Design>
		                    <Caption xmlns="""">$Caption</Caption>
		                    <DataSource xmlns="""">$DSName</DataSource>
		                    <Pattern xmlns="""">SimpleList</Pattern>
		                    <PatternVersion xmlns="""">1.1</PatternVersion>
		                    <ShowDeleteButton xmlns="""">Yes</ShowDeleteButton>
		                    <ShowNewButton xmlns="""">Yes</ShowNewButton>
		                    <Style xmlns="""">SimpleList</Style>
		                    <Controls xmlns="""">
			                    <AxFormControl xmlns=""""
				                    i_type=""AxFormActionPaneControl"">
				                    <Name>ActionPane</Name>
				                    <ConfigurationKey>$ConfigurationKey</ConfigurationKey>
				                    <Type>ActionPane</Type>
				                    <FormControlExtension
					                    i:nil=""true"" />
				                    <Controls>
					                    <AxFormControl xmlns=""""
						                    i_type=""AxFormButtonGroupControl"">
						                    <Name>Txt</Name>
						                    <Type>ButtonGroup</Type>
						                    <FormControlExtension
							                    i:nil=""true"" />
						                    <Controls>
						                    </Controls>
						                    <DataSource>$DSName</DataSource>
					                    </AxFormControl>
				                    </Controls>
			                    </AxFormControl>
			                    <AxFormControl xmlns=""""
				                    i_type=""AxFormGroupControl"">
				                    <Name>FormGroup</Name>
				                    <Pattern>CustomAndQuickFilters</Pattern>
				                    <PatternVersion>1.1</PatternVersion>
				                    <Type>Group</Type>
				                    <WidthMode>SizeToAvailable</WidthMode>
				                    <FormControlExtension
					                    i:nil=""true"" />
				                    <Controls>
					                    <AxFormControl>
						                    <Name>QuickFilter</Name>
						                    <FormControlExtension>
							                    <Name>QuickFilterControl</Name>
							                    <ExtensionComponents />
							                    <ExtensionProperties>
								                    <AxFormControlExtensionProperty>
									                    <Name>targetControlName</Name>
									                    <Type>String</Type>
									                    <Value>Grid</Value>
								                    </AxFormControlExtensionProperty>
								                    <AxFormControlExtensionProperty>
									                    <Name>placeholderText</Name>
									                    <Type>String</Type>
								                    </AxFormControlExtensionProperty>
								                    <AxFormControlExtensionProperty>
									                    <Name>defaultColumnName</Name>
									                    <Type>String</Type>
									                    <Value>Grid_$QuickFilterField</Value>
								                    </AxFormControlExtensionProperty>
							                    </ExtensionProperties>
						                    </FormControlExtension>
					                    </AxFormControl>
				                    </Controls>
				                    <ArrangeMethod>HorizontalLeft</ArrangeMethod>
				                    <DataSource>$DSName</DataSource>
				                    <FrameType>None</FrameType>
				                    <Style>CustomFilter</Style>
				                    <ViewEditMode>Edit</ViewEditMode>
			                    </AxFormControl>
			                    <AxFormControl xmlns=""""
				                    i_type=""AxFormGridControl"">
				                    <Name>Grid</Name>
				                    <Type>Grid</Type>
				                    <FormControlExtension
					                    i:nil=""true"" />
				                    <Controls>
					                    <AxFormControl xmlns=""""
						                    i_type=""AxFormStringControl"">
						                    <Name>Grid_AssortmentGroupId</Name>
						                    <Type>String</Type>
						                    <FormControlExtension
							                    i:nil=""true"" />
						                    <DataField>AssortmentGroupId</DataField>
						                    <DataSource>$DSName</DataSource>
					                    </AxFormControl>
				                    </Controls>
				                    <DataSource>$DSName</DataSource>
				                    <Style>Tabular</Style>
			                    </AxFormControl>
		                    </Controls>
	                    </Design>
	                    <Parts />
                    </AxForm>" 

    $axSimpleListForm = ConvertFrom-AxXml -AxXml $axXml
    # AxFormDataSourceField
    $axSimpleListForm.AxForm.DataSources.AxFormDataSource.Fields.AxFormDataSourceField = [System.Collections.Generic.List[Object]] $axSimpleListForm.AxForm.DataSources.AxFormDataSource.Fields.AxFormDataSourceField
    $axSimpleListForm.AxForm.DataSources.AxFormDataSource.Fields.AxFormDataSourceField.RemoveAt(0)
    $AxFormDataSourceFields | ForEach-Object {
        $axSimpleListForm.AxForm.DataSources.AxFormDataSource.Fields.AxFormDataSourceField.Add($_.AxFormDataSourceField)
    }
    # AxFormControl
    $axSimpleListForm.AxForm.Design.Controls.AxFormControl[2].Controls.AxFormControl = [System.Collections.Generic.List[Object]] $axSimpleListForm.AxForm.Design.Controls.AxFormControl[2].Controls.AxFormControl
    $axSimpleListForm.AxForm.Design.Controls.AxFormControl[2].Controls.AxFormControl.RemoveAt(0)
    $AxFormControls | ForEach-Object {
        $axSimpleListForm.AxForm.Design.Controls.AxFormControl[2].Controls.AxFormControl.Add($_.AxFormControl)
    }

    $axSimpleListForm
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
        [String]     $Name           = "AxProject",
        [String]     $guid           = [Guid]::NewGuid(),
        [Object[]]   $AxEnums        = @(),
        [Object[]]   $AxEdts         = @(),
        [Object[]]   $AxTables       = @(),
        [Object[]]   $AxForms        = @(),
        [Object]     $AxModelInfo    = (New-AxModelInfo),
        [Object]     $AxDescriptor   = (New-AxPackageDescriptor)

    )
    $modelName = $AxModelInfo.AxModelInfo.Name
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
    $axFormContents  = $AxForms  | ForEach-Object {
        $content = New-AxProjectContent -AxType "AxForm"  -Name $_.AxForm.Name
        $projectContents += $content
    }

    [XML]$axXml = "<?xml version=""1.0"" encoding=""utf-8""?>
                    <Project ToolsVersion=""14.0"" DefaultTargets=""Build"" xmlns=""http://schemas.microsoft.com/developer/msbuild/2003"">
                      <PropertyGroup>
                        <Configuration Condition="" '`$(Configuration)' == '' "">Debug</Configuration>
                        <Platform Condition="" '`$(Platform)' == '' "">AnyCPU</Platform>
                        <BuildTasksDirectory Condition="" '`$(BuildTasksDirectory)' == ''"">`$(MSBuildProgramFiles32)\MSBuild\Microsoft\Dynamics\AX</BuildTasksDirectory>
                        <Model>$modelName</Model>
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

    $project = ConvertFrom-AxXml -AxXml $axXml
    [PSCustomObject] @{
        AxEnums       = $AxEnums 
        AxEdts        = $AxEdts  
        AxTables      = $AxTables
        AxForms       = $AxForms 
        Project       = $project
        AxModelInfo   = $AxModelInfo
        AxDescriptor  = $AxDescriptor
    }
}

function Save-AxProject {
    param (
        $AxProject,
        [String]     $BasePath        = [Environment]::GetFolderPath('MyDocuments') + "\FOProjects",
        [String]     $ProjectPath     = $BasePath +"\" + $AxProject.Project.Project.PropertyGroup[0].Name
    )
    $projectName    = $AxProject.Project.Project.PropertyGroup[0].Name
    $modelInfoName  = $AxProject.AxModelInfo.AxModelInfo.Name

    Remove-Item $ProjectPath -Recurse -Force -ErrorAction SilentlyContinue

    MkDir "$ProjectPath\ProjectItem\AxEnum"  -ErrorAction SilentlyContinue | Out-Null
    MkDir "$ProjectPath\ProjectItem\AxEdt"   -ErrorAction SilentlyContinue | Out-Null
    MkDir "$ProjectPath\ProjectItem\AxTable" -ErrorAction SilentlyContinue | Out-Null
    MkDir "$ProjectPath\ProjectItem\AxForm"  -ErrorAction SilentlyContinue | Out-Null
    MkDir "$ProjectPath\Model"               -ErrorAction SilentlyContinue | Out-Null
    MkDir "$ProjectPath\Project"             -ErrorAction SilentlyContinue | Out-Null

    $AxProject.AxEnums   | ForEach-Object {
        Save-AxObject -InputObject $_ -Path "$ProjectPath\ProjectItem\AxEnum\$($_.AxEnum.Name).xml"
    }
    $AxProject.AxEdts    | ForEach-Object {
        Save-AxObject -InputObject $_ -Path "$ProjectPath\ProjectItem\AxEdt\$($_.AxEdt.Name).xml"
    }
    $AxProject.AxTables  | ForEach-Object {
        Save-AxObject -InputObject $_ -Path "$ProjectPath\ProjectItem\AxTable\$($_.AxTable.Name).xml"
    }
    $AxProject.AxForms   | ForEach-Object {
        Save-AxObject -InputObject $_ -Path "$ProjectPath\ProjectItem\AxForm\$($_.AxForm.Name).xml"
    }
    
    Save-AxObject -InputObject $AxProject.AxModelInfo     -Path "$ProjectPath\Model\$modelInfoName.xml"
    Save-AxObject -InputObject $AxProject.Project         -Path "$ProjectPath\Project\$projectName.rnrproj"
    Save-AxObject -InputObject $AxProject.AxDescriptor    -Path "$ProjectPath\BA6BECB9-70B9-4E31-BD29-1A3725A0BA4F.xml"

    Compress-Archive -Path "$ProjectPath\*" -DestinationPath "$BasePath\$projectName.zip" -Force
    Remove-Item "$BasePath\$projectName.axpp" -Force -ErrorAction SilentlyContinue
    Rename-Item "$BasePath\$projectName.zip" "$BasePath\$projectName.axpp" -Force
}

function Get-AxClassSource {
    param (
        [String] $Path
    )
    $xml = [xml] (Get-Content $Path)
    $xml.AxClass.SourceCode.Methods | % { $_.Method.Source.'#cdata-section' }
}

# Enums
$familyStatusEnum = New-AxEnum -Name ForFamilyStatus -AxEnumValues @(
    New-AxEnumValue -Name Active   -Label ActiveLabel
    New-AxEnumValue -Name Inactive -Label InactiveLabel
    New-AxEnumValue -Name Unknown  -Label UnknownLabel
)
# EDTs
$familyIdEdt          = New-AxEdt -Name ForFamilyId          -Extends SysGroup    -ReferenceTable ForFamily -RelatedField FamilyId -Label FamilyLabel
$familyDescriptionEdt = New-AxEdt -Name ForFamilyDescription -Extends Description
# TableFields
$idField          = ConvertTo-AxTableFieldFromAxEdt  -AxEdt  $familyIdEdt          -Name $familyIdEdt.AxEdt.Name.Substring(3)  -AllowEdit ([YesNo]::No)
$descriptionField = ConvertTo-AxTableFieldFromAxEdt  -AxEdt  $familyDescriptionEdt -Name $familyDescriptionEdt.AxEdt.Name.Substring(3)
$statusField      = ConvertTo-AxTableFieldFromAxEnum -AxEnum $familyStatusEnum     -Name $familyStatusEnum.AxEnum.Name.Substring(3)
#$eventField = ConvertTo-AxTableFieldFromAxEdt  -AxEdt BusinessEventId       -Name BusinessEventId
# FieldGrops
$allFieldGroup = New-AxTableFieldGroup -Name All -Label AllLabel -AxTableFieldGroupFields @(
    ConvertTo-AxTableFieldGroupFieldFromAxTableField -AxTableField $idField
    ConvertTo-AxTableFieldGroupFieldFromAxTableField -AxTableField $descriptionField
    ConvertTo-AxTableFieldGroupFieldFromAxTableField -AxTableField $statusField
    #ConvertTo-AxTableFieldGroupFieldFromAxTableField -AxTableField $eventField
)
# Index
$familyIdx = New-AxTableIndex -Name FamilyIdx -AlternateKey ([YesNo]::Yes) -AxTableIndexFields @(
    ConvertTo-AxTableIndexFieldFromFromAxTableField -AxTableField $idField
)
# Table
$familyTable = New-AxTable -Name ForFamily -SingularLabel "@FOR05" -Label "@FOR06" -AxTableFields @(
    $idField         
    $descriptionField
    $statusField     
    #$eventField
) -AxTableFieldGroups @(
    $allFieldGroup
) -AxTableIndexes @(
    $familyIdx
) -AxTableRelations @(
)
# Form
$familyForm = New-AxSimpleListForm -AxTable $familyTable -DSName $familyTable.AxTable.Name.Substring(3) -AxFormDataSourceFields @(
    $idField, $descriptionField, $statusField | ForEach-Object {
        New-AxFormDataSourceField -FieldName $_.AxTableField.Name
    }
) -AxFormControls @(
    $idField, $descriptionField, $statusField | ForEach-Object {
        ConvertTo-AxFormControlFromAxTableField -AxTableField $_ -DataSourceName $familyTable.AxTable.Name.Substring(3)
    }
)
# Project
$project = New-AxProject -Name MyProject -AxEnums @(
    $familyStatusEnum
) -AxEdts @(
    $familyIdEdt         
    $familyDescriptionEdt    
) -AxTables @(
    $familyTable
) -AxForms @(
    $familyForm
)

Save-AxProject -AxProject $project
