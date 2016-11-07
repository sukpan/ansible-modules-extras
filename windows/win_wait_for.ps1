#!powershell
# win_wait_for
# Author: Paul Northrop (GitHub: @sukpan), SAS Institute, Inc. (GitHub: @sassoftware)
#
# Purpose: To mimic the core ansible module "wait_for" on Windows platforms
#
#
# Copyright (c) 2016 SAS Institute, Inc.
#
# This module is licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.

# WANT_JSON
# POWERSHELL_COMMON


$ErrorActionPreference = "Stop"

# ================================================================
# Functions
# ================================================================

Function getConnDetails {
    param(  [string]$TargetHost,
            [string]$TargetPort,
            [string]$Timeout)

    $outputobj = New-Object PSObject
    $outputobj | Add-Member -MemberType NoteProperty -Name TargetHostName -Value $TargetHost            

    if(Test-Connection -ComputerName $TargetHost -count 2 -ErrorAction SilentlyContinue) {            
        $outputobj | Add-Member -MemberType NoteProperty -Name TargetHostStatus -Value "ONLINE"            
    } else {            
        $outputobj | Add-Member -MemberType NoteProperty -Name TargetHostStatus -Value "OFFLINE"            
    }            

    $outputobj | Add-Member -MemberType NoteProperty -Name PortNumber -Value $TargetPort       

    $Socket = New-Object System.Net.Sockets.TCPClient            
    $Connection = $Socket.BeginConnect($Targethost,$TargetPort,$null,$null)            
    $Connection.AsyncWaitHandle.WaitOne($Timeout,$false)  | Out-Null            

    if($Socket.Connected -eq $true) {            
        $outputobj | Add-Member -MemberType NoteProperty -Name ConnectionStatus -Value $true            
    } else {            
        $outputobj | Add-Member -MemberType NoteProperty -Name ConnectionStatus -Value $false           
    }            

    $Socket.Close | Out-Null                        
    return $outputobj           

}


Function getConnectionCount() {

    param(  [string]$ExcludeHosts, 
            [string]$LocalPort)

    [string[]] $hosts=($ExcludeHosts).Split(',') 

    [string[]]$ips = ""
    foreach ($myhost in $hosts)  
    {
        try
        {
            [string[]]$ipaddress = [System.Net.Dns]::GetHostAddresses($myhost) 
        
            foreach ($ip in $ipaddress)
                {
                    $ips+=$ip
                }
        }
        catch
        {
            continue
        }
    }
    $excl=  $ips | sort-object | Get-Unique

    $connCount=-1


    $conns=Get-NetTCPConnection -LocalPort $LocalPort -ErrorAction SilentlyContinue

    $conns = $conns | Where-Object { $_.State -notin "Listen" -and $_.RemoteAddress -notin $excl}
    $connCount=($conns.State).Count

    return $connCount

}

# ================================================================
# Parameters
# ================================================================
$params = Parse-Args $args;

# result
$result = New-Object PSObject;
Set-Attr $result "changed" $false;
Set-Attr $result "failed" $false;

# connect_timeout
$connect_timeout = Get-AnsibleParam -obj $params -name "connect_timeout" -default "5"

# delay - time to wait before checking required condition
$delay = Get-AnsibleParam -obj $params -name "delay" -default "0"

# exclude_hosts
$exclude_hosts = Get-AnsibleParam -obj $params -name "exclude_hosts" 

## If exclude_hosts is an array of strings, convert to a comma separated list
If ($exclude_hosts -is [system.array])
    {
        $exclude_hosts = $exclude_hosts -Join ','
    }

# _host - called _host as host is a reserved object in PowerShell
$_host = Get-AnsibleParam -obj $params -name "host" -default "127.0.0.1"

# path
$path = Get-AnsibleParam -obj $params -name "path"

# name - alias for path
$name = Get-AnsibleParam -obj $params -name "name"

