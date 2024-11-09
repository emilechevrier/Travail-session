
Import-Module CredentialManager
#Le path pour les module supporté par l'ancien powershell et qui ne sont pas trouvable sur powershell 7 il faut pointer pws 5
$env:PSModulePath += ";C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
Import-Module ActiveDirectory

#Ajout d'une DLL parce que ce n'est pas une librairie pws. Elle est récupéré de nuget.org qui contient plusieurs librairie Dotnet
#L'avantage de Npgsql est que ça retourne un objet avec lequel on peut travailler au lieu de recevoir un array de string avec la réponse
#Il faut un environnement de dev dotnet pour arriver a installer la librairie et je pointe sur la localisation du projet dotnet dans les 
#librairies de projet.J'ai dû google et chatgpt cette partie parce que normalement on utilise cette libraire en dev et non pas en 


#la librairie abstration est requise pour Npgsql il semblerait que ça donner les élement de culture probablement pour la langue de l'utilisateur
# afin de savoir le format a retourner
$abstractionPath = "$env:UserProfile\.nuget\packages\microsoft.extensions.logging.abstractions\8.0.0\microsoft.extensions.logging.abstractions.8.0.0\lib\net8.0\Microsoft.Extensions.Logging.Abstractions.dll"
Add-Type -Path $abstractionPath

$npgsqlPath = "$env:UserProfile\.nuget\packages\npgsql\8.0.5\lib\net8.0\Npgsql.dll"
Add-Type -Path $npgsqlPath


#Variable globales pour le script
#___________________________________________________________________________________________________________________________`
# Database credentials
$PGUSER = "postgres"
$PGDATABASE = "CR431"

<#Pour cette itération de code on présume que nous travaillons directement sur le serveur postgres sur lequel nous voulons faire des
changement et que postgre est configuré par défaut. Pour l'exercice j'ai codé avec des variable statique parce que ça demandais moins d'effort que de commencer 
à faire des menu d'acquisition de la configuration.Les mettre dans des varaibles globales permettrait l'amélioration à long terme  #>
$PG_HOST = "localhost"

$PG_WINDOWS_CRED_USER ="postgres_main_user"

$REGEX_O = "^[Oo]$"
$REGEX_N = "^[Nn]$"
$O_or_N_TEXT = "Tapez Oui ou Non (O/N) puis tapez la touche entrer."


$REGEX_SELECT = 'Synchronize|ReadAndExecute|Read|ReadPermissions|ExecuteFile|Traverse|ReadAttributes|ReadExtendedAttributes|ReadData|ListDirectory' 

$REGEX_COMMUN_C_U= 'WriteAttribute|CreateDirectories|AppendData|WriteData|WriteExtendedAttributes|CreateFiles|Write'
$REGEX_CREATE = 'Write' 
$REGEX_UPDATE = 'Modify' 
$REGEX_DELETE = 'Modify|DeleteSubdirectoriesAndFiles|Delete' 

#Fonction privé du module AD_TO_PSQL
#___________________________________________________________________________________________________________________________`


<#Fonction IIF pour simuler la fonction IIF dans des language et pouvoir gérer les conditions null aussi en une seule ligne parce qu'un langage devrait avoir cette contraction qui permet 
de pas perdre de temps et rendre le code plus lisible. Si le vrai ou faux n'est pas définis ils sont True ou False par défaut #>
function iif {
    param (
        [bool] $IfCondition,
        $IfTrue,
        $IfFalse 
    )
    try {
            If ($IfCondition) {
                return $IfTrue}
            Else {
                return  $IfFalse
            }  
    }
    catch {
        show_error $_
        return  $null
    }
}


