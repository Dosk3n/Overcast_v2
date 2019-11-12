function Start-Agent {
    param(
            [Parameter(Mandatory=$true)] $Url,
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

    function Create-Agent($HandlerUrl, $Password)
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
            Password = $Password
            HandlerUrl = $HandlerUrl
            SleepTime = 3000
            CreatedBy = 1
            AgentType = 2
            Killed = 0
        }

        $object = New-Object -TypeName PSObject -Property $properties

        Add-Member -memberType ScriptMethod -InputObject $object -Name "ServerOnline" -Value {
            # Check to see if server is online
			try {
                $url = $this.HandlerUrl
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                if ($responseobj.online -eq 1) {
                    "SERVER ONLINE"
                    return 1
                } else {
                    "SERVER NOT ONLINE"
                    return 0
                }
            } 
            catch {
                return 0
            } 
        }   

        Add-Member -memberType ScriptMethod -InputObject $object -Name "CheckIn" -Value {
            # Check to see if server is online
			try {
                $url = $this.HandlerUrl + "/agents/" + $this.ID
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                
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
                }
                $posturl = $this.HandlerUrl + "/agents"
                $response = Invoke-WebRequest -Uri $posturl -Method POST -Body $postParams
                $responseobj = $response.Content | ConvertFrom-Json

                if ($responseobj.agentId -And $responseobj.agentId -gt 0) {
                    $this.ID = $responseobj.agentId
                    $this.registered = 1
                    #return 1 # Returns 1 but not needed to be viewed atm
                } else {
                    return 0
                } 
            } 
            catch {
                Start-Sleep -milliseconds 300
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
                }
                $json = $postparams | ConvertTo-Json;
                $contentType = "application/json"
                $posturl = $this.HandlerUrl + "/agents"
                $response = Invoke-WebRequest -Uri $posturl -Method PUT -ContentType $contentType -Body $json
                $responseobj = $response.Content | ConvertFrom-Json

                $responseobj
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



        return $object
    }

    $agent = Create-Agent -Password $Password -HandlerUrl $url
    # This will loop until killed is set to true
    while($agent.Killed -eq 0)
    {
        # Check that the server responds before progressing
        if ( $agent.ServerOnline() ){

            # Check if agent is registered
            if (!$agent.registered) {
                "Need to register agent"
                $agent.Register()
            } else {
                # Agent is registered so get system info and then update the server with the current details of machine
                if ($agent.GtSysDts()) {
                    if($agent.Update()) {
                        # Now Updated The Server Lets Check in to see if there are any jobs etc
                        #$agent.CheckIn()
                    }
                }
            }
        }
        
        Start-Sleep -milliseconds $agent.SleepTime
    }


}
Start-Agent -Url "http://localhost:3003" -Password "MyAgentsPassword"