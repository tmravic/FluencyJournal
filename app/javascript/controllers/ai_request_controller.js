import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ai-request"
export default class extends Controller {
  static targets = ["prompt", "originalLanguage", "learningLanguage"]

  combineFields(event) {
    const originalLanguage = this.originalLanguageTarget.value.trim();
    const learningLanguage = this.learningLanguageTarget.value.trim();

    // Also later add any notes sent
    const combinedPrompt = `Original Language: ${originalLanguage}\nLearning Language: ${learningLanguage}`;

    this.promptTarget.value = combinedPrompt;
  }
}