# Enregistre les mdp et user pour pouvoir se connecter à postgre comme administrateur du serveur de données postgre. Je n'ai pas codé le changement de mot de passe pour des raisons de temps , mais serait à considérer
function save_windows_credentials ([string] $credential_name) {
    try {

        # Vérifier si la cible existe déjà dans le gestionnaire de Windows Credentials
        #$existingCredential = Get-StoredCredential -Target $credential_name 
        $credential = cmdkey /list | Select-String -Pattern $credential_name

        if ($credential){}else{

            # Demander le mot de passe de manière sécurisée
            #Secure string empêche d'accéder directement au credential pour https://learn.microsoft.com/en-us/dotnet/api/system.security.securestring?view=net-8.0           
            $user = verify_input "Entrez le nom de cette utilisateur postgre administrateur sur le serveur de la machine" "SVP entrez au minimun un caractère" "^.+$" "" 3  $False             
            $password = ConvertTo-SecureString (verify_input "Entrez le mot de passe de cette utilisateur $user" "SVP entrez au minimun un caractère" "^.+$" "" 3  $False ) -AsPlainText -Force

            # Enregistrer les credentials dans le gestionnaire Windows Credentials
            #Secure string conversion pour utilisation https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/convertfrom-securestring?view=powershell-7.4
            
            #New-StoredCredential -Target $credential_name -UserName $user -Password (ConvertTo-SecureString $password -AsPlainText -Force) -Persist LocalMachine

            cmdkey /add:$credential_name /user:$user /pass:$password
    
            Write-Output "Les informations d'identification ont été enregistrées dans le gestionnaire Windows Credentials pour la cible : $credential_name."
        }
    }
    catch {
        show_error $_
    }            
}

function PsqlCommand ([string] $query,[string] $database =$PGDATABASE, [string] $username =$PGUSER, [securestring] $password  ) {

    <# Si le mot passe de est donnée c'est pour exécuter la commande en tant qu'une user particulier sinon c'est pour prendre 
    le user postgre par défaut , mais il faut être admin de la machine pour y accéder par défaut#>
    if ($null -eq $password) {
        <#Prend le mot de passe pour le user postgre de la base de données par défaut. 
        S'il ne fait pas parti des windows credential il faut le donner pour l'enregistrer #>
        save_windows_credentials $PG_WINDOWS_CRED_USER
        $pgCredential = Get-StoredCredential -Target $PG_WINDOWS_CRED_USER
        
        #$username = $pgCredential.UserName
        #$password =  ConvertTo-SecureString($pgCredential.GetNetworkCredential().Password)

        $password = ConvertTo-SecureString ("#Dcvand007") -AsPlainText -Force
        $username = "postgres"
        
        $plain_password = ConvertFrom-SecureStringToString -SecureString $password

        
    } 

    #Fait une connexion postgre pour executer la commande sql
    $connection_param = "Host=$PG_HOST;Database=$PGDATABASE;Username=$username;Password=$plain_password;"
    $connection = New-Object Npgsql.NpgsqlConnection($connection_param)
    $connection.Open()
    $createGroupCommand = New-Object Npgsql.NpgsqlCommand($query, $connection)
    #ExecuteReader retourne la valeur 
    $reader =$createGroupCommand.ExecuteReader()
    

    $results = @()

    <#le resultat sort en un objet et il faut faire une curseur pour trouver la valeur sous forme lisible 
    en on le map dans un hash pour avoir ainsi des objets

    La fonction read li un lot de données soit 1 hash a la fois. Les hash sont fait par la fonction read 

    https://www.npgsql.org/doc/basic-usage.html
    #>
    while ($reader.Read()) {
        # Create a hashtable for each record
        $record = @{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $record[$reader.GetName($i)] = $reader.GetValue($i)
        }

        $results += $record
    }

    $connection.Close()

    # Close the reader
    $reader.Close()

    return $results 

    # Exécute la commande demandé avec le user obtenue admin ou simple utilisateur
    #$psqlCommand = "psql -h $PG_HOST -U $username -d $database -c `"$permission_query`" --password=$plain_password"

    # Execute the command
    #return Invoke-Expression $psqlCommand
}


<# Imprimer à l'utilisateur l'ensemble des erreurs#>

function show_error($exception){
        $error_message = $exception.Exception.Message
        $error_type = $exception.Exception.GetType().FullName
        $error_stack_trace = $exception.ScriptStackTrace
        Write-Output "Erreur: $error_message"
        Write-Output "Type erreur: $error_type"
        Write-Output "Étape (Stack Trace): $error_stack_trace"
}



<#
Fonction données par chatgpt pour récupérer les secures string. il utilise des objets .net pour convertir dans la mémoire temporaire.
Selon mes recherche la classe Marshal est utilisé pour l'écriture de dans la mémoire du sytème sous forme géré donc en 32 ou bits
probablement. https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.marshal?view=net-8.0
#> 

