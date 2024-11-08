Import-Module CredentialManager
#Le path pour les module supporté par l'ancien powershell et qui ne sont pas trouvable sur powershell 7 
$env:PSModulePath += ";C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
Import-Module ActiveDirectory



#Variable globales pour le script
#___________________________________________________________________________________________________________________________`
# Database credentials
$PGUSER = "postgres"
$PGDATABASE = "postgres"
$PGPASSWORD =""
<#Pour cette itération de code on présume que nous travaillons directement sur le serveur postgres sur lequel nous voulons faire des
changement et que postgre est configuré par défaut. Pour l'exercice j'ai codé avec des variable statique parce que ça demandais moins d'effort que de commencer 
à faire des menu d'acquisition de la configuration.Les mettre dans des varaibles globales permettrait l'amélioration à long terme  #>
$PSQLPORT = "5432"
$PGHOST = "localhost"

$PG_WINDOWS_CRED_USER ="postgres_main_user"

$REGEX_O = "^[Oo]$"
$REGEX_N = "^[Nn]$"
$O_or_N_TEXT = "Tapez Oui ou Non (O/N) puis tapez la touche entrer."


$SSHCONNECTION = $null




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

function psql_command ([string] $query,[string] $database =$PGDATABASE, [string] $username =$PGUSER, [securestring] $password  ) {

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
    # Exécute la commande demandé avec le user obtenue admin ou simple utilisateur
    $psqlCommand = "psql -h $PGHOST -U $username -d $database -c `"$query`" --password=$plain_password"

    # Execute the command
    Invoke-Expression $psqlCommand
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

function get_all_domain_group_permission {

    # Initialisation d'un tableau pour stocker les permissions des groupes
    $groupPermissions = @()

    # Récupération de tous les groupes qui font parti de l'arbre Domain Controllers
    $groups = Get-ADGroup -Filter * | Where-Object { $_.DistinguishedName -like "*OU=Domain Controllers,*" }|Select-Object Name

    foreach ($group in $groups) {
        $group = Get-ADGroup -Identity $group.name
        $sd = Get-ADObject -Identity $group.DistinguishedName -Properties ntSecurityDescriptor
        $sd.ntSecurityDescriptor.Access
        
        $acl = Get-Acl -Path "C:\"
        $group_access =  $acl.Access | Where-Object { $_.IdentityReference -like $group.name }
        $group_access.FileSystemRights


        $acl = Get-ACL -Path ("AD:" + $domain_group_name)

        $permissions = @()
        foreach ($access in $acl.Access) {
            # Récupération des types de permissions pour chaque entrée
            $permissions += $access.FileSystemRights.ToString()
        }

        # Ajout du groupe et de ses permissions dans le tableau
        $groupPermissions += [pscustomobject]@{
            group_name = $group.Name
            Permission = $permissions
        }
    }

    # Retourner le tableau des permissions
    return $groupPermissions
}



<#function psql_command([string]$server,[string]$database,[string]$username,[securestring] $password ){
    try {

        $username = IIf($username -eq $null,$PGUSER,$username)  
        [System.Environment]::SetEnvironmentVariable('PGPASSWORD', $connection.Password)
        psql -U $username -d $database -h $server '-c' $query
    }
    catch {
        throw "Ha non quelque chose fonctionne pas: $_"
    }
}#>

#___________________________________________________________________________________________________________________________`
#Commande du module AD_TO_PSQL



function Add-Group{
    #Paramètre d'entré de la fonction
    try {        
        #Validation de toute les entrées    
        


        $list_domain_group = get_all_domain_group_permission

        $group_name = verify_input "Entrez un nom de groupe puis appuis sur la touche Entrer." "SVP entrez au minimun un caractère" "^[A-Za-z]*$" "" 4  $False

        <#Permission sur le C: afin que les permissions soient globales , c'est dans l'optique de crééer des groupe rapidement qui peuvent représenter les permissions globale du 
        groupes sur la machine.Permission de lecture de la base et les tables de donnée.
        #>
        $database_message_1= "Est-ce que vous voulez permettre de faire"
        $database_message_2 = "sur la base de données."
        $o_n_error = "SVP entrez au minimun un caractère"

        $select_permission_db = verify_input "$database_message_1 des lecture $database_message_2 $O_or_N_TEXT" $o_n_error $REGEX_O $REGEX_N 2 $True       
        #Droit de écriture de la base de donnée et les tables de donnée. Ces permissions sont copiés au répertoire C:
        $write_permission_db = verify_input "$database_message_1 de l'écriture $database_message_2 $O_or_N_TEXT" $o_n_error $REGEX_O $REGEX_N 2 $True
        #Droit de modification de la base de donnée et les tables de donnée. Ces permissions sont copiés au répertoire C:
        $update_permission_db = verify_input "$database_message_1 la modification $database_message_2 $O_or_N_TEXT" $o_n_error $REGEX_O $REGEX_N 2 $True        
        #Droit de supprimer de la base de donnée et les tables de donnée. Ces permissions sont copiés au répertoire C:
        $delete_permission_db = verify_input "$database_message_1 la suppression $database_message_2 $O_or_N_TEXT" $o_n_error $REGEX_O $REGEX_N 2 $True
        #Droit de Super user  de la base de donnée et Full control sur le C
        $super_user = verify_input "Est-ce que vous voulez permettre d'avoir les permission d'administrator $database_message_2 $O_or_N_TEXT" $o_n_error $REGEX_O $REGEX_N 2 $True

         <#
        https://www.lepide.com/how-to/get-an-ntfs-permissions-report-using-powershell.
        
        https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemaccessrule?view=net-8.0
        #>

        Write-Host "Permission lecture $select_permission_db"
        Write-Host "Permission modification $write_permission_db"
        Write-Host "Permission modification $update_permission_db"
        Write-Host "Permission suppression $delete_permission_db"
        Write-Host "Permission administrateur $super_user"

        #Liste des accès de contrôle actuelle sur le répertoire C:
        $acl = Get-Acl "C:\"
        #Création du groupe
        $query += "CREATE ROLE $group_name;"
        
        #Variable pour savoir si les permissions sont déjà attribués
        $function_procedure_permission = $false

        $write_folder_permission = $null   
        # permission table et de la base de données
        if ($super_user) {
            $query = "ALTER ROLE $group_name WITH SUPERUSER;"
        }else{
            if ($select_permission_db) { 
                $query += "GRANT CONNECT ON DATABASE $PGDATABASE[0] TO $group_name;" 
                $query += "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $group_name;"
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO $group_name;"
            }
            if ($write_permission_db) { 
                $query += "GRANT CREATE ON DATABASE $PGDATABASE[0] TO $group_name;"
                $query += "GRANT INSERT ON ALL TABLES IN SCHEMA public TO $group_name;"
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT ON TABLES TO $group_name;"
                
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $group_name;"  
            }
            if ($update_permission_db) {
                $query += "GRANT TEMPORARY ON DATABASE $PGDATABASE[0] TO $group_name;"
                $query += "GRANT UPDATE ON ALL TABLES IN SCHEMA public TO $group_name;"
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT UPDATE ON TABLES TO $group_name;"
                if (-not $function_procedure_permission){
                    $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $group_name;"
                    $function_procedure_permission = $True
                }
            }
            if ($delete_permission_db) {
                $query += "GRANT TEMPORARY ON DATABASE $PGDATABASE[0] TO $group_name;"
                $query += "GRANT DELETE ON ALL TABLES IN SCHEMA public TO $group_name;" 
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, DELETE ON TABLES TO $group_name;"
                if (-not $function_procedure_permission){
                    $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $group_name;"
                }
            }
        }

        # Création du groupe  
        if (-not (Get-ADGroup -Filter { Name -eq $group_name })) {        
            $current_user = whoami
            New-LocalGroup -Name $group_name -Description "Ceci est un groupe créé par $current_user avec la librairie AD_TO_PSQL"
        } 

        #_______________________________________
        #permission sur le groupe 
        if ($super_user) { 
            # permissions sont mis dans les objets .net 
            $read_folder_permission = New-Object System.Security.AccessControl.FileSystemAccessRule($group_name, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
            # Ajouter les permission à l'objet
            $acl.SetAccessRule($read_folder_permission)
        }        
        if ($select_permission_db) { 
            # permissions sont mis dans les objets .net 
            $read_folder_permission = New-Object System.Security.AccessControl.FileSystemAccessRule($group_name, "ReadAndExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
            # Ajouter les permission à l'objet
            $acl.SetAccessRule($read_folder_permission)
        }
        if (($update_permission_db -or $write_folder_permission) -or ($update_permission_db -and $write_folder_permission)) {
            $write_folder_permission = New-Object System.Security.AccessControl.FileSystemAccessRule($group_name, "Write", "ContainerInherit, ObjectInherit", "None", "Allow") 
            $acl.SetAccessRule($write_folder_permission)
        }          
        if ($delete_permission_db) {
            # permission table et de la base de données
            $query += "GRANT TEMPORARY ON DATABASE $PGDATABASE[0] TO $group_name;"
            $query += "GRANT DELETE ON ALL TABLES IN SCHEMA public TO $group_name;" 
            $delete_folder_permission = New-Object System.Security.AccessControl.FileSystemAccessRule($group_name, "Delete", "ContainerInherit, ObjectInherit", "None", "Allow")
            $acl.SetAccessRule($delete_folder_permission)
        }

        $query += "GRANT USAGE ON SCHEMA public TO $group_name;"
        $query += "GRANT CREATE ON SCHEMA public TO $group_name;"
        
        $query += "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO $group_name;"
        
         
        $query += "GRANT $group_name TO existing_user;"

        Write-Host $query
        Write-Host $select_permission_db,$update_permission_db,$delete_permission_db,$super_user
        Write-Host $acl

        #Mettre en application les modification des permissions sur répertoire C: et dans la base de donnée.
        Set-Acl "C:\" $acl
        psql_command($query)
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

Add-Group

#psql_command "SELECT datname AS database_name FROM pg_database WHERE datistemplate = false;"