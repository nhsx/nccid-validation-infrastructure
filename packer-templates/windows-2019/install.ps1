# Python Conda environment
Invoke-WebRequest -Uri "https://github.com/conda-forge/miniforge/releases/download/4.10.3-6/Miniforge3-4.10.3-6-Windows-x86_64.exe" -OutFile Miniforge3-4.10.3-6-Windows-x86_64.exe
Start-Process Miniforge3-4.10.3-6-Windows-x86_64.exe -ArgumentList "/S /InstallationType=AllUsers /AddToPath=1 /RegisterPython=1 /D=%UserProfile%\Miniforge3" -NoNewWindow -Wait -PassThru

# Snakemake
# https://snakemake.readthedocs.io/en/stable/getting_started/installation.html
C:\ProgramData\miniforge3\shell\condabin\conda-hook.ps1
conda env create -n runtime --file=environment-snakemake.yml

# CloudWatch agent
Invoke-WebRequest -Uri https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi -OutFile amazon-cloudwatch-agent.msi
Start-Process msiexec.exe -ArgumentList "/i","amazon-cloudwatch-agent.msi","/passive" -NoNewWindow -Wait -PassThru

# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file-wizard.html
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-EC2-Instance-fleet.html
Move-Item -Path "amazon-cloudwatch-config.json" -Destination "C:\Program Files\Amazon\AmazonCloudWatchAgent\config.json"
& "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1" -a fetch-config -m ec2 -s -c file:"C:\Program Files\Amazon\AmazonCloudWatchAgent\config.json"

# AWS CLI v2
Invoke-WebRequest -Uri https://awscli.amazonaws.com/AWSCLIV2.msi -OutFile AWSCLIV2.msi
Start-Process msiexec.exe -ArgumentList "/i","AWSCLIV2.msi","/passive" -NoNewWindow -Wait -PassThru

# Fix Win Server 2019 Visual Style (hard to see window borders)
Set-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\DWM' -Name ColorPrevalence -Value 1

# Firefox web browser
Invoke-WebRequest -Uri "https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-GB" -OutFile FirefoxSetup.msi
Start-Process msiexec.exe -ArgumentList "/i","FirefoxSetup.msi","/passive" -NoNewWindow -Wait -PassThru