function ConvertFrom-SecureStringToString {
    param (
        [System.Security.SecureString]$SecureString
    )

    # Marshal the SecureString to unmanaged memory and read it as plain text
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}


#Function récursive pour vérifier si les conditions sont respectées. Pour les conditions vrai ou faux il faut taper la condition vrai ou sinon ça retourne faux sans faire plusieurs essait.
function verify_input (
[string] $user_input_message = "",
[string] $error_message = "Invalid input.",
[string] $trueCondition = "",
[string] $falseCondition = "",
[int] $number_trial = 0,
[bool] $returnTrueOrFalse = $False
){
    # Si échoue on garde la valeur récursive
    $false_condition_fail = $falseCondition
    $true_conditio_fail = $trueCondition
    #Validation des conditions parce que je fais la function surchargé afin de la réutiliser pour la validation booléen ou la récupération de valeur 
    $error_message = iif ($user_input_message -eq "") "Invalid input." $error_message
    $trueCondition = iif ($trueCondition -eq "") $True $trueCondition
    $falseCondition = iif ($falseCondition -eq "") $False $falseCondition
    
    $user_input = Read-Host $user_input_message

    # Valide l'entrée utilisateur
    if ($user_input -ne ""){
        if ($user_input -match $trueCondition) {    
            if ($returnTrueOrFalse -eq $True) { 
                return $True     
            } else {
                return $user_input   
            }
        } else {
            if ($user_input -match $falseCondition) {  
                if ($returnTrueOrFalse -eq $True) { 
                    return $False                 
                }
            } 
        }
    }    
    # Décrémente le compteur d'essais
    $number_trial -= 1
    # Vérifie si le nombre maximum d'essais a été dépassé
    if ($number_trial -le 0) {
            Write-Host $error_message
        throw "Trop d'erreur dans la lecture de l'entrée"
    }
    # Appel récursif pour permettre à l'utilisateur de réessayer
    Write-Host "$error_message, il vous reste $number_trial essait"             
    return verify_input $user_input_message  $error_message $true_conditio_fail $false_condition_fail $number_trial $returnTrueOrFalse          
}
#Liste de controle
#https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemrights?view=net-8.0
        
function PermissionADtoPSQL {

    # Initialisation d'un tableau pour stocker les permissions des groupes
    $group_permissions = @()

    # Récupération de tous les groupes qui font parti de l'arbre Domain Controllers
    $groups = Get-ADGroup -Filter * | Where-Object { $_.DistinguishedName -like "*OU=Domain Controllers,*" }|Select-Object Name
    $acl = Get-Acl -Path "C:\"
    foreach ($group in $groups) {
        <#Obtenir le descriptif de sécurité donc les composantes de sécurité de 
        la composant dans le cas présent le C:\#>
        $group_name = $group.name        
        $group_access =  $acl.Access | Where-Object { $_.IdentityReference -like "*$group_name" }
        $group_permission = $group_access.FileSystemRights
        #Transforme object groupe de permission en string pour passer d'un objet à un string avec le join a une liste avec split
        $split_permission = ($group_permission -join ',') -split ","
        $translatePermission = @($false,$false,$false,$false,$false)
        foreach ($permission in $split_permission ){
            <# Permission mise dans un array 
            array (select, create, update,delete,super_user)
            array (0,0,0,0,0)
            #>
            if ($permission -match 'FullControl|ChangePermissions|TakeOwnership'){
                $translatePermission = @($true,$true,$true,$true,$true)
            }else{
                switch -Regex ($permission) {
                    $REGEX_SELECT {
                        #Select  permission 
                        $translatePermission[0] = $true
                    }
                    $REGEX_COMMUN_C_U{
                        #create permission
                        $translatePermission[1] = $true
                        #update  permission
                        $translatePermission[2] = $true
                    }
                    $REGEX_CREATE {
                        #create permission 
                        $translatePermission[1] = $true
                    }
                    $REGEX_UPDATE {
                        #Permission modifie est inclus le write                          
                        #create permission
                        $translatePermission[1] = $true
                        #update  permission
                        $translatePermission[2] = $true
                    }
                    $REGEX_DELETE {
                        #update  permission 
                        $translatePermission[3] = $true
                    }
                }
            }
            #Création d'un objet pour les permissions traduites du C: vers Postgres
        }
        $group_permissions += [PSCustomObject]@{
            name = $group_name
            permissions =$translatePermission
        }
    }
    # Retourner le tableau des permissions par groupe 
    return $group_permissions
}




