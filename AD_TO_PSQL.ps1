#Variable globales pour le script
#___________________________________________________________________________________________________________________________`
# Database credentials
$PGUSER = "postgres"
$PGDATABASE = "CR431",'Database_2'
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


function menu_display{
    
}


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
        return  $null
    }
}


# Enregistre les mdp et user pour pouvoir se connecter à postgre comme administrateur du serveur de données postgre. Je n'ai pas codé le changement de mot de passe pour des raisons de temps , mais serait à considérer
function save_windows_credentials ([string] $credential_name) {
    try {
        # Vérifier si la cible existe déjà dans le gestionnaire de Windows Credentials
        $existingCredential = Get-StoredCredential -Target $credential_name

        if ($existingCredential -eq $false) {
            # Demander le mot de passe de manière sécurisée
            #Secure string empêche d'accéder directement au credential pour https://learn.microsoft.com/en-us/dotnet/api/system.security.securestring?view=net-8.0
            $password = ConvertTo-SecureString(verify_input "Entrez le mot de passe de cette utilisateur" "SVP entrez au minimun un caractère" "^[.*]*$" "" 3  $False)
            $user = verify_input "Entrez le nom de cette utilisateur postgre administrateur sur le serveur de la machine" "SVP entrez au minimun un caractère" "^[.*]*$" "" 3  $False 
    
            # Enregistrer les credentials dans le gestionnaire Windows Credentials
            #Secure string conversion pour utilisation https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/convertfrom-securestring?view=powershell-7.4
            New-StoredCredential -Target $credential_name -UserName $user -Password (ConvertFrom-SecureString $password) -Persist LocalMachine
    
            Write-Output "Les informations d'identification ont été enregistrées dans le gestionnaire Windows Credentials pour la cible : $credential_name."
        }
    }
    catch {
        
    }            
}

function connection_to_db_server(){

    save_windows_credentials $PG_WINDOWS_CRED_USER

    Get-StoredCredential -Target $PG_WINDOWS_CRED_USER

    $pgCredential = Get-StoredCredential -Target $target

    $username = $pgCredential.UserName
    $password = ($pgCredential.GetNetworkCredential().Password)


    $PGUSER = "localhost"  # Change if your PostgreSQL server is remote
    $user = "your_user"  # PostgreSQL superuser or an admin user
    $password = "your_password"  # Password for the admin user
    $newUser = "new_username"  # The new user you want to create
    $newUserPassword = "new_user_password"  # Password for the new user

# Set the password as an environment variable temporarily for use with psql
    

# Command to add a new user
    psql -h $host -U $pgCredential.UserName -d postgres -c "CREATE ROLE $newUser WITH LOGIN PASSWORD '$newUserPassword';"

# Clear the password from the environment variable
Remove-Item Env:PGPASSWORD



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
    # Décrémente le compteur d'essais
    #$number_trial -= 1
    return verify_input $user_input_message  $error_message $true_conditio_fail $false_condition_fail $number_trial $returnTrueOrFalse          
}

function psql_command([string]$server,[string]$database,[string]$username,[securestring] $password ){
    try {

        $username = IIf($username -eq $null,$PGUSER,$username)  
        [System.Environment]::SetEnvironmentVariable('PGPASSWORD', $connection.Password)
        psql -U $username -d $database -h $server '-c' $query
    }
    catch {
        throw "Ha non quelque chose fonctionne pas: $_"
    }
}

function execute_query ([string]$query,[string]$username = $null,[securestring]$password = $null){
    
    $password = IIf($password -eq $null,$PGPASSWORD,$password)
    <#Comparaison des valeurs pour éviter les valeur null on se connect en admin. Ce cas de figure arrive principalement dans 
    les connections qui doivent simplement modifier la base de données pour correspondre au active directory#>    #Connexion à la base de données en admin
    if($username -eq $null){
        psql_command($PGHOST, $PGDATABASE[0])
    }
    #Connexion à la base de données en utilisateur
    else{
        psql_command($PGHOST, $PGDATABASE[0], $username, $password)
    }
}

