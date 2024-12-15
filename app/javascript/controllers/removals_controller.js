import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="removals"
export default class extends Controller {
  remove() {
    this.element.remove()
    // When we hover the mouse on the flash message area, our mouse cursor changes even when the flash message is not visible anymore. This is because even if our flash message has an opacity of zero, it is still present in the DOM and above the rest of the page's content. To solve this problem, we need to remove the flash messages from the DOM when they reach an opacity of zero.
    // bin/rails generate stimulus removals
  }
}
