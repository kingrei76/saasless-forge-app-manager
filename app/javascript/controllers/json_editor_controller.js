import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "error"]

  validate() {
    const textarea = this.textareaTarget
    const value = textarea.value.trim()

    if (!value) {
      this.clearError()
      return
    }

    try {
      JSON.parse(value)
      this.clearError()
      textarea.classList.remove("textarea-error")
      textarea.classList.add("textarea-success")
    } catch (e) {
      this.showError(e.message)
      textarea.classList.remove("textarea-success")
      textarea.classList.add("textarea-error")
    }
  }

  format() {
    const textarea = this.textareaTarget
    try {
      const parsed = JSON.parse(textarea.value)
      textarea.value = JSON.stringify(parsed, null, 2)
      this.clearError()
    } catch (e) {
      this.showError(e.message)
    }
  }

  showError(msg) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = msg
      this.errorTarget.classList.remove("hidden")
    }
  }

  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ""
      this.errorTarget.classList.add("hidden")
    }
  }
}
