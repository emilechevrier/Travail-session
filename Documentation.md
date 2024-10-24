# Documentation

## Modules
Liste des modules utilisés dans ce projet.

## Description

- **AD-TO-PSQL** : L'objectif du module AD-TO-PSQL est de faciliter la maintenance des permissions d'une base de données en copiant les groupes de l'active directory dans la base de données. Cette fonction est fait pour gérer les permissions de lecture, écriture, création et suppression pour les utilisateur du logiciel. Parfois les applications peuvent utiliser les permissions de l'active directory , mais cette librairie est faites pour donner les permissions mêmes la base de donnée pour éviter les oublies dans le logiciel. 

## Commandes de création

### Hyper-v
Installtion du module hyper-v. Le redémarrage est automatique.
```
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All 
```
Tapez "Y" dans le terminal pour redémarrer la votre machine  

![Say_yes_image](./image/Image_1_say_yes.png)



## Installation

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser


## Commandes
Les commandes PowerShell suivantes sont utilisées dans le script :

```powershell
# Commande pour lister les fichiers dans un répertoire

```
Install Putty
```
Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-installer.msi" -OutFile "$env:TEMP\putty-installer.msi"
```
```
Start-Process msiexec.exe -ArgumentList "/i $env:TEMP\putty-installer.msi /quiet" -Wait
```


## Références

Manifest 
___
* https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/new-modulemanifest?view=powershell-7.4

Secure string
___
* https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/convertto-securestring?view=powershell-7.4


### Commandes utiles (personnel pour travailler)

 New-ModuleManifest -Path ./AD_TO_PSQL.psd1 `
