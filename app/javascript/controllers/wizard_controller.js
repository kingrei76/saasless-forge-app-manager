import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "loading"]

  connect() {
    // Handle loading states
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
  }
}
