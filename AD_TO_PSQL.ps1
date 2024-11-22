
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

$PATH_FILE_RERPORT= "$env:UserProfile\Documents\"
$FIRST_TIME_PASSWORD_PSQL ='New_p@$$w0rd_F0r_C0mp@ny_24!'

#https://uibakery.io/regex-library/password
$PASSWORD_COMPLEXITY = '^(?=(.*[A-Z]))(?=(.*[a-z]))(?=(.*\d))(?=(.*[!@#$%^&*()_+={}\[\]:;"''<>,.?-])).{8,}$'

$LOG_FILE_PATH = "$env:UserProfile\ErrorLog.txt"

$REGEX_SELECT = 'Synchronize|ReadAndExecute|Read|ReadPermissions|ExecuteFile|Traverse|ReadAttributes|ReadExtendedAttributes|ReadData|ListDirectory' 

$REGEX_COMMUN_C_U= 'WriteAttribute|CreateDirectories|AppendData|WriteData|WriteExtendedAttributes|CreateFiles|Write'
$REGEX_CREATE = 'Write' 
$REGEX_UPDATE = 'Modify' 
$REGEX_DELETE = 'Modify|DeleteSubdirectoriesAndFiles|Delete' 

#Objets 
#https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_object_creation?view=powershell-7.4
#Pour le context du travail je me tiens au concept généraux de la base de données bien que ça pourrais être plus précis
# On se tient au concept de CRUD et Admin  = select, create, update,delete,super_user
$PermissionMatrix= [PSCustomObject]@{
    select = $false
    create = $false
    update = $false
    delete = $false
    super_user = $false
}

$GroupPermissions = [PSCustomObject]@{
    name = ""
    permissions = [Object]
    ObjectGUID = ""
}

#Fonction privé du module AD_TO_PSQL
#___________________________________________________________________________________________________________________________`


<#Fonction IIF pour simuler la fonction IIF dans des language et pouvoir gérer les conditions null aussi en une seule ligne parce qu'un langage devrait avoir cette contraction qui permet 
de pas perdre de temps et rendre le code plus lisible. Si le vrai ou faux n'est pas définis ils sont True ou False par défaut #>
function iif {
    param (
        [bool]$IfCondition,
        $IfTrue,#optionnel
        $IfFalse #optionnel
    )
    try {
        if ($null -eq $IfTrue){
            $IfTrue = $true
        }
        if ($null -eq $IfFalse){
            $IfFalse = $false
        }
        If ($IfCondition) {
            return $IfTrue}
        else {
            return  $IfFalse
        }  
    }
    catch {
        showError $_
        return  $null
    }
}


