# cPanel Nginx Installer

This script installs and configures Nginx (provided by Engintron).

## Installation

```bash
wget https://raw.githubusercontent.com/diyarit/Cp-Nginx-Installer/master/install_engintron.sh && bash install_engintron.sh
```

#### 1-Check if there is another plugin normally used "nginxcp" and remove it before.
#### 2-Download and install Engintron.
#### 3-Set the dynamic cache to 30 seconds.
#### 4-For servers with 1 public IP, add a line in custom_rules to avoid errors with