#___________________________________________________________________________________________________________________________`
#Commande du module AD_TO_PSQL
function Add-Group{
    #Paramètre d'entré de la fonction
    try {        
        #Validation de toute les entrées        
        $groupName = verify_input "Entrez un nom de groupe puis appuis sur la touche Entrer." "SVP entrez au minimun un caractère" "^[A-Za-z]*$" "" 4  $False

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

        Write-Host $select_permission_db,$update_permission_db,$delete_permission_db,$super_user

        #Liste des accès de contrôle actuelle sur le répertoire C:
        $acl = Get-Acl "C:\"
        #Création du groupe
        $query += "CREATE ROLE $groupName;"
        
        $function_procedure_permission = $false

        $write_folder_permission = $null   
        # permission table et de la base de données
        if ($super_user) {
            $query = "ALTER ROLE $groupName WITH SUPERUSER;"
        }else{
            if ($select_permission_db) { 
                $query += "GRANT CONNECT ON DATABASE $PGDATABASE[0] TO $groupName;" 
                $query += "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $groupName;"
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO $groupName;"
            }
            if ($write_permission_db) { 
                $query += "GRANT CREATE ON DATABASE $PGDATABASE[0] TO $groupName;"
                $query += "GRANT INSERT ON ALL TABLES IN SCHEMA public TO $groupName;"
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT ON TABLES TO $groupName;"
                
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $groupName;"  
            }
            if ($update_permission_db) {
                $query += "GRANT TEMPORARY ON DATABASE $PGDATABASE[0] TO $groupName;"
                $query += "GRANT UPDATE ON ALL TABLES IN SCHEMA public TO $groupName;"
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT UPDATE ON TABLES TO $groupName;"
                if (-not $function_procedure_permission){
                    $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $groupName;"
                    $function_procedure_permission = $True
                }
            }
            if ($delete_permission_db) {
                $query += "GRANT TEMPORARY ON DATABASE $PGDATABASE[0] TO $groupName;"
                $query += "GRANT DELETE ON ALL TABLES IN SCHEMA public TO $groupName;" 
                $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, DELETE ON TABLES TO $groupName;"
                if (-not $function_procedure_permission){
                    $query += "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $groupName;"
                }
            }
        }
        #_______________________________________
        #permission sur le groupe 

        if ($super_user) { 
            # permissions sont mis dans les objets .net 
            $read_folder_permission = New-Object System.Security.AccessControl.FileSystemAccessRule($groupName, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
            # Ajouter les permission à l'objet
            $acl.SetAccessRule($read_folder_permission)
        }        
        if ($select_permission_db) { 
            # permissions sont mis dans les objets .net 
            $read_folder_permission = New-Object System.Security.AccessControl.FileSystemAccessRule($groupName, "ReadAndExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
            # Ajouter les permission à l'objet
            $acl.SetAccessRule($read_folder_permission)
        }
        if (($update_permission_db -or $write_folder_permission) -or ($update_permission_db -and $write_folder_permission)) {
            $write_folder_permission = New-Object System.Security.AccessControl.FileSystemAccessRule($groupName, "Write", "ContainerInherit, ObjectInherit", "None", "Allow") 
            $acl.SetAccessRule($write_folder_permission)
        }          
        if ($delete_permission_db) {
            # permission table et de la base de données
            $query += "GRANT TEMPORARY ON DATABASE $PGDATABASE[0] TO $groupName;"
            $query += "GRANT DELETE ON ALL TABLES IN SCHEMA public TO $groupName;" 
            $delete_folder_permission = New-Object System.Security.AccessControl.FileSystemAccessRule($groupName, "Delete", "ContainerInherit, ObjectInherit", "None", "Allow")
            $acl.SetAccessRule($delete_folder_permission)
        }

        $query += "GRANT USAGE ON SCHEMA public TO $groupName;"
        $query += "GRANT CREATE ON SCHEMA public TO $groupName;"
        
        $query += "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO $groupName;"
        
         
        $query += "GRANT $groupName TO existing_user;"

        Write-Host $query
        Write-Host $select_permission_db,$update_permission_db,$delete_permission_db,$super_user
        Write-Host $acl

        #Mettre en application les modification des permissions sur répertoire C: et dans la base de donnée.
        Set-Acl "C:\" $acl
        execute_query($query)
    }
    catch {
        #Voici les erreurs 
        Write-Host "La fonction à échoué après plusieurs erreurs"
    }
}


function Add-User{
    param(
        [string]$groupname
    )
}

function Remove-Group{
    param(
        [string]$groupname
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
        [string]$groupname
    )
}


#Uniquement les fonction exporté pour le module afin de garder les fonctions privé non utilisable par l'utilisateur
#Export-ModuleMember -Function  Add-Group, Add-User, Remove-Group, Remove-user, Edit-User, Edit-group

Add-Group