#Pour enregistrer les erreurs sans avoir directement des interactions avec l'utilisateur
function logError([string] $error_message){
    Add-Content -Path $LOG_FILE_PATH -Value $error_message`n
}

<# Fonction surchargé, on peut passer une base de donnée au besoin, on peut passer un utilisateur et sont mots de passe pour faire des
tests avec un utilisateur en particulier. Si on ne fournit pas ces paramètre on prend le user postgre détenue dans les windows credentials.
#>
function psqlCommand ([string] $query,[string] $database =$PGDATABASE, [string] $username =$PGUSER, [securestring] $password  ) {
    try {
        <# Si le mot passe de est donnée c'est pour exécuter la commande en tant qu'une user particulier sinon c'est pour prendre 
        le user postgre par défaut , mais il faut être admin de la machine pour y accéder par défaut#>
        if ($null -eq $password) {
            <#Obtenir toutes les credentials #>
            $pg_credential = Get-StoredCredential -Target $PG_WINDOWS_CRED_USER           
            $username = $pg_credential.UserName
            $password = $pg_credential.Password      
        } 

        #Fait une connexion postgre pour executer la commande sql
        $connection_param = "Host=$PG_HOST;Database=$PGDATABASE;Username=$username;Password="+(ConvertFrom-SecureStringToString -SecureString $password)+";"
        $connection = New-Object Npgsql.NpgsqlConnection($connection_param)

        #Vérifier si une connexion ou un cursor n'est pas gardé en mémoire lors d'un échec
        $connection.Open()
        $create_query = New-Object Npgsql.NpgsqlCommand($query, $connection)
        #ExecuteReader retourne la valeur 
        $reader =$create_query.ExecuteReader()

        $results = @()
        <#le resultat sort en un objet et il faut faire une curseur pour trouver la valeur sous forme lisible 
        en on le map dans un hash pour avoir ainsi des objets
        La fonction read li un lot de données soit 1 hash a la fois. Les hash sont fait par la fonction read 
        Je ne peux pas dire pourquoi c'est déja un hash probablement que le format de la librairie npgsql retourne un 
        format hashable. J'ai prix des exemple et fait des test a partir de code sur ce site  

        https://www.npgsql.org/doc/basic-usage.html
        https://www.npgsql.org/doc/api/Npgsql.NpgsqlCommand.html
        Ceci est un example de execute scalar , mais pour miscrosoft en c#
        https://learn.microsoft.com/en-us/dotnet/api/microsoft.data.sqlclient.sqlcommand.executescalar?view=sqlclient-dotnet-standard-5.2
        
        #>
        if ($reader.HasRows) {
            while ($reader.Read()) {
                # Initialize a hash table to store the values of each row dynamically
                $row = @{}
        
                # Loop through all columns in the current row
                for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                    # Get the column name and value, add to the row hash table
                    $colum_name = $reader.GetName($i)
                    $column_value = $reader.GetValue($i)        
                    # Store the column name and value in the row hash table
                    $row[$colum_name] = $column_value
                }
        
                # Add the current row (hash table) to the results array
                $results += $row
            }
        }     
        #Ferme la connexion
        $reader.Close()
        $connection.Close()
        return $results
    }
    catch {
        #Essai de fermer la connexion si jamais c'est encore ouvert pour éviter les erreurs
        try {$reader.Close()}catch{}
        try {$connection.Close()}catch{}        
        showError $_
    }
}

function showError($exception){
        $error_message = $exception.Exception.Message
        $error_type = $exception.Exception.GetType().FullName
        $error_stack_trace = $exception.ScriptStackTrace
        logError "Erreur: $error_message"
        logError "Type erreur: $error_type"
        logError "Étape (Stack Trace): $error_stack_trace"
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
[string] $user_input = "",
[string] $error_message = "Invalid input.",
[string] $true_condition = "",
[string] $false_condition = "",
[int] $number_trial = 0,
[bool] $returnTrueOrFalse = $False
){
    # Si échoue on garde la valeur récursive
    $false_condition_fail = $false_condition
    $true_conditio_fail = $true_condition
    #Validation des conditions parce que je fais la function surchargé afin de la réutiliser pour la validation booléen ou la récupération de valeur 
    $error_message = iif ($user_input -eq "") "Invalid input." $error_message
    $true_condition = iif ($true_condition -eq "") $True $true_condition
    $false_condition = iif ($false_condition -eq "") $False $false_condition

    # Valide l'entrée utilisateur
    if ($user_input -ne ""){
        if ($user_input -match $true_condition) {    
            if ($returnTrueOrFalse -eq $True) { 
                return $True     
            } else {
                return $user_input   
            }
        } else {
            if ($user_input -match $false_condition) {  
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
            logError $error_message
        throw "Trop d'erreur dans la lecture de l'entrée"
    }
    # Appel récursif pour permettre à l'utilisateur de réessayer
    logError "$error_message, il vous reste $number_trial essait"             
    return verify_input $user_input  $error_message $true_conditio_fail $false_condition_fail $number_trial $returnTrueOrFalse          
}

#Liste de controle de permission permettant de faires la lecture des permissions  
#https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemrights?view=net-8.0      
function getPermissionAD {

    # Initialisation d'un tableau pour stocker les permissions des groupes
    $group_permissions = @()

    # Récupération de tous les groupes qui font parti de l'arbre Domain Controllers
    $groups = Get-ADGroup -Filter * | Where-Object { ($_.DistinguishedName -like "*OU=Domain Controllers,*" )}|Select-Object Name, ObjectGUID
    $acl = Get-Acl -Path "C:\"
    foreach ($group in $groups) {

        #Copie l'objet pour avoir une réplication travaillable de l'objet AD
        $retrieive_group = $GroupPermissions.PSObject.Copy()

        <#Obtenir le descriptif de sécurité donc les composantes de sécurité de 
        la composant dans le cas présent le C:\#>
        $group_name = $group.name 
        $retrieive_group.name = $group_name  
        $retrieive_group.ObjectGUID = $group.ObjectGUID     
        $group_access =  $acl.Access | Where-Object { $_.IdentityReference -like "*$group_name" }
        $group_permission = $group_access.FileSystemRights
        #Transforme object groupe de permission en string pour passer d'un objet à un string avec le join a une liste avec split
        $split_permission = ($group_permission -join ',') -split ","
        $translatePermission = $PermissionMatrix.PSObject.Copy()
        foreach ($permission in $split_permission ){
            <# Permission mise dans l'objet PermissionMatrix
            (select, create, update,delete,super_user)
            #>
            if ($permission -match 'FullControl|ChangePermissions|TakeOwnership'){
                $translatePermission.select = $true
                $translatePermission.create = $true
                $translatePermission.update = $true
                $translatePermission.delete = $true
                $translatePermission.super_user = $true                                
            }else{
                switch -Regex ($permission) {
                    $REGEX_SELECT {
                        $translatePermission.select = $true
                    }
                    $REGEX_COMMUN_C_U{
                        $translatePermission.create = $true
                        $translatePermission.update = $true
                    }
                    $REGEX_CREATE {
                        $translatePermission.create = $true
                    }
                    $REGEX_UPDATE {
                        $translatePermission.create = $true
                        $translatePermission.update = $true
                    }
                    $REGEX_DELETE {
                        #update  permission 
                        $translatePermission.delete = $true
                    }
                }
            }
            #Création d'un objet pour les permissions traduites du C: vers Postgres
        }
        $retrieive_group.permissions = $translatePermission

        $group_permissions += $retrieive_group
    }
    # Retourner le tableau des permissions par groupe 
    return $group_permissions
}

#___________________________________________________________________________________________________________________________`
#Commande du module AD_TO_PSQL
function Update-GroupPsql{
    #Paramètre d'entré de la fonction
    try {        
        # Récupère les permissions mises sur le disque C: pour chaque groupe faisant parti des administrateur domaine AD 
        $list_domain_groups = getPermissionAD

        foreach ($group in $list_domain_groups ){
            #Droit de du groupe de la base de donnée 
            $select_permission_db = $group.permissions.select       
            $create_permission_db =$group.permissions.create   
            $update_permission_db = $group.permissions.update          
            $delete_permission_db = $group.permissions.delete  
            $super_user = $group.permissions.super_user

            #Variable pour savoir si les permissions sont déjà attribués
            $function_procedure_permission = $false
            #Les roles sont enregistrés en minuscule peut importe le input dans PG
            $group_name = ($group.name).ToLower()
            # permission table et de la base de données. 
            $group_exist_query = "SELECT 1 FROM pg_roles WHERE rolname = '$group_name';"

            $table =  psqlCommand($group_exist_query)
            $create_group_query =''
            if ($null -eq $table) {
                $create_group_query = "CREATE ROLE $group_name;"                
            }else{
                #Pour Faire un ménage des permissions sans trop de difficulté en enelvant tout les permission puisque ce n'est pas nécessaire
                $create_group_query += "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM $group_name;`n"
                $create_group_query += "ALTER ROLE $group_name WITH NOSUPERUSER;`n"
            }
            psqlCommand($create_group_query)
            
            $permission_query = ""
            if ($super_user) {
                $permission_query += "ALTER ROLE $group_name WITH SUPERUSER;"
                $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $group_name;`n"
                $function_procedure_permission = $true
            }
            if ($select_permission_db || $super_user) { 
                $permission_query += "GRANT USAGE ON SCHEMA public TO $group_name;`n"
                $permission_query += "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $group_name;`n"
                $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO $group_name;`n"
            }
            if ($create_permission_db || $super_user) { 
                $permission_query += "GRANT CREATE ON SCHEMA public TO $group_name;`n"
                $permission_query += "GRANT INSERT ON ALL TABLES IN SCHEMA public TO $group_name;`n"  
            }
            if ($update_permission_db || $super_user) {
                $permission_query += "GRANT UPDATE ON ALL TABLES IN SCHEMA public TO $group_name;`n"
                $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT UPDATE ON TABLES TO $group_name;`n"
                if (-not $function_procedure_permission) {
                    $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $group_name;`n"
                    $function_procedure_permission = $True
                }
            }
            if ($delete_permission_db || $super_user) {
                $permission_query += "GRANT DELETE ON ALL TABLES IN SCHEMA public TO $group_name;`n" 
                $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT DELETE ON TABLES TO $group_name;`n"
                if (-not $function_procedure_permission) {
                    $permission_query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $group_name;`n"
                }
            }            
            #Mettre en application les modification des permissions dans la base de donnée.
            psqlCommand($permission_query)
        }
    }
    catch {
        #Voici les erreurs 
        showError $_
    }
}

