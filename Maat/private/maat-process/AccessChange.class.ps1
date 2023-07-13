# AccessChange class : describe properties and behavior of a directory access change
class AccessChange {
  [string]$changeText
  [string]$changePreviousValue
  [string]$changeNewValue

  AccessChange([string]$text, [string]$previousValue, [string] $newValue) {
    $this.changeText = $text
    $this.changePreviousValue = $previousValue
    $this.changeNewValue = $newValue
  }

  [string]ToString() {
    return "$($this.changeText): $($this.changePreviousValue) > $($this.changeNewValue)"
  }
}