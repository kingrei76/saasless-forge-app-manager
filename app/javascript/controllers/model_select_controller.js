import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "info"]

  changed() {
    const selected = this.selectTarget.selectedOptions[0]
    if (!selected || !selected.value) {
      this.infoTarget.classList.add("hidden")
      return
    }

    const context = selected.dataset.context
    const pricing = selected.dataset.pricing
    const modelId = selected.dataset.modelId

    const parts = []
    if (modelId) parts.push(`Model: ${modelId}`)
    if (context) parts.push(`Context: ${Number(context).toLocaleString()} tokens`)
    if (pricing && pricing !== "/") {
      const [input, output] = pricing.split("/")
      if (input && input !== "null") parts.push(`$${input}/$${output} per 1M tokens (in/out)`)
    }

    if (parts.length > 0) {
      this.infoTarget.textContent = parts.join(" · ")
      this.infoTarget.classList.remove("hidden")
    } else {
      this.infoTarget.classList.add("hidden")
    }

    // Auto-set service provider from the selected model's optgroup
    const optgroup = selected.closest("optgroup")
    if (optgroup) {
      const providerName = optgroup.label
      const providerSelect = this.element.closest("form")?.querySelector("[name*='service_provider_id']")
      if (providerSelect) {
        for (const opt of providerSelect.options) {
          if (opt.text === providerName) {
            providerSelect.value = opt.value
            break
          }
        }
      }
    }
  }
}