<#objectif de la fonction Get-GroupsPsqlPermissionsReport est de faire un rapport des permissions du serveur PSQL 
afin de voir des discordances entre active directory et postgre sql
#>
function Get-GroupsPsqlPermissionsReport{
    #https://www.postgresql.org/docs/current/information-schema.html

    $list_domain_groups = getPermissionAD
    $report_document_text = "Différence entre la base de donnée et PSQL :`n"
    #Récupére les permissions de la base de données pour une groupe.
    foreach ($group in $list_domain_groups ){
        $group_name = $group.name.ToLower()
        $select_query =
        "SELECT
            grantee as `"NomGroupe`",
            privilege_type
        FROM
            information_schema.role_table_grants
        WHERE
            grantee = '$group_name'
        GROUP BY grantee,privilege_type
        union
        SELECT
            rolname AS `"NomGroupe`",
            CASE 
                WHEN rolsuper = true THEN 'SUPER_USER'
                ELSE 'REGULAR_USER'
            END AS privilege_type
        FROM
            pg_roles
        WHERE
            rolname = '$group_name';"

        $psql_list_permissions = psqlCommand($select_query)
        #Copie l'objet des permissions pour traduire les permissions de la base de données en objet standard $PermissionMatrix
        $translate_psql_permission = $PermissionMatrix.PSObject.Copy()
        foreach ($permission in $psql_list_permissions){
            switch ($permission['privilege_type']) {
                'SELECT' {
                    $translate_psql_permission.select = $true
                }
                'INSERT' {
                    $translate_psql_permission.create = $true
                }
                'UPDATE' {
                    $translate_psql_permission.update = $true
                }
                'DELETE' {
                    $translate_psql_permission.delete = $true
                }
                'SUPER_USER' {
                    $translate_psql_permission.super_user = $true
                }
            }
        }

        #Compare les permissions de postgre avec les permissions des groupes sur le domain afin de trouver les différences.
        foreach ($permission_ad in $group.permissions) {
            foreach ($key in $PermissionMatrix.PSObject.Properties) {
                # Compare les permissions par leur clé
                $ad_permission = $permission_ad.$($key.name) 
                $psql_permission = $translate_psql_permission.$($key.name) 
                if ($ad_permission -ne $psql_permission) {
                    $report_document_text += "$group_name || ("+$key.name+") | PSQL = " + $psql_permission+ " | Active Directory = " + $ad_permission+"`n"
                }
            }
        }      
    }
    <#Rapport en Unix pour avoir des non de rapport différent et pouvoir les classer au besoin 
    https://www.reddit.com/r/PowerShell/comments/a5x0cj/converting_to_and_from_windowsunix_time/?rdt=43579
    #>
    $unix_time = (Get-Date(Get-Date).ToUniversalTime() -UFormat "%s")
    $report_name= "Rapport$unix_time.txt"
    #Fichier de sortie du rapport vers les documents
    Set-Content -Path $PATH_FILE_RERPORT+$report_name -Value $report_document_text  -Encoding UTF8  
}

