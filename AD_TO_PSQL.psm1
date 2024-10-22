

#Varirable du module AD_TO_PSQL
#___________________________________________________________________________________________________________________________`

$connectionInstance


<# Paramètre de connexion à la base de donnée. On ne récupère le mots de passe admin pour la base de données afin de protéger l'utilisation du module. 
Nous le récupérons via les windows  #>

<# Paramètre de connexion de la VM. Soit entrer les informations manuellement soit utiliser ceux par défaut. Pour l'obectif du devoir elle seront présentes ici puisqu'il s'agit d'une 
vm Hyper-v avec aucune information sensible.
#>
$VMUSER = "Administrator"
$VMPASSWORD = ""

# Putty path
$PUTTYPATH = "C:\Program Files\PuTTY\putty.exe"
$PLINLKPATH = "C:\Program Files\PuTTY\plink.exe"	

# Database credentials
$PGUSER = "Admin_postgres"
$PGDATABASE = "Default database"
$PGPASSWORD =""
$PSQLPORT = "5432"
$PGHOST = "172.25.91.6"

#Variable globales pour le script
$SSHCONNECTION = $null

$REGEXIPV4 = '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'

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
Function VerifyInput([string] $user_input_message,[string] $IIFCondition,[string]$trueCondition,[string]$falseCondition,[int] $number_trial = $null){

    if ($null -eq $number_trial){
        $number_trial += 1
        If ($number_trial -gt 5){
            Write-Host "Concentrez vous sur la question ceci ne respect pas le format demandé"
            return $false
        }
    }
    $validated_input = IIf(($input -match $IIFCondition), $trueCondition, $falseCondition)
    if ($validated_input -eq $falseCondition){     
        VerifyInput($user_input_message, $IIFCondition, $trueCondition, $falseCondition, $number_trial)
    }
    return $validated_input
}



function init_module {
    # Install PuTTY if it's not present
    if (!(Test-Path $PUTTYPATH)) {
        Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-installer.msi" -OutFile "$env:TEMP\putty-installer.msi"
        Start-Process msiexec.exe -ArgumentList "/i $env:TEMP\putty-installer.msi /quiet" -Wait
    }
      $process = Start-Process plink -ArgumentList "-ssh $VMUSER@$PGHOST -pw $VMPASSWORD dir" -Wait
      Write-Host $process.ExitCode
      Write-Host $process.StandardOutput
    # Prompt before exit
    Write-host $SSHCONNECTION
    Write-Host "Press Enter to exit."
    Read-Host
}


function menu_display{
    
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