# path
$path = Get-AnsibleParam -obj $params -name "path"

# port
$port = Get-AnsibleParam -obj $params -name "port"

# search_regex
$search_regex = Get-AnsibleParam -obj $params -name "search_regex"

# state
$state = Get-AnsibleParam -obj $params -name "state" -default "started" -ValidateSet "present", "started", "stopped", "absent", "drained" -resultobj $result

# timeout
$timeout = Get-AnsibleParam -obj $params -name "timeout" -default "300"

# sleep - time to wait between each check of required condition - default 1 second
$sleep = Get-AnsibleParam -obj $params -name "sleep" -default "1"





# ================================================================
# Validation
# ================================================================

If ($delay -lt 0)
    {
        Fail-Json $result  "delay cannot be negative"
    }

If ($timeout -lt 0)
    {
        Fail-Json $result  "timeout cannot be negative"
    }

If ($delay -ge $timeout)
    {
        Fail-Json $result  "delay must be less than timeout"
    }   

If ($name -and $path)
    {
        Fail-Json $result  "name and path cannot both be specified"
    }

If ( ($name -or $path) -and !($state -or $search_regex) )
    {
        # set path to the value of name, as the main code uses path variable
        Fail-Json $result  "you must specify either state or search_regex when using a file name or path"
    }    

If ($name)
    {
        # set path to the value of name, as the main code uses path variable
        $path = "$name"
    }

If ($port -and $path)
    {
        Fail-Json $result  "port and path parameter can not both be passed to the win_wait_for module"
    }

If ($path -and ($state -eq "stopped") )
    {
        Fail-Json $result  "state=stopped should only be used for checking a port in the win_wait_for module"
    }

If ($path -and ($state -eq "drained") )
    {
        Fail-Json $result  "state=drained should only be used for checking a port in the win_wait_for module"
    }

If ($port -and $path)
    {
        Fail-Json $result  "port and path parameter can not both be passed to win_wait_for module"
    }

If ($exclude_hosts -and !($state -eq "drained") )
    {
        Fail-Json $result  "exclude_hosts should only be with state=drained with win_wait_for module"
    }

If (!($port) -and ($state -eq "drained") )
    {
        Fail-Json $result  "port must be provided for state=drained with win_wait_for module"
    }

# ================================================================
# Variable initialisation
# ================================================================

$done=$false

$iterations=0


