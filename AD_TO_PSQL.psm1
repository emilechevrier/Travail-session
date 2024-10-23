

#Varirable du module AD_TO_PSQL
#___________________________________________________________________________________________________________________________`

$connectionInstance


<# Paramètre de connexion à la base de donnée. On ne récupère le mots de passe admin pour la base de données afin de protéger l'utilisation du module. 
Nous le récupérons via les windows  #>

<# Paramètre de connexion de la VM. Soit entrer les informations manuellement soit utiliser ceux par défaut. Pour l'obectif du devoir elle seront présentes ici puisqu'il s'agit d'une 
vm Hyper-v avec aucune information sensible.
#>

# Database credentials
$PGUSER = "Admin_postgres"
$PGDATABASE = "CR431"
$PGPASSWORD =""
$PSQLPORT = "5432"
$PGHOST = "172.25.91.6"

#Variable globales pour le script
$SSHCONNECTION = $null


#Fonction privé du module AD_TO_PSQL
#___________________________________________________________________________________________________________________________`


<#Fonction IIF pour simuler la fonction IIF dans des language et pouvoir gérer les conditions null aussi en une seule ligne parce qu'un langage devrait avoir cette contraction qui permet 
de pas perdre de temps et rendre le code plus lisible. Si le vrai ou faux n'est pas définis ils sont True ou False par défaut #>
Function IIf($IfCondition, $IfTrue = $True, $IfFalse = $False) {
    try {
        If ($If) {
            return $IfTrue}
        Else {
            return  $IfFalse
        } 
    }
    catch {
        return  $null
    }
}

#Function récursive pour vérifier si les conditions sont respectées
Function VerifyInput([string] $user_input_message,[string] $error_message,[string] $IIFCondition,[string]$falseCondition,[int] $number_trial = $null){
    $user_input = Read-Host $user_input_message
    if ($null -eq $number_trial){
        $number_trial += 1
        If ($number_trial -gt 5){
            Write-Host $error_message
            return Throw "Trop d'erreur dans la lecture de l'entrée"
        }
    }
    if ($validated_input -match $IIFCondition){     
        return $validated_input        
    }else{
        VerifyInput($user_input_message, $IIFCondition, $trueCondition, $falseCondition, $number_trial)
    }
    
}

function menu_display{
    
}

#Secure string pour protéger le mot de passe est une recommendation de Microsoft
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
        psql_command($PGHOST, $PGDATABASE)
    }
    #Connexion à la base de données en utilisateur
    else{
        psql_command($PGHOST, $PGDATABASE, $username, $password)
    }
}

#___________________________________________________________________________________________________________________________`
#Commande du module AD_TO_PSQL
function Add-Group{
    #Paramètre d'entré de la fonction
    try {
        
        #Validation de toute les entrées
        $nomGroupe = VerifyInput("Entrez un nom de groupe puis appuis sur la touche Entrer.","SVP entrez au minimun un caratère","-ne $null","Throw",5 )

        #Création du groupe
        $query += "CREATE ROLE $nomGroupe;"
        
        $query +=  GRANT CREATE ON DATABASE $PGDATABASE TO $nomGroupe;
        GRANT CONNECT ON DATABASE $ TO my_group;
        
        GRANT USAGE ON SCHEMA public TO my_group;
        GRANT CREATE ON SCHEMA public TO my_group;
        
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO my_group;
        GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO my_group;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO my_group;
        
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO my_group;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO my_group;
        
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO my_group;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO my_group;
        
        GRANT my_group TO existing_user;
    


        execute_query()
    }
    catch {
        <#Do this if a terminating exception happens#>
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
Export-ModuleMember -Function  Add-Group, Add-User, Remove-Group, Remove-user, Edit-User, Edit-group

