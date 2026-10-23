# Builds the unmanaged Dataverse solution D365ContactCenterZendeskCallJourney (source folder + zip).
$root = Split-Path $PSScriptRoot
$src  = Join-Path $PSScriptRoot 'solution-src'
$out  = Join-Path $PSScriptRoot 'D365ContactCenterZendeskCallJourney_1_2_0_0.zip'
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
$CDS = [ordered]@{connectionName='shared_commondataserviceforapps';apiId='/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'}
function Hst($op){ $h=[ordered]@{}; foreach($k in $CDS.Keys){$h[$k]=$CDS[$k]}; $h.operationId=$op; $h }
$trig1 = [ordered]@{When_an_agent_accepts_a_voice_call=[ordered]@{type='OpenApiConnectionWebhook';inputs=[ordered]@{host=(Hst 'SubscribeWebhookTrigger');parameters=[ordered]@{'subscriptionRequest/message'=3;'subscriptionRequest/entityname'='msdyn_ocliveworkitem';'subscriptionRequest/scope'=4;'subscriptionRequest/filteringattributes'='msdyn_isagentaccepted';'subscriptionRequest/filterexpression'="msdyn_isagentaccepted eq true"};authentication=$authP}}}

$actions = [ordered]@{}
$actions.Get_conversation = [ordered]@{runAfter=@{};type='OpenApiConnection';inputs=[ordered]@{host=(Hst 'GetItem');parameters=[ordered]@{entityName='msdyn_ocliveworkitems';recordId="@triggerOutputs()?['body/activityid']";'$select'='msdyn_channel,subject,msdyn_createdon,msdyn_activeagentassignedon,msdyn_channelconnectionid,msdyn_copilotengaged,_msdyn_customer_value,_msdyn_cdsqueueid_value,_msdyn_activeagentid_value'};authentication=$authP}}
$actions.Get_Zendesk_token = [ordered]@{runAfter=[ordered]@{Get_conversation=@('Succeeded')};type='Http';inputs=[ordered]@{method='POST';uri="$base/oauth/tokens";headers=[ordered]@{'Content-Type'='application/json';Accept='application/json'};body=[ordered]@{grant_type='client_credentials';client_id=('@parameters(' + $q + $pCid + $q + ')');client_secret=('@parameters(' + $q + $pSec + $q + ')');scope='read write'}}}
$inside = [ordered]@{}
$inside.Get_customer = [ordered]@{runAfter=@{};type='OpenApiConnection';inputs=[ordered]@{host=$host_;parameters=[ordered]@{entityName='contacts';'$select'='fullname,mobilephone,telephone1,emailaddress1';'$filter'="contactid eq '@{coalesce(items('For_each_call')?['_msdyn_customer_value'], '00000000-0000-0000-0000-000000000000')}'";'$top'=1};authentication=$authP}}
$inside.Upsert_requester = [ordered]@{runAfter=[ordered]@{Get_customer=@('Succeeded','Failed')};type='Http';inputs=[ordered]@{method='POST';uri="$base/api/v2/users/create_or_update.json";headers=$hdr;body=[ordered]@{user=[ordered]@{name=('@coalesce(' + (F 'fullname') + ", 'Unknown caller')");email=('@coalesce(' + (F 'emailaddress1') + ", 'unknown.caller@example.com')");phone=('@coalesce(' + (F 'mobilephone') + ', ' + (F 'telephone1') + ')');role='end-user'}}}}
$inside.Create_Zendesk_ticket = [ordered]@{runAfter=[ordered]@{Upsert_requester=@('Succeeded')};type='Http';inputs=[ordered]@{method='POST';uri="$base/api/v2/tickets.json";headers=$hdr;body=[ordered]@{ticket=[ordered]@{subject=('Inbound call ' + (It 'subject'));comment=[ordered]@{body=$comment;public=$false};requester_id=('@body(' + $q + 'Upsert_requester' + $q + ')?[' + $q + 'user' + $q + ']?[' + $q + 'id' + $q + ']');external_id=(It 'activityid');tags=@('d365cc','voice')}}}}
$loop = [ordered]@{}
$loop.Find_existing_ticket = [ordered]@{runAfter=@{};type='Http';inputs=[ordered]@{method='GET';uri=("$base/api/v2/tickets.json?external_id=" + (It 'activityid'));headers=[ordered]@{Accept='application/json';Authorization=$bearer}}}
$loop.Check_new_call = [ordered]@{runAfter=[ordered]@{Find_existing_ticket=@('Succeeded')};type='If';expression=[ordered]@{and=@(@{equals=@(('@length(body(' + $q + 'Find_existing_ticket' + $q + ')?[' + $q + 'tickets' + $q + '])'),0)})};actions=$inside;else=@{actions=@{}}}
$actions.For_each_call = [ordered]@{runAfter=[ordered]@{Get_Zendesk_token=@('Succeeded')};type='Foreach';foreach="@if(equals(string(body('Get_conversation')?['msdyn_channel']), '192440000'), createArray(body('Get_conversation')), createArray())";actions=$loop}
function EnvP($label,$schema){ [ordered]@{defaultValue='';type='String';metadata=@{schemaName=$schema}} }
$params = [ordered]@{'$connections'=[ordered]@{defaultValue=@{};type='Object'};'$authentication'=[ordered]@{defaultValue=@{};type='SecureObject'}}
$params[$pSub]=EnvP $pSub 'cczd_ZendeskSubdomain'; $params[$pCid]=EnvP $pCid 'cczd_ZendeskClientId'; $params[$pSec]=EnvP $pSec 'cczd_ZendeskClientSecret'
$def = [ordered]@{'$schema'='https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#';contentVersion='1.0.0.0';parameters=$params;triggers=$trig1;actions=$actions;outputs=@{}}
$flow = [ordered]@{properties=[ordered]@{connectionReferences=[ordered]@{shared_commondataserviceforapps=[ordered]@{runtimeSource='embedded';connection=@{connectionReferenceLogicalName='cczd_dataverse'};api=@{name='shared_commondataserviceforapps'}}};definition=$def};schemaVersion='1.0.0.0'}
# ---- Flow 2: when a voice conversation ends, add the call summary, AI quality score and recording/transcript link to the Zendesk ticket
$wf2Id = '7b3e5c1a-9d24-4e8f-b6a0-2c4f1d8e9a35'
$pOrg = 'D365 Environment URL (cczd_D365OrgUrl)'
$ev = "if(equals(length(coalesce(outputs('Get_quality_evaluation')?['body/value'], json('[]'))), 0), json('{}'), first(outputs('Get_quality_evaluation')?['body/value']))"
$ej = "json(coalesce(${ev}?['msdyn_responsejson'], '{}'))"
function Dur($f){ "if(equals(body('Get_conversation')?['$f'], null), 'n/a', concat(string(div(int(body('Get_conversation')?['$f']), 60)), 'm ', string(mod(int(body('Get_conversation')?['$f']), 60)), 's'))" }
$link = "@{parameters('$pOrg')}/main.aspx?appname=new_ContactCenterCallReview&pagetype=entityrecord&etn=msdyn_ocliveworkitem&id=@{triggerOutputs()?['body/activityid']}"
$note = "Call ended (Dynamics 365 Contact Center)`nTalk time: @{$(Dur 'msdyn_conversationtalktimeinseconds')} | Wait: @{$(Dur 'msdyn_conversationfirstwaittimeinseconds')} | Handle: @{$(Dur 'msdyn_conversationhandletimeinseconds')}`nCustomer sentiment: @{coalesce(body('Get_conversation')?['msdyn_customersentimentlabel@OData.Community.Display.V1.FormattedValue'], 'n/a')}`nHandled by virtual agent: @{if(equals(body('Get_conversation')?['msdyn_copilotengaged'], true), 'yes', 'no')}`nAI quality score: @{coalesce(${ev}?['msdyn_evaluationscore'], 'not available yet')}@{if(equals(${ej}?['action_name'], null), '', concat(' (', ${ej}?['action_name'], ')'))}`nAI summary: @{coalesce(${ej}?['overall_summary'], 'not available yet')}`nRecording and transcript: $link"
$inner = [ordered]@{}
$inner.Wait_for_AI_evaluation = [ordered]@{runAfter=@{};type='Wait';inputs=[ordered]@{interval=[ordered]@{count=2;unit='Minute'}}}
$inner.Get_quality_evaluation = [ordered]@{runAfter=[ordered]@{Wait_for_AI_evaluation=@('Succeeded')};type='OpenApiConnection';inputs=[ordered]@{host=(Hst 'ListRecords');parameters=[ordered]@{entityName='msdyn_evaluationhistories';'$select'='msdyn_evaluationscore,msdyn_responsejson,createdon';'$filter'="msdyn_ocliveworkitemid eq '@{triggerOutputs()?['body/activityid']}'";'$orderby'='createdon desc';'$top'=1};authentication=$authP}}
$inner.Get_Zendesk_token = [ordered]@{runAfter=[ordered]@{Get_quality_evaluation=@('Succeeded','Failed')};type='Http';inputs=[ordered]@{method='POST';uri="$base/oauth/tokens";headers=[ordered]@{'Content-Type'='application/json';Accept='application/json'};body=[ordered]@{grant_type='client_credentials';client_id=('@parameters(' + $q + $pCid + $q + ')');client_secret=('@parameters(' + $q + $pSec + $q + ')');scope='read write'}}}
$inner.Find_ticket = [ordered]@{runAfter=[ordered]@{Get_Zendesk_token=@('Succeeded')};type='Http';inputs=[ordered]@{method='GET';uri="$base/api/v2/tickets.json?external_id=@{triggerOutputs()?['body/activityid']}";headers=[ordered]@{Accept='application/json';Authorization=$bearer}}}
$put = [ordered]@{Update_ticket=[ordered]@{runAfter=@{};type='Http';inputs=[ordered]@{method='PUT';uri=("$base/api/v2/tickets/@{first(body('Find_ticket')?['tickets'])?['id']}.json");headers=$hdr;body=[ordered]@{ticket=[ordered]@{comment=[ordered]@{body=$note;public=$false};additional_tags=@('d365cc-ended')}}}}}
$inner.If_ticket_found = [ordered]@{runAfter=[ordered]@{Find_ticket=@('Succeeded')};type='If';expression=[ordered]@{and=@(@{greater=@(('@length(body(' + $q + 'Find_ticket' + $q + ')?[' + $q + 'tickets' + $q + '])'),0)})};actions=$put;else=@{actions=@{}}}
$act2 = [ordered]@{}
$act2.Get_conversation = [ordered]@{runAfter=@{};type='OpenApiConnection';inputs=[ordered]@{host=(Hst 'GetItem');parameters=[ordered]@{entityName='msdyn_ocliveworkitems';recordId="@triggerOutputs()?['body/activityid']";'$select'='msdyn_channel,msdyn_conversationtalktimeinseconds,msdyn_conversationfirstwaittimeinseconds,msdyn_conversationhandletimeinseconds,msdyn_customersentimentlabel,msdyn_copilotengaged'};authentication=$authP}}
$act2.If_voice_call = [ordered]@{runAfter=[ordered]@{Get_conversation=@('Succeeded')};type='If';expression=[ordered]@{and=@(@{equals=@("@string(body('Get_conversation')?['msdyn_channel'])",'192440000')})};actions=$inner;else=@{actions=@{}}}
$trig2 = [ordered]@{When_a_voice_conversation_ends=[ordered]@{type='OpenApiConnectionWebhook';inputs=[ordered]@{host=(Hst 'SubscribeWebhookTrigger');parameters=[ordered]@{'subscriptionRequest/message'=3;'subscriptionRequest/entityname'='msdyn_ocliveworkitem';'subscriptionRequest/scope'=4;'subscriptionRequest/filteringattributes'='statuscode';'subscriptionRequest/filterexpression'='(statuscode eq 4 or statuscode eq 5)'};authentication=$authP}}}
$params2 = [ordered]@{'$connections'=[ordered]@{defaultValue=@{};type='Object'};'$authentication'=[ordered]@{defaultValue=@{};type='SecureObject'}}
$params2[$pSub]=EnvP $pSub 'cczd_ZendeskSubdomain'; $params2[$pCid]=EnvP $pCid 'cczd_ZendeskClientId'; $params2[$pSec]=EnvP $pSec 'cczd_ZendeskClientSecret'; $params2[$pOrg]=EnvP $pOrg 'cczd_D365OrgUrl'
$def2 = [ordered]@{'$schema'='https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#';contentVersion='1.0.0.0';parameters=$params2;triggers=$trig2;actions=$act2;outputs=@{}}
$flow2 = [ordered]@{properties=[ordered]@{connectionReferences=[ordered]@{shared_commondataserviceforapps=[ordered]@{runtimeSource='embedded';connection=@{connectionReferenceLogicalName='cczd_dataverse'};api=@{name='shared_commondataserviceforapps'}}};definition=$def2};schemaVersion='1.0.0.0'}
$wf2File = "D365ContactCenter-AddcallsummarytoZendeskticketwhenacallends-$($wf2Id.ToUpper()).json"
New-Item -ItemType Directory -Force "$src\Workflows" | Out-Null
$wfFile = "D365ContactCenter-CreateZendeskticketwhenanagentacce-$($wfId.ToUpper()).json"
[IO.File]::WriteAllText("$src\Workflows\$wfFile", ($flow | ConvertTo-Json -Depth 40), (New-Object Text.UTF8Encoding $false))
[IO.File]::WriteAllText("$src\Workflows\$wf2File", ($flow2 | ConvertTo-Json -Depth 40), (New-Object Text.UTF8Encoding $false))
# ---- Flow 3: ring signal. While a voice call rings for a human agent, tag the matching Zendesk agent user (d365cc-ring) so the Zendesk app can show an alert; the tag is removed when the call is accepted, dropped or ended.
# The D365 agent is matched to Zendesk by e-mail; when the e-mails differ, every Zendesk agent and admin is alerted instead.
$wf3Id = '3c9a7e52-6b18-4d0f-a5e3-8f1b2d4c6a70'
$a3 = [ordered]@{}
$a3.Get_conversation = [ordered]@{runAfter=@{};type='OpenApiConnection';inputs=[ordered]@{host=(Hst 'GetItem');parameters=[ordered]@{entityName='msdyn_ocliveworkitems';recordId="@triggerOutputs()?['body/activityid']";'$select'='msdyn_channel,msdyn_isagentaccepted,msdyn_isabandoned,msdyn_activeagentassignedon,statuscode,_msdyn_activeagentid_value'};authentication=$authP}}
$tok3 = [ordered]@{runAfter=@{};type='Http';inputs=[ordered]@{method='POST';uri="$base/oauth/tokens";headers=[ordered]@{'Content-Type'='application/json';Accept='application/json'};body=[ordered]@{grant_type='client_credentials';client_id=('@parameters(' + $q + $pCid + $q + ')');client_secret=('@parameters(' + $q + $pSec + $q + ')');scope='read write'}}}
$tagBody = [ordered]@{tags=@('d365cc-ring')}
$ringExpr = "@and(not(equals(coalesce(body('Get_conversation')?['_msdyn_activeagentid_value'], ''), '')), not(equals(body('Get_conversation')?['msdyn_activeagentassignedon'], null)), not(equals(body('Get_conversation')?['msdyn_isagentaccepted'], true)), not(equals(body('Get_conversation')?['msdyn_isabandoned'], true)), not(equals(body('Get_conversation')?['statuscode'], 4)), not(equals(body('Get_conversation')?['statuscode'], 5)))"
$ringYes = [ordered]@{}
$ringYes.Get_agent = [ordered]@{runAfter=@{};type='OpenApiConnection';inputs=[ordered]@{host=(Hst 'GetItem');parameters=[ordered]@{entityName='systemusers';recordId="@body('Get_conversation')?['_msdyn_activeagentid_value']";'$select'='internalemailaddress,accessmode'};authentication=$authP}}
$ringYes.Search_Zendesk_agent = [ordered]@{runAfter=[ordered]@{Get_agent=@('Succeeded')};type='Http';inputs=[ordered]@{method='GET';uri="$base/api/v2/users/search.json?query=email:@{encodeUriComponent(body('Get_agent')?['internalemailaddress'])}";headers=[ordered]@{Accept='application/json';Authorization=$bearer}}}
$ringYes.Target_users = [ordered]@{runAfter=[ordered]@{Search_Zendesk_agent=@('Succeeded')};type='Compose';inputs="@if(greater(length(body('Search_Zendesk_agent')?['users']), 0), body('Search_Zendesk_agent')?['users'], body('List_Zendesk_agents')?['users'])"}
$addTag = [ordered]@{Add_ring_tag=[ordered]@{runAfter=@{};type='Http';inputs=[ordered]@{method='PUT';uri="$base/api/v2/users/@{items('For_each_target')?['id']}/tags.json";headers=$hdr;body=$tagBody}}}
$ringYes.If_human_agent = [ordered]@{runAfter=[ordered]@{Target_users=@('Succeeded')};type='If';expression=[ordered]@{and=@(@{equals=@("@body('Get_agent')?['accessmode']",0)})};actions=[ordered]@{For_each_target=[ordered]@{runAfter=@{};type='Foreach';foreach="@outputs('Target_users')";actions=$addTag}};else=@{actions=@{}}}
$clearTag = [ordered]@{Remove_ring_tag=[ordered]@{runAfter=@{};type='Http';inputs=[ordered]@{method='DELETE';uri="$base/api/v2/users/@{items('For_each_all')?['id']}/tags.json";headers=$hdr;body=$tagBody}}}
$doneExpr = "@or(equals(body('Get_conversation')?['msdyn_isagentaccepted'], true), equals(body('Get_conversation')?['msdyn_isabandoned'], true), equals(body('Get_conversation')?['statuscode'], 4), equals(body('Get_conversation')?['statuscode'], 5))"
$ringNo = [ordered]@{If_call_over=[ordered]@{runAfter=@{};type='If';expression=[ordered]@{and=@(@{equals=@($doneExpr,$true)})};actions=[ordered]@{For_each_all=[ordered]@{runAfter=@{};type='Foreach';foreach="@body('List_Zendesk_agents')?['users']";actions=$clearTag}};else=@{actions=@{}}}}
$in3 = [ordered]@{}
$in3.Get_Zendesk_token = $tok3
$in3.List_Zendesk_agents = [ordered]@{runAfter=[ordered]@{Get_Zendesk_token=@('Succeeded')};type='Http';inputs=[ordered]@{method='GET';uri="$base/api/v2/users.json?role[]=admin&role[]=agent";headers=[ordered]@{Accept='application/json';Authorization=$bearer}}}
$in3.If_ringing = [ordered]@{runAfter=[ordered]@{List_Zendesk_agents=@('Succeeded')};type='If';expression=[ordered]@{and=@(@{equals=@($ringExpr,$true)})};actions=$ringYes;else=@{actions=$ringNo}}
$a3.If_voice_call = [ordered]@{runAfter=[ordered]@{Get_conversation=@('Succeeded')};type='If';expression=[ordered]@{and=@(@{equals=@("@string(body('Get_conversation')?['msdyn_channel'])",'192440000')})};actions=$in3;else=@{actions=@{}}}
$trig3 = [ordered]@{When_a_voice_call_changes=[ordered]@{type='OpenApiConnectionWebhook';inputs=[ordered]@{host=(Hst 'SubscribeWebhookTrigger');parameters=[ordered]@{'subscriptionRequest/message'=4;'subscriptionRequest/entityname'='msdyn_ocliveworkitem';'subscriptionRequest/scope'=4;'subscriptionRequest/filteringattributes'='msdyn_activeagentassignedon,msdyn_isagentaccepted,msdyn_isabandoned,statuscode';'subscriptionRequest/filterexpression'='msdyn_activeagentassignedon ne null or msdyn_isabandoned eq true or statuscode eq 4 or statuscode eq 5'};authentication=$authP}}}
$params3 = [ordered]@{'$connections'=[ordered]@{defaultValue=@{};type='Object'};'$authentication'=[ordered]@{defaultValue=@{};type='SecureObject'}}
$params3[$pSub]=EnvP $pSub 'cczd_ZendeskSubdomain'; $params3[$pCid]=EnvP $pCid 'cczd_ZendeskClientId'; $params3[$pSec]=EnvP $pSec 'cczd_ZendeskClientSecret'
$def3 = [ordered]@{'$schema'='https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#';contentVersion='1.0.0.0';parameters=$params3;triggers=$trig3;actions=$a3;outputs=@{}}
$flow3 = [ordered]@{properties=[ordered]@{connectionReferences=[ordered]@{shared_commondataserviceforapps=[ordered]@{runtimeSource='embedded';connection=@{connectionReferenceLogicalName='cczd_dataverse'};api=@{name='shared_commondataserviceforapps'}}};definition=$def3};schemaVersion='1.0.0.0'}
$wf3File = "D365ContactCenter-SignalringingcalltoZendesk-$($wf3Id.ToUpper()).json"
[IO.File]::WriteAllText("$src\Workflows\$wf3File", ($flow3 | ConvertTo-Json -Depth 40), (New-Object Text.UTF8Encoding $false))
$zip = $out; if(Test-Path $zip){Remove-Item $zip}
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$fs=[IO.File]::Create($zip); $za=New-Object IO.Compression.ZipArchive($fs,[IO.Compression.ZipArchiveMode]::Create)
Get-ChildItem $src -Recurse -File | % { $rel=$_.FullName.Substring($src.Length+1).Replace('\','/'); $e=$za.CreateEntry($rel); $s=$e.Open(); $b=[IO.File]::ReadAllBytes($_.FullName); $s.Write($b,0,$b.Length); $s.Dispose() }
$za.Dispose(); $fs.Dispose()
"built $zip ($((Get-Item $zip).Length) bytes)"

