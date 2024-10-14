

#Varirable du module AD_TO_PSQL
#___________________________________________________________________________________________________________________________`

$connectionInstance


<# Paramètre de connexion à la base de donnée. On ne récupère le mots de passe admin pour la base de données afin de protéger l'utilisation du module. 
Nous le récupérons via les windows  #>

<# Paramètre de connexion de la VM. Soit entrer les informations manuellement soit utiliser ceux par défaut. Pour l'obectif du devoir elle seront présentes ici puisqu'il s'agit d'une 
vm Hyper-v avec aucune information sensible.
#>
$VMUSER = "vm_user"
$VMPASSWORD = "vm_password"


# Database credentials
$PGUSER = "Admin_postgres"
$PGDATABASE = "Default database"
$PGHOST = "localhost"

#Fonction privé du module AD_TO_PSQL
#___________________________________________________________________________________________________________________________`


function init_module{
    
}

function connect_database{
    <#Paramètre d'entré de la fonction. L'utilisateur peut être null parce que nous utiliserons l'admin postgre afin de faire des opérations sur la base de données autrement si
    l'utilisateur est données avec sont mot de passe il peut faire une lecture sur la base de données selon les permissions de sont groupes qui lui est accordés.
    #>
    param(
        [string]$server,
        [string]$database,
        [string]$username = $null,
        #Secure string pour protéger le mot de passe est une recommendation de Microsoft
        [securestring]$password = $null 
    )

    if ($username -eq $null){ 
        #Récupération de l'utilisateur admin de la base de données
        $username = $PGUSER
        
        #$password = récupération du mot de passe dans windows credentials voir si securesring fonctionnera avec les commandes PSQL
    }
}

function execute_query{
    #Paramètre d'entré de la fonction
    param(
        [string]$query,
        [string]$username = $null,
        [securestring]$password = $null
    )

    #Connexion à la base de données en admin
    if($username -eq $null){
        connect_database($PGHOST, $PGDATABASE)
    }
    #Connexion à la base de données en utilisateur
    else{
        connect_database($PGHOST, $PGDATABASE, $username, $password)
    }
}

#___________________________________________________________________________________________________________________________`
#Commande du module AD_TO_PSQL
function Add-Group{
    #Paramètre d'entré de la fonction
    param(
        [string]$groupname
    )
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

#Uniquement les fonction exporté pour le module afin de garder les fonctions privé non utilisable par l'utilisateur
Export-ModuleMember -Function Get-UserData, Add-Group, Add-User, Remove-Group, Remove-user