# ================================================================
# Main section
# ================================================================
Try {
    $start = Get-Date
    $stop_at = $start.AddSeconds($timeout)
    
    # Don't sleep if no path or port is set as all we want to do is a pure wait. 
    If ( ($delay -gt 0) -and ($path -or $port) ) 
        {
            sleep $delay
            Set-Attr $result "slept" $true
        }
	Else
        {
            Set-Attr $result "slept" $false
        }

    If ( !($path) -and !($port) -and ($state -ne "drained") )
        {
            # just wait
            sleep $timeout
            $done = $true;
            
            # set iterations to 1 so the status is changed
            $iterations = 1
            $done = $true
        }
    ElseIf ( ($state -eq "absent") -or ($state -eq "stopped") )
        {
            While ( !($done) -and ( (Get-Date) -lt $stop_at) )
                {
                    If ($path) 
                        {
                            # wait for file to be removed
                            If (!(Test-Path -Path $path -PathType Leaf)) 
                                {
                                    $done = $true;
                                    break
                                }
                        }
                    If ($port) 
                        {
                            # wait for port to be unresponsive
                            $portCheck = getConnDetails -TargetHost $_host -TargetPort $port -Timeout $connect_timeout
                            if ($portCheck.TargetHostStatus -eq "OFFLINE")
                                {
                                    Fail-Json $result  "host '$_host' cannot be resolved"
                                }
                            if ( !($portCheck.ConnectionStatus) )
                                {
                                    $done = $true;
                                    break
                                }

                        }
                        
                    sleep $sleep
                    $iterations = $iterations + 1                        
                }
                
                If ( !$done )
                    {
                        $finished = Get-Date
                        $elapsed = $finished - $start
                                                
                        Set-Attr $result "elapsed" $elapsed.Seconds

                        If ($path)
                            {
                                Set-Attr $result "path" $path
                                Fail-Json $result  "timeout exceeded waiting for $path to be absent"
                            }
                        If ($port)
                            {
                                Set-Attr $result "port" $port
                                Fail-Json $result  "timeout exceeded waiting for $_host on $port to be stopped"
                            }
                    }
        }
    ElseIf ( ($state -eq "started") -or ($state -eq "present") )
        {
            While ( !($done) -and ( (Get-Date) -lt $stop_at) )
                {
                    If ($path) 
                        {
                            # wait for file to exist
                            If ((Test-Path -Path $path -PathType Leaf)) 
                                {
                                    If ($search_regex) 
                                        {                
                                            # read the files contents and match against the regular expression
                                            $contents = Get-Content $path -Raw | Select-String $search_regex
                                            If ($contents -ne $null)
                                                {
                                                    $done = $true;
                                                    break
                                                }
                                        }
                                    Else 
                                        {
                                        $done = $true;
                                        break
                                        }
                                }
                        }
                    If ($port) 
                        {
                            # wait for port to respond
                            $portCheck = getConnDetails -TargetHost $_host -TargetPort $port -Timeout $connect_timeout
                            if ($portCheck.TargetHostStatus -eq "OFFLINE")
                                {
                                    Fail-Json $result  "host '$_host' cannot be resolved"
                                }
                            if ( $portCheck.ConnectionStatus )
                                {
                                    $done = $true;
                                    break
                                }

                        }
                        
                    sleep $sleep
                    $iterations = $iterations + 1                        
                }
                
                If ( !$done )
                    {
                        $finished = Get-Date
                        $elapsed = $finished - $start
                                                
                        Set-Attr $result "elapsed" $elapsed.Seconds

                        If ($path -and !($search_regex) )
                            {
                                Set-Attr $result "path" $path
                                Fail-Json $result  "timeout exceeded waiting for $path to be present"
                            }
                        If ($port)
                            {
                                Set-Attr $result "port" $port
                                Fail-Json $result  "timeout exceeded waiting for $_host on $port to be present"
                            }
                        If ($path -and $search_regex)
                            {
                                Set-Attr $result "path" $path
                                Fail-Json $result  "timeout exceeded waiting for line regular expression match in $path to be present"
                            }                            
                    }        
        }
    ElseIf ( ($state -eq "drained") )
        {
            ### wait until all active connections are gone
            
            While ( !($done) -and ( (Get-Date) -lt $stop_at) )
                {
                    $active_connections = getConnectionCount -ExcludeHosts $exclude_hosts -LocalPort $port
                    If ($active_connections -eq 0)
                        {
                            $done = $true
                            break
                        }
                    sleep $sleep
                    $iterations = $iterations + 1                                        
                }
            If (!$done)
                {
                    Set-Attr $result "port" $port
                    Set-Attr $result "exclude_hosts" $exclude_hosts
                    Fail-Json $result  "timeout exceeded waiting for $_host on $port to be drained"                
                }        
        }

    $finished = Get-Date
    $elapsed = $finished - $start

    Set-Attr $result "elapsed" $elapsed.Seconds

    If ($done -and $iterations -eq 0) 
        {
            Set-Attr $result "changed" $false;
        }    
    ElseIf ($done) 
        {
            Set-Attr $result "changed" $true;
        }    
    Else 
        {
            Fail-Json $result  "timeout exceeded waiting for condition"
        }


}
Catch {
    $ErrorMessage = $_.Exception.Message
    Fail-Json $result "an unhandled error occured. Error message is '$ErrorMessage'."
}

Exit-Json $result