<#L'objectif est de créer un nouvel utilisateur dans l'active directory sous un group faisant parti du domaine
Le script créé l'utilisteur dans la table utilisateur de la base de donnée 
Si l'utilisateur est full contrôle sur le C: on lui fait un utilisateur afin qu'il puisse faire les opérations 
de la base de donnée avec son utilisateur. On n'efface pas les utilisateur, mais on ne recré jamais un utilisateur avec
le même nom. On donne un mot de passe par défaut s'il n'est pas fourni 
#>
function Add-UserAdAndPsql([string] $username,[string] $first_name,[string]$last_name,[string] $group_name,[string] $email,[string] $password = $FIRST_TIME_PASSWORD_PSQL ) {
    try {
        $group_name = $group_name.ToLower()
        $email = $email.ToLower()
        ## Mise à jour des groupes PSQL pour représenter l'active directory
        Update-GroupPsql

        #Validation des paramètres entrés par l'utilisateur
        $invalide_input_format

        $invalide_input_format = verify_input $username "Le nom utilisateur est invalide. Entrez des lettre de a-Z ou des chiffre de 0-9" "^[a-zA-Z0-9_-]+$" "" 0  $true
        $invalide_input_format = verify_input $email "Le format d'email est invalide" "^[\w-]+@[\w-]+\.[\w-]{2,}$" "" 0  $true
        $invalide_input_format = verify_input $first_name "Le nom est invalide. Entrez des lettre de a-Z" "^[a-zA-Z-]+$" "" 0  $true
        $invalide_input_format = verify_input $last_name "Le nom de famille utilisateur est invalide. Entrez des lettre de a-Z " "^[a-zA-Z-]+$" "" 0  $true
        $invalide_input_format = verify_input $group_name "Le nom groupe est invalide. Entrez des lettre de a-Z ou des chiffre de 0-9" "^[a-zA-Z0-9_-]+$" "" 0  $true
        $invalide_input_format = verify_input $password "Le mot de passe n'est pas assez complexe" $PASSWORD_COMPLEXITY "" 0  $true        

        $secure_password
        $pg_postgre_value
        if ($password -ne ""){ 
            #Supprimer de la mémoire la variable du mot de passe maintenant qu'elle est dans une securestring   
            $secure_password = ConvertTo-SecureString ($password) -AsPlainText -Force

            #Si le mot de passe contient un ' on remplace ''. La raison est pour ne pas faire d'erreur dans postgres
            $pg_postgre_value = ConvertTo-SecureString ( $password -replace "'" , "''") -AsPlainText -Force
            Remove-Variable -Name "password"
        }else {
            #On donne le mot de passe par défaut
            $secure_password = ConvertTo-SecureString ($FIRST_TIME_PASSWORD_PSQL) -AsPlainText -Force 
        }

        #On valide si le group active directory existe
        $list_group = getPermissionAD
        # Méthode surchargé en quelque sorte si on ne fournit pas les paramètres True et false la logique retourne un boul                     
        $ad_validation = $false
        $ad_validation = iif (($list_group | Where-Object { ($_.name).ToLower() -eq "$group_name" }).Count -gt 0) $true logError "le groupe $group_name n'existe pas dans AD"

        # On vérifie le users de la base de donnée n'existe pas
        $query = "SELECT * FROM USERS"
        $database_user_list  = psqlCommand($query)
        $user_db_validation = $false
        $user_db_validation = iif (($database_user_list | Where-Object { ($_.email).ToLower() -eq "$email"}).Count -eq 0) $true logError "Le email $email est déjà utilisé dans la table users"

        # On vérifie les users du serveur  n'existe pas        
        $query = "SELECT * FROM USER"
        $server_user_list  = psqlCommand($query) 
        $user_server_validation = $false             
        $user_server_validation = iif (($server_user_list | Where-Object { ($_.user).ToLower() -eq "$username"}).Count -eq 0)  $true logError "Le $username est déjà utilisé sur le serveur"

        #Valide si l'utilisateur n'est pas déja dans l'AD
        try{        
            $user = Get-ADUser -Identity $username -ErrorAction SilentlyContinue
        }catch{
            $user = $false
        }
        if ($user) {
            logError "L'utilisateur $username existe déjà dans l'AD"
        }else {           
            if($ad_validation -and $user_server_validation -and $user_db_validation){
                $ad_object_guid = ($list_group | Where-Object { ($_.name).ToLower() -eq "$group_name" }).ObjectGUID
            
                #Information de domain actuel
                $forest = Get-ADForest
                #Ajouter le groupe au active directory
                New-ADUser `
                -SamAccountName $username `
                -UserPrincipalName "$username@$($forest.name)" `
                -GivenName $first_name `
                -Surname $last_name `
                -Name "$first_name $last_name" `
                -DisplayName "$first_name $last_name" `
                -EmailAddress $email `
                -AccountPassword $secure_password `
                -Enabled $true `
                -PassThru   

                #Récupère le nom non traduit parce que celui de la liste est changé pour être filtré. Seulement AD ne peut retrouver ce groupe
                $group = Get-ADObject -Filter "ObjectGUID -eq '$ad_object_guid'" -Properties Name
                # Add the new user to the specified group
                Add-ADGroupMember -Identity $group -Members $username 
                # On ajoute l'utilisateur dans la base de donnée , mais si la transaction échoue on la renverse en sql avec rollback
                #compris dans le commit si quelques chose échoue
                try{     
                    $query_user += "BEGIN;`n"               
                    if ($group_name = 'administrateur'){
                        #Créer le user 
                        $query_user += "CREATE USER $username WITH PASSWORD '"+(ConvertFrom-SecureStringToString $pg_postgre_value)+"';`n"
                        $query_user += "GRANT $group_name TO $username;`n"
                    }
                    $query_user += "INSERT INTO public.users(username, first_name, last_name, group_name, email, password)VALUES ('$username','$first_name','$last_name','$group_name','$email','"+(ConvertFrom-SecureStringToString $pg_postgre_value)+"' );`n"
                    $query_user += "COMMIT;`n" 
                    if ($null -ne (psqlCommand $query_user | Where-Object { $_ -match "error" }) ){
                        #Lance l'erreur pour effacer dans active directory
                        throw
                    } 
                }catch{
                    Remove-ADUser -Identity $username -Confirm:$false
                    logError "Les opérations on étés annulés à cause d'une erreur dans la base de données "
                }
            }else{                
                showError $_ 
            }
        }
    }
    catch {
        showError $_
    }
}
 #>

#Uniquement les fonction exporté pour le module afin de garder les fonctions privé non utilisable par l'utilisateur
#Export-ModuleMember -Function  Add-UserAdAndPsql, Get-GroupsPsqlPermissionsReport, Update-GroupPsql

#Add-UserAdAndPsql  "jonny_doe" "Jonny" "Doe" "Administrateur" "jonny_doe@example.com" "password123fk3209*840((48_))"


#Add-UserAdAndPsql  "jonny_doe" "Jonny" "Doe" "Administrateur" "jonny_doe@example.com" "weak_pass!"
#Add-UserAdAndPsql  "phillip_v" "Phillip" "Veilleux" "Administrateur" "ph_v@Cr431.com" "password123fk3209*840((48_))"
#Get-GroupsPsqlPermissionsReport
#Update-GroupPsql