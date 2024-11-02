function IIf($IfCondition, $IfTrue, $IfFalse ) {

    try {
        if ($IfTrue -eq ""){
            If ($IfCondition) {
                return $true}
            Else {
                return  $false
            } 
        }else {
            If ($IfCondition) {
                return $IfTrue}
            Else {
                return  $IfFalse
            } 
        }

    }
    catch {
        return  $null
    }
}

$error_message = IIF($user_input_message -eq "", "Invalid input.",$error_message)