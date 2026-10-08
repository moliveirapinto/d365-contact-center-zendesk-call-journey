# Builds the unmanaged Dataverse solution D365ContactCenterZendeskCallJourney (source folder + zip).
$root = Split-Path $PSScriptRoot
$src  = Join-Path $PSScriptRoot 'solution-src'
$out  = Join-Path $PSScriptRoot 'D365ContactCenterZendeskCallJourney_1_0_0_0.zip'
$wfId = 'd6a0e1b4-5c2f-4f6b-9a41-7a1d3c8e2f10'
$q = "'"
function P($n){ "@parameters(" + $q + $n + $q + ")" }
$pSub = 'Zendesk Subdomain (cczd_ZendeskSubdomain)'
$pCid  = 'Zendesk OAuth Client ID (cczd_ZendeskClientId)'
$pSec = 'Zendesk OAuth Client Secret (cczd_ZendeskClientSecret)'
$base = 'https://@{parameters(' + $q + $pSub + $q + ')}.zendesk.com'
$bearer = 'Bearer @{body(' + $q + 'Get_Zendesk_token' + $q + ')?[' + $q + 'access_token' + $q + ']}'
$host_ = [ordered]@{connectionName='shared_commondataserviceforapps';apiId='/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps';operationId='ListRecords'}
$authP = '@parameters(' + $q + '$authentication' + $q + ')'
$cust = 'first(body(' + $q + 'Get_customer' + $q + ')?[' + $q + 'value' + $q + '])'
function F($n){ return $cust + '?[' + $q + $n + $q + ']' }
function It($n){ return '@{items(' + $q + 'For_each_call' + $q + ')?[' + $q + $n + $q + ']}' }
$hdr = [ordered]@{'Content-Type'='application/json';Accept='application/json';Authorization=$bearer}
$fq = '_msdyn_cdsqueueid_value@OData.Community.Display.V1.FormattedValue'
$fa = '_msdyn_activeagentid_value@OData.Community.Display.V1.FormattedValue'
$comment = 'Inbound voice call received ' + (It 'msdyn_createdon') + ".`nQueue: " + (It $fq) + "`nAgent: " + (It $fa) + "`nD365 conversation: " + (It 'activityid')
$actions = [ordered]@{}
$actions.List_accepted_voice_calls = [ordered]@{runAfter=@{};type='OpenApiConnection';inputs=[ordered]@{host=$host_;parameters=[ordered]@{entityName='msdyn_ocliveworkitems';'$select'='subject,msdyn_createdon,msdyn_activeagentassignedon,msdyn_channelconnectionid,msdyn_copilotengaged,_msdyn_customer_value,_msdyn_cdsqueueid_value,_msdyn_activeagentid_value';'$filter'="msdyn_channel eq '192440000' and msdyn_activeagentassignedon ne null and createdon ge @{addMinutes(utcNow(), -30)}";'$top'=20};authentication=$authP}}
$actions.Get_Zendesk_token = [ordered]@{runAfter=[ordered]@{List_accepted_voice_calls=@('Succeeded')};type='Http';inputs=[ordered]@{method='POST';uri="$base/oauth/tokens";headers=[ordered]@{'Content-Type'='application/json';Accept='application/json'};body=[ordered]@{grant_type='client_credentials';client_id=('@parameters(' + $q + $pCid + $q + ')');client_secret=('@parameters(' + $q + $pSec + $q + ')');scope='read write'}}}
$inside = [ordered]@{}
$inside.Get_customer = [ordered]@{runAfter=@{};type='OpenApiConnection';inputs=[ordered]@{host=$host_;parameters=[ordered]@{entityName='contacts';'$select'='fullname,mobilephone,telephone1,emailaddress1';'$filter'="contactid eq '@{coalesce(items('For_each_call')?['_msdyn_customer_value'], '00000000-0000-0000-0000-000000000000')}'";'$top'=1};authentication=$authP}}
$inside.Upsert_requester = [ordered]@{runAfter=[ordered]@{Get_customer=@('Succeeded','Failed')};type='Http';inputs=[ordered]@{method='POST';uri="$base/api/v2/users/create_or_update.json";headers=$hdr;body=[ordered]@{user=[ordered]@{name=('@coalesce(' + (F 'fullname') + ", 'Unknown caller')");email=('@coalesce(' + (F 'emailaddress1') + ", 'unknown.caller@example.com')");phone=('@coalesce(' + (F 'mobilephone') + ', ' + (F 'telephone1') + ')');role='end-user'}}}}
$inside.Create_Zendesk_ticket = [ordered]@{runAfter=[ordered]@{Upsert_requester=@('Succeeded')};type='Http';inputs=[ordered]@{method='POST';uri="$base/api/v2/tickets.json";headers=$hdr;body=[ordered]@{ticket=[ordered]@{subject=('Inbound call ' + (It 'subject'));comment=[ordered]@{body=$comment;public=$false};requester_id=('@body(' + $q + 'Upsert_requester' + $q + ')?[' + $q + 'user' + $q + ']?[' + $q + 'id' + $q + ']');external_id=(It 'activityid');tags=@('d365cc','voice')}}}}
$loop = [ordered]@{}
$loop.Find_existing_ticket = [ordered]@{runAfter=@{};type='Http';inputs=[ordered]@{method='GET';uri=("$base/api/v2/tickets.json?external_id=" + (It 'activityid'));headers=[ordered]@{Accept='application/json';Authorization=$bearer}}}
$loop.Check_new_call = [ordered]@{runAfter=[ordered]@{Find_existing_ticket=@('Succeeded')};type='If';expression=[ordered]@{and=@(@{equals=@(('@length(body(' + $q + 'Find_existing_ticket' + $q + ')?[' + $q + 'tickets' + $q + '])'),0)})};actions=$inside;else=@{actions=@{}}}
$actions.For_each_call = [ordered]@{runAfter=[ordered]@{Get_Zendesk_token=@('Succeeded')};type='Foreach';foreach=('@outputs(' + $q + 'List_accepted_voice_calls' + $q + ')?[' + $q + 'body/value' + $q + ']');actions=$loop}
function EnvP($label,$schema){ [ordered]@{defaultValue='';type='String';metadata=@{schemaName=$schema}} }
$params = [ordered]@{'$connections'=[ordered]@{defaultValue=@{};type='Object'};'$authentication'=[ordered]@{defaultValue=@{};type='SecureObject'}}
$params[$pSub]=EnvP $pSub 'cczd_ZendeskSubdomain'; $params[$pCid]=EnvP $pCid 'cczd_ZendeskClientId'; $params[$pSec]=EnvP $pSec 'cczd_ZendeskClientSecret'
$def = [ordered]@{'$schema'='https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#';contentVersion='1.0.0.0';parameters=$params;triggers=[ordered]@{Every_minute=[ordered]@{type='Recurrence';recurrence=[ordered]@{frequency='Minute';interval=1}}};actions=$actions;outputs=@{}}
$flow = [ordered]@{properties=[ordered]@{connectionReferences=[ordered]@{shared_commondataserviceforapps=[ordered]@{runtimeSource='embedded';connection=@{connectionReferenceLogicalName='cczd_dataverse'};api=@{name='shared_commondataserviceforapps'}}};definition=$def};schemaVersion='1.0.0.0'}
New-Item -ItemType Directory -Force "$src\Workflows" | Out-Null
$wfFile = "D365ContactCenter-CreateZendeskticketwhenanagentacce-$($wfId.ToUpper()).json"
[IO.File]::WriteAllText("$src\Workflows\$wfFile", ($flow | ConvertTo-Json -Depth 40), (New-Object Text.UTF8Encoding $false))
$zip = $out; if(Test-Path $zip){Remove-Item $zip}
Add-Type -A System.IO.Compression.FileSystem
$fs=[IO.File]::Create($zip); $za=New-Object IO.Compression.ZipArchive($fs,[IO.Compression.ZipArchiveMode]::Create)
Get-ChildItem $src -Recurse -File | % { $rel=$_.FullName.Substring($src.Length+1).Replace('\','/'); $e=$za.CreateEntry($rel); $s=$e.Open(); $b=[IO.File]::ReadAllBytes($_.FullName); $s.Write($b,0,$b.Length); $s.Dispose() }
$za.Dispose(); $fs.Dispose()
"built $zip ($((Get-Item $zip).Length) bytes)"

