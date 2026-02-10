import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clientSearch", "clientSelect", "appSearch", "appList", "appValidation", "newAppsContainer"]

  connect() {
    this.validateApps()
  }

  filterClients(event) {
    const searchTerm = event.target.value.toLowerCase()
    const options = this.clientSelectTarget.querySelectorAll("option")

    options.forEach(option => {
      if (option.value === "") return // Skip the placeholder
      const text = option.textContent.toLowerCase()
      option.style.display = text.includes(searchTerm) ? "" : "none"
    })
  }

  showClientDropdown() {
    // Focus handling if needed
  }

  filterAppsByClient() {
    const selectedClientId = this.clientSelectTarget.value

    if (!this.hasAppListTarget) return

    const appItems = this.appListTarget.querySelectorAll(".app-item")

    appItems.forEach(item => {
      if (!selectedClientId) {
        // No client selected - show all apps
        item.style.display = ""
      } else {
        // Filter by client
        const clientIds = (item.dataset.clientIds || "").split(",")
        if (clientIds.includes(selectedClientId)) {
          item.style.display = ""
        } else {
          item.style.display = "none"
        }
      }
    })
  }

  filterApps(event) {
    const searchTerm = event.target.value.toLowerCase()

    if (!this.hasAppListTarget) return

    const appItems = this.appListTarget.querySelectorAll(".app-item")

    appItems.forEach(item => {
      const appName = item.dataset.appName || ""
      if (appName.includes(searchTerm)) {
        item.style.display = ""
      } else {
        item.style.display = "none"
      }
    })
  }

  addNewApp() {
    const container = this.newAppsContainerTarget
    const row = document.createElement("div")
    row.className = "flex gap-2 new-app-row"
    row.innerHTML = `
      <input type="text" name="new_app_names[]" class="input input-bordered input-sm flex-1" placeholder="New app name" data-action="input->bid-wizard#validateApps">
      <button type="button" class="btn btn-ghost btn-sm text-error" data-action="click->bid-wizard#removeNewApp">
        <i class="fas fa-times"></i>
      </button>
    `
    container.appendChild(row)
    row.querySelector("input").focus()
    this.validateApps()
  }

  removeNewApp(event) {
    event.currentTarget.closest(".new-app-row").remove()
    this.validateApps()
  }

  validateApps() {
    const hasSelectedApp = this.hasAppListTarget &&
      this.appListTarget.querySelectorAll("input[type='checkbox']:checked").length > 0

    const newAppInputs = this.newAppsContainerTarget.querySelectorAll("input[name='new_app_names[]']")
    const hasNewApp = Array.from(newAppInputs).some(input => input.value.trim() !== "")

    const isValid = hasSelectedApp || hasNewApp

    if (this.hasAppValidationTarget) {
      if (isValid) {
        this.appValidationTarget.classList.add("hidden")
      } else {
        // Don't show error until user tries to submit
      }
    }

    return isValid
  }

  validateAndSubmit(event) {
    if (!this.validateApps()) {
      event.preventDefault()
      if (this.hasAppValidationTarget) {
        this.appValidationTarget.classList.remove("hidden")
        this.appValidationTarget.scrollIntoView({ behavior: "smooth", block: "center" })
      }
      return false
    }
    // Form will submit naturally
  }
}
