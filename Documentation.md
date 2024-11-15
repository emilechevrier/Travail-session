# Documentation

## Modules
Liste des modules utilisés dans ce projet.

## Description

- **AD-TO-PSQL** : L'objectif du module AD-TO-PSQL est de faciliter la maintenance des permissions d'une base de données en copiant les groupes de l'Active Directory dans la base de données. Cette fonction est faite pour gérer les permissions de lecture, écriture, création et suppression pour les utilisateurs du logiciel. Parfois, les applications peuvent utiliser les permissions de l'Active Directory, mais cette librairie est conçue pour donner les permissions directement dans la base de données afin d'éviter les oublis dans le logiciel.

## Installation de .NET

1. Installer le package développeur :
   Télécharger .NET Framework

2. Exécuter les commandes suivantes dans PowerShell :
   ```powershell
   Invoke-WebRequest -Uri https://dot.net/v1/dotnet-install.ps1 -OutFile dotnet-install.ps1
   powershell -ExecutionPolicy Bypass -File ./dotnet-install.ps1 -Channel 8.0
   ```

3. Mettre à jour la variable d'environnement :
   ```
   C:\Users\Administrator\AppData\Local\Microsoft\dotnet
   ```

4. Créer un nouveau projet :
   ```powershell
   mkdir "C:\Program Files\npgsql"
   dotnet new console -n MyNpgsqlProject
   cd "C:\Program Files\npgsql\MyNpgsqlProject"
   dotnet add package Npgsql
   dotnet build
   ```

5. Vérifier l'emplacement du package Npgsql :
   ```
   %UserProfile%\.nuget\packages\npgsql\8.0.5\lib\net8.0
   ```

6. Assurez-vous d'avoir l'abstraction nécessaire :
   ```
   C:\Users\Administrator\.nuget\packages\microsoft.extensions.logging.abstractions\8.0.0\microsoft.extensions.logging.abstractions.8.0.0\lib\net8.0
   ```

## Installation

1. Enregistrer le dépôt PSGallery si ce n'est pas déjà fait :
   ```powershell
   Register-PSRepository -Default
   ```

2. Installer le module CredentialManager :
   ```powershell
   Install-Module -Name CredentialManager -Scope CurrentUser -Force
   ```

3. Ajouter les capacités Active Directory :
   ```powershell
   Get-WindowsCapability -Name RSAT.ActiveDirectory* -Online | Add-WindowsCapability -Online
   ```

4. Lister les modules disponibles :
   ```powershell
   Get-Module -ListAvailable -Name ActiveDirectory
   ```
___

## Commandes du module 

```powershell
Get-Module -ListAvailable
```
## Add-UserAdAndPsql
La fonction permet de créer un nouvel utilisateur sous un groupe des domaines présent dans l’Active Directory. Au même moment, l'utilisateur est créé sous le même groupe du même nom dans PSQL. L’utilisateur ne sera pas créé s’il existe déjà dans l’Active Directory. Si le mot de passe n’est pas passé en paramètre le mot de passe par défaut sera utilisé. Si l’utilisateur est sous le groupe administrateur un utilisateur sera créé dans la base de données en plus de son utilisateur dans la table user. La fonction appel  Update-GroupPsql pour éviter les groupes inexistant dans la base de données lors de l’insertion. Pour savoir si un utilisateur est unique dans PSQL nous nous basons sur le courriel unique. 

Add-UserAdAndPsql([string] $username,[string] $first_name,[string]$last_name,[string] $group_name,[string] $email,[string] $password = $FIRST_TIME_PASSWORD_PSQL ) {
   
### exemple:
```
Add-UserAdAndPsql  "phillip_v" "Phillip" "Veilleux" "Administrateur" "ph_v@Cr431.com" "password123fk3209*840((48_))
```

## Get-GroupsPsqlPermissionsReport
Cette fonction permet d’obtenir un rapport sur les permissions qui sont différentes entre la base de données et l’Active Directory. L'objectif est de permettre de noter les groupes ayant des différences de permissions qui pourraient arriver lors de la modification du serveur postgre ou des permissions d’un groupe sur le répertoire C:. Cette fonction peut être roulée quotidiennement pour tracer des différences. Le répertoire C: est la référence des permissions et la base de données réplique les permissions. Le fichier est récupérable sous le répertoire:

```
%USERPROFILE%\Documents\Nom_document_en_temps_unix.txt 
```
Get-GroupsPsqlPermissionsReport
   
### exemple:
```
Get-GroupsPsqlPermissionsReport
```

## Update-GroupPsql
Cette fonction permet de remettre à jour les permissions de postgre pour qu’elle concorde avec celle du groupe sur le disque C:. Cette fonction ne prend pas en compte les groupes ajoutés dans la base de données. Par contre elle s’assure que tous les groupes dans l’Active Directory soient présents dans la base de données. La raison pour laquelle on n'efface pas les groupes inexistants dans postgre est pour sécuriser l’application et permettre au développeur d’ajouter des groupes. 

Update-GroupPsql

### exemple:
```
Update-GroupPsql
```