function Global:prompt {
    $e = "$([char]27)"
    $heart = "❤", "🧡", "💛", "💚", "💙", "💜", "💔", "💕", "💓", "💗", "💖", "💘", "💝" | Get-Random
    "$($e)[107m$($e)[30mI${heart}PS$($e)[37m$($e)[49m> "
}