#___________________________________________________________________________________________________________________________`
#Commande du module AD_TO_PSQL
function Update-GroupPsqlDb{
    #Paramètre d'entré de la fonction
    try {        
        # Récupère les permissions mises sur le disque C: pour chaque groupe faisant parti des administrateur domaine AD 
        $list_domain_groups = PermissionADtoPSQL

        foreach ($group in $list_domain_groups ){
            $select_permission_db = $group.permissions[0]       
            #Droit de écriture de la base de donnée et les tables de donnée. Ces permissions sont copiés au répertoire C:
            $write_permission_db =$group.permissions[1]  
            #Droit de modification de la base de donnée et les tables de donnée. Ces permissions sont copiés au répertoire C:
            $update_permission_db = $group.permissions[2]         
            #Droit de supprimer de la base de donnée et les tables de donnée. Ces permissions sont copiés au répertoire C:
            $delete_permission_db = $group.permissions[3]  
            #Droit de Super user  de la base de donnée et Full control sur le C
            $super_user = $group.permissions[4]      
            #Variable pour savoir si les permissions sont déjà attribués
            $function_procedure_permission = $false
    
            $groupName = $group.name
            # permission table et de la base de données
            $group_exist_query = "SELECT 1 FROM pg_roles WHERE rolname = '$groupName';"


            $group_exist_query = 'SELECT * FROM public.authors;'
            $exist =  PsqlCommand($group_exist_query)

            if ($exists -ne "") {
                # Group does not exist, create it
                $createGroupQuery = "CREATE ROLE $groupName;"
                PsqlCommand($createGroupQuery, $connection)
            }
            
            $permission_query = ""
            if ($super_user) {
                $permission_query += "ALTER ROLE $groupName WITH SUPERUSER;"
            } else {
                if ($select_permission_db) { 
                    $permission_query += "GRANT CONNECT ON SERVER TO $groupName;`n" 
                    $permission_query += "GRANT USAGE ON SCHEMA public TO $groupName;`n"
                    $permission_query += "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $groupName;`n"
                    $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO $groupName;`n"
                }
                if ($write_permission_db) { 
                    $permission_query += "GRANT CREATE ON SCHEMA public TO $groupName;`n"
                    $permission_query += "GRANT INSERT ON ALL TABLES IN SCHEMA public TO $groupName;`n"
                    $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT ON TABLES TO $groupName;`n"
                    $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $groupName;`n"  
                }
                if ($update_permission_db) {
                    $permission_query += "GRANT UPDATE ON ALL TABLES IN SCHEMA public TO $groupName;`n"
                    $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT UPDATE ON TABLES TO $groupName;`n"
                    if (-not $function_procedure_permission) {
                        $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $groupName;`n"
                        $function_procedure_permission = $True
                    }
                }
                if ($delete_permission_db) {
                    $permission_query += "GRANT DELETE ON ALL TABLES IN SCHEMA public TO $groupName;`n" 
                    $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT DELETE ON TABLES TO $groupName;`n"
                    if (-not $function_procedure_permission) {
                        $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $groupName;`n"
                    }
                }
            }

            #Mettre en application les modification des permissions dans la base de donnée.
            PsqlCommand($permission_query)
        }
    }
    catch {
        #Voici les erreurs 
        show_error $_
        Write-Host "La fonction à échoué après plusieurs erreurs"
    }
}


function Add-User{
    param(
        [string]$group_name
    )
}

function Remove-Group{
    param(
        [string]$group_name
    )
}

function Remove-user{
    param(
        [string]$username
    )
}

function Edit-User{
    param(
        [string]$username
    )
} 

function Edit-group{
    param(
        [string]$group_name
    )
}


#Uniquement les fonction exporté pour le module afin de garder les fonctions privé non utilisable par l'utilisateur
#Export-ModuleMember -Function  Add-Group, Add-User, Remove-Group, Remove-user, Edit-User, Edit-group

Update-GroupPsqlDb

#PsqlCommand "SELECT datname AS database_name FROM pg_database WHERE datistemplate = false;"