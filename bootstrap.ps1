# Setup my execution policy for both the 64 bit and 32 bit shells
Set-ExecutionPolicy Unrestricted
Start-Job -RunAs32 { Set-ExecutionPolicy Unrestricted } | Receive-Job -Wait

# Install the latest stable ChefDK
Invoke-RestMethod 'https://omnitruck.chef.io/install.ps1' | Invoke-Expression
install-project chefdk -verbose

# Install Chocolatey
Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable -n allowGlobalConfirmation

# Get a basic setup recipe
invoke-restmethod 'https://gist.githubusercontent.com/smurawski/da67107b5efd00876af7bb0c8cfe8453/raw' | out-file -encoding ascii -filepath c:/basic.rb

# Use Chef Apply to setup
chef-apply c:/basic.rb
